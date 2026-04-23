# ai.py - Personal Finance Assistant
# Final Version: Gemini AI Integration

import matplotlib.pyplot as plt
import google.generativeai as genai

# --- PUT YOUR GEMINI API KEY HERE ---
genai.configure(api_key="AIzaSyA0l_rc2claeqF7Cqg9RMZHZpgw-iEIZw4")

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
        advice_given = True

    save_percent = (remaining / income) * 100 if remaining > 0 else 0
    if 0 <= save_percent < 10:
        print(f"\n  ⚠️  LOW SAVINGS: Saving only {save_percent:.1f}% of income.")
        print(f"     Aim for at least 20% (₹{income * 0.20:,.2f}/month).")
        advice_given = True
    elif save_percent >= 20:
        print(f"\n  ✅ GREAT: Saving {save_percent:.1f}% of income (₹{remaining:,.2f})!")
        advice_given = True

    rent = category_totals.get("Rent/Housing", 0)
    if (rent / income) * 100 > 30:
        print(f"\n  🏠 HIGH RENT: ₹{rent:,.2f} is {(rent/income)*100:.1f}% of income.")
        print(f"     Ideal is under 30% (₹{income * 0.30:,.2f}).")
        advice_given = True

    food = category_totals.get("Food & Groceries", 0)
    if (food / income) * 100 > 20:
        print(f"\n  🍔 HIGH FOOD: ₹{food:,.2f} is {(food/income)*100:.1f}% of income.")
        print(f"     Cooking at home could save ₹{food - income * 0.20:,.2f}/month.")
        advice_given = True

    entertainment = category_totals.get("Entertainment", 0)
    if (entertainment / income) * 100 > 10:
        print(f"\n  🎬 HIGH ENTERTAINMENT: ₹{entertainment:,.2f}.")
        print(f"     Cutting to 10% saves ₹{entertainment - income * 0.10:,.2f}/month.")
        advice_given = True

    shopping = category_totals.get("Shopping", 0)
    if (shopping / income) * 100 > 10:
        print(f"\n  🛍️  HIGH SHOPPING: ₹{shopping:,.2f}.")
        print(f"     Cutting to 10% saves ₹{shopping - income * 0.10:,.2f}/month.")
        advice_given = True

    if not advice_given:
        print(f"\n  ✅ Spending looks balanced! Consider investing your savings.")

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


def show_goal_analysis(goal, remaining, income, category_totals):
    if goal is None:
        return None, None, None

    required_monthly = goal["amount"] / goal["months"]
    current_savings  = max(remaining, 0)
    gap              = required_monthly - current_savings

    print("\n" + "=" * 50)
    print("           🎯 GOAL ANALYSIS")
    print("=" * 50)
    print(f"\n  Goal          : {goal['name']}")
    print(f"  Target Amount : ₹{goal['amount']:,.2f}")
    print(f"  Time Frame    : {goal['months']} months")
    print("\n" + "-" * 50)
    print(f"  Required Monthly Savings : ₹{required_monthly:,.2f}")
    print(f"  Your Current Savings     : ₹{current_savings:,.2f}")

    if gap <= 0:
        print(f"\n  ✅ You can already achieve this goal!")
        print(f"     You have ₹{abs(gap):,.2f} extra every month.")
    else:
        print(f"\n  ⚠️  GAP: You need ₹{gap:,.2f} more per month.")

    print("=" * 50)

    run_decision_engine(goal, required_monthly, current_savings, gap, income, category_totals)

    return required_monthly, current_savings, gap


def run_decision_engine(goal, required_monthly, current_savings, gap, income, category_totals):
    print("\n" + "=" * 50)
    print("        ⚙️  DECISION ENGINE")
    print("=" * 50)

    if gap <= 0:
        difficulty = "easy"
    elif gap <= income * 0.10:
        difficulty = "medium"
    else:
        difficulty = "hard"

    print(f"\n  Goal        : {goal['name']}")
    print(f"  Monthly Gap : ₹{max(gap, 0):,.2f}")

    if difficulty == "easy":
        print(f"\n  ✅ GOAL DIFFICULTY: EASY")
        print(f"     You are already on track!")
        print(f"     Put savings in a separate account so you don't spend it.")

    elif difficulty == "medium":
        print(f"\n  ⚠️  GOAL DIFFICULTY: MEDIUM")
        print(f"     Small adjustments can close the ₹{gap:,.2f} gap.\n")
        entertainment = category_totals.get("Entertainment", 0)
        if entertainment > 0:
            print(f"     • Reduce Entertainment by ₹{min(entertainment*0.20, gap):,.2f}")
        shopping = category_totals.get("Shopping", 0)
        if shopping > 0:
            print(f"     • Reduce Shopping by ₹{min(shopping*0.20, gap):,.2f}")
        food = category_totals.get("Food & Groceries", 0)
        if food > 0:
            print(f"     • Reduce Food by ₹{min(food*0.10, gap):,.2f}")

    elif difficulty == "hard":
        print(f"\n  🚨 GOAL DIFFICULTY: HARD")
        print(f"     Serious changes needed to bridge ₹{gap:,.2f}/month.\n")
        sorted_cats = sorted(category_totals.items(), key=lambda x: x[1], reverse=True)
        for cat, amount in sorted_cats[:2]:
            print(f"     • Cut {cat} by 20% → save ₹{amount*0.20:,.2f}/month")
        extended_months = goal["months"] + 3
        print(f"\n     • Or extend to {extended_months} months →")
        print(f"       Only ₹{goal['amount']/extended_months:,.2f}/month needed")

    print("\n" + "=" * 50)
    return difficulty


