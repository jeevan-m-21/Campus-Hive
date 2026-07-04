"""
Authentication routes
Login, registration, token refresh, and password management
"""

from flask import Blueprint, request, current_app
from datetime import datetime

from app.database import db
from app.models import User, Organization, UserSession
from app.middleware.auth import generate_tokens, require_organization
from app.utils.validators import UserRegisterSchema, UserLoginSchema, validate_schema
from app.utils.helpers import success_response, error_response, hash_password, verify_password, generate_uuid

auth_bp = Blueprint('auth', __name__)


@auth_bp.route('/register', methods=['POST'])
def register():
    """
    Register new user
    POST /api/v1/auth/register
    """
    data = request.get_json()
    
    # Validate input
    schema = UserRegisterSchema()
    validated_data, errors = validate_schema(schema, data)
    if errors:
        return error_response(errors, 'Validation failed', 400)
    
    # Check if email already exists in organization
    org_id = validated_data['organization_id']
    email = validated_data['email']
    
    existing_user = User.query.filter_by(
        organization_id=org_id,
        email=email
    ).first()
    
    if existing_user:
        return error_response('email_exists', 'Email already registered in this organization', 400)
    
    # Verify organization exists
    org = Organization.query.get(org_id)
    if not org:
        return error_response('org_not_found', 'Organization not found', 404)
    
    # Create new user
    user = User(
        id=generate_uuid(),
        organization_id=org_id,
        email=email,
        password_hash=hash_password(validated_data['password']),
        first_name=validated_data.get('first_name'),
        last_name=validated_data.get('last_name'),
        phone=validated_data.get('phone'),
        role=validated_data.get('role', 'student'),
        is_verified=True
    )
    
    db.session.add(user)
    db.session.commit()
    
    current_app.logger.info(f'User registered: {email}')
    
    return success_response(
        {'user_id': user.id, 'email': user.email},
        'User registered successfully',
        201
    )


@auth_bp.route('/login', methods=['POST'])
def login():
    """
    Login user and return JWT tokens
    POST /api/v1/auth/login
    """
    data = request.get_json()
    
    # Validate input
    schema = UserLoginSchema()
    validated_data, errors = validate_schema(schema, data)
    if errors:
        return error_response(errors, 'Validation failed', 400)
    
    email = validated_data['email']
    password = validated_data['password']
    
    # Find user by email (search across organizations for super admin)
    user = User.query.filter_by(email=email).first()
    
    if not user or not verify_password(password, user.password_hash):
        return error_response('invalid_credentials', 'Invalid email or password', 401)
    
    if not user.is_active:
        return error_response('user_inactive', 'User account is inactive', 403)
    
    # Update last login and FCM token
    user.last_login_at = datetime.utcnow()
    if validated_data.get('fcm_token'):
        user.fcm_token = validated_data['fcm_token']
        user.fcm_token_updated_at = datetime.utcnow()
    if validated_data.get('device_id'):
        user.device_id = validated_data['device_id']
    
    db.session.commit()
    
    # Generate tokens
    tokens = generate_tokens(user)
    
    current_app.logger.info(f'User logged in: {email}')
    
    return success_response({
        'tokens': tokens,
        'user': {
            'id': user.id,
            'email': user.email,
            'full_name': user.full_name,
            'role': user.role,
            'organization_id': user.organization_id
        }
    }, 'Login successful', 200)


@auth_bp.route('/refresh', methods=['POST'])
def refresh_token():
    """
    Refresh access token
    POST /api/v1/auth/refresh
    """
    # TODO: Implement token refresh
    return success_response({}, 'Token refreshed', 200)


@auth_bp.route('/logout', methods=['POST'])
def logout():
    """
    Logout user
    POST /api/v1/auth/logout
    """
    # TODO: Implement logout
    return success_response({}, 'Logout successful', 200)


@auth_bp.route('/verify', methods=['GET'])
def verify():
    """
    Verify token validity
    GET /api/v1/auth/verify
    """
    # TODO: Implement token verification
    return success_response({}, 'Token valid', 200)
