"""
Configuration management for CampusHive Backend
Handles environment-specific settings and credentials
"""

import os
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent

# Load environment variables from .env file relative to backend root
load_dotenv(dotenv_path=BASE_DIR / '.env')


class Config:
    """Base configuration - common settings for all environments"""

    # Flask Settings
    DEBUG = False
    TESTING = False
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')

    # Database Configuration
    SQLALCHEMY_DATABASE_URI = os.getenv(
        'DATABASE_URL',
        'mysql+pymysql://root:password@localhost:3306/campushive'
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_size': 20,
        'pool_recycle': 3600,
        'pool_pre_ping': True,
    }

    # JWT Configuration
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'jwt-secret-key-change-in-production')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=24)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    JWT_ALGORITHM = 'HS256'

    # CORS Configuration
    CORS_ORIGINS = os.getenv('CORS_ORIGINS', 'http://localhost:3000,http://localhost:8080').split(',')

    # Firebase Configuration
    FIREBASE_CREDENTIALS_PATH = os.getenv('FIREBASE_CREDENTIALS_PATH', './config/firebase-key.json')
    FIREBASE_STORAGE_BUCKET = os.getenv('FIREBASE_STORAGE_BUCKET', 'campushive-storage.appspot.com')

    # File Upload Configuration
    MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50MB max file size
    _upload_folder_env = os.getenv('UPLOAD_FOLDER')
    if _upload_folder_env:
        UPLOAD_FOLDER = _upload_folder_env if os.path.isabs(_upload_folder_env) else str((BASE_DIR / _upload_folder_env).resolve())
    else:
        UPLOAD_FOLDER = str(BASE_DIR / 'uploads')
    ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx'}

    # AWS & Amazon S3 Configuration
    AWS_REGION = os.getenv('AWS_REGION') or os.getenv('AWS_DEFAULT_REGION') or 'ap-south-1'
    S3_BUCKET_NAME = os.getenv('S3_BUCKET_NAME', 'campushive-media-2026')
    _s3_enabled_env = os.getenv('S3_STORAGE_ENABLED')
    S3_STORAGE_ENABLED = _s3_enabled_env.strip().lower() in ('true', '1', 'yes') if _s3_enabled_env is not None else True
    S3_KEY_PREFIX = os.getenv('S3_KEY_PREFIX', '').strip().strip('/')
    S3_PRESIGNED_REDIRECT = os.getenv('S3_PRESIGNED_REDIRECT', 'false').strip().lower() in ('true', '1', 'yes')
    S3_PRESIGNED_EXPIRES = int(os.getenv('S3_PRESIGNED_EXPIRES', '3600'))

    # Email Configuration
    MAIL_SERVER = os.getenv('MAIL_SERVER') or os.getenv('SMTP_SERVER') or 'smtp.gmail.com'
    MAIL_PORT = int(os.getenv('MAIL_PORT') or os.getenv('SMTP_PORT') or 587)
    _mail_use_tls_raw = os.getenv('MAIL_USE_TLS') if os.getenv('MAIL_USE_TLS') is not None else os.getenv('SMTP_USE_TLS')
    if _mail_use_tls_raw is not None:
        if isinstance(_mail_use_tls_raw, bool):
            MAIL_USE_TLS = _mail_use_tls_raw
        else:
            MAIL_USE_TLS = str(_mail_use_tls_raw).strip().lower() in ('true', '1', 'yes')
    else:
        MAIL_USE_TLS = True
    MAIL_USERNAME = os.getenv('MAIL_USERNAME') or os.getenv('SMTP_USERNAME') or ''
    MAIL_PASSWORD = os.getenv('MAIL_PASSWORD') or os.getenv('SMTP_PASSWORD') or ''
    MAIL_DEFAULT_SENDER = (
        os.getenv('MAIL_DEFAULT_SENDER')
        or os.getenv('MAIL_USERNAME')
        or os.getenv('SMTP_USERNAME')
        or 'campushive.team@gmail.com'
    )

    # API Configuration
    API_TITLE = 'CampusHive API'
    API_VERSION = 'v1'
    API_PREFIX = '/api/v1'
    API_RATE_LIMIT = '200/hour'

    # Application Settings
    ITEMS_PER_PAGE = 20
    MAX_RETRIES = 3
    REQUEST_TIMEOUT = 30

    # Logging Configuration
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FILE = './logs/campushive.log'
    LOG_MAX_BYTES = 10485760  # 10MB
    LOG_BACKUP_COUNT = 10

    # ML Model Configuration
    ML_MODEL_PATH = './app/ml/models/'
    ML_MODEL_VERSION = '1.0'
    ML_PREDICTION_THRESHOLD = 0.6

    # Scheduler Configuration
    SCHEDULER_ENABLED = True
    SCHEDULER_TIMEZONE = 'Asia/Kolkata'
    ML_RETRAINING_ENABLED = os.getenv('ML_RETRAINING_ENABLED', 'false').lower() == 'true'
    ML_RETRAINING_INTERVAL_HOURS = int(os.getenv('ML_RETRAINING_INTERVAL_HOURS', '1'))
    ML_RETRAINING_BATCH_SIZE = int(os.getenv('ML_RETRAINING_BATCH_SIZE', '10'))
    ML_RETRAINING_DELAY_HOURS = int(os.getenv('ML_RETRAINING_DELAY_HOURS', '24'))

    # Complaint Escalation Settings
    ESCALATION_CHECK_INTERVAL_MINUTES = 60
    HIGH_PRIORITY_HOURS = 24
    MEDIUM_PRIORITY_HOURS = 72
    LOW_PRIORITY_DAYS = 7

    # SocketIO Configuration
    SOCKETIO_CORS_ALLOWED_ORIGINS = CORS_ORIGINS
    SOCKETIO_ASYNC_MODE = 'threading'
    SOCKETIO_PING_TIMEOUT = 60
    SOCKETIO_PING_INTERVAL = 25


class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    TESTING = False
    SQLALCHEMY_ECHO = True
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=30)  # Longer for development
    LOG_LEVEL = 'DEBUG'


class TestingConfig(Config):
    """Testing configuration"""
    DEBUG = False
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    SQLALCHEMY_ENGINE_OPTIONS = {}
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=5)
    MAIL_BACKEND = 'locmem'  # Use in-memory email backend for testing
    S3_STORAGE_ENABLED = False  # Disabled by default in tests; enabled in S3-specific tests via mock


class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    TESTING = False
    # Additional security settings
    SESSION_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    PERMANENT_SESSION_LIFETIME = timedelta(days=1)


# Configuration dictionary
config_by_name = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}


def get_config(config_name=None):
    """Get configuration object based on environment"""
    if config_name is None:
        config_name = os.getenv('FLASK_ENV', 'development')
    return config_by_name.get(config_name, config_by_name['default'])
