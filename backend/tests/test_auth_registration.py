"""Tests for student registration, public discovery, and security constraints."""

import pytest
from app import create_app
from app.database import db
from app.models import AcademicDepartment, Organization, User
from app.services.auth_service import AuthService, AuthServiceError, ConflictError, ValidationError


@pytest.fixture
def test_app(monkeypatch):
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    db.init_app(app)

    with app.app_context():
        Organization.__table__.create(db.engine, checkfirst=True)
        AcademicDepartment.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)

        # Seed test data
        active_org = Organization(
            organization_id=1,
            organization_name='KS Institute of Technology',
            organization_code='KSIT',
            email_domain='ksit.edu.in',
            is_active=True,
        )
        inactive_org = Organization(
            organization_id=2,
            organization_name='Inactive University',
            organization_code='INACT',
            email_domain='inactive.edu',
            is_active=False,
        )
        db.session.add_all([active_org, inactive_org])
        db.session.commit()

        active_dept_cse = AcademicDepartment(
            academic_department_id=1,
            organization_id=1,
            department_name='Computer Science & Engineering',
            department_code='CSE',
            is_active=True,
        )
        active_dept_ece = AcademicDepartment(
            academic_department_id=2,
            organization_id=1,
            department_name='Electronics & Communication Engineering',
            department_code='ECE',
            is_active=True,
        )
        inactive_dept = AcademicDepartment(
            academic_department_id=3,
            organization_id=1,
            department_name='Old Phased Out Dept',
            department_code='OLD',
            is_active=False,
        )
        other_org_dept = AcademicDepartment(
            academic_department_id=4,
            organization_id=2,
            department_name='Other Branch',
            department_code='OB',
            is_active=True,
        )
        db.session.add_all([active_dept_cse, active_dept_ece, inactive_dept, other_org_dept])
        db.session.commit()

        yield app
        db.session.remove()


@pytest.fixture
def client(test_app):
    return test_app.test_client()


def test_public_organizations_returns_only_active(client):
    """GET /api/v1/organizations/public returns only active orgs with safe fields."""
    response = client.get('/api/v1/organizations/public')
    assert response.status_code == 200
    data = response.get_json()['data']
    assert len(data) == 1
    org = data[0]
    assert org['organization_id'] == 1
    assert org['organization_name'] == 'KS Institute of Technology'
    assert org['organization_code'] == 'KSIT'
    assert org['email_domain'] == 'ksit.edu.in'


def test_public_academic_departments_returns_only_active_for_org(client):
    """GET /api/v1/organizations/<id>/academic-departments returns active departments."""
    response = client.get('/api/v1/organizations/1/academic-departments')
    assert response.status_code == 200
    data = response.get_json()['data']
    assert len(data) == 2
    codes = [d['department_code'] for d in data]
    assert 'CSE' in codes
    assert 'ECE' in codes
    assert 'OLD' not in codes  # Inactive department excluded


def test_public_academic_departments_returns_404_for_invalid_or_inactive_org(client):
    """GET /api/v1/organizations/<id>/academic-departments returns 404 for unknown or inactive org."""
    response_unknown = client.get('/api/v1/organizations/999/academic-departments')
    assert response_unknown.status_code == 404

    response_inactive = client.get('/api/v1/organizations/2/academic-departments')
    assert response_inactive.status_code == 404


def test_successful_student_registration(test_app, monkeypatch):
    """Registering a student with valid token and payload persists user with STUDENT role."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-1',
            'email': 'student1@ksit.edu.in',
        }),
    )

    with test_app.app_context():
        result = AuthService.register_user(
            'valid-token',
            organization_id=1,
            academic_department_id=1,
            full_name='John Doe',
            usn_or_employee_id='1KS23CS001',
            phone='9876543210',
        )

        user_data = result['user']
        assert user_data['full_name'] == 'John Doe'
        assert user_data['role'] == 'STUDENT'
        assert user_data['email'] == 'student1@ksit.edu.in'
        assert user_data['organization_id'] == 1
        assert user_data['academic_department_id'] == 1
        assert user_data['academic_department_name'] == 'Computer Science & Engineering'
        assert user_data['usn_or_employee_id'] == '1KS23CS001'

        user = User.query.filter_by(firebase_uid='firebase-student-1').first()
        assert user is not None
        assert user.role == 'STUDENT'
        # Verify User.to_dict() serialization
        serialized = user.to_dict()
        assert serialized['academic_department_id'] == 1
        assert serialized['academic_department_name'] == 'Computer Science & Engineering'


def test_registration_prevents_role_escalation(test_app, monkeypatch):
    """Attempts to register as admin or supervisor must be rejected."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-hacker',
            'email': 'hacker@ksit.edu.in',
        }),
    )

    with test_app.app_context():
        for disallowed_role in ('SUPER_ADMIN', 'ORG_ADMIN', 'SUPERVISOR', 'admin'):
            with pytest.raises(ValidationError, match="Self-registration is only allowed for the STUDENT role"):
                AuthService.register_user(
                    'valid-token',
                    organization_id=1,
                    academic_department_id=1,
                    role=disallowed_role,
                    full_name='Malicious User',
                    usn_or_employee_id='1KS23CS999',
                )


