"""Tests for Organization Admin supervisor account creation in CampusHive."""

import uuid
from types import SimpleNamespace
import pytest

from app import create_app
from app.database import db
from app.models import (
    Complaint,
    ComplaintImage,
    ComplaintStatusHistory,
    ComplaintSupport,
    Department,
    Notification,
    Organization,
    User,
)
from app.services.auth_service import AuthService, AuthServiceError


@pytest.fixture
def test_app(monkeypatch):
    """Set up test Flask application with in-memory SQLite database."""
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    db.init_app(app)

    with app.app_context():
        for table in [Complaint, ComplaintImage, ComplaintSupport, ComplaintStatusHistory, Notification]:
            for idx in list(table.__table__.indexes):
                idx.name = f"idx_{table.__tablename__}_{idx.name}"

        Organization.__table__.create(db.engine, checkfirst=True)
        Department.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)
        Complaint.__table__.create(db.engine, checkfirst=True)
        ComplaintImage.__table__.create(db.engine, checkfirst=True)
        ComplaintSupport.__table__.create(db.engine, checkfirst=True)
        ComplaintStatusHistory.__table__.create(db.engine, checkfirst=True)
        Notification.__table__.create(db.engine, checkfirst=True)

        # Seed Organizations
        org1 = Organization(
            organization_id=1,
            organization_name='KSIT Campus',
            organization_code='KSIT',
            email_domain='ksit.edu.in',
            is_active=True,
        )
        org2 = Organization(
            organization_id=2,
            organization_name='Other University',
            organization_code='OTHER',
            email_domain='other.edu',
            is_active=True,
        )
        db.session.add_all([org1, org2])
        db.session.flush()

        # Seed Departments
        dept_electrical = Department(
            department_id=1,
            organization_id=1,
            department_name='Electrical Maintenance',
            description='Electrical issues',
        )
        dept_housekeeping = Department(
            department_id=2,
            organization_id=1,
            department_name='Housekeeping',
            description='Cleaning and hygiene',
        )
        dept_org2 = Department(
            department_id=3,
            organization_id=2,
            department_name='External Dept',
            description='Belongs to Org 2',
        )
        db.session.add_all([dept_electrical, dept_housekeeping, dept_org2])
        db.session.flush()

        # Seed Admin User
        admin = User(
            user_id=10,
            organization_id=1,
            full_name='KSIT Admin',
            usn_or_employee_id='ADMIN01',
            email='admin@ksit.edu.in',
            firebase_uid='uid_admin_1',
            role='ORG_ADMIN',
            is_active=True,
        )
        # Seed Student User
        student = User(
            user_id=20,
            organization_id=1,
            full_name='Student Alice',
            usn_or_employee_id='1KS20CS001',
            email='student@ksit.edu.in',
            firebase_uid='uid_student_1',
            role='STUDENT',
            is_active=True,
        )
        # Seed Existing Supervisor
        supervisor = User(
            user_id=30,
            organization_id=1,
            department_id=1,
            full_name='Existing Supervisor',
            usn_or_employee_id='SUP001',
            email='existing.sup@ksit.edu.in',
            firebase_uid='uid_sup_1',
            role='SUPERVISOR',
            is_active=True,
        )
        # Inactive Admin
        inactive_admin = User(
            user_id=11,
            organization_id=1,
            full_name='Inactive Admin',
            usn_or_employee_id='ADMIN02',
            email='inactive.admin@ksit.edu.in',
            firebase_uid='uid_admin_inactive',
            role='ORG_ADMIN',
            is_active=False,
        )
        db.session.add_all([admin, student, supervisor, inactive_admin])
        db.session.commit()

        yield app
        db.session.remove()


@pytest.fixture
def client(test_app):
    return test_app.test_client()


