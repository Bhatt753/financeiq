# services/loan_engine.py
# Smart loan analysis and advice engine

MONTH_ORDER = {
    "January": 1, "February": 2, "March": 3,
    "April": 4, "May": 5, "June": 6,
    "July": 7, "August": 8, "September": 9,
    "October": 10, "November": 11, "December": 12
}


def calculate_months_passed(start_month, start_year):
    """Calculate how many months have passed since loan started"""
    import datetime
    now          = datetime.datetime.now()
    start_m      = MONTH_ORDER.get(start_month, 1)
    months_passed = ((now.year - start_year) * 12 +
                     (now.month - start_m))
    return max(0, months_passed)


def analyze_single_loan(loan):
    """
    Analyze a single loan in detail:
    - Amount paid so far
    - Remaining balance
    - Months remaining
    - Total interest paid
    - Payoff date
    """
    principal     = loan["principal"]
    emi           = loan["emi"]
    interest_rate = loan["interest_rate"]
    tenure        = loan["tenure_months"]
    start_month   = loan["start_month"]
    start_year    = loan["start_year"]

    months_passed   = calculate_months_passed(start_month, start_year)
    months_paid     = min(months_passed, tenure)
    months_remaining= max(0, tenure - months_paid)

    # Calculate actual outstanding using reducing balance method
    monthly_rate = interest_rate / (12 * 100)

    if monthly_rate > 0:
        # Reducing balance formula
        outstanding = principal * (
            (1 + monthly_rate) ** tenure -
            (1 + monthly_rate) ** months_paid
        ) / (
            (1 + monthly_rate) ** tenure - 1
        )
    else:
        # Zero interest loan
        outstanding = max(0, principal - (emi * months_paid))

    outstanding    = max(0, round(outstanding, 2))
    amount_paid    = round(principal - outstanding + (emi * months_paid - (principal - outstanding)), 2)
    total_payment  = emi * tenure
    total_interest = round(total_payment - principal, 2)
    interest_paid  = round(total_interest * (months_paid / tenure) if tenure > 0 else 0, 2)
    principal_paid = round(principal - outstanding, 2)

    # Payoff date
    import datetime
    now           = datetime.datetime.now()
    payoff_month  = now.month + months_remaining
    payoff_year   = now.year + (payoff_month - 1) // 12
    payoff_month  = ((payoff_month - 1) % 12) + 1
    month_names   = ["January","February","March","April","May","June",
                     "July","August","September","October","November","December"]
    payoff_date   = f"{month_names[payoff_month-1]} {payoff_year}"

    # Progress percentage
    progress_pct  = round((months_paid / tenure) * 100, 1) if tenure > 0 else 100

    # Monthly breakdown for graph
    monthly_breakdown = []
    bal = principal
    for m in range(min(tenure, 60)):  # max 60 months for graph
        if monthly_rate > 0:
            interest_component  = round(bal * monthly_rate, 2)
            principal_component = round(emi - interest_component, 2)
        else:
            interest_component  = 0
            principal_component = emi

        bal = max(0, round(bal - principal_component, 2))
        monthly_breakdown.append({
            "month"     : m + 1,
            "balance"   : bal,
            "principal" : principal_component,
            "interest"  : interest_component,
            "paid"      : m < months_paid
        })

    return {
        "loan_id"         : loan.get("id"),
        "loan_name"       : loan["loan_name"],
        "loan_type"       : loan["loan_type"],
        "principal"       : principal,
        "emi"             : emi,
        "interest_rate"   : interest_rate,
        "tenure"          : tenure,
        "months_paid"     : months_paid,
        "months_remaining": months_remaining,
        "outstanding"     : outstanding,
        "principal_paid"  : principal_paid,
        "interest_paid"   : interest_paid,
        "total_interest"  : total_interest,
        "progress_pct"    : progress_pct,
        "payoff_date"     : payoff_date,
        "monthly_breakdown": monthly_breakdown,
        "is_completed"    : months_remaining == 0
    }


def analyze_all_loans(loans):
    """Analyze all loans and generate combined insights"""
    if not loans:
        return {
            "loans"           : [],
            "total_emi"       : 0,
            "total_outstanding": 0,
            "total_principal" : 0,
            "completing_soon" : [],
            "high_interest"   : [],
            "insights"        : [],
            "has_loans"       : False
        }

    analyzed      = [analyze_single_loan(loan) for loan in loans]
    total_emi     = sum(loan["emi"] for loan in loans)
    total_outstanding = sum(a["outstanding"] for a in analyzed)
    total_principal   = sum(loan["principal"] for loan in loans)

    # Loans completing in next 6 months
    completing_soon = [
        a for a in analyzed
        if 0 < a["months_remaining"] <= 6
    ]

    # High interest loans (>12%)
    high_interest = [
        a for a in analyzed
        if loans[analyzed.index(a)]["interest_rate"] > 12
    ]

    return {
        "loans"            : analyzed,
        "total_emi"        : total_emi,
        "total_outstanding": total_outstanding,
        "total_principal"  : total_principal,
        "completing_soon"  : completing_soon,
        "high_interest"    : high_interest,
        "has_loans"        : True
    }


