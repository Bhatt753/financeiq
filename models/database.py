# models/database.py
# Supports both SQLite (local) and PostgreSQL (production)

import os
import sqlite3

# Check if we're using PostgreSQL or SQLite
DATABASE_URL = os.environ.get("DATABASE_URL", "")

USE_POSTGRES = DATABASE_URL.startswith("postgres")

if USE_POSTGRES:
    import psycopg2
    import psycopg2.extras


def get_db():
    if USE_POSTGRES:
        conn = psycopg2.connect(DATABASE_URL)
        return conn
    else:
        db_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..",
            "finance_app.db"
        )
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        return conn


def placeholder(n=1):
    if USE_POSTGRES:
        return "%s"
    return "?"


def init_db():
    conn = get_db()
    c    = conn.cursor()

    if USE_POSTGRES:
        c.execute("""
                  CREATE TABLE IF NOT EXISTS users (
                    id         SERIAL PRIMARY KEY,
                    username   TEXT UNIQUE NOT NULL,
                    password   TEXT,
                    name       TEXT NOT NULL,
                    profession TEXT NOT NULL DEFAULT 'Not specified',
                    email      TEXT UNIQUE,
                    google_id  TEXT UNIQUE,
                    avatar     TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
        """)

        c.execute("""
            CREATE TABLE IF NOT EXISTS monthly_data (
                id             SERIAL PRIMARY KEY,
                user_id        INTEGER NOT NULL,
                month          TEXT NOT NULL,
                year           INTEGER NOT NULL,
                income         REAL NOT NULL,
                total_expenses REAL NOT NULL,
                savings        REAL NOT NULL,
                savings_rate   REAL NOT NULL,
                expense_ratio  REAL NOT NULL DEFAULT 0,
                fixed_total    REAL NOT NULL DEFAULT 0,
                variable_total REAL NOT NULL DEFAULT 0,
                health_score   INTEGER NOT NULL,
                created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, month, year)
            )
        """)

        c.execute("""
            CREATE TABLE IF NOT EXISTS expenses (
                id         SERIAL PRIMARY KEY,
                user_id    INTEGER NOT NULL,
                month      TEXT NOT NULL,
                year       INTEGER NOT NULL,
                name       TEXT NOT NULL,
                category   TEXT NOT NULL,
                type       TEXT NOT NULL,
                amount     REAL NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        c.execute("""
            CREATE TABLE IF NOT EXISTS goals (
                id               SERIAL PRIMARY KEY,
                user_id          INTEGER NOT NULL,
                goal_name        TEXT NOT NULL,
                goal_amount      REAL NOT NULL,
                goal_months      INTEGER NOT NULL,
                current_savings  REAL NOT NULL,
                difficulty       TEXT NOT NULL,
                status           TEXT DEFAULT 'active',
                created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

    else:
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
                expense_ratio  REAL NOT NULL DEFAULT 0,
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
                amount     REAL NOT NULL
            )
        """)

    conn.commit()
    conn.close()
    print("✅ Database initialized!")


def dict_row(row):
    if USE_POSTGRES:
        return dict(row) if row else None
    return dict(row) if row else None


def fetchall_as_dict(rows):
    if USE_POSTGRES:
        return [dict(r) for r in rows] if rows else []
    return rows



#USER QUERIES

def create_user(username, password, name, profession):
    conn = get_db()
    try:
        p = placeholder()
        conn.cursor().execute(
            f"INSERT INTO users (username, password, name, profession) VALUES ({p},{p},{p},{p})",
            (username, password, name, profession)
        )
        conn.commit()
        return True, None
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()


def get_user_by_username(username):
    conn = get_db()
    try:
        p = placeholder()
        c = conn.cursor()
        if USE_POSTGRES:
            c.execute(f"SELECT * FROM users WHERE username={p}", (username,))
            row = c.fetchone()
            if row:
                cols = [desc[0] for desc in c.description]
                return dict(zip(cols, row))
            return None
        else:
            conn.row_factory = sqlite3.Row
            c = conn.cursor()
            c.execute(f"SELECT * FROM users WHERE username={p}", (username,))
            return c.fetchone()
    finally:
        conn.close()


#MONTHLY DATA QUERIES

def save_monthly_data(user_id, month, year, income, metrics):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()

        c.execute(
            f"SELECT id FROM monthly_data WHERE user_id={p} AND month={p} AND year={p}",
            (user_id, month, year)
        )
        if c.fetchone():
            return False, "Data for this month already exists. Use edit instead."

        c.execute(f"""
            INSERT INTO monthly_data
            (user_id, month, year, income, total_expenses, savings,
             savings_rate, expense_ratio, fixed_total, variable_total, health_score)
            VALUES ({p},{p},{p},{p},{p},{p},{p},{p},{p},{p},{p})
        """, (
            user_id, month, year, income,
            metrics["total_expenses"],
            metrics["savings"],
            metrics["savings_rate"],
            metrics.get("expense_ratio", 0),
            metrics.get("fixed_total", 0),
            metrics.get("variable_total", 0),
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
    p    = placeholder()
    try:
        c = conn.cursor()
        for e in expenses:
            c.execute(f"""
                INSERT INTO expenses (user_id, month, year, name, category, type, amount)
                VALUES ({p},{p},{p},{p},{p},{p},{p})
            """, (user_id, month, year, e["name"], e["category"], e["type"], e["amount"]))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error saving expenses: {e}")
        return False
    finally:
        conn.close()


def get_monthly_history(user_id):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(
            f"SELECT * FROM monthly_data WHERE user_id={p} ORDER BY year DESC, month DESC",
            (user_id,)
        )
        rows = c.fetchall()
        if USE_POSTGRES:
            cols = [desc[0] for desc in c.description]
            return [dict(zip(cols, row)) for row in rows]
        return rows
    finally:
        conn.close()


def get_monthly_entry(entry_id, user_id):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(
            f"SELECT * FROM monthly_data WHERE id={p} AND user_id={p}",
            (entry_id, user_id)
        )
        row = c.fetchone()
        if USE_POSTGRES and row:
            cols = [desc[0] for desc in c.description]
            return dict(zip(cols, row))
        return row
    finally:
        conn.close()


def get_expenses_for_month(user_id, month, year):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(
            f"SELECT * FROM expenses WHERE user_id={p} AND month={p} AND year={p}",
            (user_id, month, year)
        )
        rows = c.fetchall()
        if USE_POSTGRES:
            cols = [desc[0] for desc in c.description]
            return [dict(zip(cols, row)) for row in rows]
        return rows
    finally:
        conn.close()


def update_monthly_entry(entry_id, income, metrics):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(f"""
            UPDATE monthly_data SET
            income={p}, total_expenses={p}, savings={p},
            savings_rate={p}, expense_ratio={p},
            fixed_total={p}, variable_total={p}, health_score={p}
            WHERE id={p}
        """, (
            income,
            metrics["total_expenses"],
            metrics["savings"],
            metrics["savings_rate"],
            metrics.get("expense_ratio", 0),
            metrics.get("fixed_total", 0),
            metrics.get("variable_total", 0),
            metrics["health_score"],
            entry_id
        ))
        conn.commit()
        return True
    except Exception as e:
        print(f"Update error: {e}")
        return False
    finally:
        conn.close()


def delete_monthly_entry(entry_id, user_id, month, year):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(
            f"DELETE FROM expenses WHERE user_id={p} AND month={p} AND year={p}",
            (user_id, month, year)
        )
        c.execute(
            f"DELETE FROM monthly_data WHERE id={p} AND user_id={p}",
            (entry_id, user_id)
        )
        conn.commit()
        return True
    except Exception as e:
        print(f"Delete error: {e}")
        return False
    finally:
        conn.close()


def delete_expenses_for_month(user_id, month, year):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(
            f"DELETE FROM expenses WHERE user_id={p} AND month={p} AND year={p}",
            (user_id, month, year)
        )
        conn.commit()
    finally:
        conn.close()

def get_user_by_google_id(google_id):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(
            f"SELECT * FROM users WHERE google_id={p}",
            (google_id,)
        )
        row = c.fetchone()
        if USE_POSTGRES and row:
            cols = [desc[0] for desc in c.description]
            return dict(zip(cols, row))
        return row
    finally:
        conn.close()


def get_user_by_email(email):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(
            f"SELECT * FROM users WHERE email={p}",
            (email,)
        )
        row = c.fetchone()
        if USE_POSTGRES and row:
            cols = [desc[0] for desc in c.description]
            return dict(zip(cols, row))
        return row
    finally:
        conn.close()

#Google 
def create_google_user(google_id, email, name, avatar):
    conn = get_db()
    p    = placeholder()
    try:
        # Create username from email
        username = email.split("@")[0]

        # Make username unique if taken
        base     = username
        counter  = 1
        c        = conn.cursor()

        while True:
            c.execute(
                f"SELECT id FROM users WHERE username={p}",
                (username,)
            )
            if not c.fetchone():
                break
            username = f"{base}{counter}"
            counter += 1

        c.execute(f"""
            INSERT INTO users (username, name, email, google_id, avatar, profession)
            VALUES ({p},{p},{p},{p},{p},{p})
        """, (username, name, email, google_id, avatar, "Not specified"))

        conn.commit()

        # Return the created user
        c.execute(
            f"SELECT * FROM users WHERE google_id={p}",
            (google_id,)
        )
        row = c.fetchone()
        if USE_POSTGRES and row:
            cols = [desc[0] for desc in c.description]
            return dict(zip(cols, row))
        return row
    except Exception as e:
        print(f"Error creating Google user: {e}")
        return None
    finally:
        conn.close()


def update_user_profession(user_id, profession):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(
            f"UPDATE users SET profession={p} WHERE id={p}",
            (profession, user_id)
        )
        conn.commit()
        return True
    except Exception as e:
        print(f"Error updating profession: {e}")
        return False
    finally:
        conn.close()

#gmail login support

def create_user_with_email(username, password, name, profession, email):
    conn = get_db()
    p    = placeholder()
    try:
        c = conn.cursor()
        c.execute(f"""
            INSERT INTO users (username, password, name, profession, email)
            VALUES ({p},{p},{p},{p},{p})
        """, (username, password, name, profession, email))
        conn.commit()
        return True, None
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()

def migrate_db():
    conn = get_db()
    c    = conn.cursor()
    p    = placeholder()

    migrations = [
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id TEXT",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar TEXT",
    ]

    for migration in migrations:
        try:
            c.execute(migration)
            print(f"✅ Migration: {migration}")
        except Exception as e:
            print(f"⚠️ Migration skipped: {e}")

    conn.commit()
    conn.close()