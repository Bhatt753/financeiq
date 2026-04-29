# config.py
# All configuration in one place

import os
from dotenv import load_dotenv

load_dotenv()  # loads .env file

class Config:
    # Security
    SECRET_KEY = os.environ.get("SECRET_KEY", "change-this-in-production")

    # Database
    DATABASE_URL = os.environ.get("DATABASE_URL", "finance_app.db")

    # App settings
    DEBUG = os.environ.get("DEBUG", "False") == "True"

    # Finance constants
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