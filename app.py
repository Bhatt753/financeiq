# Main entry point — keep this slim!

from flask import Flask
from config import Config
from models.database import init_db

app = Flask(__name__)
app.secret_key = Config.SECRET_KEY

# Register route blueprints
from routes.auth    import auth_bp
from routes.dashboard import dashboard_bp
from routes.finance import finance_bp
from routes.goals   import goals_bp

app.register_blueprint(auth_bp)
app.register_blueprint(dashboard_bp)
app.register_blueprint(finance_bp)
app.register_blueprint(goals_bp)

# Initialize database
init_db()

if __name__ == "__main__":
    print("\n🚀 FinanceIQ is running!")
    print("👉 Open: http://127.0.0.1:5000")
    app.run(debug=Config.DEBUG)