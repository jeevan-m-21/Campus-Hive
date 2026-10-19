"""
Unit and regression tests for Organization endpoints:
- Public organization and academic department discovery
- Authenticated organization detail retrieval and cross-org access boundaries
- Authenticated organization statistics, role restrictions, and metrics accuracy
"""

from datetime import datetime
from types import SimpleNamespace
import pytest

from app import create_app
from app.database import db
from app.models import (
    AcademicDepartment,
    Announcement,
    Complaint,
    Department,
    LostFound,
    Organization,
    User,
)
from app.services.auth_service import AuthService


@pytest.fixture
def org_test_app(monkeypatch):
    """Set up test Flask app with in-memory SQLite and sample organizational data."""
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    db.init_app(app)

    with app.app_context():
        for table in [Organization, AcademicDepartment, Department, User, Complaint, LostFound, Announcement]:
            for idx in list(table.__table__.indexes):
                idx.name = f"idx_{table.__tablename__}_{idx.name}"

        Organization.__table__.create(db.engine, checkfirst=True)
        AcademicDepartment.__table__.create(db.engine, checkfirst=True)
        Department.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)
        Complaint.__table__.create(db.engine, checkfirst=True)
        LostFound.__table__.create(db.engine, checkfirst=True)
        Announcement.__table__.create(db.engine, checkfirst=True)

        # Organization 1 (Active)
        org1 = Organization(
            organization_id=1,
            organization_name='Alpha University',
            organization_code='ALPHA',
            email_domain='alpha.edu',
            is_active=True,
        )
        # Organization 2 (Active)
        org2 = Organization(
            organization_id=2,
            organization_name='Beta Institute',
            organization_code='BETA',
            email_domain='beta.edu',
            is_active=True,
        )
        # Organization 3 (Inactive)
        org3 = Organization(
            organization_id=3,
            organization_name='Inactive College',
            organization_code='INACT',
            email_domain='inact.edu',
            is_active=False,
        )
        db.session.add_all([org1, org2, org3])

        # Academic departments for Org 1
        acad1 = AcademicDepartment(
            academic_department_id=101,
            organization_id=1,
            department_name='Computer Science',
            department_code='CSE',
            is_active=True,
        )
        acad2 = AcademicDepartment(
            academic_department_id=102,
            organization_id=1,
            department_name='Mechanical Engineering',
            department_code='MECH',
            is_active=False,
        )
        db.session.add_all([acad1, acad2])

        # Operational departments for Org 1
        dept1 = Department(
            department_id=1,
            organization_id=1,
            department_name='IT Support',
            priority_high_hours=24,
            priority_medium_hours=48,
            priority_low_hours=72,
        )
        dept2 = Department(
            department_id=2,
            organization_id=1,
            department_name='Maintenance',
            priority_high_hours=12,
            priority_medium_hours=36,
            priority_low_hours=72,
        )
        db.session.add_all([dept1, dept2])

        # Users for Org 1
        admin_org1 = User(
            user_id=10,
            organization_id=1,
            full_name='Alpha Admin',
            email='admin@alpha.edu',
            firebase_uid='uid-alpha-admin',
            role='ORG_ADMIN',
            is_active=True,
        )
        supervisor_org1 = User(
            user_id=11,
            organization_id=1,
            full_name='Alpha Supervisor',
            email='supervisor@alpha.edu',
            firebase_uid='uid-alpha-supervisor',
            role='SUPERVISOR',
            is_active=True,
        )
        student_org1 = User(
            user_id=12,
            organization_id=1,
            full_name='Alpha Student',
            email='student@alpha.edu',
            firebase_uid='uid-alpha-student',
            role='STUDENT',
            is_active=True,
        )

        # Users for Org 2
        admin_org2 = User(
            user_id=20,
            organization_id=2,
            full_name='Beta Admin',
            email='admin@beta.edu',
            firebase_uid='uid-beta-admin',
            role='ORG_ADMIN',
            is_active=True,
        )

        # Super Admin
        super_admin = User(
            user_id=99,
            organization_id=1,
            full_name='Super Administrator',
            email='super@system.edu',
            firebase_uid='uid-super-admin',
            role='SUPER_ADMIN',
            is_active=True,
        )
        db.session.add_all([admin_org1, supervisor_org1, student_org1, admin_org2, super_admin])

        # Complaints for Org 1
        c1 = Complaint(
            complaint_id=1,
            organization_id=1,
            student_id=12,
            department_id=1,
            title='Wifi broken',
            description='Wifi is down in lab',
            status='PENDING',
            final_priority='HIGH',
        )
        c2 = Complaint(
            complaint_id=2,
            organization_id=1,
            student_id=12,
            department_id=1,
            title='Slow net',
            description='Slow internet',
            status='IN_PROGRESS',
            final_priority='MEDIUM',
        )
        c3 = Complaint(
            complaint_id=3,
            organization_id=1,
            student_id=12,
            department_id=2,
            title='Leaky tap',
            description='Water leaking in washroom',
            status='RESOLVED',
            final_priority='HIGH',
        )
        db.session.add_all([c1, c2, c3])

        # Lost & Found for Org 1
        lf1 = LostFound(
            item_id=1,
            organization_id=1,
            posted_by=12,
            item_type='LOST',
            title='Blue backpack',
            description='Lost near canteen',
            status='OPEN',
        )
        lf2 = LostFound(
            item_id=2,
            organization_id=1,
            posted_by=12,
            item_type='FOUND',
            title='Water bottle',
            description='Found in library',
            status='CLOSED',
        )
        db.session.add_all([lf1, lf2])

        # Announcements for Org 1
        ann1 = Announcement(
            announcement_id=1,
            organization_id=1,
            created_by=10,
            title='Welcome event',
            description='Welcome to the new academic year',
        )
        db.session.add(ann1)

        db.session.commit()

    return app


