# routes/goals.py

from flask import Blueprint, render_template, request, redirect, session, url_for
from services.goal_engine import analyze_goal
from utils.validators import validate_goal

goals_bp = Blueprint("goals", __name__)


def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated


@goals_bp.route("/goal", methods=["GET", "POST"])
@login_required
def goal():
    if request.method == "POST":
        values, errors = validate_goal(
            request.form.get("goal_amount"),
            request.form.get("goal_months"),
            request.form.get("savings"),
            request.form.get("income")
        )

        if errors:
            return render_template("goal.html", error=errors[0])

        # Get category totals from form if available
        category_totals = {}
        variable_total  = float(request.form.get("variable_total", 0))

        result, err = analyze_goal(
            goal_name      = request.form.get("goal_name", "My Goal"),
            goal_amount    = values["goal_amount"],
            goal_months    = values["goal_months"],
            income         = values["income"],
            current_savings= values["savings"],
            variable_total = variable_total,
            category_totals= category_totals
        )

        if err:
            return render_template("goal.html", error=err)

        return render_template("goal_result.html", result=result)

    return render_template("goal.html")