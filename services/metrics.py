# Core financial metrics engine

from config import Config


def calculate_metrics(income, expenses):
    # Edge case: zero income
    if not income or income <= 0:
        return None, "Income must be greater than zero."

    # Edge case: no expenses
    if not expenses:
        return {
            "income"          : income,
            "total_expenses"  : 0,
            "savings"         : income,
            "savings_rate"    : 100.0,
            "expense_ratio"   : 0.0,
            "fixed_total"     : 0,
            "variable_total"  : 0,
            "category_totals" : {},
            "category_percent": {},
            "health_score"    : 100,
            "score_breakdown" : []
        }, None

    total_expenses = sum(e["amount"] for e in expenses)
    savings        = income - total_expenses
    fixed_total    = sum(e["amount"] for e in expenses if e["type"] == "Fixed")
    variable_total = sum(e["amount"] for e in expenses if e["type"] == "Variable")

    # Category totals
    category_totals = {}
    for e in expenses:
        cat = e["category"]
        category_totals[cat] = category_totals.get(cat, 0) + e["amount"]

    # Category % of income
    category_percent = {
        cat: round((amt / income) * 100, 2)
        for cat, amt in category_totals.items()
    }

    save_rate = round((max(savings, 0) / income) * 100, 2)
    exp_ratio = round((total_expenses / income) * 100, 2)

    # --- Health Score with explanation ---
    score          = 100
    score_breakdown = []

    if save_rate < 10:
        score -= 30
        score_breakdown.append({
            "reason" : "Very low savings rate",
            "impact" : -30,
            "fix"    : f"Increase savings to at least ₹{income * 0.10:,.0f}/month"
        })
    elif save_rate < 20:
        score -= 15
        score_breakdown.append({
            "reason" : "Below recommended savings rate",
            "impact" : -15,
            "fix"    : f"Aim to save ₹{income * 0.20:,.0f}/month (20% of income)"
        })

    if exp_ratio > 90:
        score -= 20
        score_breakdown.append({
            "reason" : "Very high expense ratio",
            "impact" : -20,
            "fix"    : "Cut at least 2-3 expense categories"
        })
    elif exp_ratio > 80:
        score -= 10
        score_breakdown.append({
            "reason" : "High expense ratio",
            "impact" : -10,
            "fix"    : "Try to reduce expenses by 10%"
        })

    for cat, pct in category_percent.items():
        limit = Config.HEALTHY_LIMITS.get(cat, 10)
        if pct > limit:
            score -= 10
            score_breakdown.append({
                "reason" : f"{cat} over limit ({pct}% vs {limit}% limit)",
                "impact" : -10,
                "fix"    : f"Reduce {cat} from ₹{category_totals[cat]:,.0f} to ₹{income * limit / 100:,.0f}"
            })

    return {
        "income"          : income,
        "total_expenses"  : round(total_expenses, 2),
        "savings"         : round(savings, 2),
        "savings_rate"    : save_rate,
        "expense_ratio"   : exp_ratio,
        "fixed_total"     : round(fixed_total, 2),
        "variable_total"  : round(variable_total, 2),
        "category_totals" : category_totals,
        "category_percent": category_percent,
        "health_score"    : max(score, 0),
        "score_breakdown" : score_breakdown
    }, None