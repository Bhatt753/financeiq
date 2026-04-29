# routes/dashboard.py

from flask import Blueprint, render_template, redirect, session, url_for
from models.database import get_monthly_history, get_monthly_entry, \
    delete_monthly_entry, get_expenses_for_month
from services.trends import analyze_trends, calculate_annual_summary

dashboard_bp = Blueprint("dashboard", __name__)


def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated


@dashboard_bp.route("/dashboard")
@login_required
def dashboard():
    history = get_monthly_history(session["user_id"])
    trends  = analyze_trends(history)
    summary = calculate_annual_summary(history)
    return render_template("dashboard.html",
        history=history, trends=trends, summary=summary)


@dashboard_bp.route("/history")
@login_required
def history():
    history = get_monthly_history(session["user_id"])
    return render_template("history.html", history=history)


@dashboard_bp.route("/delete_entry/<int:entry_id>", methods=["POST"])
@login_required
def delete_entry(entry_id):
    entry = get_monthly_entry(entry_id, session["user_id"])
    if entry:
        delete_monthly_entry(entry_id, session["user_id"], entry["month"], entry["year"])
    return redirect(url_for("dashboard.history"))