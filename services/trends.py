# Month over month trend analysis

def analyze_trends(history):
    if not history or len(history) < 2:
        return None

    latest = history[0]
    prev   = history[1]

    savings_change  = round(latest["savings"] - prev["savings"], 2)
    expense_change  = round(latest["total_expenses"] - prev["total_expenses"], 2)
    score_change    = latest["health_score"] - prev["health_score"]

    return {
        "savings_change"     : savings_change,
        "savings_trend"      : "up" if savings_change > 0 else "down",
        "expense_change"     : expense_change,
        "expense_trend"      : "up" if expense_change > 0 else "down",
        "score_change"       : score_change,
        "score_trend"        : "up" if score_change > 0 else "down",
        "savings_change_pct" : round((savings_change / max(prev["savings"], 1)) * 100, 1),
        "months_compared"    : f"{prev['month']} vs {latest['month']}"
    }


def calculate_annual_summary(history):
    if not history:
        return None

    total_income   = sum(h["income"] for h in history)
    total_expenses = sum(h["total_expenses"] for h in history)
    total_savings  = sum(h["savings"] for h in history)
    avg_score      = round(sum(h["health_score"] for h in history) / len(history), 1)

    return {
        "total_income"   : round(total_income, 2),
        "total_expenses" : round(total_expenses, 2),
        "total_savings"  : round(total_savings, 2),
        "avg_health_score": avg_score,
        "months_tracked" : len(history)
    }