def _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN', is_active=True):
    """Mock authentication context."""
    mock_user = SimpleNamespace(
        user_id=user_id,
        organization_id=org_id,
        role=role,
        is_active=is_active,
    )

    def fake_authenticate():
        from flask import g
        g.current_user = mock_user
        return mock_user

    monkeypatch.setattr('app.middleware.firebase_auth._authenticate_request', fake_authenticate)
    return mock_user


def _mock_firebase_provisioning(monkeypatch):
    """Mock Firebase user creation and deletion."""
    created_uids = []
    deleted_uids = []

    def fake_create(email, password, display_name):
        uid = f"mock_firebase_{uuid.uuid4().hex[:10]}"
        created_uids.append({'uid': uid, 'email': email, 'display_name': display_name})
        return uid

    def fake_delete(uid):
        deleted_uids.append(uid)

    monkeypatch.setattr(AuthService, '_create_firebase_user', fake_create)
    monkeypatch.setattr(AuthService, '_delete_firebase_user', fake_delete)
    return created_uids, deleted_uids


# ==================== 1. SUCCESSFUL SUPERVISOR CREATION ====================

def test_create_supervisor_success(test_app, client, monkeypatch):
    """Org Admin can create a complete supervisor account with role SUPERVISOR."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    created_fb, _ = _mock_firebase_provisioning(monkeypatch)

    payload = {
        'full_name': 'Bob Electrical',
        'email': 'bob.supervisor@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP_ELEC_01',
        'department_id': 1,
        'phone': '9876543210',
    }

    res = client.post('/api/v1/complaints/supervisors', json=payload)
    assert res.status_code == 201
    body = res.get_json()
    assert body['success'] is True
    assert 'Supervisor created successfully' in body['message']

    data = body['data']
    assert 'user' in data
    assert 'supervisor' in data

    user_info = data['user']
    assert user_info['full_name'] == 'Bob Electrical'
    assert user_info['email'] == 'bob.supervisor@ksit.edu.in'
    assert user_info['role'] == 'SUPERVISOR'
    assert user_info['organization_id'] == 1
    assert user_info['department_id'] == 1
    assert user_info['usn_or_employee_id'] == 'EMP_ELEC_01'
    assert user_info['phone'] == '9876543210'
    assert user_info['is_active'] is True

    # Check MySQL DB
    with test_app.app_context():
        saved_user = User.query.filter_by(email='bob.supervisor@ksit.edu.in').first()
        assert saved_user is not None
        assert saved_user.role == 'SUPERVISOR'
        assert saved_user.organization_id == 1
        assert saved_user.department_id == 1
        assert saved_user.usn_or_employee_id == 'EMP_ELEC_01'
        assert saved_user.firebase_uid.startswith('mock_firebase_')

    # Also works via /api/v1/auth/supervisors
    res_auth = client.post('/api/v1/auth/supervisors', json={
        'full_name': 'Charlie Cleaning',
        'email': 'charlie@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP_HK_01',
        'department_id': 2,
    })
    assert res_auth.status_code == 201


# ==================== 2. SECURITY & AUTHORIZATION ====================

def test_create_supervisor_requires_admin_role(client, monkeypatch):
    """Students and existing Supervisors cannot create supervisor accounts."""
    _mock_firebase_provisioning(monkeypatch)

    # Student -> 403
    _mock_auth(monkeypatch, user_id=20, org_id=1, role='STUDENT')
    res = client.post('/api/v1/complaints/supervisors', json={
        'full_name': 'Test',
        'email': 'test@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP99',
        'department_id': 1,
    })
    assert res.status_code == 403

    # Supervisor -> 403
    _mock_auth(monkeypatch, user_id=30, org_id=1, role='SUPERVISOR')
    res = client.post('/api/v1/complaints/supervisors', json={
        'full_name': 'Test',
        'email': 'test@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP99',
        'department_id': 1,
    })
    assert res.status_code == 403


def test_create_supervisor_inactive_admin_rejected(client, monkeypatch):
    """Inactive admin cannot create supervisor accounts."""
    _mock_firebase_provisioning(monkeypatch)
    _mock_auth(monkeypatch, user_id=11, org_id=1, role='ORG_ADMIN', is_active=False)

    res = client.post('/api/v1/complaints/supervisors', json={
        'full_name': 'Test',
        'email': 'test@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP99',
        'department_id': 1,
    })
    assert res.status_code == 403


def test_create_supervisor_client_supplied_org_id_ignored(test_app, client, monkeypatch):
    """Client cannot supply or spoof organization_id; derived strictly from admin identity."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    _mock_firebase_provisioning(monkeypatch)

    payload = {
        'organization_id': 9999,  # Spoofed
        'full_name': 'Spoof Attempt',
        'email': 'spoof@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP_SPOOF',
        'department_id': 1,
    }

    res = client.post('/api/v1/complaints/supervisors', json=payload)
    assert res.status_code == 201

    with test_app.app_context():
        u = User.query.filter_by(email='spoof@ksit.edu.in').first()
        assert u.organization_id == 1  # Strictly 1, not 9999


