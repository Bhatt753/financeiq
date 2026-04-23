
# Goal system + gap calculation

import matplotlib.pyplot as plt

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


def get_income():
    print("\n👋 Welcome to Your Personal Finance Assistant!")
    print("-" * 45)

    profession = input("What is your profession? ")

    while True:
        try:
            income = float(input("What is your monthly income (₹)? "))
            if income <= 0:
                print("❌ Please enter a valid income amount.")
                continue
            break
        except ValueError:
            print("❌ Please enter a number only.")

    return profession, income


def pick_category():
    print("\n  📂 Choose a category:")
    for i, cat in enumerate(CATEGORIES, 1):
        print(f"    {i}. {cat}")

    while True:
        try:
            choice = int(input("  Enter category number: "))
            if 1 <= choice <= len(CATEGORIES):
                return CATEGORIES[choice - 1]
            else:
                print(f"  ❌ Please enter a number between 1 and {len(CATEGORIES)}.")
        except ValueError:
            print("  ❌ Please enter a number only.")


def get_expenses():
    expenses = []
    print("\n📋 Let's add your expenses.")
    print("Type 'done' when you have entered all expenses.\n")

    while True:
        name = input("Expense name (or type 'done' to finish): ").strip()

        if name.lower() == "done":
            if len(expenses) == 0:
                print("❌ Please add at least one expense.")
                continue
            break

        if name == "":
            print("❌ Expense name cannot be empty.")
            continue

        category = pick_category()

        while True:
            try:
                amount = float(input(f"  Amount for '{name}' (₹): "))
                if amount <= 0:
                    print("  ❌ Please enter a valid amount.")
                    continue
                break
            except ValueError:
                print("  ❌ Please enter a number only.")

        expenses.append({
            "name": name,
            "category": category,
            "amount": amount
        })
        print(f"  ✅ Added: {name} ({category}) - ₹{amount:.2f}\n")

    return expenses


def get_category_totals(expenses):
    totals = {}
    for e in expenses:
        cat = e["category"]
        totals[cat] = totals.get(cat, 0) + e["amount"]
    return totals


def show_summary(profession, income, expenses):
    total_expenses = sum(e["amount"] for e in expenses)
    remaining = income - total_expenses
    category_totals = get_category_totals(expenses)

    print("\n" + "=" * 50)
    print("          💰 YOUR FINANCIAL SUMMARY")
    print("=" * 50)
    print(f"  Profession     : {profession}")
    print(f"  Monthly Income : ₹{income:,.2f}")

    print("\n" + "-" * 50)
    print("  📋 ALL EXPENSES:")
    print("-" * 50)
    for e in expenses:
        print(f"    • {e['name']:<18} [{e['category']}]   ₹{e['amount']:>10,.2f}")

    print("\n" + "-" * 50)
    print("  📂 CATEGORY-WISE BREAKDOWN:")
    print("-" * 50)
    for cat, total in category_totals.items():
        percent = (total / income) * 100
        bar = "█" * int(percent / 2)
        print(f"    {cat:<20} ₹{total:>10,.2f}   ({percent:.1f}%)  {bar}")

    print("\n" + "-" * 50)
    spent_percent = (total_expenses / income) * 100
    print(f"  Total Expenses : ₹{total_expenses:,.2f}  ({spent_percent:.1f}% of income)")

    if remaining >= 0:
        save_percent = (remaining / income) * 100
        print(f"  Savings        : ₹{remaining:,.2f}  ({save_percent:.1f}% of income) ✅")
    else:
        print(f"  Deficit        : ₹{abs(remaining):,.2f} ⚠️  (You are overspending!)")

    print("=" * 50)

    return total_expenses, remaining, category_totals


