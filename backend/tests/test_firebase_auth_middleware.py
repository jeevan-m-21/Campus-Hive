"""
Regression and unit tests for Firebase authentication and role authorization middleware.
Verifies single execution, invalid tokens, role restrictions, and session context.
"""

from types import SimpleNamespace
from unittest.mock import MagicMock
import pytest
from flask import Blueprint, jsonify

from app import create_app
from app.database import db
from app.models import Organization, Department, User
from app.middleware.firebase_auth import (
    firebase_login_required,
    role_required,
    _authenticate_request,
)
from app.services.auth_service import AuthService, AuthServiceError


# Test blueprint with various decoration patterns
test_auth_bp = Blueprint('test_auth_bp', __name__)


@test_auth_bp.route('/stacked-both', methods=['GET'])
@firebase_login_required
@role_required('ORG_ADMIN', 'SUPER_ADMIN')
def endpoint_stacked_both():
    from flask import g
    return jsonify({
        'success': True,
        'user_id': g.current_user.user_id,
        'role': g.current_user.role,
        'claims_uid': g.firebase_claims.get('firebase_uid'),
    }), 200


@test_auth_bp.route('/login-required-only', methods=['GET'])
@firebase_login_required
def endpoint_login_required_only():
    from flask import g
    return jsonify({
        'success': True,
        'user_id': g.current_user.user_id,
        'role': g.current_user.role,
    }), 200


@test_auth_bp.route('/role-required-only', methods=['GET'])
@role_required('STUDENT')
def endpoint_role_required_only():
    from flask import g
    return jsonify({
        'success': True,
        'user_id': g.current_user.user_id,
        'role': g.current_user.role,
    }), 200


@test_auth_bp.route('/role-required-empty', methods=['GET'])
@firebase_login_required
@role_required()
def endpoint_role_required_empty():
    from flask import g
    return jsonify({
        'success': True,
        'user_id': g.current_user.user_id,
    }), 200


@pytest.fixture
def auth_test_app(monkeypatch):
    """Set up test Flask app with SQLite in-memory database."""
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    db.init_app(app)

    # Register test routes
    app.register_blueprint(test_auth_bp, url_prefix='/test-auth')

    with app.app_context():
        Organization.__table__.create(db.engine, checkfirst=True)
        Department.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)

        org = Organization(
            organization_id=1,
            organization_name='Test College',
            organization_code='TEST',
            email_domain='test.edu',
            is_active=True,
        )
        db.session.add(org)

        # Active Admin user
        admin = User(
            user_id=10,
            organization_id=1,
            full_name='Admin User',
            email='admin@test.edu',
            firebase_uid='uid-admin-10',
            role='ORG_ADMIN',
            is_active=True,
        )
        # Active Student user
        student = User(
            user_id=20,
            organization_id=1,
            full_name='Student User',
            email='student@test.edu',
            firebase_uid='uid-student-20',
            role='STUDENT',
            is_active=True,
        )
        # Inactive user
        inactive = User(
            user_id=30,
            organization_id=1,
            full_name='Inactive User',
            email='inactive@test.edu',
            firebase_uid='uid-inactive-30',
            role='STUDENT',
            is_active=False,
        )
        db.session.add_all([admin, student, inactive])
        db.session.commit()

    return app


@pytest.fixture
def client(auth_test_app):
    return auth_test_app.test_client()


# ==================== 1. REDUNDANT AUTHENTICATION VERIFICATION ====================