def test_registration_enforces_organization_email_domain(test_app, monkeypatch):
    """Email domain must match the organization's email_domain."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-2',
            'email': 'student@gmail.com',  # Does not match ksit.edu.in
        }),
    )

    with test_app.app_context():
        with pytest.raises(ValidationError, match="Please register using your ksit.edu.in email address"):
            AuthService.register_user(
                'valid-token',
                organization_id=1,
                academic_department_id=1,
                full_name='Jane Student',
                usn_or_employee_id='1KS23CS002',
            )


def test_registration_rejects_department_from_another_org(test_app, monkeypatch):
    """Academic department must belong to the selected organization."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-3',
            'email': 'student3@ksit.edu.in',
        }),
    )

    with test_app.app_context():
        # Department 4 belongs to organization 2, not organization 1
        with pytest.raises(ValidationError, match="Academic department not found for this organization"):
            AuthService.register_user(
                'valid-token',
                organization_id=1,
                academic_department_id=4,
                full_name='Department Mismatch',
                usn_or_employee_id='1KS23CS003',
            )


def test_registration_rejects_missing_required_fields(test_app, monkeypatch):
    """Academic department, USN, and full name are mandatory."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-4',
            'email': 'student4@ksit.edu.in',
        }),
    )

    with test_app.app_context():
        # Missing academic department
        with pytest.raises(ValidationError, match="academic_department_id is required"):
            AuthService.register_user(
                'valid-token',
                organization_id=1,
                academic_department_id=None,
                full_name='Test Student',
                usn_or_employee_id='1KS23CS004',
            )

        # Missing USN
        with pytest.raises(ValidationError, match="USN or student identifier is required"):
            AuthService.register_user(
                'valid-token',
                organization_id=1,
                academic_department_id=1,
                full_name='Test Student',
                usn_or_employee_id='',
            )

        # Missing Full Name
        with pytest.raises(ValidationError, match="Full name is required"):
            AuthService.register_user(
                'valid-token',
                organization_id=1,
                academic_department_id=1,
                full_name='',
                usn_or_employee_id='1KS23CS004',
            )


def test_registration_rejects_duplicate_usn_within_organization(test_app, monkeypatch):
    """A duplicate USN in the same organization raises ConflictError."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-first',
            'email': 'first@ksit.edu.in',
        }),
    )

    with test_app.app_context():
        AuthService.register_user(
            'valid-token',
            organization_id=1,
            academic_department_id=1,
            full_name='First Student',
            usn_or_employee_id='1KS23CS010',
        )

    # Second student tries to register with same USN in org 1
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-second',
            'email': 'second@ksit.edu.in',
        }),
    )

    with test_app.app_context():
        with pytest.raises(ConflictError, match="A user with this USN or student identifier already exists"):
            AuthService.register_user(
                'valid-token-2',
                organization_id=1,
                academic_department_id=1,
                full_name='Second Student',
                usn_or_employee_id=' 1ks23cs010 ',  # Case and whitespace insensitive
            )


def test_registration_rejects_duplicate_email(test_app, monkeypatch):
    """A duplicate email address raises ConflictError."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-a',
            'email': 'shared@ksit.edu.in',
        }),
    )

    with test_app.app_context():
        AuthService.register_user(
            'valid-token',
            organization_id=1,
            academic_department_id=1,
            full_name='Student A',
            usn_or_employee_id='1KS23CS020',
        )

    # Different firebase_uid tries to use same email
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-b',
            'email': 'shared@ksit.edu.in',
        }),
    )

    with test_app.app_context():
        with pytest.raises(ConflictError, match="A user with this email already exists"):
            AuthService.register_user(
                'valid-token-b',
                organization_id=1,
                academic_department_id=1,
                full_name='Student B',
                usn_or_employee_id='1KS23CS021',
            )


def test_register_endpoint_via_client(client, monkeypatch):
    """POST /api/v1/auth/register handles complete HTTP round-trip."""
    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {
            'firebase_uid': 'firebase-student-http',
            'email': 'httpstudent@ksit.edu.in',
        }),
    )

    response = client.post(
        '/api/v1/auth/register',
        headers={'Authorization': 'Bearer test-firebase-token'},
        json={
            'organization_id': 1,
            'academic_department_id': 1,
            'full_name': 'HTTP Student',
            'usn_or_employee_id': '1KS23CS099',
            'phone': '9876543210',
        },
    )

    assert response.status_code == 201
    body = response.get_json()
    assert body['success'] is True
    assert body['data']['user']['role'] == 'STUDENT'
    assert body['data']['user']['academic_department_name'] == 'Computer Science & Engineering'
