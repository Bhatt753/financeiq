# Personalized financial advice engine

from config import Config


def generate_advice(metrics, profession=None):
    advice   = []
    income   = metrics["income"]
    savings  = metrics["savings"]
    save_rate= metrics["savings_rate"]
    cat_totals = metrics["category_totals"]
    cat_pct    = metrics["category_percent"]

    # --- Critical: Overspending ---
    if savings < 0:
        advice.append({
            "type"    : "danger",
            "icon"    : "🚨",
            "title"   : "CRITICAL: You Are Overspending!",
            "message" : f"You spend ₹{abs(savings):,.0f} more than you earn every month.",
            "action"  : f"Immediately cut ₹{abs(savings):,.0f} from variable expenses like shopping and entertainment.",
            "impact"  : "High"
        })
        return advice  # Return immediately — no point showing other advice

    # --- Savings Rate ---
    if save_rate < 10:
        needed = round((income * 0.20) - savings, 2)
        advice.append({
            "type"    : "warning",
            "icon"    : "⚠️",
            "title"   : "Dangerously Low Savings",
            "message" : f"You save only {save_rate}% of income. This leaves no safety net.",
            "action"  : f"Cut ₹{needed:,.0f}/month from variable expenses to reach 20% savings rate.",
            "impact"  : "High"
        })
    elif save_rate < 20:
        needed = round((income * 0.20) - savings, 2)
        advice.append({
            "type"    : "warning",
            "icon"    : "📊",
            "title"   : "Below Recommended Savings",
            "message" : f"You save {save_rate}% of income. Target is 20%.",
            "action"  : f"Save ₹{needed:,.0f} more per month to reach the 20% benchmark.",
            "impact"  : "Medium"
        })
    elif save_rate >= 30:
        advice.append({
            "type"    : "success",
            "icon"    : "🌟",
            "title"   : "Excellent Savings Rate!",
            "message" : f"You save {save_rate}% of income (₹{savings:,.0f}/month).",
            "action"  : f"Invest ₹{savings:,.0f}/month in SIP mutual funds for wealth building.",
            "impact"  : "Positive"
        })
    else:
        advice.append({
            "type"    : "success",
            "icon"    : "✅",
            "title"   : "Good Savings Rate",
            "message" : f"You save {save_rate}% of income. Keep it up!",
            "action"  : "Consider increasing SIP investments for long-term wealth.",
            "impact"  : "Positive"
        })

    # --- Category-wise advice ---
    over_limit_cats = []
    for cat, amt in cat_totals.items():
        pct   = cat_pct[cat]
        limit = Config.HEALTHY_LIMITS.get(cat, 10)
        if pct > limit:
            save_monthly = round(amt * 0.10, 2)
            save_yearly  = round(save_monthly * 12, 2)
            over_limit_cats.append(cat)
            advice.append({
                "type"    : "warning",
                "icon"    : "✂️",
                "title"   : f"High {cat} Spending",
                "message" : f"₹{amt:,.0f}/month ({pct}% of income) exceeds {limit}% limit.",
                "action"  : f"Reduce by 10% → save ₹{save_monthly:,.0f}/month = ₹{save_yearly:,.0f}/year.",
                "impact"  : "Medium"
            })

    # --- Emergency Fund ---
    emergency_needed = metrics["total_expenses"] * 6
    if savings > 0:
        months_away = round(emergency_needed / savings)
        advice.append({
            "type"    : "info",
            "icon"    : "🏦",
            "title"   : "Emergency Fund Status",
            "message" : f"You need ₹{emergency_needed:,.0f} (6 months of expenses).",
            "action"  : f"At current savings, you'll build it in {months_away} months. Keep a separate FD for this.",
            "impact"  : "Medium"
        })

    # --- Investment opportunity ---
    if savings > 500:
        sip_3yr = round(savings * 12 * 3 * 1.12, 0)
        sip_5yr = round(savings * 12 * 5 * 1.12, 0)
        advice.append({
            "type"    : "success",
            "icon"    : "📈",
            "title"   : "Investment Opportunity",
            "message" : f"Investing ₹{savings:,.0f}/month in SIP:",
            "action"  : f"3 years → ~₹{sip_3yr:,.0f} | 5 years → ~₹{sip_5yr:,.0f} at 12% returns.",
            "impact"  : "Positive"
        })

    # --- Fixed vs Variable balance ---
    if metrics["variable_total"] > 0:
        var_ratio = metrics["variable_ratio"] if "variable_ratio" in metrics else \
                    round(metrics["variable_total"] / metrics["total_expenses"] * 100, 1)
        if var_ratio > 60:
            potential = round(metrics["variable_total"] * 0.20, 0)
            advice.append({
                "type"    : "info",
                "icon"    : "💡",
                "title"   : "High Variable Spending",
                "message" : f"{var_ratio}% of your expenses are flexible (variable).",
                "action"  : f"Cutting variable expenses by 20% frees up ₹{potential:,.0f}/month.",
                "impact"  : "Medium"
            })

    return advice


def generate_annual_projection(metrics):
    savings      = metrics["savings"]
    annual_save  = round(savings * 12, 2)
    sip_1yr      = round(savings * 12 * 1.12, 2)
    sip_3yr      = round(savings * 12 * 3 * 1.12, 2)
    sip_5yr      = round(savings * 12 * 5 * 1.12, 2)

    return {
        "annual_savings" : annual_save,
        "sip_1yr"        : sip_1yr,
        "sip_3yr"        : sip_3yr,
        "sip_5yr"        : sip_5yr
    }