def build_ai_prompt(profession, income, total_expenses, remaining,
                    category_totals, goal, required_monthly, current_savings, gap):

    category_lines = ""
    for cat, amount in category_totals.items():
        percent = (amount / income) * 100
        category_lines += f"  - {cat}: ₹{amount:,.2f} ({percent:.1f}% of income)\n"

    if goal:
        if gap <= 0:
            difficulty = "EASY"
            gap_line = f"No gap. User has ₹{abs(gap):,.2f} extra per month."
        elif gap <= income * 0.10:
            difficulty = "MEDIUM"
            gap_line = f"Gap of ₹{gap:,.2f}/month. Small changes needed."
        else:
            difficulty = "HARD"
            gap_line = f"Gap of ₹{gap:,.2f}/month. Major changes needed."

        goal_section = f"""
SAVINGS GOAL:
  - Goal Name       : {goal['name']}
  - Target Amount   : ₹{goal['amount']:,.2f}
  - Time Frame      : {goal['months']} months
  - Required/month  : ₹{required_monthly:,.2f}
  - Current Savings : ₹{current_savings:,.2f}
  - Goal Difficulty : {difficulty}
  - Gap Status      : {gap_line}
"""
    else:
        goal_section = "SAVINGS GOAL: None set by user.\n"
        difficulty = "none"

    prompt = f"""
You are a practical, no-nonsense personal finance advisor in India.
Analyze this person's REAL financial data and give genuinely useful advice
like a smart friend who knows finance deeply.

STRICT RULES:
1. Use exact ₹ numbers from their data in your advice.
2. Never say vague things like "spend less" — say exactly WHERE and HOW MUCH.
3. Tackle the biggest financial problems first.
4. If goal is HARD → be firm but realistic. Give a step-by-step plan.
5. If goal is EASY/MEDIUM → encourage and suggest small improvements.
6. Always suggest at least one way to increase income if expenses are high.
7. Keep advice practical for someone living in India.
8. End with one powerful motivational sentence based on their situation.
9. Use clear sections with emojis for readability.
10. Speak directly to the user as "you". Be like a mentor, not a robot.

USER DATA:
  - Profession      : {profession}
  - Monthly Income  : ₹{income:,.2f}
  - Total Expenses  : ₹{total_expenses:,.2f}
  - Monthly Savings : ₹{max(remaining, 0):,.2f}
  - Savings Rate    : {(max(remaining, 0)/income)*100:.1f}% of income

SPENDING BREAKDOWN:
{category_lines}
{goal_section}

Give honest, practical, specific advice now. No fluff. Real talk.
"""
    return prompt, difficulty


def get_ai_advice(profession, income, total_expenses, remaining,
                  category_totals, goal, required_monthly, current_savings, gap):

    print("\n" + "=" * 50)
    print("        🤖 AI FINANCIAL MENTOR")
    print("=" * 50)
    print("\n  ⏳ Analyzing your finances...\n")

    prompt, difficulty = build_ai_prompt(
        profession, income, total_expenses, remaining,
        category_totals, goal, required_monthly, current_savings, gap
    )

    try:
        model = genai.GenerativeModel(model_name="gemini-2.0-flash")

        full_prompt = (
            "You are a practical Indian personal finance advisor. "
            "You give real, actionable advice with exact ₹ numbers. "
            "You are direct, honest, and genuinely helpful. "
            "Never give generic advice. Always use the user's actual data. "
            "Talk like a smart, caring mentor — not a robot.\n\n"
            + prompt
        )

        response = model.generate_content(full_prompt)
        advice = response.text
        print(advice)

    except Exception as e:
        print(f"  ❌ AI Error: {e}")
        print("  Make sure your Gemini API key is correct.")

    except Exception as e:
        print(f"  ❌ AI Error: {e}")
        print("  Make sure your Gemini API key is correct.")

    print("\n" + "=" * 50)


def show_charts(profession, income, expenses, total_expenses, remaining, category_totals):
    print("\n📊 Opening charts...")

    labels = list(category_totals.keys())
    sizes  = list(category_totals.values())

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
    expenses           = get_expenses()

    total_expenses, remaining, category_totals = show_summary(profession, income, expenses)
    give_advice(income, total_expenses, remaining, category_totals)

    goal = get_goal()
    required_monthly = current_savings = gap = None

    if goal:
        required_monthly, current_savings, gap = show_goal_analysis(
            goal, remaining, income, category_totals
        )

    get_ai_advice(
        profession, income, total_expenses, remaining,
        category_totals, goal,
        required_monthly or 0,
        current_savings or max(remaining, 0),
        gap or 0
    )

    show_charts(profession, income, expenses, total_expenses, remaining, category_totals)