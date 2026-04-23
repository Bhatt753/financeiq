# database.py
# Handles all database operations

import sqlite3
import os

DB_NAME = "finance.db"


def create_connection():
    conn = sqlite3.connect(DB_NAME)
    return conn


def create_tables():
    conn = create_connection()
    cursor = conn.cursor()

    # Users table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL,
            profession TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Income table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS income (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            amount  REAL NOT NULL,
            month   TEXT NOT NULL,
            year    INTEGER NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    """)

    # Expenses table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS expenses (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id  INTEGER NOT NULL,
            name     TEXT NOT NULL,
            category TEXT NOT NULL,
            type     TEXT NOT NULL,
            amount   REAL NOT NULL,
            month    TEXT NOT NULL,
            year     INTEGER NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    """)

    # Metrics table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS metrics (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id        INTEGER NOT NULL,
            month          TEXT NOT NULL,
            year           INTEGER NOT NULL,
            total_expenses REAL,
            savings        REAL,
            savings_rate   REAL,
            expense_ratio  REAL,
            health_score   INTEGER,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    """)

    conn.commit()
    conn.close()
    print("  ✅ Database ready!")


def save_user(name, profession):
    conn   = create_connection()
    cursor = conn.cursor()

    # Check if user already exists
    cursor.execute(
        "SELECT id FROM users WHERE name = ? AND profession = ?",
        (name, profession)
    )
    existing = cursor.fetchone()

    if existing:
        user_id = existing[0]
        print(f"  ✅ Welcome back, {name}!")
    else:
        cursor.execute(
            "INSERT INTO users (name, profession) VALUES (?, ?)",
            (name, profession)
        )
        conn.commit()
        user_id = cursor.lastrowid
        print(f"  ✅ New user created: {name}")

    conn.close()
    return user_id


def save_income(user_id, amount, month, year):
    conn   = create_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO income (user_id, amount, month, year)
        VALUES (?, ?, ?, ?)
    """, (user_id, amount, month, year))

    conn.commit()
    conn.close()


def save_expenses(user_id, expenses, month, year):
    conn   = create_connection()
    cursor = conn.cursor()

    for e in expenses:
        cursor.execute("""
            INSERT INTO expenses (user_id, name, category, type, amount, month, year)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (user_id, e["name"], e["category"], e["type"], e["amount"], month, year))

    conn.commit()
    conn.close()


def save_metrics(user_id, metrics, month, year):
    conn   = create_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO metrics (
            user_id, month, year,
            total_expenses, savings,
            savings_rate, expense_ratio, health_score
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        user_id, month, year,
        metrics["total_expenses"],
        metrics["savings"],
        metrics["savings_rate"],
        metrics["expense_ratio"],
        metrics["health_score"]
    ))

    conn.commit()
    conn.close()


def get_monthly_history(user_id):
    conn   = create_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT month, year, total_expenses, savings,
               savings_rate, expense_ratio, health_score
        FROM metrics
        WHERE user_id = ?
        ORDER BY year ASC, month ASC
    """, (user_id,))

    rows = cursor.fetchall()
    conn.close()
    return rows


def show_history(user_id, name):
    rows = get_monthly_history(user_id)

    if not rows:
        print("\n  No history found yet.")
        return

    print("\n" + "=" * 65)
    print(f"  📅 MONTHLY HISTORY FOR: {name}")
    print("=" * 65)
    print(f"  {'Month':<12} {'Year':<6} {'Expenses':>12} {'Savings':>12} {'Save%':>7} {'Score':>7}")
    print("-" * 65)

    for row in rows:
        month, year, expenses, savings, save_rate, exp_ratio, score = row
        print(f"  {month:<12} {year:<6} ₹{expenses:>10,.2f} ₹{savings:>10,.2f} {save_rate:>6}% {score:>6}/100")

    print("=" * 65)

    # --- Month over month comparison ---
    if len(rows) >= 2:
        last  = rows[-1]
        prev  = rows[-2]
        diff_savings  = round(last[3] - prev[3], 2)
        diff_score    = last[6] - prev[6]

        print(f"\n  📈 VS LAST MONTH:")
        if diff_savings >= 0:
            print(f"  Savings   : ▲ ₹{diff_savings:,.2f} better")
        else:
            print(f"  Savings   : ▼ ₹{abs(diff_savings):,.2f} worse")

        if diff_score >= 0:
            print(f"  Health    : ▲ {diff_score} points better")
        else:
            print(f"  Health    : ▼ {abs(diff_score)} points worse")

        print("=" * 65)