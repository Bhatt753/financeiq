# routes/auth.py

from flask import Blueprint, render_template, request, redirect, session, url_for
from models.database import create_user, get_user_by_credentials
from utils.auth import hash_password, verify_password
from utils.validators import validate_register

auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/")
def home():
    if "user_id" in session:
        return redirect(url_for("dashboard.dashboard"))
    return redirect(url_for("auth.login"))


@auth_bp.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username   = request.form.get("username", "").strip()
        password   = request.form.get("password", "").strip()
        name       = request.form.get("name", "").strip()
        profession = request.form.get("profession", "").strip()

        errors = validate_register(username, password, name, profession)
        if errors:
            return render_template("register.html", error=errors[0])

        success, error = create_user(username, hash_password(password), name, profession)
        if success:
            return redirect(url_for("auth.login"))
        else:
            return render_template("register.html", error="Username already exists!")

    return render_template("register.html")


@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        if not username or not password:
            return render_template("login.html", error="Please enter both fields.")

        # Get user by username only, then verify password
        from models.database import get_db
        conn = get_db()
        user = conn.execute(
            "SELECT * FROM users WHERE username=?", (username,)
        ).fetchone()
        conn.close()

        if user and verify_password(password, user["password"]):
            session["user_id"]    = user["id"]
            session["username"]   = user["username"]
            session["name"]       = user["name"]
            session["profession"] = user["profession"]
            return redirect(url_for("dashboard.dashboard"))
        else:
            return render_template("login.html", error="Wrong username or password!")

    return render_template("login.html")


@auth_bp.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("auth.login"))