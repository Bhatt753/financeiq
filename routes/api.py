# routes/api.py  — JSON API for Flutter app (JWT-authenticated)

from flask import Blueprint, request, jsonify
from functools import wraps
import jwt as pyjwt
from datetime import datetime, timedelta

from config import Config
from models.database import (
    get_user_by_username, get_user_by_email,
    create_user_with_email,
    get_monthly_history, get_monthly_entry,
    save_monthly_data, save_expenses,
    get_expenses_for_month, delete_expenses_for_month,
    update_monthly_entry, delete_monthly_entry,
    get_user_loans, save_loan, delete_loan, get_loan_by_id,
    get_user_goals, save_goal, complete_goal, delete_goal,
)
from services.metrics import calculate_metrics
from services.advice import generate_advice
from services.trends import analyze_trends, calculate_annual_summary
from services.health_score import calculate_health_score
from services.loan_engine import analyze_all_loans, generate_loan_advice
from services.goal_engine import analyze_goal
from utils.auth import hash_password, verify_password
from utils.validators import validate_income, validate_expenses
from utils.loan_utils import get_active_loans

api_bp = Blueprint("api", __name__, url_prefix="/api")

# ──────────────────────────────────────────────
# JWT helpers
# ──────────────────────────────────────────────

def _gen_token(user_id: int) -> str:
    payload = {
        "user_id": user_id,
        "exp": datetime.utcnow() + timedelta(days=60),
    }
    return pyjwt.encode(payload, Config.SECRET_KEY, algorithm="HS256")


def _verify_token(token: str):
    try:
        data = pyjwt.decode(token, Config.SECRET_KEY, algorithms=["HS256"])
        return data["user_id"]
    except Exception:
        return None


