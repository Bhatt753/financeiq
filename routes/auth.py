# routes/auth.py

from flask import Blueprint, render_template, request, redirect, session, url_for
from authlib.integrations.flask_client import OAuth
from models.database import (
    create_user, get_user_by_username,
    get_user_by_google_id, get_user_by_email,
    create_google_user, update_user_profession
)
from utils.auth import hash_password, verify_password
from utils.validators import validate_register
from config import Config
import os

auth_bp = Blueprint("auth", __name__)

# Setup OAuth
oauth = OAuth()

def init_oauth(app):
    oauth.init_app(app)
    oauth.register(
        name                  = "google",
        client_id             = Config.GOOGLE_CLIENT_ID,
        client_secret         = Config.GOOGLE_CLIENT_SECRET,
        server_metadata_url   = "https://accounts.google.com/.well-known/openid-configuration",
        client_kwargs         = {"scope": "openid email profile"}
    )


@auth_bp.route("/")
def home():
    if "user_id" in session:
        return redirect(url_for("dashboard.dashboard"))
    return redirect(url_for("auth.login"))


@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        if not username or not password:
            return render_template("login.html", error="Please enter both fields.")

        user = get_user_by_username(username)

        if user and user["password"] and verify_password(password, user["password"]):
            _set_session(user)
            return redirect(url_for("dashboard.dashboard"))
        else:
            return render_template("login.html", error="Wrong username or password!")

    return render_template("login.html")


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

        success, error = create_user(
            username, hash_password(password), name, profession
        )
        if success:
            return redirect(url_for("auth.login"))
        else:
            return render_template("register.html", error="Username already exists!")

    return render_template("register.html")


@auth_bp.route("/login/google")
def google_login():
    redirect_uri = url_for("auth.google_callback", _external=True)
    return oauth.google.authorize_redirect(redirect_uri)


@auth_bp.route("/callback")
def google_callback():
    try:
        token    = oauth.google.authorize_access_token()
        userinfo = token.get("userinfo")

        if not userinfo:
            return redirect(url_for("auth.login"))

        google_id = userinfo["sub"]
        email     = userinfo["email"]
        name      = userinfo.get("name", email.split("@")[0])
        avatar    = userinfo.get("picture", "")

        # Check if user exists
        user = get_user_by_google_id(google_id)

        if not user:
            # Check if email already registered manually
            user = get_user_by_email(email)
            if user:
                # Link Google to existing account
                from models.database import get_db, placeholder, USE_POSTGRES
                conn = get_db()
                p    = placeholder()
                c    = conn.cursor()
                c.execute(
                    f"UPDATE users SET google_id={p}, avatar={p} WHERE email={p}",
                    (google_id, avatar, email)
                )
                conn.commit()
                conn.close()
            else:
                # Create new Google user
                user = create_google_user(google_id, email, name, avatar)

                if not user:
                    return render_template("login.html", error="Failed to create account.")

                # Ask for profession if new user
                _set_session(user)
                return redirect(url_for("auth.setup_profile"))

        _set_session(user)
        return redirect(url_for("dashboard.dashboard"))

    except Exception as e:
        print(f"Google OAuth error: {e}")
        return render_template("login.html", error="Google login failed. Try again.")


@auth_bp.route("/setup_profile", methods=["GET", "POST"])
def setup_profile():
    if "user_id" not in session:
        return redirect(url_for("auth.login"))

    if request.method == "POST":
        profession = request.form.get("profession", "").strip()
        if profession:
            update_user_profession(session["user_id"], profession)
            session["profession"] = profession
        return redirect(url_for("dashboard.dashboard"))

    return render_template("setup_profile.html")


@auth_bp.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("auth.login"))


def _set_session(user):
    if isinstance(user, dict):
        session["user_id"]    = user["id"]
        session["username"]   = user["username"]
        session["name"]       = user["name"]
        session["profession"] = user.get("profession", "Not specified")
        session["avatar"]     = user.get("avatar", "")
        session["email"]      = user.get("email", "")
    else:
        session["user_id"]    = user["id"]
        session["username"]   = user["username"]
        session["name"]       = user["name"]
        session["profession"] = user["profession"] if user["profession"] else "Not specified"
        session["avatar"]     = user["avatar"] if user["avatar"] else ""
        session["email"]      = user["email"] if user["email"] else ""