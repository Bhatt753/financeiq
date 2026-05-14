#goals-Handles goal setting, analysis, and tracking routes

from flask import (Blueprint, render_template, request,
                   redirect, session, url_for)
from models.database import (
    get_monthly_history, get_user_loans,
    save_goal, get_user_goals, get_goal_by_id,
    complete_goal, delete_goal
)
from services.goal_engine import analyze_goal
from services.loan_engine import analyze_all_loans
from functools import wraps

goals_bp = Blueprint("goals", __name__)


def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated


@goals_bp.route("/goal", methods=["GET", "POST"])
@login_required
def goal():
    user_id = session["user_id"]

    # Auto-fetch user's financial data
    history      = get_monthly_history(user_id)
    user_loans   = get_user_loans(user_id)
    loan_analysis= analyze_all_loans(user_loans)
    active_goals = get_user_goals(user_id)

    # Get latest financial data
    if history:
        latest         = history[0]
        income         = latest["income"]
        # savings already has EMI deducted (fixed in metrics)
        savings        = max(latest["savings"], 0)
        variable_total = latest.get("variable_total", 0)
    else:
        income         = 0
        savings        = 0
        variable_total = 0

    # Calculate total EMI
    total_emi = loan_analysis["total_emi"] if loan_analysis["has_loans"] else 0

    # Loans completing soon
    completing_loans = loan_analysis.get("completing_soon", [])

    # Extra: calculate free savings after loans complete
    completing_soon_emi = sum(
        l["emi"] for l in completing_loans
    ) if completing_loans else 0

    if request.method == "POST":
        goal_name   = request.form.get("goal_name", "").strip()
        goal_amount = float(request.form.get("goal_amount", 0))
        goal_months = int(request.form.get("goal_months", 12))

        if not goal_name or goal_amount <= 0 or goal_months <= 0:
            return render_template("goal.html",
                error          = "Please fill all fields correctly!",
                history        = history,
                income         = income,
                savings        = savings,
                total_emi      = total_emi,
                active_goals   = active_goals,
                completing_loans = completing_loans,
                has_data       = len(history) > 0
            )

        # Analyze goal using real data
        result, err = analyze_goal(
            goal_name      = goal_name,
            goal_amount    = goal_amount,
            goal_months    = goal_months,
            income         = income,
            current_savings= savings,
            variable_total = variable_total,
            category_totals= {}
        )

        if err:
            return render_template("goal.html",
                error          = err,
                history        = history,
                income         = income,
                savings        = savings,
                total_emi      = total_emi,
                active_goals   = active_goals,
                completing_loans = completing_loans,
                has_data       = len(history) > 0
            )

        # Add loan awareness to result
        result["loan_impact"]      = _calculate_loan_impact(
            loan_analysis, goal_months, savings
        )
        result["completing_loans"] = completing_loans
        result["total_emi"]        = total_emi

        # Save goal to database
        save_goal(user_id, goal_name, goal_amount, goal_months)

        # Build monthly progress for graph
        monthly_progress = _build_monthly_progress(
            savings, goal_amount, goal_months,
            completing_loans
        )
        result["monthly_progress"] = monthly_progress

        return render_template("goal_result.html",
            result  = result,
            income  = income,
            savings = savings
        )

    return render_template("goal.html",
        history          = history,
        income           = income,
        savings          = savings,
        total_emi        = total_emi,
        active_goals     = active_goals,
        completing_loans = completing_loans,
        has_data         = len(history) > 0
    )


@goals_bp.route("/goals/complete/<int:goal_id>")
@login_required
def mark_complete(goal_id):
    complete_goal(goal_id, session["user_id"])
    return redirect(url_for("goals.my_goals"))


@goals_bp.route("/goals/delete/<int:goal_id>")
@login_required
def remove_goal(goal_id):
    delete_goal(goal_id, session["user_id"])
    return redirect(url_for("goals.my_goals"))


@goals_bp.route("/my_goals")
@login_required
def my_goals():
    user_id      = session["user_id"]
    active_goals = get_user_goals(user_id)
    history      = get_monthly_history(user_id)

    savings = max(history[0]["savings"], 0) if history else 0

    # Enrich each goal with progress
    enriched = []
    for g in active_goals:
        months_elapsed = 0  # Will calculate based on created_at
        saved_so_far   = savings * max(months_elapsed, 1)
        progress_pct   = min(
            round((saved_so_far / g["goal_amount"]) * 100, 1)
            if g["goal_amount"] > 0 else 0,
            100
        )
        enriched.append({
            **g,
            "saved_so_far" : round(saved_so_far, 2),
            "progress_pct" : progress_pct,
            "remaining"    : max(g["goal_amount"] - saved_so_far, 0)
        })

    return render_template("my_goals.html",
        goals   = enriched,
        savings = savings
    )


def _calculate_loan_impact(loan_analysis, goal_months, current_savings):
    """Calculate how loans affect goal achievement"""
    if not loan_analysis["has_loans"]:
        return None

    completing = [
        l for l in loan_analysis.get("completing_soon", [])
        if l["months_remaining"] <= goal_months
    ]

    if not completing:
        return None

    freed_amount = sum(l["emi"] for l in completing)
    new_savings  = current_savings + freed_amount

    return {
        "loans_completing" : len(completing),
        "freed_amount"     : freed_amount,
        "new_savings_rate" : new_savings,
        "boost_message"    : (
            f"{len(completing)} loan(s) completing during your goal period "
            f"will free ₹{freed_amount:,.0f}/month — "
            f"boosting your savings to ₹{new_savings:,.0f}/month!"
        )
    }


def _build_monthly_progress(monthly_savings, goal_amount,
                             goal_months, completing_loans):
    """Build month by month projection for graph"""
    progress    = []
    accumulated = 0

    for month in range(1, goal_months + 1):
        # Check if any loan completes this month
        extra = sum(
            l["emi"] for l in completing_loans
            if l["months_remaining"] == month
        )
        accumulated += monthly_savings + extra
        progress.append({
            "month"      : month,
            "accumulated": round(min(accumulated, goal_amount), 2),
            "target"     : goal_amount,
            "pct"        : round(
                min((accumulated / goal_amount) * 100, 100), 1
            )
        })

    return progress