#health_score.py


from config import Config

#COMPONENT 1: SAVINGS RATE SCORE (25%)


def score_savings_rate(savings_rate):
    """
    Industry standard:
    - <5%  : Critical (score 0-20)
    - 5-10%  : Poor    (score 20-40)
    - 10-20% : Average (score 40-70)
    - 20-30% : Good    (score 70-85)
    - >30%   : Excellent (score 85-100)
    """
    if savings_rate < 0:
        score       = 0
        grade       = "F"
        explanation = f"You are overspending. Negative savings rate of {savings_rate}% means you are going into debt every month."
        action      = "Immediately cut expenses. Start with largest variable expense category."

    elif savings_rate < 5:
        score       = 15
        grade       = "F"
        explanation = f"Critical savings rate of {savings_rate}%. Almost nothing saved — one emergency could destabilize your finances."
        action      = "Set a minimum ₹500/month auto-transfer to savings account on salary day."

    elif savings_rate < 10:
        score       = 30
        grade       = "D"
        explanation = f"Poor savings rate of {savings_rate}%. Below the minimum recommended 10%."
        action      = f"Cut one major expense to reach 10% savings target."

    elif savings_rate < 20:
        score       = 55
        grade       = "C"
        explanation = f"Average savings rate of {savings_rate}%. Meeting minimum but below recommended 20%."
        action      = f"Increase savings by reducing variable expenses."

    elif savings_rate < 30:
        score       = 80
        grade       = "B"
        explanation = f"Good savings rate of {savings_rate}%. Above recommended 20% benchmark."
        action      = "Consider investing surplus in SIP or index funds."

    else:
        score       = 100
        grade       = "A"
        explanation = f"Excellent savings rate of {savings_rate}%. Top 10% of savers in India."
        action      = "Diversify investments: SIP, PPF, NPS for tax efficiency."

    return {
        "component"   : "Savings Rate",
        "weight"      : 0.25,
        "raw_score"   : score,
        "weighted"    : round(score * 0.25, 2),
        "grade"       : grade,
        "value"       : f"{savings_rate}%",
        "explanation" : explanation,
        "action"      : action,
        "benchmark"   : "20%+ is recommended"
    }



#COMPONENT 2: EXPENSE RATIO SCORE (20%)


def score_expense_ratio(expense_ratio):
    """
    How much of income goes to expenses:
    - >100% : Spending more than earning
    - 90-100%: Critical
    - 80-90% : Poor
    - 70-80% : Warning
    - 60-70% : Average
    - <60%   : Good
    """
    if expense_ratio > 100:
        score       = 0
        grade       = "F"
        explanation = f"You spend {expense_ratio}% of income — more than you earn. Immediate action needed."
        action      = "Track every expense for 30 days. Eliminate all non-essential spending."

    elif expense_ratio > 90:
        score       = 15
        grade       = "F"
        explanation = f"Critical expense ratio of {expense_ratio}%. Only {100-expense_ratio}% left for savings."
        action      = "Identify top 3 expenses and cut each by 15%."

    elif expense_ratio > 80:
        score       = 35
        grade       = "D"
        explanation = f"High expense ratio of {expense_ratio}%. Leaves little room for savings or emergencies."
        action      = "Reduce variable expenses by 20% this month."

    elif expense_ratio > 70:
        score       = 55
        grade       = "C"
        explanation = f"Moderate expense ratio of {expense_ratio}%. Can improve with small lifestyle changes."
        action      = "Try the 50-30-20 rule: 50% needs, 30% wants, 20% savings."

    elif expense_ratio > 60:
        score       = 75
        grade       = "B"
        explanation = f"Good expense ratio of {expense_ratio}%. Decent control over spending."
        action      = "Maintain current discipline. Look for investment opportunities."

    else:
        score       = 100
        grade       = "A"
        explanation = f"Excellent expense ratio of {expense_ratio}%. Strong spending control."
        action      = "Channel surplus into long-term wealth building investments."

    return {
        "component"   : "Expense Ratio",
        "weight"      : 0.20,
        "raw_score"   : score,
        "weighted"    : round(score * 0.20, 2),
        "grade"       : grade,
        "value"       : f"{expense_ratio}%",
        "explanation" : explanation,
        "action"      : action,
        "benchmark"   : "Below 70% is ideal"
    }

#COMPONENT 3: DEBT BURDEN SCORE (25%)


