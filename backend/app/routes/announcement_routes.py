"""
Announcement routes
Organization announcements
"""

from flask import Blueprint
from app.middleware.auth import jwt_required
from app.utils.helpers import success_response

announcement_bp = Blueprint('announcements', __name__)


@announcement_bp.route('', methods=['GET'])
@jwt_required
def get_announcements():
    """Get announcements"""
    return success_response({}, 'Announcements retrieved', 200)
