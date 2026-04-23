# Personal Finance Analytics System

import datetime
import matplotlib.pyplot as plt
import pandas as pd
import os
import sqlite3


#CONSTANTS


CATEGORIES = [
    "Rent/Housing",
    "Food & Groceries",
    "Transport",
    "Utilities",
    "Healthcare",
    "Entertainment",
    "Shopping",
    "Education",
    "Other"
]

HEALTHY_LIMITS = {
    "Rent/Housing"     : 30,
    "Food & Groceries" : 20,
    "Transport"        : 15,
    "Utilities"        : 10,
    "Healthcare"       : 10,
    "Entertainment"    : 10,
    "Shopping"         : 10,
    "Education"        : 10,
    "Other"            : 5
}

#DATA INPUT LAYER


def get_user_info():
    print("\n" + "=" * 55)
    print("     💰 PERSONAL FINANCE ANALYTICS SYSTEM")
    print("=" * 55)

    name       = input("\n  Enter your name: ").strip()
    profession = input("  Enter your profession: ").strip()

    while True:
        try:
            income = float(input("  Enter your monthly income (₹): "))
            if income <= 0:
                print("  ❌ Please enter a valid amount.")
                continue
            break
        except ValueError:
            print("  ❌ Numbers only please.")

    print("\n  📅 Enter the month for this data:")
    print("     (Press Enter to use current month)")
    month_input = input("  Month name (e.g. January, February): ").strip()
    month = month_input if month_input else datetime.datetime.now().strftime("%B")

    print("  Enter the year:")
    year_input = input("  Year (e.g. 2026, press Enter for current): ").strip()
    year = int(year_input) if year_input else datetime.datetime.now().year
    return {
        "name"      : name,
        "profession": profession,
        "income"    : income,
        "month"     : month,
        "year"      : year
    }


def pick_category():
    print("\n    📂 Choose a category:")
    for i, cat in enumerate(CATEGORIES, 1):
        print(f"      {i}. {cat}")

    while True:
        try:
            choice = int(input("    Enter category number: "))
            if 1 <= choice <= len(CATEGORIES):
                return CATEGORIES[choice - 1]
            print(f"    ❌ Enter number between 1 and {len(CATEGORIES)}.")
        except ValueError:
            print("    ❌ Numbers only please.")


def get_expenses():
    expenses = []
    print("\n  📋 Add your expenses (type 'done' to finish)\n")

    while True:
        name = input("  Expense name (or 'done'): ").strip()

        if name.lower() == "done":
            if len(expenses) == 0:
                print("  ❌ Add at least one expense.")
                continue
            break

        if name == "":
            print("  ❌ Name cannot be empty.")
            continue

        category = pick_category()

        print("\n    💡 Expense type:")
        print("      1. Fixed   (same every month e.g. rent)")
        print("      2. Variable (changes monthly e.g. shopping)")
        while True:
            try:
                etype = int(input("    Enter 1 or 2: "))
                if etype in [1, 2]:
                    break
                print("    ❌ Enter 1 or 2 only.")
            except ValueError:
                print("    ❌ Numbers only.")

        expense_type = "Fixed" if etype == 1 else "Variable"

        while True:
            try:
                amount = float(input(f"    Amount for '{name}' (₹): "))
                if amount <= 0:
                    print("    ❌ Enter a valid amount.")
                    continue
                break
            except ValueError:
                print("    ❌ Numbers only please.")

        expenses.append({
            "name"    : name,
            "category": category,
            "type"    : expense_type,
            "amount"  : amount
        })
        print(f"    ✅ Added: {name} ({category} | {expense_type}) - ₹{amount:,.2f}\n")

    return expenses



#ANALYTICS LAYER


def calculate_metrics(user, expenses):
    income         = user["income"]
    total_expenses = sum(e["amount"] for e in expenses)
    savings        = income - total_expenses

    category_totals = {}
    for e in expenses:
        cat = e["category"]
        category_totals[cat] = category_totals.get(cat, 0) + e["amount"]

    fixed_total    = sum(e["amount"] for e in expenses if e["type"] == "Fixed")
    variable_total = sum(e["amount"] for e in expenses if e["type"] == "Variable")

    metrics = {
        "income"          : income,
        "total_expenses"  : total_expenses,
        "savings"         : savings,
        "savings_rate"    : round((max(savings, 0) / income) * 100, 2),
        "expense_ratio"   : round((total_expenses / income) * 100, 2),
        "fixed_total"     : fixed_total,
        "variable_total"  : variable_total,
        "fixed_ratio"     : round((fixed_total / total_expenses) * 100, 2) if total_expenses > 0 else 0,
        "variable_ratio"  : round((variable_total / total_expenses) * 100, 2) if total_expenses > 0 else 0,
        "category_totals" : category_totals,
        "category_percent": {
            cat: round((amt / income) * 100, 2)
            for cat, amt in category_totals.items()
        }
    }

    score = 100
    if metrics["savings_rate"] < 10:   score -= 30
    elif metrics["savings_rate"] < 20: score -= 15
    if metrics["expense_ratio"] > 90:  score -= 20
    elif metrics["expense_ratio"] > 80: score -= 10
    for cat, pct in metrics["category_percent"].items():
        limit = HEALTHY_LIMITS.get(cat, 10)
        if pct > limit:
            score -= 10

    metrics["health_score"] = max(score, 0)
    return metrics



