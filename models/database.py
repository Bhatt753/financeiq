# models/database.py
# All database operations in one place

import sqlite3
import os
from config import Config


def get_db():
    db_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..",
        Config.DATABASE_URL
    )
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    c    = conn.cursor()

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
            expense_ratio  REAL NOT NULL,
            fixed_total    REAL NOT NULL DEFAULT 0,
            variable_total REAL NOT NULL DEFAULT 0,
            health_score   INTEGER NOT NULL,
            created_at     TEXT DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, month, year)
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS expenses (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id    INTEGER NOT NULL,
            month      TEXT NOT NULL,
            year       INTEGER NOT NULL,
            name       TEXT NOT NULL,
            category   TEXT NOT NULL,
            type       TEXT NOT NULL,
            amount     REAL NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS goals (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id          INTEGER NOT NULL,
            goal_name        TEXT NOT NULL,
            goal_amount      REAL NOT NULL,
            goal_months      INTEGER NOT NULL,
            current_savings  REAL NOT NULL,
            difficulty       TEXT NOT NULL,
            status           TEXT DEFAULT 'active',
            created_at       TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Add indexes for faster queries
    c.execute("CREATE INDEX IF NOT EXISTS idx_monthly_user ON monthly_data(user_id)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_expenses_user ON expenses(user_id)")

    conn.commit()
    conn.close()
    print("✅ Database initialized!")


# USER QUERIES

def create_user(username, password, name, profession):
    conn = get_db()
    try:
        conn.execute(
            "INSERT INTO users (username, password, name, profession) VALUES (?, ?, ?, ?)",
            (username, password, name, profession)
        )
        conn.commit()
        return True, None
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()


def get_user_by_credentials(username, password):
    conn = get_db()
    try:
        user = conn.execute(
            "SELECT * FROM users WHERE username=? AND password=?",
            (username, password)
        ).fetchone()
        return user
    finally:
        conn.close()

#MONTHLY DATA QUERIES

def save_monthly_data(user_id, month, year, income, metrics):
    conn = get_db()
    try:
        # Check if already exists
        existing = conn.execute(
            "SELECT id FROM monthly_data WHERE user_id=? AND month=? AND year=?",
            (user_id, month, year)
        ).fetchone()

        if existing:
            return False, "Data for this month already exists. Use edit instead."

        conn.execute("""
            INSERT INTO monthly_data
            (user_id, month, year, income, total_expenses, savings,
             savings_rate, expense_ratio, fixed_total, variable_total, health_score)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            user_id, month, year, income,
            metrics["total_expenses"],
            metrics["savings"],
            metrics["savings_rate"],
            metrics["expense_ratio"],
            metrics["fixed_total"],
            metrics["variable_total"],
            metrics["health_score"]
        ))
        conn.commit()
        return True, None
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()


def save_expenses(user_id, month, year, expenses):
    conn = get_db()
    try:
        for e in expenses:
            conn.execute("""
                INSERT INTO expenses (user_id, month, year, name, category, type, amount)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (user_id, month, year, e["name"], e["category"], e["type"], e["amount"]))
        conn.commit()
        return True
    except Exception as e:
        return False
    finally:
        conn.close()


def get_monthly_history(user_id):
    conn = get_db()
    try:
        return conn.execute(
            "SELECT * FROM monthly_data WHERE user_id=? ORDER BY year DESC, month DESC",
            (user_id,)
        ).fetchall()
    finally:
        conn.close()


def get_monthly_entry(entry_id, user_id):
    conn = get_db()
    try:
        return conn.execute(
            "SELECT * FROM monthly_data WHERE id=? AND user_id=?",
            (entry_id, user_id)
        ).fetchone()
    finally:
        conn.close()


def get_expenses_for_month(user_id, month, year):
    conn = get_db()
    try:
        return conn.execute(
            "SELECT * FROM expenses WHERE user_id=? AND month=? AND year=?",
            (user_id, month, year)
        ).fetchall()
    finally:
        conn.close()


def update_monthly_entry(entry_id, income, metrics):
    conn = get_db()
    try:
        conn.execute("""
            UPDATE monthly_data SET
            income=?, total_expenses=?, savings=?,
            savings_rate=?, expense_ratio=?,
            fixed_total=?, variable_total=?, health_score=?
            WHERE id=?
        """, (
            income,
            metrics["total_expenses"],
            metrics["savings"],
            metrics["savings_rate"],
            metrics["expense_ratio"],
            metrics["fixed_total"],
            metrics["variable_total"],
            metrics["health_score"],
            entry_id
        ))
        conn.commit()
        return True
    except Exception as e:
        return False
    finally:
        conn.close()


def delete_monthly_entry(entry_id, user_id, month, year):
    conn = get_db()
    try:
        conn.execute(
            "DELETE FROM expenses WHERE user_id=? AND month=? AND year=?",
            (user_id, month, year)
        )
        conn.execute(
            "DELETE FROM monthly_data WHERE id=? AND user_id=?",
            (entry_id, user_id)
        )
        conn.commit()
        return True
    except Exception as e:
        return False
    finally:
        conn.close()