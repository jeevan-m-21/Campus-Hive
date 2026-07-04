"""
JWT Authentication Middleware
Handles JWT token verification and user context
"""

from functools import wraps
from flask import request, jsonify, current_app, g
from flask_jwt_extended import JWTManager, create_access_token, create_refresh_token, verify_jwt_in_request
from flask_jwt_extended import jwt_required as jwt_required_decorator
from flask_jwt_extended import get_jwt_identity, get_jwt
from datetime import datetime, timedelta
import jwt

from app.models import User, Organization
from app.database import db


class JWTManager:
    """JWT Authentication Manager"""
    
    def __init__(self, app=None):
        """Initialize JWT manager with Flask app"""
        self.app = app
        if app:
            self.init_app(app)
    
    def init_app(self, app):
        """
        Initialize JWT with Flask app
        
        Args:
            app: Flask application instance
        """
        from flask_jwt_extended import JWTManager as FlaskJWTManager
        
        jwt = FlaskJWTManager(app)
        
        @jwt.additional_claims_loader
        def add_claims_to_jwt(identity):
            """Add additional claims to JWT"""
            user = User.query.get(identity)
            if user:
                return {
                    'role': user.role,
                    'organization_id': user.organization_id,
                    'email': user.email,
                    'full_name': user.full_name
                }
            return {}
        
        @jwt.user_lookup_loader
        def user_lookup_callback(_jwt_header, jwt_data):
            """Load user from JWT"""
            identity = jwt_data['sub']
            return User.query.get(identity)


def jwt_required(fn):
    """
    Wrapper to require JWT authentication
    Verifies token and sets user context
    """
    @wraps(fn)
    @jwt_required_decorator()
    def wrapper(*args, **kwargs):
        # Get user ID from JWT
        user_id = get_jwt_identity()
        claims = get_jwt()
        
        # Load user from database
        user = User.query.get(user_id)
        if not user:
            return {'error': 'User not found'}, 404
        
        if not user.is_active:
            return {'error': 'User is inactive'}, 403
        
        # Set user context for request
        g.current_user = user
        g.current_organization_id = user.organization_id
        g.claims = claims
        
        return fn(*args, **kwargs)
    
    return wrapper


def require_role(*allowed_roles):
    """
    Decorator to require specific roles
    
    Args:
        *allowed_roles: Allowed user roles
    """
    def decorator(fn):
        @wraps(fn)
        @jwt_required_decorator()
        def wrapper(*args, **kwargs):
            user_id = get_jwt_identity()
            claims = get_jwt()
            
            user = User.query.get(user_id)
            if not user:
                return {'error': 'User not found'}, 404
            
            if user.role not in allowed_roles:
                return {'error': f'This action requires one of these roles: {", ".join(allowed_roles)}'}, 403
            
            g.current_user = user
            g.current_organization_id = user.organization_id
            g.claims = claims
            
            return fn(*args, **kwargs)
        
        return wrapper
    return decorator


def require_organization(fn):
    """
    Decorator to enforce organization-scoped access
    Verifies that accessed resources belong to user's organization
    """
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not hasattr(g, 'current_user'):
            return {'error': 'Authentication required'}, 401
        
        # Check if organization_id is in request
        org_id = request.json.get('organization_id') if request.is_json else None
        org_id = org_id or kwargs.get('organization_id')
        
        # If organization_id is specified, verify it matches user's organization
        if org_id and org_id != g.current_user.organization_id:
            return {'error': 'Access denied - different organization'}, 403
        
        return fn(*args, **kwargs)
    
    return wrapper


def generate_tokens(user):
    """
    Generate access and refresh tokens for user
    
    Args:
        user: User instance
        
    Returns:
        dict: Dictionary with access and refresh tokens
    """
    access_token = create_access_token(identity=user.id)
    refresh_token = create_refresh_token(identity=user.id)
    
    return {
        'access_token': access_token,
        'refresh_token': refresh_token,
        'token_type': 'Bearer',
        'expires_in': 86400  # 24 hours in seconds
    }


def verify_token(token):
    """
    Verify JWT token
    
    Args:
        token (str): JWT token
        
    Returns:
        dict: Token payload or None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            current_app.config['JWT_SECRET_KEY'],
            algorithms=[current_app.config.get('JWT_ALGORITHM', 'HS256')]
        )
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None
