# routes/finance.py

from flask import Blueprint, render_template, request, redirect, session, url_for
from models.database import save_monthly_data, save_expenses, \
    get_monthly_entry, get_expenses_for_month, update_monthly_entry
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
        
        # Parse loans
        loan_types       = request.form.getlist("loan_type[]")
        loan_emis        = request.form.getlist("loan_emi[]")
        loan_rates       = request.form.getlist("loan_rate[]")
        loan_outstanding = request.form.getlist("loan_outstanding[]")
        emergency_fund   = float(request.form.get("emergency_fund", 0) or 0)

        loans = []
        for i in range(len(loan_types)):
            try:
                emi = float(loan_emis[i]) if loan_emis[i] else 0
                rate = float(loan_rates[i]) if loan_rates[i] else 0
                outstanding = float(loan_outstanding[i]) if loan_outstanding[i] else 0
                if emi > 0:
                    loans.append({
                        "type"         : loan_types[i],
                        "emi"          : emi,
                        "interest_rate": rate,
                        "outstanding"  : outstanding
                    })
            except (ValueError, IndexError):
                continue

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
        metrics, err = calculate_metrics(income, expenses)
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

    return render_template("add_data.html",
        categories=Config.CATEGORIES,
        months=_get_months())


@finance_bp.route("/edit_entry/<int:entry_id>", methods=["GET", "POST"])
@login_required
def edit_entry(entry_id):
    entry = get_monthly_entry(entry_id, session["user_id"])
    if not entry:
        return redirect(url_for("dashboard.history"))

    expenses = get_expenses_for_month(
        session["user_id"], entry["month"], entry["year"]
    )

    if request.method == "POST":
        income, err = validate_income(request.form.get("income"))
        if err:
            return render_template("edit_entry.html",
                entry=entry, expenses=expenses,
                categories=Config.CATEGORIES, error=err)

        names      = request.form.getlist("expense_name[]")
        amounts    = request.form.getlist("expense_amount[]")
        categories = request.form.getlist("expense_category[]")
        types      = request.form.getlist("expense_type[]")

        new_expenses = []
        for i in range(len(names)):
            if names[i] and amounts[i]:
                new_expenses.append({
                    "name"    : names[i].strip(),
                    "category": categories[i],
                    "type"    : types[i],
                    "amount"  : float(amounts[i])
                })

        metrics, err = calculate_metrics(income, new_expenses)
        if err:
            return render_template("edit_entry.html",
                entry=entry, expenses=expenses,
                categories=Config.CATEGORIES, error=err)

        update_monthly_entry(entry_id, income, metrics)

        from models.database import get_db
        conn = get_db()
        conn.execute(
            "DELETE FROM expenses WHERE user_id=? AND month=? AND year=?",
            (session["user_id"], entry["month"], entry["year"])
        )
        conn.commit()
        conn.close()

        save_expenses(session["user_id"], entry["month"], entry["year"], new_expenses)

        return redirect(url_for("dashboard.history"))

    return render_template("edit_entry.html",
        entry=entry, expenses=expenses, categories=Config.CATEGORIES)


def _get_months():
    return ["January","February","March","April","May",
            "June","July","August","September","October",
            "November","December"]