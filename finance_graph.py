# finance.py - Personal Finance Assistant
# Step 2: Category-wise breakdown + percentages

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
        bar = "█" * int(percent / 2)  # simple text bar
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


# --- Main Program ---
if __name__ == "__main__":
    profession, income = get_income()
    expenses = get_expenses()
    show_summary(profession, income, expenses)