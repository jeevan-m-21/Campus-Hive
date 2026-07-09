"""
Database initialization and configuration
Uses SQLAlchemy ORM for database operations
"""

from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate

# Initialize SQLAlchemy
db = SQLAlchemy()

# Initialize Flask-Migrate
migrate = Migrate()


def init_db(app):
    """
    Initialize database with Flask app
    
    Args:
        app: Flask application instance
    """
    db.init_app(app)
    migrate.init_app(app, db)

    # Create tables if they don't exist