#OUTPUT LAYER


def show_report(user, expenses, metrics):
    print("\n" + "=" * 55)
    print("         📊 FINANCIAL ANALYTICS REPORT")
    print("=" * 55)
    print(f"  Name          : {user['name']}")
    print(f"  Profession    : {user['profession']}")
    print(f"  Period        : {user['month']} {user['year']}")
    print(f"  Monthly Income: ₹{metrics['income']:,.2f}")

    print("\n" + "-" * 55)
    print("  📋 EXPENSE SUMMARY")
    print("-" * 55)
    for e in expenses:
        print(f"  • {e['name']:<18} [{e['category']:<18}] [{e['type']:<8}] ₹{e['amount']:>10,.2f}")

    print("\n" + "-" * 55)
    print("  📈 CORE METRICS")
    print("-" * 55)
    print(f"  Total Expenses  : ₹{metrics['total_expenses']:,.2f}  ({metrics['expense_ratio']}% of income)")
    print(f"  Monthly Savings : ₹{metrics['savings']:,.2f}  ({metrics['savings_rate']}% of income)")
    print(f"  Fixed Expenses  : ₹{metrics['fixed_total']:,.2f}  ({metrics['fixed_ratio']}% of expenses)")
    print(f"  Variable Expenses: ₹{metrics['variable_total']:,.2f} ({metrics['variable_ratio']}% of expenses)")

    print("\n" + "-" * 55)
    print("  📂 CATEGORY ANALYSIS")
    print("-" * 55)
    for cat, amt in metrics["category_totals"].items():
        pct    = metrics["category_percent"][cat]
        limit  = HEALTHY_LIMITS.get(cat, 10)
        status = "✅" if pct <= limit else "❌ OVER LIMIT"
        bar    = "█" * int(pct / 2)
        print(f"  {status} {cat:<20} ₹{amt:>9,.2f}  ({pct}%)  {bar}")

    print("\n" + "-" * 55)
    print("  💯 FINANCIAL HEALTH SCORE")
    print("-" * 55)
    print(f"  Score : {metrics['health_score']} / 100")

    if metrics["health_score"] >= 80:
        print("  Status: 🟢 EXCELLENT - Keep it up!")
    elif metrics["health_score"] >= 60:
        print("  Status: 🟡 AVERAGE - Room for improvement")
    elif metrics["health_score"] >= 40:
        print("  Status: 🟠 POOR - Needs attention")
    else:
        print("  Status: 🔴 CRITICAL - Immediate action needed")

    print("=" * 55)


#BUSINESS INSIGHTS LAYER

