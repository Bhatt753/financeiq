# routes/loans.py

from flask import (Blueprint, render_template, request,
                   redirect, session, url_for, jsonify)
from models.database import (save_loan, get_user_loans,
                              get_loan_by_id, delete_loan)
from services.loan_engine import (analyze_all_loans,
                                   generate_loan_advice)
from functools import wraps

loans_bp = Blueprint("loans", __name__)


def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated


LOAN_TYPES = [
    "Home Loan", "Personal Loan", "Car Loan",
    "Education Loan", "Credit Card", "Business Loan", "Other"
]

MONTHS = ["January","February","March","April","May","June",
          "July","August","September","October","November","December"]


@loans_bp.route("/loans")
@login_required
def loans():
    user_loans    = get_user_loans(session["user_id"])
    loan_analysis = analyze_all_loans(user_loans)

    # Get income from latest monthly data
    from models.database import get_monthly_history
    history = get_monthly_history(session["user_id"])
    income  = history[0]["income"] if history else 0
    savings = history[0]["savings"] if history else 0

    advice = generate_loan_advice(
        loan_analysis, income, savings
    )

    return render_template("loans.html",
        loan_analysis = loan_analysis,
        advice        = advice,
        income        = income,
        loan_types    = LOAN_TYPES,
        months        = MONTHS
    )


@loans_bp.route("/loans/add", methods=["POST"])
@login_required
def add_loan():
    try:
        loan_name    = request.form.get("loan_name", "").strip()
        loan_type    = request.form.get("loan_type")
        principal    = float(request.form.get("principal", 0))
        emi          = float(request.form.get("emi", 0))
        interest_rate= float(request.form.get("interest_rate", 0))
        tenure       = int(request.form.get("tenure_months", 0))
        start_month  = request.form.get("start_month")
        start_year   = int(request.form.get("start_year", 2024))

        if not loan_name or principal <= 0 or emi <= 0 or tenure <= 0:
            return redirect(url_for("loans.loans"))

        save_loan(
            session["user_id"], loan_name, loan_type,
            principal, emi, interest_rate,
            tenure, start_month, start_year
        )
    except Exception as e:
        print(f"Error adding loan: {e}")

    return redirect(url_for("loans.loans"))


@loans_bp.route("/loans/delete/<int:loan_id>")
@login_required
def remove_loan(loan_id):
    delete_loan(loan_id, session["user_id"])
    return redirect(url_for("loans.loans"))