def score_debt_burden(income, loans):
    """
    EMI to Income Ratio (FOIR - Fixed Obligation to Income Ratio)
    Used by all Indian banks for loan eligibility:
    - 0%     : Perfect (no debt)
    - <20%   : Healthy
    - 20-30% : Manageable
    - 30-40% : Stretched
    - 40-50% : High risk
    - >50%   : Critical (banks reject loans above this)

    Extra penalty for high-interest loans (>18% p.a.)
    """
    if not loans or len(loans) == 0:
        return {
            "component"      : "Debt Burden",
            "weight"         : 0.25,
            "raw_score"      : 100,
            "weighted"       : 25.0,
            "grade"          : "A",
            "value"          : "No loans",
            "emi_ratio"      : 0,
            "total_emi"      : 0,
            "loan_breakdown" : [],
            "explanation"    : "No loans detected. Debt-free status gives maximum score.",
            "action"         : "Maintain debt-free status. If taking loans, keep EMI below 30% of income.",
            "benchmark"      : "EMI/Income ratio below 30%"
        }

    total_emi        = sum(loan.get("emi", 0) for loan in loans)
    emi_ratio        = round((total_emi / income) * 100, 2) if income > 0 else 100
    high_interest    = [l for l in loans if l.get("interest_rate", 0) > 18]
    penalty          = len(high_interest) * 10

    # Base score from EMI ratio
    if emi_ratio == 0:
        base_score = 100
        grade      = "A"
        explanation = "No EMI obligations. Excellent debt management."
        action      = "Maintain debt-free status."

    elif emi_ratio <= 10:
        base_score  = 90
        grade       = "A"
        explanation = f"Very low EMI ratio of {emi_ratio}%. Excellent debt management."
        action      = "Well within safe limits. You have high loan eligibility."

    elif emi_ratio <= 20:
        base_score  = 75
        grade       = "B"
        explanation = f"Healthy EMI ratio of {emi_ratio}%. Well within manageable limits."
        action      = "Good debt management. Avoid taking additional loans."

    elif emi_ratio <= 30:
        base_score  = 55
        grade       = "C"
        explanation = f"Moderate EMI ratio of {emi_ratio}%. Banks consider this manageable."
        action      = "Avoid new loans. Focus on prepaying highest-interest loan first."

    elif emi_ratio <= 40:
        base_score  = 35
        grade       = "D"
        explanation = f"High EMI ratio of {emi_ratio}%. Stretched finances. Limited loan eligibility."
        action      = "Prioritize debt repayment. Use any bonus/extra income to prepay loans."

    elif emi_ratio <= 50:
        base_score  = 15
        grade       = "F"
        explanation = f"Very high EMI ratio of {emi_ratio}%. Banks typically reject loans above 50%."
        action      = "Emergency debt reduction needed. Consider loan consolidation."

    else:
        base_score  = 0
        grade       = "F"
        explanation = f"Critical EMI ratio of {emi_ratio}%. Severely over-leveraged. High default risk."
        action      = "Seek financial counseling immediately. Debt restructuring may be needed."

    # Apply high-interest penalty
    final_score = max(0, base_score - penalty)

    # Build loan breakdown
    loan_breakdown = []
    for loan in loans:
        emi          = loan.get("emi", 0)
        rate         = loan.get("interest_rate", 0)
        loan_type    = loan.get("type", "Unknown")
        loan_ratio   = round((emi / income) * 100, 2) if income > 0 else 0
        risk         = "High Risk" if rate > 18 else "Moderate" if rate > 12 else "Low Risk"

        loan_breakdown.append({
            "type"       : loan_type,
            "emi"        : emi,
            "rate"       : rate,
            "ratio"      : loan_ratio,
            "risk"       : risk
        })

    if high_interest:
        action = f"You have {len(high_interest)} high-interest loan(s) (>18% p.a.). Prepay these first to save on interest."

    return {
        "component"      : "Debt Burden",
        "weight"         : 0.25,
        "raw_score"      : final_score,
        "weighted"       : round(final_score * 0.25, 2),
        "grade"          : grade,
        "value"          : f"{emi_ratio}% EMI ratio",
        "emi_ratio"      : emi_ratio,
        "total_emi"      : total_emi,
        "high_interest_count": len(high_interest),
        "penalty_applied": penalty,
        "loan_breakdown" : loan_breakdown,
        "explanation"    : explanation,
        "action"         : action,
        "benchmark"      : "EMI/Income ratio below 30% (FOIR)"
    }

#COMPONENT 4: EMERGENCY FUND SCORE (20%)


