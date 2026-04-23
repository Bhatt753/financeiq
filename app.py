# Personal Finance Web App

from flask import Flask, render_template, request, redirect, session, url_for
import sqlite3
import datetime
import os
import hashlib

app = Flask(__name__)
app.secret_key = "finance_secret_2026"

#CONSTANTS

CATEGORIES = [
    "Rent/Housing", "Food & Groceries", "Transport",
    "Utilities", "Healthcare", "Entertainment",
    "Shopping", "Education", "Other"
]

HEALTHY_LIMITS = {
    "Rent/Housing": 30, "Food & Groceries": 20,
    "Transport": 15, "Utilities": 10,
    "Healthcare": 10, "Entertainment": 10,
    "Shopping": 10, "Education": 10, "Other": 5
}

import os
DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "finance_app.db")

#DATABASE

def get_db():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            username   TEXT UNIQUE NOT NULL,
            password   TEXT NOT NULL,
            name       TEXT NOT NULL,
            profession TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS monthly_data (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id        INTEGER NOT NULL,
            month          TEXT NOT NULL,
            year           INTEGER NOT NULL,
            income         REAL NOT NULL,
            total_expenses REAL NOT NULL,
            savings        REAL NOT NULL,
            savings_rate   REAL NOT NULL,
            health_score   INTEGER NOT NULL,
            created_at     TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS expenses (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id  INTEGER NOT NULL,
            month    TEXT NOT NULL,
            year     INTEGER NOT NULL,
            name     TEXT NOT NULL,
            category TEXT NOT NULL,
            type     TEXT NOT NULL,
            amount   REAL NOT NULL
        )
    """)

    conn.commit()
    conn.close()


def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()


#ANALYTICS

def calculate_metrics(income, expenses):
    total_expenses = sum(e["amount"] for e in expenses)
    savings        = income - total_expenses

    category_totals = {}
    for e in expenses:
        cat = e["category"]
        category_totals[cat] = category_totals.get(cat, 0) + e["amount"]

    fixed_total    = sum(e["amount"] for e in expenses if e["type"] == "Fixed")
    variable_total = sum(e["amount"] for e in expenses if e["type"] == "Variable")

    category_percent = {
        cat: round((amt / income) * 100, 2)
        for cat, amt in category_totals.items()
    }

    score = 100
    save_rate = round((max(savings, 0) / income) * 100, 2)
    exp_ratio = round((total_expenses / income) * 100, 2)

    if save_rate < 10:    score -= 30
    elif save_rate < 20:  score -= 15
    if exp_ratio > 90:    score -= 20
    elif exp_ratio > 80:  score -= 10
    for cat, pct in category_percent.items():
        if pct > HEALTHY_LIMITS.get(cat, 10):
            score -= 10

    return {
        "income"          : income,
        "total_expenses"  : total_expenses,
        "savings"         : savings,
        "savings_rate"    : save_rate,
        "expense_ratio"   : exp_ratio,
        "fixed_total"     : fixed_total,
        "variable_total"  : variable_total,
        "category_totals" : category_totals,
        "category_percent": category_percent,
        "health_score"    : max(score, 0)
    }


def generate_advice(metrics):
    advice = []
    income        = metrics["income"]
    savings       = metrics["savings"]
    savings_rate  = metrics["savings_rate"]
    category_totals = metrics["category_totals"]
    category_pct    = metrics["category_percent"]

    # Savings advice
    if savings < 0:
        advice.append({
            "type"   : "danger",
            "icon"   : "🚨",
            "title"  : "CRITICAL: Overspending!",
            "message": f"You are spending ₹{abs(savings):,.2f} more than you earn. Cut expenses immediately!"
        })
    elif savings_rate < 10:
        advice.append({
            "type"   : "warning",
            "icon"   : "⚠️",
            "title"  : "Low Savings Rate",
            "message": f"You save only {savings_rate}% of income. Aim for 20% (₹{income*0.20:,.2f}/month)."
        })
    elif savings_rate >= 20:
        advice.append({
            "type"   : "success",
            "icon"   : "✅",
            "title"  : "Great Savings Rate!",
            "message": f"You save {savings_rate}% of income (₹{savings:,.2f}/month). Keep it up!"
        })

    # Category advice
    for cat, amt in category_totals.items():
        pct   = category_pct[cat]
        limit = HEALTHY_LIMITS.get(cat, 10)
        if pct > limit:
            save_amt = amt * 0.10
            advice.append({
                "type"   : "warning",
                "icon"   : "✂️",
                "title"  : f"High {cat} Spending",
                "message": f"₹{amt:,.2f} ({pct}% of income) is over {limit}% limit. Reducing by 10% saves ₹{save_amt:,.2f}/month → ₹{save_amt*12:,.2f}/year."
            })

    # Emergency fund
    emergency = metrics["total_expenses"] * 6
    months_away = round(emergency / savings) if savings > 0 else 999
    advice.append({
        "type"   : "info",
        "icon"   : "🏦",
        "title"  : "Emergency Fund",
        "message": f"You need ₹{emergency:,.2f} (6 months expenses). At current savings → {months_away} months away."
    })

    # Investment
    if savings > 0:
        sip_5yr = savings * 12 * 5 * 1.12
        advice.append({
            "type"   : "success",
            "icon"   : "📈",
            "title"  : "Investment Opportunity",
            "message": f"Invest ₹{savings:,.2f}/month in SIP → ~₹{sip_5yr:,.2f} in 5 years at 12% returns."
        })

    return advice

#ROUTES

@app.route("/")
def home():
    if "user_id" in session:
        return redirect(url_for("dashboard"))
    return redirect(url_for("login"))


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username   = request.form["username"].strip()
        password   = request.form["password"].strip()
        name       = request.form["name"].strip()
        profession = request.form["profession"].strip()

        if not all([username, password, name, profession]):
            return render_template("register.html", error="All fields required!")

        conn = get_db()
        try:
            conn.execute(
                "INSERT INTO users (username, password, name, profession) VALUES (?, ?, ?, ?)",
                (username, hash_password(password), name, profession)
            )
            conn.commit()
            return redirect(url_for("login"))
        except sqlite3.IntegrityError:
            return render_template("register.html", error="Username already exists!")
        finally:
            conn.close()

    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form["username"].strip()
        password = request.form["password"].strip()

        conn = get_db()
        user = conn.execute(
            "SELECT * FROM users WHERE username=? AND password=?",
            (username, hash_password(password))
        ).fetchone()
        conn.close()

        if user:
            session["user_id"]   = user["id"]
            session["username"]  = user["username"]
            session["name"]      = user["name"]
            session["profession"]= user["profession"]
            return redirect(url_for("dashboard"))
        else:
            return render_template("login.html", error="Wrong username or password!")

    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/dashboard")
def dashboard():
    if "user_id" not in session:
        return redirect(url_for("login"))

    conn    = get_db()
    history = conn.execute(
        "SELECT * FROM monthly_data WHERE user_id=? ORDER BY year, month",
        (session["user_id"],)
    ).fetchall()
    conn.close()

    return render_template("dashboard.html", history=history)


@app.route("/add_data", methods=["GET", "POST"])
def add_data():
    if "user_id" not in session:
        return redirect(url_for("login"))

    if request.method == "POST":
        income     = float(request.form["income"])
        month      = request.form["month"]
        year       = int(request.form["year"])
        names      = request.form.getlist("expense_name[]")
        categories = request.form.getlist("expense_category[]")
        types      = request.form.getlist("expense_type[]")
        amounts    = request.form.getlist("expense_amount[]")

        expenses = []
        for i in range(len(names)):
            if names[i] and amounts[i]:
                expenses.append({
                    "name"    : names[i],
                    "category": categories[i],
                    "type"    : types[i],
                    "amount"  : float(amounts[i])
                })

        metrics = calculate_metrics(income, expenses)
        advice  = generate_advice(metrics)

        # Save to database
        conn = get_db()
        conn.execute("""
            INSERT INTO monthly_data
            (user_id, month, year, income, total_expenses, savings, savings_rate, health_score)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            session["user_id"], month, year,
            income, metrics["total_expenses"],
            metrics["savings"], metrics["savings_rate"],
            metrics["health_score"]
        ))

        for e in expenses:
            conn.execute("""
                INSERT INTO expenses (user_id, month, year, name, category, type, amount)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (session["user_id"], month, year, e["name"], e["category"], e["type"], e["amount"]))

        conn.commit()
        conn.close()

        return render_template(
            "results.html",
            metrics  = metrics,
            advice   = advice,
            expenses = expenses,
            month    = month,
            year     = year,
            categories = CATEGORIES,
            healthy_limits = HEALTHY_LIMITS
        )

    months = ["January","February","March","April","May","June",
              "July","August","September","October","November","December"]
    return render_template("add_data.html", categories=CATEGORIES, months=months)


@app.route("/goal", methods=["GET", "POST"])
def goal():
    if "user_id" not in session:
        return redirect(url_for("login"))

    if request.method == "POST":
        income        = float(request.form["income"])
        savings       = float(request.form["savings"])
        goal_name     = request.form["goal_name"]
        goal_amount   = float(request.form["goal_amount"])
        goal_months   = int(request.form["goal_months"])
        variable_total= float(request.form["variable_total"])

        required_monthly = round(goal_amount / goal_months, 2)
        gap              = round(required_monthly - savings, 2)
        realistic_months = round(goal_amount / savings) if savings > 0 else None

        if gap <= income * 0.05:
            difficulty = "EASY"
        elif gap <= income * 0.15:
            difficulty = "MEDIUM"
        else:
            difficulty = "HARD"

        return render_template("goal_result.html",
            goal_name      = goal_name,
            goal_amount    = goal_amount,
            goal_months    = goal_months,
            required_monthly = required_monthly,
            current_savings  = savings,
            gap            = gap,
            difficulty     = difficulty,
            realistic_months = realistic_months,
            variable_total = variable_total,
            income         = income
        )

    return render_template("goal.html")


@app.route("/history")
def history():
    if "user_id" not in session:
        return redirect(url_for("login"))

    conn    = get_db()
    history = conn.execute(
        """SELECT m.*, 
           GROUP_CONCAT(e.name || ' (' || e.category || ') ₹' || e.amount, ' | ') as expense_list
           FROM monthly_data m
           LEFT JOIN expenses e ON m.id = e.user_id 
           AND m.month = e.month AND m.year = e.year
           WHERE m.user_id = ?
           GROUP BY m.id
           ORDER BY m.year DESC, m.month DESC""",
        (session["user_id"],)
    ).fetchall()
    conn.close()

    return render_template("history.html", history=history)


@app.route("/delete_entry/<int:entry_id>")
def delete_entry(entry_id):
    if "user_id" not in session:
        return redirect(url_for("login"))

    conn = get_db()
    # Verify entry belongs to user
    entry = conn.execute(
        "SELECT * FROM monthly_data WHERE id=? AND user_id=?",
        (entry_id, session["user_id"])
    ).fetchone()

    if entry:
        # Delete expenses for this month
        conn.execute(
            "DELETE FROM expenses WHERE user_id=? AND month=? AND year=?",
            (session["user_id"], entry["month"], entry["year"])
        )
        # Delete monthly data
        conn.execute(
            "DELETE FROM monthly_data WHERE id=?",
            (entry_id,)
        )
        conn.commit()

    conn.close()
    return redirect(url_for("history"))

@app.route("/edit_entry/<int:entry_id>", methods=["GET", "POST"])
def edit_entry(entry_id):
    if "user_id" not in session:
        return redirect(url_for("login"))

    conn  = get_db()
    entry = conn.execute(
        "SELECT * FROM monthly_data WHERE id=? AND user_id=?",
        (entry_id, session["user_id"])
    ).fetchone()

    expenses = conn.execute(
        "SELECT * FROM expenses WHERE user_id=? AND month=? AND year=?",
        (session["user_id"], entry["month"], entry["year"])
    ).fetchall()

    if request.method == "POST":
        income     = float(request.form["income"])
        names      = request.form.getlist("expense_name[]")
        categories = request.form.getlist("expense_category[]")
        types      = request.form.getlist("expense_type[]")
        amounts    = request.form.getlist("expense_amount[]")

        new_expenses = []
        for i in range(len(names)):
            if names[i] and amounts[i]:
                new_expenses.append({
                    "name"    : names[i],
                    "category": categories[i],
                    "type"    : types[i],
                    "amount"  : float(amounts[i])
                })

        metrics = calculate_metrics(income, new_expenses)

        # Update monthly data
        conn.execute("""
            UPDATE monthly_data SET
            income=?, total_expenses=?, savings=?,
            savings_rate=?, health_score=?
            WHERE id=?
        """, (
            income, metrics["total_expenses"],
            metrics["savings"], metrics["savings_rate"],
            metrics["health_score"], entry_id
        ))

        # Delete old expenses and insert new ones
        conn.execute(
            "DELETE FROM expenses WHERE user_id=? AND month=? AND year=?",
            (session["user_id"], entry["month"], entry["year"])
        )

        for e in new_expenses:
            conn.execute("""
                INSERT INTO expenses (user_id, month, year, name, category, type, amount)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (session["user_id"], entry["month"], entry["year"],
                  e["name"], e["category"], e["type"], e["amount"]))

        conn.commit()
        conn.close()
        return redirect(url_for("history"))

    conn.close()
    return render_template("edit_entry.html",
        entry=entry, expenses=expenses, categories=CATEGORIES)



#APP DETAILS(local and render too)
init_db()

if __name__ == "__main__":
    print("\n🚀 Finance App is running!")
    print("👉 Open: http://127.0.0.1:5000")
    app.run(debug=True)