"""
CampusHive Backend - Main Entry Point
Production-ready Flask API for campus issue management platform
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from app import create_app

BASE_DIR = Path(__file__).resolve().parent

# Load environment variables from backend directory
load_dotenv(dotenv_path=BASE_DIR / '.env')

# Create Flask app and SocketIO instance
app, socketio = create_app(os.getenv('FLASK_ENV', 'development'))


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for load balancer"""
    return {'status': 'healthy', 'version': '1.0.0'}, 200


@app.route('/api/v1', methods=['GET'])
def api_info():
    """API information endpoint"""
    return {
        'name': 'CampusHive API',
        'version': '1.0.0',
        'status': 'active',
        'docs': '/api/v1/docs'
    }, 200


@app.shell_context_processor
def make_shell_context():
    """Shell context for Flask CLI"""
    from app.database import db
    from app.models import (
        User, Organization, Department, Complaint,
        LostFound, Notification, Announcement,
    )
    
    return {
        'db': db,
        'User': User,
        'Organization': Organization,
        'Department': Department,
        'Complaint': Complaint,
        'LostFound': LostFound,
        'Notification': Notification,
        'Announcement': Announcement,
    }


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


if __name__ == '__main__':
    # Get host and port from environment
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV', 'development') == 'development'
    
    # Run with SocketIO
    socketio.run(
        app,
        host=host,
        port=port,
        debug=debug,
        use_reloader=debug,
        log_output=True
    )
