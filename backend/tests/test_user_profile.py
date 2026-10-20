"""Unit and regression tests for User Profile Update endpoint:
- Successful authenticated profile update (PATCH and PUT)
- Name spelling correction
- Clearing phone number
- Invalid or empty input
- Excessively long field values
- Unsupported/protected fields (role, organization_id, usn_or_employee_id, email, is_active, user_id, etc.)
- Unauthenticated requests
- Inactive user rejection
- Attempts to update another user's profile
- Database persistence and response verification
- Profile image URL safety
"""

import pytest
from app import create_app
from app.database import db
from app.models import Organization, Department, AcademicDepartment, User
from app.services.auth_service import AuthService


@pytest.fixture
def profile_test_app(monkeypatch):
    """Set up test Flask app with in-memory SQLite and test users."""
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    db.init_app(app)

    with app.app_context():
        Organization.__table__.create(db.engine, checkfirst=True)
        AcademicDepartment.__table__.create(db.engine, checkfirst=True)
        Department.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)

        org = Organization(
            organization_id=1,
            organization_name='Campus University',
            organization_code='CAMPUS',
            email_domain='campus.edu',
            is_active=True,
        )
        db.session.add(org)

        student1 = User(
            user_id=101,
            organization_id=1,
            full_name='Jeevan Kumar',
            usn_or_employee_id='1CH20CS001',
            email='jeevan@campus.edu',
            firebase_uid='uid-student-101',
            phone='9876543210',
            role='STUDENT',
            is_active=True,
        )

        student2 = User(
            user_id=102,
            organization_id=1,
            full_name='Alice Smith',
            usn_or_employee_id='1CH20CS002',
            email='alice@campus.edu',
            firebase_uid='uid-student-102',
            phone='9123456780',
            role='STUDENT',
            is_active=True,
        )

        inactive_user = User(
            user_id=103,
            organization_id=1,
            full_name='Inactive User',
            usn_or_employee_id='1CH20CS003',
            email='inactive@campus.edu',
            firebase_uid='uid-inactive-103',
            phone='9000000000',
            role='STUDENT',
            is_active=False,
        )

        db.session.add_all([student1, student2, inactive_user])
        db.session.commit()

    return app


@pytest.fixture
def client(profile_test_app):
    return profile_test_app.test_client()


def _auth_header(token):
    return {'Authorization': f'Bearer {token}'}


@pytest.fixture(autouse=True)
def mock_firebase_token(monkeypatch):
    """Mock verify_firebase_token to map test token to corresponding firebase_uid."""
    def fake_verify(token, *args, **kwargs):
        tokens = {
            'token-student-101': {'firebase_uid': 'uid-student-101'},
            'token-student-102': {'firebase_uid': 'uid-student-102'},
            'token-inactive-103': {'firebase_uid': 'uid-inactive-103'},
        }
        if token in tokens:
            return tokens[token]
        raise AuthService.verify_firebase_token.__globals__['AuthenticationError']('Invalid token.')

    monkeypatch.setattr(AuthService, 'verify_firebase_token', fake_verify)


# ==================== 1. SUCCESSFUL PROFILE UPDATES ====================

def test_update_profile_success_patch(client, profile_test_app):
    """Verify PATCH /api/v1/auth/profile successfully updates allowed fields."""
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={
            'full_name': 'Jeevan K. M.',
            'phone': '9988776655',
        },
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['data']['user']['full_name'] == 'Jeevan K. M.'
    assert data['data']['user']['phone'] == '9988776655'

    # Verify persistence in database
    with profile_test_app.app_context():
        user = User.query.get(101)
        assert user.full_name == 'Jeevan K. M.'
        assert user.phone == '9988776655'


def test_update_profile_success_put(client, profile_test_app):
    """Verify PUT /api/v1/auth/profile also works for profile updates."""
    res = client.put(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={
            'full_name': 'Jeevan PUT Update',
            'phone': '9876543211',
        },
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['data']['user']['full_name'] == 'Jeevan PUT Update'

    with profile_test_app.app_context():
        user = User.query.get(101)
        assert user.full_name == 'Jeevan PUT Update'


def test_update_profile_me_patch(client, profile_test_app):
    """Verify PATCH /api/v1/auth/me alias endpoint."""
    res = client.patch(
        '/api/v1/auth/me',
        headers=_auth_header('token-student-101'),
        json={
            'full_name': 'Jeevan Me Update',
        },
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['data']['user']['full_name'] == 'Jeevan Me Update'


def test_name_spelling_correction(client, profile_test_app):
    """Verify name spelling correction specifically."""
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={
            'full_name': 'Jeeva Mohan',
        },
    )
    assert res.status_code == 200
    assert res.get_json()['data']['user']['full_name'] == 'Jeeva Mohan'

    with profile_test_app.app_context():
        user = User.query.get(101)
        assert user.full_name == 'Jeeva Mohan'


def test_clear_phone_number(client, profile_test_app):
    """Verify phone can be cleared by sending None or empty string."""
    # Test setting phone to None
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={'phone': None},
    )
    assert res.status_code == 200
    assert res.get_json()['data']['user']['phone'] is None

    with profile_test_app.app_context():
        user = User.query.get(101)
        assert user.phone is None

    # Test setting phone to empty string
    res2 = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={'phone': '   '},
    )
    assert res2.status_code == 200
    assert res2.get_json()['data']['user']['phone'] is None


# ==================== 2. INPUT VALIDATION & LENGTH CHECKS ====================

def test_empty_payload_rejected(client):
    """Verify empty dictionary payload is rejected with 400."""
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={},
    )
    assert res.status_code == 400
    data = res.get_json()
    assert data['success'] is False
    assert 'At least one profile field' in data['message']