def score_emergency_fund(monthly_expenses, current_savings, existing_emergency_fund=0):
    """
    Emergency Fund = months of expenses covered
    RBI and financial advisors recommend 6 months minimum:
    - 0 months   : Critical
    - <1 month   : Very poor
    - 1-3 months : Poor
    - 3-6 months : Moderate
    - 6-12 months: Good
    - >12 months : Excellent
    """
    if monthly_expenses <= 0:
        return {
            "component"   : "Emergency Fund",
            "weight"      : 0.20,
            "raw_score"   : 50,
            "weighted"    : 10.0,
            "grade"       : "C",
            "value"       : "Cannot calculate",
            "months_covered": 0,
            "explanation" : "Cannot calculate emergency fund without expense data.",
            "action"      : "Track monthly expenses to calculate emergency fund strength.",
            "benchmark"   : "6 months of expenses"
        }

    total_fund    = existing_emergency_fund + max(current_savings, 0)
    months        = round(total_fund / monthly_expenses, 1) if monthly_expenses > 0 else 0
    target_amount = monthly_expenses * 6

    if months <= 0:
        score       = 0
        grade       = "F"
        explanation = "No emergency fund. One unexpected expense could cause financial crisis."
        action      = f"Start immediately. Target ₹{target_amount:,.0f} (6 months expenses). Save ₹{monthly_expenses*0.5:,.0f}/month."

    elif months < 1:
        score       = 15
        grade       = "F"
        explanation = f"Less than 1 month emergency coverage (₹{total_fund:,.0f}). Extremely vulnerable."
        action      = f"Build to 3 months (₹{monthly_expenses*3:,.0f}) as first milestone."

    elif months < 3:
        score       = 35
        grade       = "D"
        explanation = f"{months} months emergency coverage. Below the minimum 3-month safety net."
        action      = f"Add ₹{(monthly_expenses*3)-total_fund:,.0f} more to reach 3-month safety net."

    elif months < 6:
        score       = 65
        grade       = "C"
        explanation = f"{months} months emergency coverage. Between 3-6 months — moderate safety."
        action      = f"Add ₹{(monthly_expenses*6)-total_fund:,.0f} more to reach recommended 6-month fund."

    elif months < 12:
        score       = 85
        grade       = "B"
        explanation = f"{months} months emergency coverage. Strong safety net above RBI recommendation."
        action      = "Invest any additional savings beyond 6 months in liquid mutual funds."

    else:
        score       = 100
        grade       = "A"
        explanation = f"{months} months emergency coverage. Excellent financial safety net."
        action      = "Your emergency fund is fully built. Focus on wealth creation now."

    return {
        "component"      : "Emergency Fund",
        "weight"         : 0.20,
        "raw_score"      : score,
        "weighted"       : round(score * 0.20, 2),
        "grade"          : grade,
        "value"          : f"{months} months coverage",
        "months_covered" : months,
        "total_fund"     : total_fund,
        "target_amount"  : target_amount,
        "explanation"    : explanation,
        "action"         : action,
        "benchmark"      : "6 months minimum (RBI recommendation)"
    }


#COMPONENT 5: SPENDING DISCIPLINE SCORE (10%)


def score_spending_discipline(category_percent, income):
    """
    Checks how well user follows healthy spending limits
    per category. Each violation reduces score.
    """
    limits       = Config.HEALTHY_LIMITS
    violations   = []
    total_over   = 0
    categories_checked = 0

    for cat, limit in limits.items():
        actual = category_percent.get(cat, 0)
        if actual > 0:
            categories_checked += 1
        if actual > limit:
            over_by = round(actual - limit, 1)
            total_over += over_by
            violations.append({
                "category" : cat,
                "actual"   : actual,
                "limit"    : limit,
                "over_by"  : over_by,
                "excess_amount": round((over_by / 100) * income, 0)
            })

    num_violations = len(violations)

    if num_violations == 0:
        score       = 100
        grade       = "A"
        explanation = "All spending categories within healthy limits. Excellent discipline."
        action      = "Maintain current spending habits."

    elif num_violations == 1:
        score       = 75
        grade       = "B"
        explanation = f"1 category over limit: {violations[0]['category']} ({violations[0]['actual']}% vs {violations[0]['limit']}% limit)."
        action      = f"Reduce {violations[0]['category']} by ₹{violations[0]['excess_amount']:,.0f}/month."

    elif num_violations == 2:
        score       = 50
        grade       = "C"
        cats        = " and ".join([v["category"] for v in violations])
        explanation = f"2 categories over limit: {cats}."
        action      = f"Focus on reducing these 2 categories first."

    elif num_violations <= 4:
        score       = 25
        grade       = "D"
        explanation = f"{num_violations} categories exceed healthy limits. Spending discipline needs work."
        action      = "Apply the envelope budgeting method. Set strict monthly limits per category."

    else:
        score       = 5
        grade       = "F"
        explanation = f"{num_violations} categories exceed limits. Spending is unstructured."
        action      = "Complete spending overhaul needed. Use a budgeting app to track daily expenses."

    return {
        "component"     : "Spending Discipline",
        "weight"        : 0.10,
        "raw_score"     : score,
        "weighted"      : round(score * 0.10, 2),
        "grade"         : grade,
        "value"         : f"{num_violations} violations",
        "violations"    : violations,
        "num_violations": num_violations,
        "explanation"   : explanation,
        "action"        : action,
        "benchmark"     : "0 category limit violations"
    }

