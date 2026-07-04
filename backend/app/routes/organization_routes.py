"""
Organization routes
Organization management endpoints
"""

from flask import Blueprint, request, g
from app.middleware.auth import jwt_required, require_role
from app.utils.helpers import success_response, error_response

org_bp = Blueprint('organizations', __name__)


@org_bp.route('', methods=['GET'])
@jwt_required
def get_organization():
    """Get organization details"""
    return success_response({}, 'Organization retrieved', 200)


@org_bp.route('/<org_id>/stats', methods=['GET'])
@jwt_required
@require_role('admin', 'super_admin')
def get_org_stats(org_id):
    """Get organization statistics"""
    return success_response({}, 'Stats retrieved', 200)
