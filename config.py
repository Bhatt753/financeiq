# config.py

import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SECRET_KEY           = os.environ.get("SECRET_KEY", "change-this")
    DATABASE_URL         = os.environ.get("DATABASE_URL", "")
    DEBUG                = os.environ.get("DEBUG", "False") == "True"
    GOOGLE_CLIENT_ID     = os.environ.get("GOOGLE_CLIENT_ID")
    GOOGLE_CLIENT_SECRET = os.environ.get("GOOGLE_CLIENT_SECRET")

    CATEGORIES = [
        "Rent/Housing", "Food & Groceries", "Transport",
        "Utilities", "Healthcare", "Entertainment",
        "Shopping", "Education", "Other"
    ]

    HEALTHY_LIMITS = {
        "Rent/Housing"    : 30,
        "Food & Groceries": 20,
        "Transport"       : 15,
        "Utilities"       : 10,
        "Healthcare"      : 10,
        "Entertainment"   : 10,
        "Shopping"        : 10,
        "Education"       : 10,
        "Other"           : 5
    }