def test_stacked_decorators_execute_authentication_only_once(client, monkeypatch):
    """
    Verify that an endpoint decorated with both @firebase_login_required and @role_required
    executes token verification and DB lookup exactly once per request.
    """
    verify_call_count = 0
    orig_verify = AuthService.verify_firebase_token

    def counting_verify(token):
        nonlocal verify_call_count
        verify_call_count += 1
        return {'firebase_uid': 'uid-admin-10'}

    monkeypatch.setattr(AuthService, 'verify_firebase_token', counting_verify)

    import app.middleware.firebase_auth as fb_auth
    load_call_count = 0
    orig_load = fb_auth._load_current_user

    def counting_load(uid):
        nonlocal load_call_count
        load_call_count += 1
        return orig_load(uid)

    monkeypatch.setattr(fb_auth, '_load_current_user', counting_load)

    res = client.get(
        '/test-auth/stacked-both',
        headers={'Authorization': 'Bearer valid-token-for-admin'},
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['user_id'] == 10
    assert data['role'] == 'ORG_ADMIN'

    # Crucial assertion: both verification and DB lookup occurred EXACTLY ONCE
    assert verify_call_count == 1, f"Expected 1 token verification, got {verify_call_count}"
    assert load_call_count == 1, f"Expected 1 DB user lookup, got {load_call_count}"


def test_force_reauthentication_bypasses_cache(auth_test_app, monkeypatch):
    """Verify that passing force=True to _authenticate_request executes re-authentication."""
    from flask import g

    call_count = 0
    def counting_verify(token):
        nonlocal call_count
        call_count += 1
        return {'firebase_uid': 'uid-admin-10'}

    monkeypatch.setattr(AuthService, 'verify_firebase_token', counting_verify)

    with auth_test_app.test_request_context(
        '/test-auth/stacked-both',
        headers={'Authorization': 'Bearer valid-token'},
    ):
        user1 = _authenticate_request()
        assert call_count == 1
        assert g.current_user.user_id == 10

        # Second call with force=False returns cached user
        user2 = _authenticate_request(force=False)
        assert call_count == 1
        assert user2 is user1

        # Third call with force=True re-executes verification
        user3 = _authenticate_request(force=True)
        assert call_count == 2
        assert user3.user_id == 10


# ==================== 2. TOKEN & HEADER VALIDATION ====================

def test_missing_authorization_header_returns_401(client):
    """Requests without Authorization header must return HTTP 401 with missing_token."""
    res = client.get('/test-auth/stacked-both')
    assert res.status_code == 401
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'missing_token'


@pytest.mark.parametrize('bad_header', [
    'Basic dXNlcjpwYXNz',
    'Token some-token',
    'Bearer',
    'Bearer ',
    'NotBearer token-123',
])
def test_malformed_authorization_header_returns_401(client, bad_header):
    """Requests with non-Bearer or empty token must return HTTP 401 with invalid_token."""
    res = client.get('/test-auth/stacked-both', headers={'Authorization': bad_header})
    assert res.status_code == 401
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'invalid_token'


def test_invalid_firebase_token_returns_401(client, monkeypatch):
    """When Firebase SDK rejects a token, middleware must return HTTP 401."""
    def rejecting_verify(token):
        raise AuthServiceError('Invalid or expired Firebase ID token.', status_code=401, error_code='invalid_token')

    monkeypatch.setattr(AuthService, 'verify_firebase_token', rejecting_verify)

    res = client.get(
        '/test-auth/stacked-both',
        headers={'Authorization': 'Bearer expired-or-tampered-token'},
    )
    assert res.status_code == 401
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'invalid_token'


def test_token_missing_firebase_uid_returns_401(client, monkeypatch):
    """When Firebase token claims do not include firebase_uid, return HTTP 401."""
    monkeypatch.setattr(AuthService, 'verify_firebase_token', lambda token: {'email': 'admin@test.edu'})

    res = client.get(
        '/test-auth/stacked-both',
        headers={'Authorization': 'Bearer token-without-uid'},
    )
    assert res.status_code == 401
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'invalid_token'


# ==================== 3. USER DATABASE LOOKUP & STATUS ====================

def test_user_not_found_in_database_returns_401(client, monkeypatch):
    """Valid Firebase token with no matching user record in MySQL returns HTTP 401."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        lambda token: {'firebase_uid': 'non-existent-uid'},
    )

    res = client.get(
        '/test-auth/stacked-both',
        headers={'Authorization': 'Bearer token-for-ghost-user'},
    )
    assert res.status_code == 401
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'user_not_found'


def test_inactive_user_returns_403(client, monkeypatch):
    """Inactive user in MySQL returns HTTP 403 user_inactive."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        lambda token: {'firebase_uid': 'uid-inactive-30'},
    )

    res = client.get(
        '/test-auth/stacked-both',
        headers={'Authorization': 'Bearer token-for-inactive-user'},
    )
    assert res.status_code == 403
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'user_inactive'


# ==================== 4. ROLE-BASED AUTHORIZATION ====================

def test_disallowed_role_returns_403_forbidden(client, monkeypatch):
    """Student attempting to access ORG_ADMIN endpoint is forbidden."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        lambda token: {'firebase_uid': 'uid-student-20'},
    )

    res = client.get(
        '/test-auth/stacked-both',
        headers={'Authorization': 'Bearer student-token'},
    )
    assert res.status_code == 403
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'forbidden'


def test_allowed_role_succeeds(client, monkeypatch):
    """Org Admin accessing ORG_ADMIN endpoint succeeds."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        lambda token: {'firebase_uid': 'uid-admin-10'},
    )

    res = client.get(
        '/test-auth/stacked-both',
        headers={'Authorization': 'Bearer admin-token'},
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['role'] == 'ORG_ADMIN'


def test_role_required_only_endpoint(client, monkeypatch):
    """Endpoint decorated only with @role_required authenticates and enforces role."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        lambda token: {'firebase_uid': 'uid-student-20'},
    )

    res = client.get(
        '/test-auth/role-required-only',
        headers={'Authorization': 'Bearer student-token'},
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['role'] == 'STUDENT'


def test_role_required_empty_allows_any_active_role(client, monkeypatch):
    """@role_required() with no specified roles allows any authenticated active user."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        lambda token: {'firebase_uid': 'uid-student-20'},
    )

    res = client.get(
        '/test-auth/role-required-empty',
        headers={'Authorization': 'Bearer student-token'},
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['user_id'] == 20


def test_login_required_only_endpoint(client, monkeypatch):
    """Endpoint with only @firebase_login_required authenticates and allows access."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        lambda token: {'firebase_uid': 'uid-student-20'},
    )

    res = client.get(
        '/test-auth/login-required-only',
        headers={'Authorization': 'Bearer student-token'},
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['user_id'] == 20
