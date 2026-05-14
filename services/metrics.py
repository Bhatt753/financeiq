# services/metrics.py

from config import Config
from services.health_score import calculate_health_score


def calculate_metrics(income, expenses, loans=None, existing_emergency_fund=0):

    if not income or income <= 0:
        return None, "Income must be greater than zero."

    if not expenses:
        expenses = []

    if not loans:
        loans = []

    # Regular expenses
    total_expenses = sum(e["amount"] for e in expenses)

    # Total EMI from all loans
    total_emi = sum(loan.get("emi", 0) for loan in loans)

    # Real savings = income - expenses - EMI
    savings      = income - total_expenses - total_emi
    total_outflow= total_expenses + total_emi
    save_rate    = round((max(savings, 0) / income) * 100, 2)
    exp_ratio    = round((total_outflow / income) * 100, 2)

    fixed_total    = sum(e["amount"] for e in expenses if e["type"] == "Fixed")
    variable_total = sum(e["amount"] for e in expenses if e["type"] == "Variable")

    # Category breakdown
    category_totals = {}
    for e in expenses:
        cat = e["category"]
        category_totals[cat] = category_totals.get(cat, 0) + e["amount"]

    category_percent = {
        cat: round((amt / income) * 100, 2)
        for cat, amt in category_totals.items()
    }

    # Health score
    health_data = calculate_health_score(
        income, expenses, loans, existing_emergency_fund
    )

    return {
        "income"           : income,
        "total_expenses"   : round(total_expenses, 2),
        "total_emi"        : round(total_emi, 2),
        "total_outflow"    : round(total_outflow, 2),
        "savings"          : round(savings, 2),
        "savings_rate"     : save_rate,
        "expense_ratio"    : exp_ratio,
        "fixed_total"      : round(fixed_total, 2),
        "variable_total"   : round(variable_total, 2),
        "category_totals"  : category_totals,
        "category_percent" : category_percent,
        "health_score"     : health_data["final_score"],
        "health_data"      : health_data,
        "loans"            : loans,
    }, None