@pytest.fixture
def client(org_test_app):
    return org_test_app.test_client()


def mock_auth(monkeypatch, user_id, role, org_id):
    """Mock authentication helper returning a verified user with role and org."""
    mock_user = SimpleNamespace(
        user_id=user_id,
        organization_id=org_id,
        role=role,
        is_active=True,
    )

    def fake_authenticate(force=False):
        from flask import g
        g.current_user = mock_user
        g.firebase_claims = {'firebase_uid': f'uid-{user_id}'}
        return mock_user

    monkeypatch.setattr('app.middleware.firebase_auth._authenticate_request', fake_authenticate)
    return mock_user


# ==================== 1. PUBLIC DISCOVERY ENDPOINTS ====================

def test_get_public_organizations_returns_only_active(client):
    """GET /api/v1/organizations/public returns only active orgs with safe fields."""
    res = client.get('/api/v1/organizations/public')
    assert res.status_code == 200
    data = res.get_json()['data']
    assert len(data) == 2
    org_ids = [o['organization_id'] for o in data]
    assert 1 in org_ids
    assert 2 in org_ids
    assert 3 not in org_ids  # Inactive org excluded


def test_get_public_academic_departments(client):
    """GET /api/v1/organizations/<id>/academic-departments returns only active departments."""
    res = client.get('/api/v1/organizations/1/academic-departments')
    assert res.status_code == 200
    data = res.get_json()['data']
    assert len(data) == 1
    assert data[0]['academic_department_id'] == 101
    assert data[0]['department_code'] == 'CSE'


def test_get_public_academic_departments_unknown_org_returns_404(client):
    """GET /api/v1/organizations/999/academic-departments returns HTTP 404."""
    res = client.get('/api/v1/organizations/999/academic-departments')
    assert res.status_code == 404
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'not_found'


# ==================== 2. AUTHENTICATED ORGANIZATION DETAILS ====================

def test_get_organization_unauthenticated_returns_401(client):
    """GET /api/v1/organizations without auth token returns 401."""
    res = client.get('/api/v1/organizations')
    assert res.status_code == 401
    assert res.get_json()['error'] == 'missing_token'


def test_get_organization_returns_current_user_org(client, monkeypatch):
    """GET /api/v1/organizations returns current user's organization details."""
    mock_auth(monkeypatch, user_id=12, role='STUDENT', org_id=1)

    res = client.get('/api/v1/organizations')
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['message'] == 'Organization retrieved'
    assert data['data']['organization_id'] == 1
    assert data['data']['organization_name'] == 'Alpha University'
    assert data['data']['departments_count'] == 2