def test_empty_or_whitespace_name_rejected(client):
    """Verify empty or whitespace-only name is rejected."""
    for invalid_name in ['', '   ', None]:
        res = client.patch(
            '/api/v1/auth/profile',
            headers=_auth_header('token-student-101'),
            json={'full_name': invalid_name},
        )
        assert res.status_code == 400
        assert res.get_json()['success'] is False


def test_non_string_name_rejected(client):
    """Verify non-string name is rejected."""
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={'full_name': 12345},
    )
    assert res.status_code == 400
    assert 'must be a string' in res.get_json()['message']


def test_non_string_phone_rejected(client):
    """Verify numeric phone (non-string) is rejected."""
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={'phone': 9876543210},
    )
    assert res.status_code == 400
    assert 'must be a string or null' in res.get_json()['message']


def test_excessively_long_name_rejected(client):
    """Verify name exceeding 100 characters is rejected."""
    long_name = 'A' * 101
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={'full_name': long_name},
    )
    assert res.status_code == 400
    assert '100 characters or fewer' in res.get_json()['message']


def test_excessively_long_phone_rejected(client):
    """Verify phone exceeding 15 characters is rejected."""
    long_phone = '1' * 16
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={'phone': long_phone},
    )
    assert res.status_code == 400
    assert '15 characters or fewer' in res.get_json()['message']


def test_excessively_long_profile_image_rejected(client):
    """Verify profile_image URL exceeding 255 characters is rejected."""
    long_image = 'https://example.com/' + 'a' * 250
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={'profile_image': long_image},
    )
    assert res.status_code == 400
    assert '255 characters or fewer' in res.get_json()['message']


# ==================== 3. SECURITY & PROTECTED FIELDS ====================

@pytest.mark.parametrize('protected_field,test_val', [
    ('role', 'SUPER_ADMIN'),
    ('organization_id', 99),
    ('usn_or_employee_id', 'HACK123'),
    ('email', 'hacker@other.edu'),
    ('password', 'newsecretpass'),
    ('is_active', False),
    ('user_id', 999),
    ('firebase_uid', 'hacked-uid'),
    ('department_id', 5),
    ('academic_department_id', 5),
    ('fcm_token', 'token123'),
])
def test_protected_fields_strictly_rejected(client, protected_field, test_val):
    """Verify that any attempt to modify protected or authorization fields returns 400."""
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={protected_field: test_val},
    )
    assert res.status_code == 400
    data = res.get_json()
    assert data['success'] is False
    assert f"Field '{protected_field}' cannot be modified." in data['message']


def test_cannot_update_another_user_profile(client, profile_test_app):
    """Verify that user 101 cannot update user 102's profile.
    Client-supplied user_id in payload is rejected;
    Client-supplied user_id in query parameters is ignored.
    """
    # 1. user_id in payload rejected as protected field
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-student-101'),
        json={
            'user_id': 102,
            'full_name': 'Hacked Name',
        },
    )
    assert res.status_code == 400
    assert "Field 'user_id' cannot be modified." in res.get_json()['message']

    # 2. query param ?user_id=102 has zero effect on user 102
    res2 = client.patch(
        '/api/v1/auth/profile?user_id=102',
        headers=_auth_header('token-student-101'),
        json={'full_name': 'Valid Name For 101'},
    )
    assert res2.status_code == 200

    with profile_test_app.app_context():
        user101 = User.query.get(101)
        user102 = User.query.get(102)
        assert user101.full_name == 'Valid Name For 101'
        assert user102.full_name == 'Alice Smith'  # Completely untouched


# ==================== 4. AUTHENTICATION & STATUS ====================

def test_unauthenticated_request_rejected(client):
    """Verify unauthenticated request returns 401."""
    res = client.patch(
        '/api/v1/auth/profile',
        json={'full_name': 'No Token'},
    )
    assert res.status_code == 401


def test_invalid_bearer_token_rejected(client):
    """Verify invalid token returns 401."""
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('invalid-fake-token'),
        json={'full_name': 'Bad Token'},
    )
    assert res.status_code == 401


def test_inactive_user_rejected(client):
    """Verify inactive user cannot update their profile."""
    res = client.patch(
        '/api/v1/auth/profile',
        headers=_auth_header('token-inactive-103'),
        json={'full_name': 'Trying Update'},
    )
    assert res.status_code == 403


# ==================== 5. PROFILE IMAGE URL SAFETY ====================

def test_safe_profile_image_url_accepted(client, profile_test_app):
    """Verify safe profile image URLs are accepted."""
    for safe_url in [
        '/uploads/profile/my_pic.jpg',
        'https://example.com/avatar.png',
        None,
    ]:
        res = client.patch(
            '/api/v1/auth/profile',
            headers=_auth_header('token-student-101'),
            json={'profile_image': safe_url},
        )
        assert res.status_code == 200
        assert res.get_json()['success'] is True


def test_dangerous_profile_image_url_rejected(client):
    """Verify dangerous profile image URL schemes are rejected."""
    for dangerous_url in [
        'javascript:alert(1)',
        'data:image/png;base64,abc',
        'vbscript:msgbox',
        '//malicious.com/pic.jpg',
        'https://example.com/pic with spaces.jpg',
    ]:
        res = client.patch(
            '/api/v1/auth/profile',
            headers=_auth_header('token-student-101'),
            json={'profile_image': dangerous_url},
        )
        assert res.status_code == 400
        assert 'Invalid profile_image URL.' in res.get_json()['message']
