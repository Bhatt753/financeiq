# utils/loan_utils.py
# Date-based EMI filtering — only include loans active for a given month/year

MONTH_ORDER = {
    "January": 1, "February": 2, "March": 3,  "April": 4,
    "May": 5,     "June": 6,     "July": 7,   "August": 8,
    "September": 9, "October": 10, "November": 11, "December": 12
}

_MONTH_NAMES = list(MONTH_ORDER.keys())   # index 0 = "January"


def get_active_loans(user_id, month=None, year=None):
    """
    Returns (active_loans, inactive_loans).

    active_loans   — loans active during the given month/year (EMI deducted)
    inactive_loans — loans that exist but were not active that month

    Rules:
      - status == 'closed'                    → never included in either list
      - missing start_month / start_year      → assumed always active
      - month / year not provided             → all non-closed loans are active
    """
    from models.database import get_user_loans
    user_loans = get_user_loans(user_id)

    active   = []
    inactive = []

    for loan in user_loans:
        if loan.get("status") == "closed":
            continue

        loan_dict = {
            "type"          : loan["loan_type"],
            "emi"           : loan["emi"],
            "interest_rate" : loan["interest_rate"],
            "outstanding"   : loan.get("principal", 0),
            "loan_name"     : loan.get("loan_name", loan["loan_type"]),
            "start_month"   : loan.get("start_month", ""),
            "start_year"    : loan.get("start_year"),
            "tenure_months" : loan.get("tenure_months", 0),
        }

        # No filter → all non-closed loans are active
        if month is None or year is None:
            active.append(loan_dict)
            continue

        # Missing date info → assume always active
        if (not loan.get("start_month") or not loan.get("start_year")
                or not loan.get("tenure_months")):
            active.append(loan_dict)
            continue

        start_m = MONTH_ORDER.get(loan["start_month"], 1)
        start_y = int(loan["start_year"])
        tenure  = int(loan["tenure_months"])

        start_total = start_y * 12 + start_m - 1
        end_total   = start_total + tenure - 1   # inclusive last active month
        given_total = int(year) * 12 + MONTH_ORDER.get(month, 1) - 1

        if start_total <= given_total <= end_total:
            active.append(loan_dict)
        else:
            # Human-readable note about why it's inactive
            end_m_num = end_total % 12 + 1
            end_y_num = end_total // 12
            end_m_name = _MONTH_NAMES[end_m_num - 1][:3]

            if given_total < start_total:
                note = f"Starts {loan['start_month'][:3]} {start_y}"
            else:
                note = f"Ended {end_m_name} {end_y_num}"

            loan_dict["status_note"] = note
            inactive.append(loan_dict)

    return active, inactive
