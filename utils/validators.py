# Input validation for all forms

def validate_register(username, password, name, profession):
    errors = []

    if not username or len(username) < 3:
        errors.append("Username must be at least 3 characters.")
    if len(username) > 30:
        errors.append("Username must be under 30 characters.")
    if not password or len(password) < 6:
        errors.append("Password must be at least 6 characters.")
    if not name or len(name) < 2:
        errors.append("Name must be at least 2 characters.")
    if not profession or len(profession) < 2:
        errors.append("Profession must be at least 2 characters.")

    return errors


def validate_income(income_str):
    try:
        income = float(income_str)
        if income <= 0:
            return None, "Income must be greater than 0."
        if income > 10000000:
            return None, "Please enter a realistic income amount."
        return income, None
    except (ValueError, TypeError):
        return None, "Income must be a valid number."


def validate_expenses(names, amounts):
    expenses_valid = []
    errors = []

    for i in range(len(names)):
        name   = names[i].strip() if names[i] else ""
        amount = amounts[i].strip() if amounts[i] else ""

        if not name and not amount:
            continue

        if not name:
            errors.append(f"Expense #{i+1} is missing a name.")
            continue

        try:
            amt = float(amount)
            if amt <= 0:
                errors.append(f"Amount for '{name}' must be greater than 0.")
                continue
            expenses_valid.append((name, amt))
        except ValueError:
            errors.append(f"Amount for '{name}' must be a valid number.")

    if not expenses_valid:
        errors.append("Please add at least one valid expense.")

    return expenses_valid, errors


def validate_goal(goal_amount_str, goal_months_str, savings_str, income_str):
    errors = []
    values = {}

    try:
        values["goal_amount"] = float(goal_amount_str)
        if values["goal_amount"] <= 0:
            errors.append("Goal amount must be greater than 0.")
    except (ValueError, TypeError):
        errors.append("Goal amount must be a valid number.")

    try:
        values["goal_months"] = int(goal_months_str)
        if values["goal_months"] <= 0:
            errors.append("Timeline must be at least 1 month.")
        if values["goal_months"] > 600:
            errors.append("Timeline cannot exceed 50 years.")
    except (ValueError, TypeError):
        errors.append("Timeline must be a valid number.")

    try:
        values["savings"] = float(savings_str)
        if values["savings"] < 0:
            errors.append("Savings cannot be negative.")
    except (ValueError, TypeError):
        errors.append("Savings must be a valid number.")

    try:
        values["income"] = float(income_str)
        if values["income"] <= 0:
            errors.append("Income must be greater than 0.")
    except (ValueError, TypeError):
        errors.append("Income must be a valid number.")

    return values, errors