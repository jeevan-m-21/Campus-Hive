"""
CampusHive Backend - Main Entry Point
Production-ready Flask API for campus issue management platform
"""

import os
import sys
from dotenv import load_dotenv
from app import create_app

# Load environment variables
load_dotenv()

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
        User, Organization, Department, Supervisor, Student,
        Complaint, LostFoundItem, Notification, Announcement
    )
    
    return {
        'db': db,
        'User': User,
        'Organization': Organization,
        'Department': Department,
        'Supervisor': Supervisor,
        'Student': Student,
        'Complaint': Complaint,
        'LostFoundItem': LostFoundItem,
        'Notification': Notification,
        'Announcement': Announcement
    }


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