#MASTER SCORE CALCULATOR


def calculate_health_score(income, expenses, loans=None,
                            existing_emergency_fund=0):
    """
    Master function that combines all 5 components
    into a single weighted health score.

    Returns complete breakdown with explanations.
    """

    # Edge case: zero income
    if not income or income <= 0:
        return {
            "final_score"  : 0,
            "grade"        : "F",
            "status"       : "Cannot Calculate",
            "explanation"  : "Income must be greater than zero to calculate health score.",
            "components"   : [],
            "summary"      : "Invalid data"
        }

    total_expenses   = sum(e["amount"] for e in expenses) if expenses else 0
    savings          = income - total_expenses
    savings_rate     = round((max(savings, 0) / income) * 100, 2)
    expense_ratio    = round((total_expenses / income) * 100, 2)

    # Category percentages
    category_totals  = {}
    for e in expenses:
        cat = e["category"]
        category_totals[cat] = category_totals.get(cat, 0) + e["amount"]

    category_percent = {
        cat: round((amt / income) * 100, 2)
        for cat, amt in category_totals.items()
    }

    # Calculate each component
    c1 = score_savings_rate(savings_rate)
    c2 = score_expense_ratio(expense_ratio)
    c3 = score_debt_burden(income, loans or [])
    c4 = score_emergency_fund(total_expenses, savings, existing_emergency_fund)
    c5 = score_spending_discipline(category_percent, income)

    components   = [c1, c2, c3, c4, c5]
    final_score  = round(sum(c["weighted"] for c in components))
    final_score  = max(0, min(100, final_score))

    # Grade
    if final_score >= 85:
        grade  = "A"
        status = "Excellent"
        color  = "#4ade80"
        summary = "Your finances are in excellent shape. Focus on wealth building."

    elif final_score >= 70:
        grade  = "B"
        status = "Good"
        color  = "#86efac"
        summary = "Good financial health with room for improvement."

    elif final_score >= 55:
        grade  = "C"
        status = "Average"
        color  = "#fbbf24"
        summary = "Average financial health. Several areas need attention."

    elif final_score >= 40:
        grade  = "D"
        status = "Poor"
        color  = "#fb923c"
        summary = "Poor financial health. Immediate changes needed."

    else:
        grade  = "F"
        status = "Critical"
        color  = "#fca5a5"
        summary = "Critical financial situation. Urgent action required."

    # Top 3 priority actions
    sorted_components = sorted(components, key=lambda x: x["raw_score"])
    priority_actions  = [
        {
            "component": c["component"],
            "action"   : c["action"],
            "score"    : c["raw_score"]
        }
        for c in sorted_components[:3]
    ]

    return {
        "final_score"      : final_score,
        "grade"            : grade,
        "status"           : status,
        "color"            : color,
        "summary"          : summary,
        "components"       : components,
        "priority_actions" : priority_actions,
        "raw_data": {
            "income"        : income,
            "total_expenses": total_expenses,
            "savings"       : savings,
            "savings_rate"  : savings_rate,
            "expense_ratio" : expense_ratio
        }
    }

#SCORE INTERPRETATION


SCORE_RANGES = [
    {"min": 85, "max": 100, "grade": "A", "label": "Excellent",
     "description": "Top tier financial health. You are building wealth effectively."},
    {"min": 70, "max": 84,  "grade": "B", "label": "Good",
     "description": "Above average. Small improvements will take you to excellent."},
    {"min": 55, "max": 69,  "grade": "C", "label": "Average",
     "description": "Middle ground. Multiple areas need consistent improvement."},
    {"min": 40, "max": 54,  "grade": "D", "label": "Poor",
     "description": "Below average. Financial vulnerabilities present."},
    {"min": 0,  "max": 39,  "grade": "F", "label": "Critical",
     "description": "Serious financial risk. Immediate corrective action needed."},
]