def give_advice(income, total_expenses, remaining, category_totals):
    print("\n" + "=" * 50)
    print("        🧠 PRACTICAL FINANCIAL ADVICE")
    print("=" * 50)

    advice_given = False

    if remaining < 0:
        print(f"\n  🚨 CRITICAL: You are overspending by ₹{abs(remaining):,.2f}!")
        print(f"     You MUST cut expenses immediately.")
        print(f"     Start by reducing your biggest expense category.")
        advice_given = True

    save_percent = (remaining / income) * 100 if remaining > 0 else 0
    if 0 <= save_percent < 10:
        print(f"\n  ⚠️  LOW SAVINGS: You are saving only {save_percent:.1f}% of your income.")
        print(f"     Aim for at least 20% savings (₹{income * 0.20:,.2f}/month).")
        print(f"     Try reducing small daily expenses first.")
        advice_given = True
    elif save_percent >= 20:
        print(f"\n  ✅ GREAT JOB: You are saving {save_percent:.1f}% of your income!")
        print(f"     That's ₹{remaining:,.2f}/month. Consider investing this amount.")
        advice_given = True

    rent = category_totals.get("Rent/Housing", 0)
    rent_percent = (rent / income) * 100
    if rent_percent > 30:
        suggested_rent = income * 0.30
        print(f"\n  🏠 HIGH RENT: Your rent is {rent_percent:.1f}% of income (₹{rent:,.2f}).")
        print(f"     Ideal rent should be under 30% (₹{suggested_rent:,.2f}).")
        print(f"     Consider sharing accommodation or moving to a cheaper place.")
        advice_given = True

    food = category_totals.get("Food & Groceries", 0)
    food_percent = (food / income) * 100
    if food_percent > 20:
        suggested_food = income * 0.20
        save_amount = food - suggested_food
        print(f"\n  🍔 HIGH FOOD EXPENSE: Food is {food_percent:.1f}% of income (₹{food:,.2f}).")
        print(f"     Try cooking at home more often.")
        print(f"     Reducing to 20% could save you ₹{save_amount:,.2f}/month.")
        advice_given = True

    entertainment = category_totals.get("Entertainment", 0)
    ent_percent = (entertainment / income) * 100
    if ent_percent > 10:
        suggested_ent = income * 0.10
        save_amount = entertainment - suggested_ent
        print(f"\n  🎬 HIGH ENTERTAINMENT: {ent_percent:.1f}% of income (₹{entertainment:,.2f}).")
        print(f"     Try cutting this to 10% and save ₹{save_amount:,.2f}/month.")
        advice_given = True

    shopping = category_totals.get("Shopping", 0)
    shop_percent = (shopping / income) * 100
    if shop_percent > 10:
        suggested_shop = income * 0.10
        save_amount = shopping - suggested_shop
        print(f"\n  🛍️  HIGH SHOPPING: {shop_percent:.1f}% of income (₹{shopping:,.2f}).")
        print(f"     Reduce impulse buying. Cutting to 10% saves ₹{save_amount:,.2f}/month.")
        advice_given = True

    transport = category_totals.get("Transport", 0)
    trans_percent = (transport / income) * 100
    if trans_percent > 15:
        suggested_trans = income * 0.15
        save_amount = transport - suggested_trans
        print(f"\n  🚗 HIGH TRANSPORT: {trans_percent:.1f}% of income (₹{transport:,.2f}).")
        print(f"     Consider using public transport or carpooling.")
        print(f"     Reducing to 15% could save ₹{save_amount:,.2f}/month.")
        advice_given = True

    if not advice_given:
        print(f"\n  ✅ Your spending looks balanced!")
        print(f"     Keep maintaining this habit.")
        print(f"     Consider investing your savings in SIP or FD for growth.")

    print("\n" + "=" * 50)


def get_goal():
    print("\n" + "=" * 50)
    print("           🎯 SAVINGS GOAL SETUP")
    print("=" * 50)

    want_goal = input("\n  Do you have a savings goal? (yes/no): ").strip().lower()

    if want_goal != "yes":
        print("  No problem! You can set a goal anytime.")
        return None

    goal_name = input("\n  What is your goal? (e.g. Buy a bike, Emergency fund): ").strip()

    while True:
        try:
            goal_amount = float(input(f"  How much do you need for '{goal_name}' (₹)? "))
            if goal_amount <= 0:
                print("  ❌ Please enter a valid amount.")
                continue
            break
        except ValueError:
            print("  ❌ Please enter a number only.")

    while True:
        try:
            goal_months = int(input(f"  In how many months do you want to achieve this? "))
            if goal_months <= 0:
                print("  ❌ Please enter a valid number of months.")
                continue
            break
        except ValueError:
            print("  ❌ Please enter a whole number.")

    return {
        "name": goal_name,
        "amount": goal_amount,
        "months": goal_months
    }


def show_goal_analysis(goal, remaining):
    if goal is None:
        return

    required_monthly = goal["amount"] / goal["months"]
    current_savings = max(remaining, 0)
    gap = required_monthly - current_savings

    print("\n" + "=" * 50)
    print("           🎯 GOAL ANALYSIS")
    print("=" * 50)
    print(f"\n  Goal         : {goal['name']}")
    print(f"  Target Amount: ₹{goal['amount']:,.2f}")
    print(f"  Time Frame   : {goal['months']} months")
    print("\n" + "-" * 50)
    print(f"  Required Monthly Savings : ₹{required_monthly:,.2f}")
    print(f"  Your Current Savings     : ₹{current_savings:,.2f}")

    if gap <= 0:
        print(f"\n  ✅ GREAT! You can already achieve this goal!")
        print(f"     You have ₹{abs(gap):,.2f} extra every month.")
    else:
        print(f"\n  ⚠️  GAP: You need ₹{gap:,.2f} more per month to reach your goal.")
        print(f"     You will need to either reduce expenses or increase income.")

    print("=" * 50)

    return required_monthly, current_savings, gap


def show_charts(profession, income, expenses, total_expenses, remaining, category_totals):
    print("\n📊 Opening charts...")

    labels = list(category_totals.keys())
    sizes = list(category_totals.values())

    fig, axes = plt.subplots(1, 2, figsize=(14, 6))
    fig.suptitle(f"Finance Summary - {profession}", fontsize=14, fontweight="bold")

    axes[0].pie(sizes, labels=labels, autopct="%1.1f%%", startangle=140)
    axes[0].set_title("Category-wise Spending")

    bar_labels = ["Monthly Income", "Total Expenses", "Savings"]
    bar_values = [income, total_expenses, max(remaining, 0)]
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


# --- Main Program ---
if __name__ == "__main__":
    profession, income = get_income()
    expenses = get_expenses()
    total_expenses, remaining, category_totals = show_summary(profession, income, expenses)
    give_advice(income, total_expenses, remaining, category_totals)
    goal = get_goal()
    show_goal_analysis(goal, remaining)
    show_charts(profession, income, expenses, total_expenses, remaining, category_totals)