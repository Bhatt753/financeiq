from flask import Blueprint, render_template, request, redirect, session, url_for
from models.database import save_monthly_data, save_expenses
from services.metrics import calculate_metrics
from services.advice  import generate_advice
from utils.validators import validate_income, validate_expenses
from config import Config

finance_bp = Blueprint("finance", __name__)


def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated


@finance_bp.route("/add_data", methods=["GET", "POST"])
@login_required
def add_data():
    if request.method == "POST":
        # Validate income
        income, err = validate_income(request.form.get("income"))
        if err:
            return render_template("add_data.html",
                categories=Config.CATEGORIES,
                months=_get_months(),
                error=err)

        month = request.form.get("month")
        year  = request.form.get("year")

        try:
            year = int(year)
        except (ValueError, TypeError):
            return render_template("add_data.html",
                categories=Config.CATEGORIES,
                months=_get_months(),
                error="Invalid year.")

        # Validate expenses
        names      = request.form.getlist("expense_name[]")
        amounts    = request.form.getlist("expense_amount[]")
        categories = request.form.getlist("expense_category[]")
        types      = request.form.getlist("expense_type[]")

        _, errors = validate_expenses(names, amounts)
        if errors:
            return render_template("add_data.html",
                categories=Config.CATEGORIES,
                months=_get_months(),
                error=errors[0])
        
        # Use saved loans from database
        from models.database import get_user_loans
        user_loans     = get_user_loans(session["user_id"])
        emergency_fund = float(request.form.get("emergency_fund", 0) or 0)

        loans = []
        for loan in user_loans:
            loans.append({
                "type"         : loan["loan_type"],
                "emi"          : loan["emi"],
                "interest_rate": loan["interest_rate"],
                "outstanding"  : loan.get("principal", 0)
            })

        # Build expenses list
        expenses = []
        for i in range(len(names)):
            if names[i] and amounts[i]:
                expenses.append({
                    "name"    : names[i].strip(),
                    "category": categories[i],
                    "type"    : types[i],
                    "amount"  : float(amounts[i])
                })

        # Calculate metrics
        metrics, err = calculate_metrics(income, expenses, loans, emergency_fund)
        if err:
            return render_template("add_data.html",
                categories=Config.CATEGORIES,
                months=_get_months(),
                error=err)

        # Save to database
        success, err = save_monthly_data(
            session["user_id"], month, year, income, metrics
        )
        if not success:
            return render_template("add_data.html",
                categories=Config.CATEGORIES,
                months=_get_months(),
                error=err)

        save_expenses(session["user_id"], month, year, expenses)

        advice = generate_advice(metrics, session.get("profession"))

        return render_template("results.html",
            metrics  = metrics,
            advice   = advice,
            expenses = expenses,
            month    = month,
            year     = year
        )

    from models.database import get_user_loans
    existing_loans = get_user_loans(session["user_id"])

    return render_template("add_data.html",
        categories     = Config.CATEGORIES,
        months         = _get_months(),
        existing_loans = existing_loans)



def _get_months():
    return ["January","February","March","April","May",
            "June","July","August","September","October",
            "November","December"]