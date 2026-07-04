"""
Notification routes
User notifications
"""

from flask import Blueprint
from app.middleware.auth import jwt_required
from app.utils.helpers import success_response

notif_bp = Blueprint('notifications', __name__)


@notif_bp.route('', methods=['GET'])
@jwt_required
def get_notifications():
    """Get user notifications"""
    return success_response({}, 'Notifications retrieved', 200)
