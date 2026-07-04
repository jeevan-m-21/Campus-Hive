"""
Lost and found routes
Lost/found item management
"""

from flask import Blueprint
from app.middleware.auth import jwt_required
from app.utils.helpers import success_response

lf_bp = Blueprint('lost_found', __name__)


@lf_bp.route('', methods=['GET'])
@jwt_required
def list_lost_found():
    """List lost and found items"""
    return success_response({}, 'Items retrieved', 200)


@lf_bp.route('', methods=['POST'])
@jwt_required
def create_lost_found():
    """Create lost/found post"""
    return success_response({}, 'Post created', 201)