def test_get_organization_by_id_same_org_succeeds(client, monkeypatch):
    """GET /api/v1/organizations/1 for user in Org 1 succeeds."""
    mock_auth(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/1')
    assert res.status_code == 200
    data = res.get_json()['data']
    assert data['organization_id'] == 1
    assert data['organization_code'] == 'ALPHA'


def test_get_organization_cross_org_access_forbidden(client, monkeypatch):
    """User in Org 1 attempting to access Org 2 details is rejected with HTTP 403."""
    mock_auth(monkeypatch, user_id=12, role='STUDENT', org_id=1)

    res = client.get('/api/v1/organizations/2')
    assert res.status_code == 403
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'forbidden'


def test_get_organization_query_param_cross_org_forbidden(client, monkeypatch):
    """User in Org 1 attempting to access Org 2 via query param ?organization_id=2 returns 403."""
    mock_auth(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations?organization_id=2')
    assert res.status_code == 403
    data = res.get_json()
    assert data['error'] == 'forbidden'


def test_get_organization_super_admin_can_access_any_org(client, monkeypatch):
    """SUPER_ADMIN can access details of any organization."""
    mock_auth(monkeypatch, user_id=99, role='SUPER_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/2')
    assert res.status_code == 200
    data = res.get_json()['data']
    assert data['organization_id'] == 2
    assert data['organization_code'] == 'BETA'


def test_get_organization_invalid_param_returns_400(client, monkeypatch):
    """Passing a non-integer organization_id query param returns HTTP 400 validation_error."""
    mock_auth(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations?organization_id=not-an-int')
    assert res.status_code == 400
    assert res.get_json()['error'] == 'validation_error'


def test_get_organization_not_found_returns_404(client, monkeypatch):
    """Requesting a non-existent organization by super admin returns HTTP 404."""
    mock_auth(monkeypatch, user_id=99, role='SUPER_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/999')
    assert res.status_code == 404
    assert res.get_json()['error'] == 'not_found'


# ==================== 3. AUTHENTICATED ORGANIZATION STATISTICS ====================

def test_get_org_stats_unauthenticated_returns_401(client):
    """GET /api/v1/organizations/1/stats without auth token returns 401."""
    res = client.get('/api/v1/organizations/1/stats')
    assert res.status_code == 401
    assert res.get_json()['error'] == 'missing_token'


def test_get_org_stats_student_forbidden(client, monkeypatch):
    """STUDENT role attempting to access stats returns HTTP 403 forbidden."""
    mock_auth(monkeypatch, user_id=12, role='STUDENT', org_id=1)

    res = client.get('/api/v1/organizations/1/stats')
    assert res.status_code == 403
    assert res.get_json()['error'] == 'forbidden'


def test_get_org_stats_supervisor_forbidden(client, monkeypatch):
    """SUPERVISOR role attempting to access stats returns HTTP 403 forbidden."""
    mock_auth(monkeypatch, user_id=11, role='SUPERVISOR', org_id=1)

    res = client.get('/api/v1/organizations/1/stats')
    assert res.status_code == 403
    assert res.get_json()['error'] == 'forbidden'


def test_get_org_stats_admin_success(client, monkeypatch):
    """
    ORG_ADMIN accessing stats for their organization returns accurate metrics:
    - Complaints breakdown (total, pending, in_progress, resolved, high priority)
    - Active high priority count (high priority and not resolved/closed)
    - User counts (students, supervisors, admins)
    - Departments count, lost & found count, announcements count
    """
    mock_auth(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/1/stats')
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert data['message'] == 'Stats retrieved'
    stats = data['data']

    assert stats['organization_id'] == 1
    assert stats['organization_name'] == 'Alpha University'

    # Top-level counts matching AdminDashboardStats
    assert stats['total'] == 3
    assert stats['pending'] == 1
    assert stats['assigned'] == 0
    assert stats['in_progress'] == 1
    assert stats['resolved'] == 1
    assert stats['reopened'] == 0
    assert stats['closed'] == 0
    assert stats['high_priority'] == 2
    assert stats['medium_priority'] == 1
    assert stats['low_priority'] == 0
    # Active high priority: c1 is HIGH and PENDING (active); c3 is HIGH but RESOLVED (not active)
    assert stats['active_high_priority'] == 1

    # Granular subsections
    assert stats['complaints']['total'] == 3
    assert stats['users']['total'] == 4  # admin10, sup11, stu12, super99 (all active and org 1)
    assert stats['users']['students'] == 1
    assert stats['users']['supervisors'] == 1
    assert stats['users']['admins'] == 1
    assert stats['departments_count'] == 2
    assert stats['lost_found']['total'] == 2
    assert stats['lost_found']['open'] == 1
    assert stats['lost_found']['closed'] == 1
    assert stats['announcements_count'] == 1


def test_get_org_stats_no_id_defaults_to_current_org(client, monkeypatch):
    """GET /api/v1/organizations/stats without path parameter defaults to current org stats."""
    mock_auth(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/stats')
    assert res.status_code == 200
    stats = res.get_json()['data']
    assert stats['organization_id'] == 1
    assert stats['total'] == 3


def test_get_org_stats_cross_org_forbidden(client, monkeypatch):
    """ORG_ADMIN from Org 1 attempting to access Org 2 stats is rejected with HTTP 403."""
    mock_auth(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/2/stats')
    assert res.status_code == 403
    data = res.get_json()
    assert data['success'] is False
    assert data['error'] == 'forbidden'


def test_get_org_stats_super_admin_can_access_any_org(client, monkeypatch):
    """SUPER_ADMIN can access statistics for any organization."""
    mock_auth(monkeypatch, user_id=99, role='SUPER_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/2/stats')
    assert res.status_code == 200
    stats = res.get_json()['data']
    assert stats['organization_id'] == 2
    assert stats['organization_name'] == 'Beta Institute'
    assert stats['total'] == 0  # No complaints in org 2


def test_get_org_stats_not_found(client, monkeypatch):
    """Requesting stats for non-existent org returns HTTP 404."""
    mock_auth(monkeypatch, user_id=99, role='SUPER_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/999/stats')
    assert res.status_code == 404
    assert res.get_json()['error'] == 'not_found'


def test_get_org_stats_invalid_param_returns_400(client, monkeypatch):
    """Passing a non-integer query param returns HTTP 400 validation_error."""
    mock_auth(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)

    res = client.get('/api/v1/organizations/stats?organization_id=invalid')
    assert res.status_code == 400
    assert res.get_json()['error'] == 'validation_error'