def test_create_supervisor_rejects_cross_org_department(client, monkeypatch):
    """Reject departments belonging to another organization (Department 3 belongs to Org 2)."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    _mock_firebase_provisioning(monkeypatch)

    payload = {
        'full_name': 'Cross Org',
        'email': 'cross@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP_CROSS',
        'department_id': 3,  # Belongs to Org 2
    }

    res = client.post('/api/v1/complaints/supervisors', json=payload)
    assert res.status_code == 400
    assert 'Department not found in your organization' in res.get_json()['message']


def test_create_supervisor_prevents_role_escalation(client, monkeypatch):
    """Reject attempts to create accounts with roles other than SUPERVISOR."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    _mock_firebase_provisioning(monkeypatch)

    for bad_role in ['ORG_ADMIN', 'SUPER_ADMIN', 'STUDENT']:
        payload = {
            'role': bad_role,
            'full_name': 'Escalation Attempt',
            'email': f'escalate_{bad_role.lower()}@ksit.edu.in',
            'password': 'Password123!',
            'usn_or_employee_id': f'EMP_{bad_role}',
            'department_id': 1,
        }
        res = client.post('/api/v1/complaints/supervisors', json=payload)
        assert res.status_code == 400
        assert 'SUPERVISOR' in res.get_json()['message']


# ==================== 3. VALIDATION & DUPLICATES ====================

def test_create_supervisor_duplicate_email_rejected(client, monkeypatch):
    """Reject duplicate email address (409 Conflict)."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    _mock_firebase_provisioning(monkeypatch)

    payload = {
        'full_name': 'Duplicate Email',
        'email': 'existing.sup@ksit.edu.in',  # Seeded
        'password': 'Password123!',
        'usn_or_employee_id': 'NEW_EMP_01',
        'department_id': 1,
    }

    res = client.post('/api/v1/complaints/supervisors', json=payload)
    assert res.status_code == 409
    assert 'email already exists' in res.get_json()['message']


def test_create_supervisor_duplicate_employee_id_rejected(client, monkeypatch):
    """Reject duplicate employee ID in the organization (409 Conflict)."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    _mock_firebase_provisioning(monkeypatch)

    payload = {
        'full_name': 'Duplicate Emp',
        'email': 'new.sup@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'SUP001',  # Seeded
        'department_id': 1,
    }

    res = client.post('/api/v1/complaints/supervisors', json=payload)
    assert res.status_code == 409
    assert 'employee ID already exists' in res.get_json()['message']


