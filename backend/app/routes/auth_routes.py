"""Authentication routes for Firebase-backed auth."""

from flask import Blueprint, g, request

from app.middleware.firebase_auth import firebase_login_required
from app.services.auth_service import (
    AuthService,
    AuthServiceError,
)
from app.utils.helpers import error_response, success_response


auth_bp = Blueprint('auth', __name__)


def _extract_id_token(payload):
    """Extract Firebase ID token from Authorization header or request body."""

    auth_header = request.headers.get("Authorization")

    if auth_header and auth_header.startswith("Bearer "):
        return auth_header.split(" ", 1)[1]

    return (
        payload.get("id_token")
        or payload.get("firebase_id_token")
        or payload.get("token")
    )

def _handle_auth_error(error: AuthServiceError):
    """Translate auth service exceptions into API responses."""

    return error_response(error.error_code, error.message, error.status_code)


@auth_bp.route('/register', methods=['POST'])
def register():
    """Register or sync a Firebase-authenticated user."""

    payload = request.get_json(silent=True) or {}
    id_token = _extract_id_token(payload)

    if not id_token:
        return error_response('missing_token', 'Firebase ID token is required.', 401)

    try:
        result = AuthService.register_user(
            id_token,
            organization_id=payload.get('organization_id'),
            academic_department_id=payload.get('academic_department_id'),
            department_id=payload.get('department_id'),
            role=payload.get('role'),
            full_name=payload.get('full_name'),
            usn_or_employee_id=payload.get('usn_or_employee_id'),
            phone=payload.get('phone'),
            profile_image=payload.get('profile_image'),
            fcm_token=payload.get('fcm_token'),
        )
    except AuthServiceError as error:
        return _handle_auth_error(error)

    return success_response(result, 'User registered successfully.', 201)


@auth_bp.route('/login', methods=['POST'])
def login():
    """Authenticate a Firebase user and sync the login state."""

    payload = request.get_json(silent=True) or {}
    id_token = _extract_id_token(payload)

    if not id_token:
        return error_response('missing_token', 'Firebase ID token is required.', 401)

    try:
        result = AuthService.login_user(
            id_token,
            fcm_token=payload.get('fcm_token'),
        )
    except AuthServiceError as error:
        return _handle_auth_error(error)

    return success_response(result, 'Login successful.', 200)


@auth_bp.route('/me', methods=['GET'])
@firebase_login_required
def me():
    """Return the authenticated user."""

    return success_response(
        {
            'user': g.current_user.to_dict(),
        },
        'Current user fetched successfully.',
        200,
    )


@auth_bp.route('/update-fcm-token', methods=['POST'])
@firebase_login_required
def update_fcm_token():
    """Update the current user's FCM token."""

    payload = request.get_json(silent=True) or {}
    fcm_token = payload.get('fcm_token')

    if not fcm_token:
        return error_response('validation_error', 'fcm_token is required.', 400)

    try:
        result = AuthService.update_fcm_token(
            fcm_token=fcm_token,
            user_id=g.current_user.user_id,
        )
    except AuthServiceError as error:
        return _handle_auth_error(error)

    return success_response(result, 'FCM token updated successfully.', 200)
