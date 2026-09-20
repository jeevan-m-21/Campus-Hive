"""
Main Flask Application Factory
Initializes and configures the Flask application
"""

import os
import logging
from logging.handlers import RotatingFileHandler
from flask import Flask
from flask_cors import CORS
from flask_socketio import SocketIO

from config import get_config
from app.database import init_db
from app.utils.logger import setup_logger


def create_app(config_name=None):
    """
    Application factory function
    Creates and configures Flask application
    
    Args:
        config_name (str): Configuration name (development/testing/production)
        
    Returns:
        Flask: Configured Flask application instance
    """
    
    # Get configuration
    config = get_config(config_name)
    
    # Create Flask app
    app = Flask(__name__)
    app.config.from_object(config)
    
    # Setup logging
    setup_logger(app)
    
    # Initialize extensions
    CORS(app, origins=config.CORS_ORIGINS)
    init_db(app)
    
    
    # Initialize SocketIO
    socketio = SocketIO(
        app,
        cors_allowed_origins=config.SOCKETIO_CORS_ALLOWED_ORIGINS,
        async_mode=config.SOCKETIO_ASYNC_MODE,
        ping_timeout=config.SOCKETIO_PING_TIMEOUT,
        ping_interval=config.SOCKETIO_PING_INTERVAL
    )
    
    # Register error handlers
    register_error_handlers(app)
    
    # Register blueprints
    register_blueprints(app)
    
    # Register SocketIO events
    register_socketio_events(app, socketio)
    
    # Initialize schedulers
    #init_schedulers(app)
    
    app.logger.info('Flask application created and configured successfully')
    
    return app, socketio


def register_blueprints(app):
    """
    Register all route blueprints
    
    Args:
        app: Flask application instance
    """
    from app.routes.auth_routes import auth_bp
    from app.routes.complaint_routes import complaint_bp
    from app.routes.organization_routes import org_bp
    from app.routes.lost_found_routes import lf_bp
    from app.routes.notification_routes import notif_bp
    from app.routes.announcement_routes import announcement_bp
    from app.routes.analytics_routes import analytics_bp
    
    # Register blueprints with API prefix
    api_prefix = app.config.get('API_PREFIX', '/api/v1')
    
    app.register_blueprint(auth_bp, url_prefix=f'{api_prefix}/auth')
    app.register_blueprint(complaint_bp, url_prefix=f'{api_prefix}/complaints')
    app.register_blueprint(org_bp, url_prefix=f'{api_prefix}/organizations')
    app.register_blueprint(lf_bp, url_prefix=f'{api_prefix}/lost-found')
    app.register_blueprint(notif_bp, url_prefix=f'{api_prefix}/notifications')
    app.register_blueprint(announcement_bp, url_prefix=f'{api_prefix}/announcements')
    app.register_blueprint(analytics_bp, url_prefix=f'{api_prefix}/analytics')
    
    app.logger.info('All blueprints registered successfully')


def register_error_handlers(app):
    """
    Register error handlers for common errors
    
    Args:
        app: Flask application instance
    """
    
    @app.errorhandler(400)
    def bad_request(error):
        return {'error': 'Bad Request', 'message': str(error)}, 400
    
    @app.errorhandler(401)
    def unauthorized(error):
        return {'error': 'Unauthorized', 'message': 'Authentication required'}, 401
    
    @app.errorhandler(403)
    def forbidden(error):
        return {'error': 'Forbidden', 'message': 'You do not have permission'}, 403
    
    @app.errorhandler(404)
    def not_found(error):
        return {'error': 'Not Found', 'message': 'Resource not found'}, 404
    
    @app.errorhandler(500)
    def internal_error(error):
        app.logger.error(f'Internal server error: {str(error)}')
        return {'error': 'Internal Server Error', 'message': 'An error occurred'}, 500


def register_socketio_events(app, socketio):
    """
    Register SocketIO event handlers
    
    Args:
        app: Flask application instance
        socketio: SocketIO instance
    """
    from app.sockets.complaint_events import register_complaint_events
    from app.sockets.notification_events import register_notification_events
    
    register_complaint_events(socketio, app)
    register_notification_events(socketio, app)


def init_schedulers(app):
    """
    Initialize background task schedulers
    
    Args:
        app: Flask application instance
    """
    if not app.config.get('SCHEDULER_ENABLED', True):
        return
    
    from apscheduler.schedulers.background import BackgroundScheduler
    from app.services.escalation_service import EscalationService
    from app.services.analytics_service import AnalyticsService
    
    scheduler = BackgroundScheduler(timezone=app.config.get('SCHEDULER_TIMEZONE', 'UTC'))
    
    # Add scheduled jobs
    scheduler.add_job(
        func=lambda: EscalationService.check_escalations(),
        trigger='interval',
        minutes=app.config.get('ESCALATION_CHECK_INTERVAL_MINUTES', 60),
        id='escalation_checker',
        name='Check for escalations',
        replace_existing=True
    )
    
    scheduler.add_job(
        func=lambda: AnalyticsService.calculate_daily_statistics(),
        trigger='cron',
        hour=0,
        minute=0,
        id='daily_stats',
        name='Calculate daily statistics',
        replace_existing=True
    )

    if app.config.get('ML_RETRAINING_ENABLED', False):
        from app.services.retraining_service import RetrainingService

        def run_retraining_check():
            with app.app_context():
                RetrainingService.check_and_retrain()

        scheduler.add_job(
            func=run_retraining_check,
            trigger='interval',
            hours=app.config.get('ML_RETRAINING_INTERVAL_HOURS', 1),
            id='ml_priority_retraining',
            name='Retrain complaint priority model',
            replace_existing=True,
        )
    
    scheduler.start()
    app.logger.info('Background schedulers initialized')