def test_create_supervisor_email_domain_enforcement(client, monkeypatch):
    """If organization has email domain configured, supervisor email must match."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    _mock_firebase_provisioning(monkeypatch)

    payload = {
        'full_name': 'Wrong Domain',
        'email': 'supervisor@gmail.com',  # Does not match ksit.edu.in
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP_GMAIL',
        'department_id': 1,
    }

    res = client.post('/api/v1/complaints/supervisors', json=payload)
    assert res.status_code == 400
    assert 'ksit.edu.in' in res.get_json()['message']


def test_create_supervisor_field_validations(client, monkeypatch):
    """Validate required fields, string lengths, and password length."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    _mock_firebase_provisioning(monkeypatch)

    base = {
        'full_name': 'Valid Name',
        'email': 'valid@ksit.edu.in',
        'password': 'Password123',
        'usn_or_employee_id': 'EMP_VALID',
        'department_id': 1,
    }

    # Short password (< 6 chars)
    short_pw = dict(base, password='123')
    res = client.post('/api/v1/complaints/supervisors', json=short_pw)
    assert res.status_code == 400
    assert 'at least 6 characters' in res.get_json()['message']

    # Missing full_name
    no_name = dict(base, full_name='')
    res = client.post('/api/v1/complaints/supervisors', json=no_name)
    assert res.status_code == 400

    # Missing email
    no_email = dict(base, email='')
    res = client.post('/api/v1/complaints/supervisors', json=no_email)
    assert res.status_code == 400

    # Missing employee id
    no_emp = dict(base, usn_or_employee_id='')
    res = client.post('/api/v1/complaints/supervisors', json=no_emp)
    assert res.status_code == 400

    # Missing department id
    no_dept = dict(base, department_id=None)
    res = client.post('/api/v1/complaints/supervisors', json=no_dept)
    assert res.status_code == 400


# ==================== 4. FIREBASE CLEANUP ON MYSQL FAILURE ====================

def test_firebase_cleanup_on_mysql_failure(test_app, client, monkeypatch):
    """If MySQL transaction fails, Firebase user is immediately cleaned up/deleted."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    created_fb, deleted_fb = _mock_firebase_provisioning(monkeypatch)

    # Force db.session.commit to raise an exception
    def broken_commit():
        raise Exception('Database disk full')

    monkeypatch.setattr(db.session, 'commit', broken_commit)

    payload = {
        'full_name': 'Rollback Supervisor',
        'email': 'rollback@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP_ROLLBACK',
        'department_id': 1,
    }

    res = client.post('/api/v1/complaints/supervisors', json=payload)
    assert res.status_code == 500
    assert len(created_fb) == 1
    created_uid = created_fb[0]['uid']
    assert len(deleted_fb) == 1
    assert deleted_fb[0] == created_uid


# ==================== 5. LISTING & LOGIN COMPATIBILITY ====================

def test_supervisor_appears_in_management_list_and_can_login(test_app, client, monkeypatch):
    """After creation, supervisor appears in GET /supervisors and can log in via login_user."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    _mock_firebase_provisioning(monkeypatch)

    payload = {
        'full_name': 'David Plumber',
        'email': 'david.plumber@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP_PLUMB_01',
        'department_id': 1,
    }

    res = client.post('/api/v1/complaints/supervisors', json=payload)
    assert res.status_code == 201

    # Verify listing
    res_list = client.get('/api/v1/complaints/supervisors')
    assert res_list.status_code == 200
    supervisors = res_list.get_json()['data']
    supervisor_emails = [s['email'] for s in supervisors]
    assert 'david.plumber@ksit.edu.in' in supervisor_emails

    matching = next(s for s in supervisors if s['email'] == 'david.plumber@ksit.edu.in')
    assert matching['department_name'] == 'Electrical Maintenance'
    assert matching['usn_or_employee_id'] == 'EMP_PLUMB_01'

    # Test login via existing AuthService.login_user flow
    with test_app.app_context():
        created_user = User.query.filter_by(email='david.plumber@ksit.edu.in').first()
        monkeypatch.setattr(
            AuthService,
            'verify_firebase_token',
            lambda token: {'firebase_uid': created_user.firebase_uid, 'email': created_user.email},
        )
        login_res = AuthService.login_user('fake_supervisor_id_token')
        assert login_res['user']['role'] == 'SUPERVISOR'
        assert login_res['user']['email'] == 'david.plumber@ksit.edu.in'