def generate_loan_advice(loan_analysis, income, savings,
                         goals=None, emergency_fund=0):
    """
    Generate genuine practical advice based on loan situation,
    income, savings and goals.
    """
    advice = []

    if not loan_analysis["has_loans"]:
        advice.append({
            "type"   : "success",
            "icon"   : "🎉",
            "title"  : "Debt Free!",
            "message": "You have no active loans. Your entire income is working for you.",
            "action" : f"Invest ₹{savings:,.0f}/month in SIP mutual funds for long-term wealth."
        })
        return advice

    total_emi     = loan_analysis["total_emi"]
    emi_ratio     = round((total_emi / income) * 100, 1) if income > 0 else 0
    completing    = loan_analysis["completing_soon"]
    high_interest = loan_analysis["high_interest"]

    # --- Advice 1: EMI burden ---
    if emi_ratio > 40:
        advice.append({
            "type"   : "danger",
            "icon"   : "🚨",
            "title"  : f"High EMI Burden ({emi_ratio}% of income)",
            "message": f"You pay ₹{total_emi:,.0f}/month in EMIs — {emi_ratio}% of income. Banks consider >40% as high risk.",
            "action" : "Avoid any new loans. Focus on prepaying highest-interest loan first."
        })
    elif emi_ratio > 30:
        advice.append({
            "type"   : "warning",
            "icon"   : "⚠️",
            "title"  : f"Moderate EMI Burden ({emi_ratio}% of income)",
            "message": f"₹{total_emi:,.0f}/month in EMIs. Manageable but limiting your financial flexibility.",
            "action" : "Try to prepay one loan to free up cash flow."
        })
    else:
        advice.append({
            "type"   : "success",
            "icon"   : "✅",
            "title"  : f"Healthy EMI Ratio ({emi_ratio}%)",
            "message": f"Your EMI burden of ₹{total_emi:,.0f}/month is within safe limits.",
            "action" : "You have room for one more loan if needed, but avoid unless necessary."
        })

    # --- Advice 2: High interest loans ---
    if high_interest:
        for loan in high_interest:
            rate = loans_rate = loan["interest_rate"] if "interest_rate" in loan else 0
            advice.append({
                "type"   : "warning",
                "icon"   : "💸",
                "title"  : f"High Interest: {loan['loan_name']}",
                "message": f"₹{loan['outstanding']:,.0f} remaining at high interest. Every month costs you extra in interest.",
                "action" : f"Prepay ₹{min(savings, loan['outstanding']):,.0f} to save significantly on interest charges."
            })

    # --- Advice 3: Loans completing soon ---
    if completing:
        for loan in completing:
            freed_amount = loan["emi"]
            advice.append({
                "type"   : "success",
                "icon"   : "🎯",
                "title"  : f"{loan['loan_name']} Completes in {loan['months_remaining']} Months!",
                "message": f"Your {loan['loan_name']} EMI of ₹{freed_amount:,.0f}/month will be freed up by {loan['payoff_date']}.",
                "action" : _suggest_freed_emi_use(freed_amount, emergency_fund, goals, savings)
            })

    # --- Advice 4: Goal + Loan interaction ---
    if goals:
        for goal in goals:
            goal_amount  = goal.get("goal_amount", 0)
            goal_months  = goal.get("goal_months", 12)
            goal_name    = goal.get("goal_name", "your goal")
            needed       = round(goal_amount / goal_months, 0)

            # Check if any loan completes before goal deadline
            helpful_loans = [
                l for l in completing
                if l["months_remaining"] <= goal_months
            ]

            if helpful_loans:
                total_freed = sum(l["emi"] for l in helpful_loans)
                advice.append({
                    "type"   : "info",
                    "icon"   : "🔮",
                    "title"  : f"Loan Freedom Helps Your Goal: {goal_name}",
                    "message": f"{len(helpful_loans)} loan(s) completing before your goal deadline will free ₹{total_freed:,.0f}/month.",
                    "action" : f"After loans complete, redirect ₹{total_freed:,.0f} directly to {goal_name} savings. You'll reach ₹{goal_amount:,.0f} faster!"
                })

    # --- Advice 5: Emergency fund with loans ---
    months_emergency = round(emergency_fund / (income * 0.5), 1) if income > 0 else 0
    if emergency_fund < total_emi * 3:
        advice.append({
            "type"   : "warning",
            "icon"   : "🛡️",
            "title"  : "Emergency Fund Too Low for Loan Safety",
            "message": f"With ₹{total_emi:,.0f}/month EMIs, you need at least ₹{total_emi*3:,.0f} emergency fund (3 months EMIs).",
            "action" : f"Build emergency fund to ₹{total_emi*6:,.0f} before aggressively prepaying loans."
        })

    return advice


def _suggest_freed_emi_use(freed_amount, emergency_fund,
                            goals, current_savings):
    """Suggest best use of freed EMI amount"""
    emergency_target = freed_amount * 6

    if emergency_fund < emergency_target:
        needed = round(emergency_target - emergency_fund, 0)
        return (f"Add ₹{freed_amount:,.0f} to emergency fund. "
                f"You need ₹{needed:,.0f} more to reach 6-month safety net.")

    if goals:
        goal = goals[0]
        return (f"Put ₹{freed_amount:,.0f} directly into "
                f"'{goal['goal_name']}' savings. "
                f"This accelerates your goal by months!")

    return (f"Invest ₹{freed_amount:,.0f}/month in SIP mutual funds. "
            f"At 12% returns, this becomes "
            f"₹{freed_amount * 12 * 5 * 1.12:,.0f} in 5 years!")