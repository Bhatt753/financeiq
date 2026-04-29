# Smart goal decision engine

from config import Config


def analyze_goal(goal_name, goal_amount, goal_months,
                 income, current_savings, variable_total, category_totals):

    # Edge cases
    if goal_months <= 0:
        return None, "Goal timeline must be at least 1 month."
    if goal_amount <= 0:
        return None, "Goal amount must be greater than zero."

    required_monthly = round(goal_amount / goal_months, 2)
    gap              = round(required_monthly - current_savings, 2)
    realistic_months = round(goal_amount / current_savings) if current_savings > 0 else None

    # --- Classify difficulty ---
    if gap <= 0:
        difficulty = "ACHIEVED"
    elif gap <= income * 0.05:
        difficulty = "EASY"
    elif gap <= income * 0.15:
        difficulty = "MEDIUM"
    else:
        difficulty = "HARD"

    # --- Generate action plan based on difficulty ---
    action_plan = []

    if difficulty == "ACHIEVED":
        action_plan.append({
            "step"   : 1,
            "title"  : "You're Already On Track!",
            "detail" : f"You save ₹{current_savings:,.0f}/month which covers ₹{required_monthly:,.0f} needed.",
            "savings": 0
        })
        action_plan.append({
            "step"   : 2,
            "title"  : "Open a Separate Account",
            "detail" : f"Auto-transfer ₹{required_monthly:,.0f} on salary day to a dedicated savings account.",
            "savings": required_monthly
        })

    elif difficulty == "EASY":
        action_plan.append({
            "step"   : 1,
            "title"  : f"Save ₹{gap:,.0f} More Per Month",
            "detail" : "This is a small adjustment — skip 2-3 food orders or reduce one subscription.",
            "savings": gap
        })

    elif difficulty == "MEDIUM":
        var_cut = round(variable_total * 0.15, 2)
        remaining_after_cut = round(gap - var_cut, 2)

        action_plan.append({
            "step"   : 1,
            "title"  : "Cut Variable Expenses by 15%",
            "detail" : f"Reduce shopping, entertainment and dining out by 15% → saves ₹{var_cut:,.0f}/month.",
            "savings": var_cut
        })

        if remaining_after_cut > 0:
            action_plan.append({
                "step"   : 2,
                "title"  : f"Bridge Remaining ₹{remaining_after_cut:,.0f} Gap",
                "detail" : "Consider freelancing, tutoring or part-time work on weekends.",
                "savings": remaining_after_cut
            })

        action_plan.append({
            "step"   : 3,
            "title"  : "Alternative: Extend Timeline",
            "detail" : f"Extend to {goal_months + 4} months → only ₹{round(goal_amount / (goal_months + 4), 0):,.0f}/month needed.",
            "savings": 0
        })

    elif difficulty == "HARD":
        # Sort categories by amount to find biggest cuts
        sorted_cats = sorted(category_totals.items(), key=lambda x: x[1], reverse=True)

        action_plan.append({
            "step"   : 1,
            "title"  : "Cut Variable Expenses by 25%",
            "detail" : f"Aggressively reduce variable spending → saves ₹{round(variable_total * 0.25, 0):,.0f}/month.",
            "savings": round(variable_total * 0.25, 2)
        })

        if len(sorted_cats) >= 1:
            cat1, amt1 = sorted_cats[0]
            action_plan.append({
                "step"   : 2,
                "title"  : f"Reduce {cat1} (Your Biggest Expense)",
                "detail" : f"₹{amt1:,.0f}/month → cut by 20% to save ₹{round(amt1 * 0.20, 0):,.0f}/month.",
                "savings": round(amt1 * 0.20, 2)
            })

        action_plan.append({
            "step"   : 3,
            "title"  : "Increase Income",
            "detail" : f"Find ₹{round(gap / 2, 0):,.0f}/month extra through freelancing or part-time work.",
            "savings": round(gap / 2, 2)
        })

        extended  = goal_months + 6
        new_req   = round(goal_amount / extended, 2)
        action_plan.append({
            "step"   : 4,
            "title"  : f"Consider Extended Timeline ({extended} months)",
            "detail" : f"Reduces monthly requirement from ₹{required_monthly:,.0f} to ₹{new_req:,.0f}.",
            "savings": 0
        })

    # --- Golden rules for every goal ---
    golden_rules = [
        f"Save ₹{required_monthly:,.0f} on the SAME day you receive your salary",
        "Keep goal money in a SEPARATE savings account — never mix with daily expenses",
        "Review your progress every month and adjust if needed",
        "Put 50% of any extra/bonus income directly into this goal",
        "Never borrow to fund lifestyle goals — only borrow for assets"
    ]

    return {
        "goal_name"       : goal_name,
        "goal_amount"     : goal_amount,
        "goal_months"     : goal_months,
        "required_monthly": required_monthly,
        "current_savings" : current_savings,
        "gap"             : gap,
        "difficulty"      : difficulty,
        "realistic_months": realistic_months,
        "action_plan"     : action_plan,
        "golden_rules"    : golden_rules,
        "extended_months" : goal_months + (4 if difficulty == "MEDIUM" else 6),
        "extended_amount" : round(goal_amount / (goal_months + 6), 2)
    }, None