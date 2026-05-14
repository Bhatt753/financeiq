# routes/dashboard.py

from flask import Blueprint, render_template, redirect, session, url_for
from models.database import get_monthly_history, get_monthly_entry, \
    delete_monthly_entry, get_expenses_for_month
from services.trends import analyze_trends, calculate_annual_summary

dashboard_bp = Blueprint("dashboard", __name__)


def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated


@dashboard_bp.route("/dashboard")
@login_required
def dashboard():
    history = get_monthly_history(session["user_id"])
    trends  = analyze_trends(history)
    summary = calculate_annual_summary(history)
    return render_template("dashboard.html",
        history=history, trends=trends, summary=summary)


@dashboard_bp.route("/history")
@login_required
def history():
    history = get_monthly_history(session["user_id"])
    return render_template("history.html", history=history)


@dashboard_bp.route("/edit_entry/<int:entry_id>", methods=["GET", "POST"])
@login_required
def edit_entry(entry_id):
    from models.database import get_expenses_for_month, delete_expenses_for_month
    from services.metrics import calculate_metrics
    from config import Config

    user_id = session["user_id"]
    entry   = get_monthly_entry(entry_id, user_id)

    if not entry:
        return redirect(url_for("dashboard.history"))

    if request.method == "POST":
        from flask import request as req
        income = float(req.form.get("income", 0))
        month  = entry["month"]
        year   = entry["year"]

        names      = req.form.getlist("expense_name[]")
        categories = req.form.getlist("expense_category[]")
        types      = req.form.getlist("expense_type[]")
        amounts    = req.form.getlist("expense_amount[]")

        expenses = []
        for i in range(len(names)):
            try:
                amt = float(amounts[i])
                if amt > 0:
                    expenses.append({
                        "name"    : names[i],
                        "category": categories[i],
                        "type"    : types[i],
                        "amount"  : amt
                    })
            except (ValueError, IndexError):
                continue

        from models.database import get_user_loans
        user_loans     = get_user_loans(user_id)
        emergency_fund = float(req.form.get("emergency_fund", 0) or 0)

        loans = []
        for loan in user_loans:
            loans.append({
                "type"         : loan["loan_type"],
                "emi"          : loan["emi"],
                "interest_rate": loan["interest_rate"],
                "outstanding"  : loan.get("principal", 0)
            })

        metrics, err = calculate_metrics(income, expenses, loans, emergency_fund)
        if err:
            return redirect(url_for("dashboard.history"))

        from models.database import update_monthly_entry
        delete_expenses_for_month(user_id, month, year)
        update_monthly_entry(entry_id, income, metrics)

        from models.database import save_expenses
        save_expenses(user_id, month, year, expenses)

        return redirect(url_for("dashboard.history"))


    expenses = get_expenses_for_month(user_id, entry["month"], entry["year"])
    expenses_list = []
    for e in expenses:
        expenses_list.append({
            "name"    : e["name"] if isinstance(e, dict) else e[4],
            "category": e["category"] if isinstance(e, dict) else e[5],
            "type"    : e["type"] if isinstance(e, dict) else e[6],
            "amount"  : e["amount"] if isinstance(e, dict) else e[7],
        })

    from config import Config
    return render_template("edit_entry.html",
        entry    = entry,
        expenses = expenses_list,
        categories = Config.CATEGORIES
    )


@dashboard_bp.route("/health")
@login_required
def health():
    from models.database import get_user_loans
    from services.health_score import calculate_health_score

    user_id = session["user_id"]
    history = get_monthly_history(user_id)

    if not history:
        return render_template("health.html",
            has_data = False,
            score    = None,
            month    = "",
            year     = ""
        )

    latest       = history[0]
    expenses_raw = get_expenses_for_month(user_id, latest["month"], latest["year"])
    user_loans   = get_user_loans(user_id)

    expenses = []
    for e in expenses_raw:
        expenses.append({
            "name"    : e["name"] if isinstance(e, dict) else e[4],
            "category": e["category"] if isinstance(e, dict) else e[5],
            "type"    : e["type"] if isinstance(e, dict) else e[6],
            "amount"  : e["amount"] if isinstance(e, dict) else e[7],
        })

    loans = []
    for loan in user_loans:
        loans.append({
            "type"         : loan["loan_type"],
            "emi"          : loan["emi"],
            "interest_rate": loan["interest_rate"],
            "outstanding"  : loan.get("principal", 0)
        })

    health_data = calculate_health_score(
        latest["income"], expenses, loans, 0
    )

    return render_template("health.html",
        has_data = True,
        score    = health_data,
        month    = latest["month"],
        year     = latest["year"],
        income   = latest["income"]
    )