def generate_insights(user, metrics):
    income          = metrics["income"]
    total_expenses  = metrics["total_expenses"]
    savings         = metrics["savings"]
    savings_rate    = metrics["savings_rate"]
    category_totals = metrics["category_totals"]
    category_pct    = metrics["category_percent"]

    print("\n" + "=" * 55)
    print("        📋 BUSINESS INSIGHTS REPORT")
    print("=" * 55)

    insights = []

    annual_savings = savings * 12
    insights.append(
        f"💰 At your current rate, you will save "
        f"₹{annual_savings:,.2f} this year."
    )

    for cat, amt in category_totals.items():
        pct   = category_pct[cat]
        limit = HEALTHY_LIMITS.get(cat, 10)
        if pct > limit:
            reduce_by     = amt * 0.10
            annual_saving = reduce_by * 12
            insights.append(
                f"✂️  Reducing {cat} by just 10% "
                f"saves ₹{reduce_by:,.2f}/month "
                f"→ ₹{annual_saving:,.2f}/year."
            )

    if savings_rate >= 30:
        insights.append(
            f"🌟 EXCELLENT: Your {savings_rate}% savings rate "
            f"puts you in top 10% of savers in India."
        )
    elif savings_rate >= 20:
        insights.append(
            f"✅ GOOD: Your {savings_rate}% savings rate "
            f"meets the recommended 20% benchmark."
        )
    elif savings_rate >= 10:
        insights.append(
            f"⚠️  AVERAGE: Your {savings_rate}% savings rate "
            f"is below recommended 20%. "
            f"Increase by ₹{(income * 0.20) - savings:,.2f}/month."
        )
    else:
        insights.append(
            f"🚨 CRITICAL: Only {savings_rate}% savings rate. "
            f"You need ₹{(income * 0.20) - savings:,.2f} more "
            f"saved per month to reach safe zone."
        )

    if metrics["variable_ratio"] > 50:
        potential = metrics["variable_total"] * 0.20
        insights.append(
            f"📊 {metrics['variable_ratio']}% of your expenses "
            f"are variable (flexible). "
            f"Cutting them by 20% frees ₹{potential:,.2f}/month."
        )

    emergency_fund_needed = total_expenses * 6
    months_to_emergency   = (
        round(emergency_fund_needed / savings)
        if savings > 0 else "∞"
    )
    insights.append(
        f"🏦 EMERGENCY FUND: You need ₹{emergency_fund_needed:,.2f} "
        f"(6 months expenses). "
        f"At current savings → {months_to_emergency} months away."
    )

    biggest_cat = max(category_totals, key=category_totals.get)
    biggest_amt = category_totals[biggest_cat]
    biggest_pct = category_pct[biggest_cat]
    insights.append(
        f"🔍 BIGGEST EXPENSE: {biggest_cat} at "
        f"₹{biggest_amt:,.2f} ({biggest_pct}% of income). "
        f"This is your #1 area to optimize."
    )

    if savings > 0:
        sip_5yr = savings * 12 * 5 * 1.12
        insights.append(
            f"📈 INVESTMENT OPPORTUNITY: If you invest "
            f"₹{savings:,.2f}/month in SIP → "
            f"~₹{sip_5yr:,.2f} in 5 years at 12% returns."
        )

    print()
    for i, insight in enumerate(insights, 1):
        print(f"  {i}. {insight}")
        print()

    print("=" * 55)


#FUTURE SAVINGS PLANNER

