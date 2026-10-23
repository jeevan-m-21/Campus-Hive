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
    
    # Register CLI commands
    register_cli_commands(app)
    
    # Initialize schedulers
    #init_schedulers(app)
    
    app.logger.info('Flask application created and configured successfully')
    
    return app, socketio


def make_app():
    """Application factory for Flask CLI that returns only the Flask instance."""
    flask_app, _ = create_app()
    return flask_app


def register_cli_commands(app):
    """Register custom CLI commands."""

    @app.cli.command('test-smtp')
    def test_smtp_cli():
        """Verify SMTP connection, STARTTLS, and credentials safely without sending an email."""
        from app.services.email_service import EmailService

        result = EmailService.verify_smtp_connection(app)
        if result.get('success'):
            print(f"[SUCCESS] {result.get('message')}")
            print(f"Details: host={result.get('server')}:{result.get('port')}, tls={result.get('tls')}, credentials_configured={result.get('credentials_configured')}")
        else:
            print(f"[FAILED] Failed during stage: '{result.get('stage')}'")
            print(f"Host: {result.get('server')}:{result.get('port')}, TLS: {result.get('tls')}, Credentials configured: {result.get('credentials_configured')}")
            print(f"Error class: {result.get('error_class')}")
            if result.get('smtp_code'):
                print(f"SMTP code: {result.get('smtp_code')}")
            print(f"Error message: {result.get('error')}")


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
    
    # Register blueprints with API prefix
    api_prefix = app.config.get('API_PREFIX', '/api/v1')
    
    app.register_blueprint(auth_bp, url_prefix=f'{api_prefix}/auth')
    app.register_blueprint(complaint_bp, url_prefix=f'{api_prefix}/complaints')
    app.register_blueprint(org_bp, url_prefix=f'{api_prefix}/organizations')
    app.register_blueprint(lf_bp, url_prefix=f'{api_prefix}/lost-found')
    app.register_blueprint(notif_bp, url_prefix=f'{api_prefix}/notifications')
    app.register_blueprint(announcement_bp, url_prefix=f'{api_prefix}/announcements')

    from flask import Response, redirect, send_from_directory

    @app.route('/uploads/<path:filename>')
    def serve_uploads(filename):
        # Path traversal guard
        if '..' in filename or filename.startswith(('/', '\\')):
            return {'error': 'Bad Request', 'message': 'Invalid file path'}, 400

        from app.services.s3_service import S3Service, S3ServiceError

        if S3Service.is_enabled():
            try:
                if app.config.get('S3_PRESIGNED_REDIRECT', False):
                    presigned_url = S3Service.generate_presigned_url(filename)
                    return redirect(presigned_url, code=302)

                s3_file = S3Service.get_file_stream(filename)
                body = s3_file['body']

                def generate_chunks():
                    try:
                        yield from body.iter_chunks()
                    finally:
                        body.close()

                headers = {
                    'Cache-Control': 'public, max-age=86400',
                }
                if s3_file.get('content_length') is not None:
                    headers['Content-Length'] = str(s3_file['content_length'])
                if s3_file.get('etag'):
                    headers['ETag'] = s3_file['etag']

                response = Response(
                    generate_chunks(),
                    mimetype=s3_file.get('content_type', 'application/octet-stream'),
                    headers=headers,
                )
                response.call_on_close(body.close)
                return response
            except S3ServiceError as exc:
                if exc.status_code == 404:
                    # Genuine 404: check local filesystem for legacy file backward compatibility
                    upload_folder = os.path.abspath(app.config.get('UPLOAD_FOLDER', './uploads'))
                    local_path = os.path.join(upload_folder, filename)
                    if os.path.exists(local_path) and os.path.isfile(local_path):
                        return send_from_directory(upload_folder, filename)
                    return {'error': 'Not Found', 'message': 'File not found'}, 404
                if exc.status_code == 400:
                    return {'error': 'Bad Request', 'message': 'Invalid file path'}, 400

                # Server-side S3 error (IAM permission failure, connection error, etc.)
                app.logger.error(f"S3 retrieval failure for {filename}: {exc.message}")
                return {'error': 'Internal Server Error', 'message': 'Failed to retrieve file'}, 500
            except Exception as exc:
                app.logger.error(f"Unexpected error serving upload from S3 for {filename}: {type(exc).__name__}")
                return {'error': 'Internal Server Error', 'message': 'Failed to retrieve file'}, 500

        upload_folder = os.path.abspath(app.config.get('UPLOAD_FOLDER', './uploads'))
        return send_from_directory(upload_folder, filename)
    
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