def jwt_required(f):
    """Decorator — extracts user_id from Bearer token and injects as first arg."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "Unauthorized"}), 401
        uid = _verify_token(auth[7:])
        if uid is None:
            return jsonify({"error": "Invalid or expired token"}), 401
        return f(uid, *args, **kwargs)
    return wrapper


def _user_dict(user) -> dict:
    """Normalize a DB user row to a safe dict (no password)."""
    d = dict(user) if not isinstance(user, dict) else user
    d.pop("password", None)
    return d


# ──────────────────────────────────────────────
# Auth
# ──────────────────────────────────────────────

@api_bp.route("/auth/login", methods=["POST"])
def api_login():
    data     = request.get_json(force=True) or {}
    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()

    if not username or not password:
        return jsonify({"error": "Username and password required"}), 400

    user = get_user_by_username(username)
    if not user or not user.get("password"):
        return jsonify({"error": "Wrong username or password"}), 401
    if not verify_password(password, user["password"]):
        return jsonify({"error": "Wrong username or password"}), 401

    token = _gen_token(user["id"])
    return jsonify({
        "token": token,
        "user": {
            "id"        : user["id"],
            "username"  : user["username"],
            "name"      : user["name"],
            "profession": user.get("profession", ""),
            "email"     : user.get("email", ""),
            "avatar"    : user.get("avatar", ""),
        }
    })


@api_bp.route("/auth/register", methods=["POST"])
def api_register():
    data       = request.get_json(force=True) or {}
    username   = (data.get("username") or "").strip()
    password   = (data.get("password") or "").strip()
    name       = (data.get("name") or "").strip()
    profession = (data.get("profession") or "").strip()
    email      = (data.get("email") or "").strip()

    if not all([username, password, name, profession, email]):
        return jsonify({"error": "All fields are required"}), 400
    if len(password) < 6:
        return jsonify({"error": "Password must be at least 6 characters"}), 400
    if "@" not in email:
        return jsonify({"error": "Invalid email"}), 400

    if get_user_by_email(email):
        return jsonify({"error": "Email already registered"}), 409

    success, err = create_user_with_email(
        username, hash_password(password), name, profession, email
    )
    if not success:
        return jsonify({"error": err or "Username already exists"}), 409

    user  = get_user_by_username(username)
    token = _gen_token(user["id"])
    return jsonify({
        "token": token,
        "user" : {
            "id"        : user["id"],
            "username"  : user["username"],
            "name"      : user["name"],
            "profession": user.get("profession", ""),
            "email"     : user.get("email", ""),
        }
    }), 201


# ──────────────────────────────────────────────
# Dashboard
# ──────────────────────────────────────────────

@api_bp.route("/dashboard")
@jwt_required
def api_dashboard(user_id):
    history = get_monthly_history(user_id)
    trends  = analyze_trends(history)
    summary = calculate_annual_summary(history)
    goals   = get_user_goals(user_id)

    # Serialize history rows
    hist_list = [dict(r) for r in history] if history else []

    return jsonify({
        "history": hist_list,
        "trends" : trends,
        "summary": summary,
        "goals"  : goals,
    })


# ──────────────────────────────────────────────
# Finance — add monthly data
# ──────────────────────────────────────────────

@api_bp.route("/finance/add", methods=["POST"])
@jwt_required
def api_add_data(user_id):
    data  = request.get_json(force=True) or {}
    month = data.get("month", "")
    year  = data.get("year")

    income_raw, err = validate_income(data.get("income"))
    if err:
        return jsonify({"error": err}), 400

    try:
        year = int(year)
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid year"}), 400

    raw_expenses = data.get("expenses", [])
    names      = [e.get("name", "")     for e in raw_expenses]
    amounts    = [str(e.get("amount", 0)) for e in raw_expenses]
    _, exp_err = validate_expenses(names, amounts)
    if exp_err:
        return jsonify({"error": exp_err[0]}), 400

    expenses = [
        {
            "name"    : e.get("name", "").strip(),
            "category": e.get("category", "Other"),
            "type"    : e.get("type", "Variable"),
            "amount"  : float(e.get("amount", 0)),
        }
        for e in raw_expenses
        if e.get("name") and float(e.get("amount", 0)) > 0
    ]

    active_loans, inactive_loans = get_active_loans(user_id, month, year)
    emergency_fund = float(data.get("emergency_fund", 0) or 0)

    metrics, err = calculate_metrics(income_raw, expenses, active_loans, emergency_fund)
    if err:
        return jsonify({"error": err}), 400

    success, err = save_monthly_data(user_id, month, year, income_raw, metrics)
    if not success:
        return jsonify({"error": err}), 409

    save_expenses(user_id, month, year, expenses)

    profession = data.get("profession", "")
    advice     = generate_advice(metrics, profession)

    return jsonify({
        "metrics"       : metrics,
        "advice"        : advice,
        "active_loans"  : active_loans,
        "inactive_loans": inactive_loans,
        "month"         : month,
        "year"          : year,
    }), 201


# ──────────────────────────────────────────────
# Finance — form data (loans for add-data screen)
# ──────────────────────────────────────────────

@api_bp.route("/finance/form_data")
@jwt_required
def api_finance_form_data(user_id):
    from config import Config as C
    loans = [l for l in get_user_loans(user_id) if l.get("status") != "closed"]
    return jsonify({
        "loans"     : loans,
        "categories": C.CATEGORIES,
        "months"    : [
            "January","February","March","April","May","June",
            "July","August","September","October","November","December"
        ],
    })


# ──────────────────────────────────────────────
# History
# ──────────────────────────────────────────────

@api_bp.route("/history")
@jwt_required
def api_history(user_id):
    history = get_monthly_history(user_id)
    return jsonify({"history": [dict(r) for r in history] if history else []})


@api_bp.route("/history/<int:entry_id>")
@jwt_required
def api_history_entry(user_id, entry_id):
    entry    = get_monthly_entry(entry_id, user_id)
    if not entry:
        return jsonify({"error": "Not found"}), 404
    expenses = get_expenses_for_month(user_id, entry["month"], entry["year"])
    return jsonify({
        "entry"   : dict(entry),
        "expenses": [dict(e) for e in expenses],
    })


@api_bp.route("/history/<int:entry_id>", methods=["DELETE"])
@jwt_required
def api_delete_entry(user_id, entry_id):
    entry = get_monthly_entry(entry_id, user_id)
    if entry:
        delete_monthly_entry(entry_id, user_id, entry["month"], entry["year"])
    return jsonify({"ok": True})


@api_bp.route("/history/<int:entry_id>", methods=["PUT"])
@jwt_required
def api_edit_entry(user_id, entry_id):
    entry = get_monthly_entry(entry_id, user_id)
    if not entry:
        return jsonify({"error": "Not found"}), 404

    data   = request.get_json(force=True) or {}
    income = float(data.get("income", entry["income"]))
    month  = entry["month"]
    year   = entry["year"]

    expenses = [
        {
            "name"    : e.get("name", "").strip(),
            "category": e.get("category", "Other"),
            "type"    : e.get("type", "Variable"),
            "amount"  : float(e.get("amount", 0)),
        }
        for e in data.get("expenses", [])
        if float(e.get("amount", 0)) > 0
    ]

    active_loans, _ = get_active_loans(user_id, month, year)
    emergency_fund  = float(data.get("emergency_fund", 0) or 0)

    metrics, err = calculate_metrics(income, expenses, active_loans, emergency_fund)
    if err:
        return jsonify({"error": err}), 400

    delete_expenses_for_month(user_id, month, year)
    update_monthly_entry(entry_id, income, metrics)
    save_expenses(user_id, month, year, expenses)

    return jsonify({"ok": True, "metrics": metrics})


# ──────────────────────────────────────────────
# Loans
# ──────────────────────────────────────────────

@api_bp.route("/loans")
@jwt_required
def api_loans(user_id):
    from models.database import get_monthly_history as _hist
    loans    = get_user_loans(user_id)
    analysis = analyze_all_loans(loans)
    history  = _hist(user_id)
    income   = history[0]["income"] if history else 0
    savings  = history[0]["savings"] if history else 0
    goals    = get_user_goals(user_id)
    advice   = generate_loan_advice(analysis, income, savings, goals)
    return jsonify({
        "loans"   : loans,
        "analysis": analysis,
        "advice"  : advice,
        "income"  : income,
    })


@api_bp.route("/loans/add", methods=["POST"])
@jwt_required
def api_add_loan(user_id):
    from services.loan_engine import sync_user_history_with_loans
    d = request.get_json(force=True) or {}
    try:
        loan_name     = (d.get("loan_name") or "").strip()
        loan_type     = d.get("loan_type", "Personal Loan")
        principal     = float(d.get("principal", 0))
        emi           = float(d.get("emi", 0))
        interest_rate = float(d.get("interest_rate", 0))
        tenure        = int(d.get("tenure_months", 0))
        start_month   = d.get("start_month", "January")
        start_year    = int(d.get("start_year", 2024))

        if not loan_name or principal <= 0 or emi <= 0 or tenure <= 0:
            return jsonify({"error": "Invalid loan data"}), 400

        save_loan(user_id, loan_name, loan_type, principal,
                  emi, interest_rate, tenure, start_month, start_year)
        sync_user_history_with_loans(user_id)
    except Exception as e:
        return jsonify({"error": str(e)}), 400

    return jsonify({"ok": True}), 201


@api_bp.route("/loans/<int:loan_id>", methods=["DELETE"])
@jwt_required
def api_delete_loan(user_id, loan_id):
    from services.loan_engine import sync_user_history_with_loans
    delete_loan(loan_id, user_id)
    sync_user_history_with_loans(user_id)
    return jsonify({"ok": True})


# ──────────────────────────────────────────────
# Goals
# ──────────────────────────────────────────────

@api_bp.route("/goals")
@jwt_required
def api_goals(user_id):
    goals   = get_user_goals(user_id)
    history = get_monthly_history(user_id)
    savings = max(history[0]["savings"], 0) if history else 0

    enriched = []
    for g in goals:
        saved     = 0.0
        pct       = round(min((saved / g["goal_amount"]) * 100, 100), 1) if g["goal_amount"] > 0 else 0
        remaining = max(g["goal_amount"] - saved, 0)
        enriched.append({**g, "saved_so_far": saved, "progress_pct": pct, "remaining": remaining})

    return jsonify({"goals": enriched, "current_savings": savings})


@api_bp.route("/goals/analyze", methods=["POST"])
@jwt_required
def api_analyze_goal(user_id):
    from routes.goals import _calculate_loan_impact, _build_monthly_progress
    d = request.get_json(force=True) or {}

    goal_name   = (d.get("goal_name") or "").strip()
    goal_amount = float(d.get("goal_amount", 0))
    goal_months = int(d.get("goal_months", 12))

    if not goal_name or goal_amount <= 0 or goal_months <= 0:
        return jsonify({"error": "Invalid goal data"}), 400

    history      = get_monthly_history(user_id)
    user_loans   = get_user_loans(user_id)
    loan_analysis= analyze_all_loans(user_loans)

    income         = history[0]["income"]          if history else 0
    savings        = max(history[0]["savings"], 0) if history else 0
    variable_total = history[0].get("variable_total", 0) if history else 0

    cat_totals = {}
    if history:
        for e in get_expenses_for_month(user_id, history[0]["month"], history[0]["year"]):
            cat = e["category"] if isinstance(e, dict) else e[5]
            amt = float(e["amount"] if isinstance(e, dict) else e[7])
            cat_totals[cat] = cat_totals.get(cat, 0) + amt

    result, err = analyze_goal(goal_name, goal_amount, goal_months,
                                income, savings, variable_total, cat_totals)
    if err:
        return jsonify({"error": err}), 400

    completing_loans = loan_analysis.get("completing_soon", [])
    result["loan_impact"]       = _calculate_loan_impact(loan_analysis, goal_months, savings)
    result["completing_loans"]  = completing_loans
    result["total_emi"]         = loan_analysis["total_emi"] if loan_analysis["has_loans"] else 0
    result["monthly_progress"]  = _build_monthly_progress(savings, goal_amount, goal_months, completing_loans)

    save_goal(user_id, goal_name, goal_amount, goal_months)

    return jsonify({"result": result, "income": income, "savings": savings})


@api_bp.route("/goals/<int:goal_id>/complete", methods=["POST"])
@jwt_required
def api_complete_goal(user_id, goal_id):
    complete_goal(goal_id, user_id)
    return jsonify({"ok": True})


@api_bp.route("/goals/<int:goal_id>", methods=["DELETE"])
@jwt_required
def api_delete_goal(user_id, goal_id):
    delete_goal(goal_id, user_id)
    return jsonify({"ok": True})


# ──────────────────────────────────────────────
# Health score
# ──────────────────────────────────────────────

@api_bp.route("/health")
@jwt_required
def api_health(user_id):
    history = get_monthly_history(user_id)
    if not history:
        return jsonify({"has_data": False})

    latest       = history[0]
    expenses_raw = get_expenses_for_month(user_id, latest["month"], latest["year"])
    user_loans   = get_user_loans(user_id)

    expenses = [
        {
            "name"    : e["name"]     if isinstance(e, dict) else e[4],
            "category": e["category"] if isinstance(e, dict) else e[5],
            "type"    : e["type"]     if isinstance(e, dict) else e[6],
            "amount"  : e["amount"]   if isinstance(e, dict) else e[7],
        }
        for e in expenses_raw
    ]
    loans = [
        {
            "type"         : l["loan_type"],
            "emi"          : l["emi"],
            "interest_rate": l["interest_rate"],
            "outstanding"  : l.get("principal", 0),
        }
        for l in user_loans
    ]

    health_data = calculate_health_score(latest["income"], expenses, loans, 0)

    return jsonify({
        "has_data": True,
        "score"   : health_data,
        "month"   : latest["month"],
        "year"    : latest["year"],
        "income"  : latest["income"],
    })


# ──────────────────────────────────────────────
# Profile
# ──────────────────────────────────────────────

@api_bp.route("/profile")
@jwt_required
def api_profile(user_id):
    from models.database import get_db, placeholder, USE_POSTGRES
    import sqlite3
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(f"SELECT * FROM users WHERE id={p}", (user_id,))
        row = c.fetchone()
        if USE_POSTGRES:
            cols = [d[0] for d in c.description]
            user = dict(zip(cols, row)) if row else {}
        else:
            user = dict(row) if row else {}
        user.pop("password", None)
        return jsonify({"user": user})
    finally:
        conn.close()


@api_bp.route("/profile", methods=["PUT"])
@jwt_required
def api_update_profile(user_id):
    from models.database import get_db, placeholder
    d    = request.get_json(force=True) or {}
    name = (d.get("name") or "").strip()
    prof = (d.get("profession") or "").strip()
    if not name:
        return jsonify({"error": "Name required"}), 400

    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(f"UPDATE users SET name={p}, profession={p} WHERE id={p}",
                  (name, prof, user_id))
        conn.commit()
    finally:
        conn.close()
    return jsonify({"ok": True})


# ──────────────────────────────────────────────
# Misc
# ──────────────────────────────────────────────

@api_bp.route("/ping")
def api_ping():
    return jsonify({"status": "ok", "app": "RupeeIQ API v1"})