def goal_planning(metrics):
    print("\n" + "=" * 55)
    print("         🎯 FUTURE SAVINGS PLANNER")
    print("=" * 55)

    want_goal = input("\n  Do you have a savings goal? (yes/no): ").strip().lower()
    if want_goal != "yes":
        print("  No problem! You can plan a goal anytime.")
        return

    goal_name = input("\n  What do you want to save for? : ").strip()

    while True:
        try:
            goal_amount = float(input(f"  Total amount needed for '{goal_name}' (₹): "))
            if goal_amount <= 0:
                print("  ❌ Enter a valid amount.")
                continue
            break
        except ValueError:
            print("  ❌ Numbers only.")

    while True:
        try:
            goal_months = int(input("  In how many months do you want it?: "))
            if goal_months <= 0:
                print("  ❌ Enter a valid number.")
                continue
            break
        except ValueError:
            print("  ❌ Numbers only.")

    income           = metrics["income"]
    current_savings  = max(metrics["savings"], 0)
    required_monthly = round(goal_amount / goal_months, 2)
    gap              = round(required_monthly - current_savings, 2)
    total_variable   = metrics["variable_total"]

    if current_savings > 0:
        realistic_months = round(goal_amount / current_savings)
    else:
        realistic_months = None

    print("\n" + "=" * 55)
    print("         📊 GOAL ANALYSIS REPORT")
    print("=" * 55)
    print(f"  Goal            : {goal_name}")
    print(f"  Target Amount   : ₹{goal_amount:,.2f}")
    print(f"  Your Timeline   : {goal_months} months")
    print(f"  Required/month  : ₹{required_monthly:,.2f}")
    print(f"  Current Savings : ₹{current_savings:,.2f}/month")
    print("-" * 55)

    if gap <= 0:
        print(f"\n  ✅ GOAL IS ACHIEVABLE!")
        print(f"     You already save ₹{current_savings:,.2f}/month.")
        print(f"     You will reach ₹{goal_amount:,.2f} in {goal_months} months.")
        extra = abs(gap)
        print(f"     You'll even have ₹{extra * goal_months:,.2f} extra by then!")
        print(f"\n  💡 TIP: Open a separate savings account and auto-transfer")
        print(f"     ₹{required_monthly:,.2f} every month on salary day.")
    else:
        print(f"\n  ⚠️  GAP: You need ₹{gap:,.2f} more per month.")

        if realistic_months:
            print(f"\n  📅 REALISTIC TIMELINE:")
            print(f"     At your current savings rate,")
            print(f"     you will reach this goal in {realistic_months} months")
            print(f"     instead of {goal_months} months.")

        if gap <= income * 0.05:
            difficulty = "EASY"
        elif gap <= income * 0.15:
            difficulty = "MEDIUM"
        else:
            difficulty = "HARD"

        print(f"\n  ⚙️  GOAL DIFFICULTY: {difficulty}")
        print("-" * 55)

        if difficulty == "EASY":
            print(f"\n  Small tweaks needed to save ₹{gap:,.2f} more/month:")
            print(f"  • Skip 2-3 food orders/month → saves ₹{gap:,.2f}")
            print(f"  • Or reduce one subscription service")
            print(f"  • This is very achievable — just be consistent!")

        elif difficulty == "MEDIUM":
            print(f"\n  Moderate changes needed. Here's your action plan:")
            var_cut = round(total_variable * 0.15, 2)
            print(f"  • Cut variable expenses by 15%")
            print(f"    → That saves ₹{var_cut:,.2f}/month")
            remaining_gap = round(gap - var_cut, 2)
            if remaining_gap > 0:
                print(f"  • Still need ₹{remaining_gap:,.2f} more")
                print(f"    → Consider freelance work or part-time income")
            easier_months = goal_months + 4
            print(f"\n  📅 Extended timeline option:")
            print(f"  • Extend to {easier_months} months")
            print(f"    → Only ₹{round(goal_amount/easier_months, 2):,.2f}/month needed")

        elif difficulty == "HARD":
            print(f"\n  🚨 This goal needs serious planning.")
            print(f"  Here is your realistic step-by-step plan:\n")
            var_cut = round(total_variable * 0.25, 2)
            print(f"  STEP 1: Cut variable expenses by 25%")
            print(f"          → Saves ₹{var_cut:,.2f}/month")
            easier_months = goal_months + 6
            print(f"\n  STEP 2: Extend timeline to {easier_months} months")
            print(f"          → Reduces monthly need to ₹{round(goal_amount/easier_months, 2):,.2f}")
            print(f"\n  STEP 3: Increase income by ₹{round(gap/2, 2):,.2f}/month")
            print(f"          → Freelance, tutoring, or part-time work")
            combined_saving = round(current_savings + var_cut, 2)
            actual_months   = round(goal_amount / combined_saving) if combined_saving > 0 else "N/A"
            print(f"\n  📅 MOST REALISTIC PLAN:")
            print(f"  With cuts + extended time → reach goal in")
            print(f"  ~{actual_months} months at ₹{combined_saving:,.2f}/month savings")

    print("\n" + "-" * 55)
    print("  📌 GOLDEN RULES FOR THIS GOAL:")
    print(f"  1. Save ₹{required_monthly:,.2f} on the SAME day you get salary")
    print(f"  2. Keep goal money in a SEPARATE account")
    print(f"  3. Review your progress every month")
    print(f"  4. Any extra income → put 50% into this goal")
    print("=" * 55)

#VISUALIZATION LAYER
def show_charts(user, metrics):
    print("\n📊 Opening charts...")

    category_totals = metrics["category_totals"]
    income          = metrics["income"]
    total_expenses  = metrics["total_expenses"]
    savings         = max(metrics["savings"], 0)

    labels = list(category_totals.keys())
    sizes  = list(category_totals.values())

    fig, axes = plt.subplots(1, 2, figsize=(14, 6))
    fig.suptitle(
        f"Finance Report - {user['name']} ({user['month']} {user['year']})",
        fontsize=14,
        fontweight="bold"
    )

    axes[0].pie(sizes, labels=labels, autopct="%1.1f%%", startangle=140)
    axes[0].set_title("Category-wise Spending")

    bar_labels = ["Monthly Income", "Total Expenses", "Savings"]
    bar_values = [income, total_expenses, savings]
    bar_colors = ["#4CAF50", "#F44336", "#2196F3"]

    bars = axes[1].bar(bar_labels, bar_values, color=bar_colors, width=0.5)
    axes[1].set_title("Income vs Expenses vs Savings")
    axes[1].set_ylabel("Amount (₹)")

    for bar in bars:
        height = bar.get_height()
        axes[1].text(
            bar.get_x() + bar.get_width() / 2,
            height + (income * 0.01),
            f"₹{height:,.0f}",
            ha="center",
            va="bottom",
            fontsize=10
        )

    plt.tight_layout()
    plt.show()

#EXPORT LAYER (Power BI Ready)

