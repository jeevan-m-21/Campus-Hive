"""
Analytics routes
Analytics and dashboard data
"""

from flask import Blueprint
from app.middleware.auth import jwt_required
from app.utils.helpers import success_response

analytics_bp = Blueprint('analytics', __name__)


@analytics_bp.route('/dashboard', methods=['GET'])
@jwt_required
def get_dashboard():
    """Get dashboard data"""
    return success_response({}, 'Dashboard data retrieved', 200)