def export_to_csv(user, expenses, metrics, user_id):
    print("\n📤 Exporting data for Power BI...")

    expense_rows = []
    for e in expenses:
        expense_rows.append({
            "User_ID"       : user_id,
            "Name"          : user["name"],
            "Profession"    : user["profession"],
            "Month"         : user["month"],
            "Year"          : user["year"],
            "Expense_Name"  : e["name"],
            "Category"      : e["category"],
            "Type"          : e["type"],
            "Amount"        : e["amount"],
            "Income"        : user["income"],
            "Pct_of_Income" : round((e["amount"] / user["income"]) * 100, 2)
        })

    df_expenses = pd.DataFrame(expense_rows)

    metrics_row = {
        "User_ID"        : user_id,
        "Name"           : user["name"],
        "Profession"     : user["profession"],
        "Month"          : user["month"],
        "Year"           : user["year"],
        "Income"         : metrics["income"],
        "Total_Expenses" : metrics["total_expenses"],
        "Savings"        : metrics["savings"],
        "Savings_Rate"   : metrics["savings_rate"],
        "Expense_Ratio"  : metrics["expense_ratio"],
        "Fixed_Total"    : metrics["fixed_total"],
        "Variable_Total" : metrics["variable_total"],
        "Fixed_Ratio"    : metrics["fixed_ratio"],
        "Variable_Ratio" : metrics["variable_ratio"],
        "Health_Score"   : metrics["health_score"]
    }

    df_metrics = pd.DataFrame([metrics_row])

    category_rows = []
    for cat, amt in metrics["category_totals"].items():
        limit  = HEALTHY_LIMITS.get(cat, 10)
        pct    = metrics["category_percent"][cat]
        status = "Within Limit" if pct <= limit else "Over Limit"
        category_rows.append({
            "User_ID"       : user_id,
            "Name"          : user["name"],
            "Month"         : user["month"],
            "Year"          : user["year"],
            "Category"      : cat,
            "Amount"        : amt,
            "Pct_of_Income" : pct,
            "Healthy_Limit" : limit,
            "Status"        : status,
            "Over_By"       : round(max(pct - limit, 0), 2)
        })

    df_categories = pd.DataFrame(category_rows)

    export_folder = "exports"
    os.makedirs(export_folder, exist_ok=True)

    filename = f"{export_folder}/finance_{user['name']}_ALL_MONTHS.xlsx"

    if os.path.exists(filename):
        old_expenses   = pd.read_excel(filename, sheet_name="Expense_Details")
        old_metrics    = pd.read_excel(filename, sheet_name="Monthly_Metrics")
        old_categories = pd.read_excel(filename, sheet_name="Category_Summary")

        df_expenses   = pd.concat([old_expenses,   df_expenses],   ignore_index=True)
        df_metrics    = pd.concat([old_metrics,    df_metrics],    ignore_index=True)
        df_categories = pd.concat([old_categories, df_categories], ignore_index=True)

    with pd.ExcelWriter(filename, engine="openpyxl", mode="w") as writer:
        df_expenses.to_excel(writer,   sheet_name="Expense_Details",  index=False)
        df_metrics.to_excel(writer,    sheet_name="Monthly_Metrics",   index=False)
        df_categories.to_excel(writer, sheet_name="Category_Summary",  index=False)

    print(f"  ✅ Exported to: {filename}")
    print(f"  📂 3 sheets: Expense_Details, Monthly_Metrics, Category_Summary")
    print(f"  💡 Open this file directly in Power BI!")


    print(f"  ✅ Exported to: {filename}")
    print(f"  📂 3 sheets: Expense_Details, Monthly_Metrics, Category_Summary")
    print(f"  💡 Open this file directly in Power BI!")


#MAIN PROGRAM

if __name__ == "__main__":
    from database import (
        create_tables, save_user, save_income,
        save_expenses, save_metrics, show_history
    )

    create_tables()

    user     = get_user_info()
    expenses = get_expenses()
    metrics  = calculate_metrics(user, expenses)

    user_id  = save_user(user["name"], user["profession"])
    save_income(user_id, user["income"], user["month"], user["year"])
    save_expenses(user_id, expenses, user["month"], user["year"])
    save_metrics(user_id, metrics, user["month"], user["year"])

    show_report(user, expenses, metrics)
    generate_insights(user, metrics)

    try:
        export_to_csv(user, expenses, metrics, user_id)
    except Exception as e:
        print(f"  ❌ Export error: {e}")

    goal_planning(metrics)

    print("\n  📅 Loading your history...\n")
    show_history(user_id, user["name"])

    show_charts(user, metrics)