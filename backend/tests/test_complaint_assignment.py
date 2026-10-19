"""
Tests for CampusHive automatic category-based supervisor assignment,
missing supervisor admin notification, manual admin assignment, and
department supervisor designation.
"""

from datetime import datetime
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
from app.services.assignment_service import AssignmentService


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

        # Seed Organization 1 and Departments
        org1 = Organization(
            organization_id=1,
            organization_name='KSIT',
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

        dept_housekeeping = Department(
            department_id=1,
            organization_id=1,
            department_name='Housekeeping',
            priority_high_hours=24,
            priority_medium_hours=72,
            priority_low_hours=168,
        )
        dept_electrical = Department(
            department_id=2,
            organization_id=1,
            department_name='Electrical',
            priority_high_hours=24,
            priority_medium_hours=72,
            priority_low_hours=168,
        )
        dept_network = Department(
            department_id=4,
            organization_id=1,
            department_name='Network Connectivity',
            priority_high_hours=24,
            priority_medium_hours=72,
            priority_low_hours=168,
        )
        dept_org2 = Department(
            department_id=10,
            organization_id=2,
            department_name='Housekeeping',
            priority_high_hours=24,
            priority_medium_hours=72,
            priority_low_hours=168,
        )
        db.session.add_all([dept_housekeeping, dept_electrical, dept_network, dept_org2])
        db.session.flush()

        # Seed Users
        # Admin Org 1
        admin1 = User(
            user_id=10,
            organization_id=1,
            full_name='KSIT Admin',
            email='admin@ksit.edu.in',
            firebase_uid='uid_admin_1',
            role='ORG_ADMIN',
            is_active=True,
        )
        # Student Org 1
        student1 = User(
            user_id=20,
            organization_id=1,
            full_name='Student Alice',
            email='alice@ksit.edu.in',
            firebase_uid='uid_student_1',
            role='STUDENT',
            is_active=True,
        )
        # Housekeeping Supervisor Org 1
        supervisor_hk = User(
            user_id=30,
            organization_id=1,
            department_id=1,
            full_name='Housekeeping Supervisor',
            email='hk_sup@ksit.edu.in',
            firebase_uid='uid_sup_hk',
            role='SUPERVISOR',
            is_active=True,
        )
        # Inactive Electrical Supervisor Org 1
        supervisor_elec_inactive = User(
            user_id=31,
            organization_id=1,
            department_id=2,
            full_name='Inactive Electrical Supervisor',
            email='elec_sup_inactive@ksit.edu.in',
            firebase_uid='uid_sup_elec_inact',
            role='SUPERVISOR',
            is_active=False,
        )
        # Supervisor Org 2
        supervisor_org2 = User(
            user_id=40,
            organization_id=2,
            department_id=10,
            full_name='Org2 Supervisor',
            email='sup@other.edu',
            firebase_uid='uid_sup_org2',
            role='SUPERVISOR',
            is_active=True,
        )
        db.session.add_all([admin1, student1, supervisor_hk, supervisor_elec_inactive, supervisor_org2])
        db.session.commit()

        yield app
        db.session.remove()


@pytest.fixture
def client(test_app):
    return test_app.test_client()


def _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN'):
    """Mock authentication so requests have an authenticated user."""
    mock_user = SimpleNamespace(
        user_id=user_id,
        organization_id=org_id,
        role=role,
        is_active=True,
    )

    def fake_authenticate():
        from flask import g
        g.current_user = mock_user
        return mock_user

    monkeypatch.setattr('app.middleware.firebase_auth._authenticate_request', fake_authenticate)
    return mock_user


# ==================== 1. CATEGORY TO DEPARTMENT MAPPING ====================

def test_category_to_department_mapping_direct(test_app):
    """Verify AssignmentService correctly resolves departments from dataset and validator categories."""
    with test_app.app_context():
        # WiFi / Internet Problem -> Network Connectivity
        dept = AssignmentService.resolve_department(1, category='WiFi / Internet Problem')
        assert dept is not None
        assert dept.department_name == 'Network Connectivity'

        # internet -> Network Connectivity
        dept = AssignmentService.resolve_department(1, category='internet')
        assert dept is not None
        assert dept.department_name == 'Network Connectivity'

        # Cleanliness Issue -> Housekeeping
        dept = AssignmentService.resolve_department(1, category='Cleanliness Issue')
        assert dept is not None
        assert dept.department_name == 'Housekeeping'

        # Water Leakage -> Housekeeping
        dept = AssignmentService.resolve_department(1, category='water leakage')
        assert dept is not None
        assert dept.department_name == 'Housekeeping'

        # Electrical Issue -> Electrical
        dept = AssignmentService.resolve_department(1, category='Electrical Issue')
        assert dept is not None
        assert dept.department_name == 'Electrical'

        # Direct department name match
        dept = AssignmentService.resolve_department(1, category='Housekeeping')
        assert dept is not None
        assert dept.department_id == 1

        # Direct department_id
        dept = AssignmentService.resolve_department(1, department_id=1)
        assert dept is not None
        assert dept.department_name == 'Housekeeping'


# ==================== 2. AUTOMATIC ASSIGNMENT WHEN ACTIVE SUPERVISOR EXISTS ====================

def test_automatic_assignment_when_supervisor_exists(test_app, client, monkeypatch):
    """
    Submitting a complaint with a category whose department has an active supervisor:
    - Auto-assigns to that supervisor.
    - Status transitions from PENDING to ASSIGNED.
    - Records ComplaintStatusHistory.
    - Supervisor and student are notified.
    """
    _mock_auth(monkeypatch, user_id=20, org_id=1, role='STUDENT')

    response = client.post(
        '/api/v1/complaints',
        json={
            'category': 'Water Leakage',
            'title': 'Severe water pipe leak in Block C',
            'description': 'Water is leaking heavily from the ceiling pipe in corridor.',
            'location': 'Block C, 2nd floor',
        },
    )
    assert response.status_code == 201
    data = response.get_json()['data']
    complaint_id = data['complaint_id']

    assert data['status'] == 'ASSIGNED'
    assert data['supervisor_id'] == 30
    assert data['supervisor_name'] == 'Housekeeping Supervisor'
    assert data['department_id'] == 1
    assert data['department_name'] == 'Housekeeping'

    with test_app.app_context():
        # Check status history
        history = ComplaintStatusHistory.query.filter_by(complaint_id=complaint_id).first()
        assert history is not None
        assert history.old_status == 'PENDING'
        assert history.new_status == 'ASSIGNED'

        # Check notifications: student and supervisor notified
        sup_notif = Notification.query.filter_by(user_id=30, reference_id=complaint_id).first()
        assert sup_notif is not None
        assert 'assigned' in sup_notif.message.lower()

        student_notif = Notification.query.filter_by(user_id=20, reference_id=complaint_id).first()
        assert student_notif is not None


# ==================== 3. MISSING OR INACTIVE SUPERVISOR FALLBACK ====================

def test_no_supervisor_available_notifies_admin_and_leaves_unassigned(test_app, client, monkeypatch):
    """
    When the department has no active supervisor (e.g. Electrical has only an inactive supervisor):
    - Complaint is saved successfully.
    - supervisor_id remains NULL.
    - Status remains PENDING.
    - Org admin is notified of unassigned complaint.
    - Complaint is NOT assigned to unrelated supervisor (e.g. Housekeeping supervisor).
    """
    _mock_auth(monkeypatch, user_id=20, org_id=1, role='STUDENT')

    response = client.post(
        '/api/v1/complaints',
        json={
            'category': 'Electrical Issue',
            'title': 'Sparks from electrical socket',
            'description': 'Sparks and smoke noticed coming from switchboard.',
            'location': 'Physics Lab',
        },
    )
    assert response.status_code == 201
    data = response.get_json()['data']
    complaint_id = data['complaint_id']

    assert data['supervisor_id'] is None
    assert data['status'] == 'PENDING'
    assert data['department_name'] == 'Electrical'

    with test_app.app_context():
        # Org Admin 10 should receive an unassigned complaint notification
        admin_notif = Notification.query.filter_by(user_id=10, reference_id=complaint_id).first()
        assert admin_notif is not None
        assert admin_notif.title == 'Unassigned Complaint'
        assert 'Electrical' in admin_notif.message
        assert 'no supervisor assigned' in admin_notif.message.lower()

        # Housekeeping supervisor (30) must NOT have received notification
        hk_notif = Notification.query.filter_by(user_id=30, reference_id=complaint_id).first()
        assert hk_notif is None


# ==================== 4. ORGANIZATION ISOLATION ====================

def test_organization_isolation_in_supervisor_discovery(test_app, client, monkeypatch):
    """Supervisors from Organization 2 must never be returned to Organization 1 admins."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')

    response = client.get('/api/v1/complaints/supervisors')
    assert response.status_code == 200
    supervisors = response.get_json()['data']

    supervisor_ids = [s['user_id'] for s in supervisors]
    assert 30 in supervisor_ids  # Org 1 Housekeeping Supervisor
    assert 40 not in supervisor_ids  # Org 2 Supervisor must be isolated


def test_supervisor_cannot_be_assigned_across_organizations(test_app, client, monkeypatch):
    """Attempting to assign an Organization 2 supervisor to an Organization 1 complaint is rejected."""
    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')

    # Create unassigned complaint in Org 1
    with test_app.app_context():
        comp = Complaint(
            organization_id=1,
            student_id=20,
            department_id=1,
            title='Test isolation',
            description='Test isolation description',
            status='PENDING',
        )
        db.session.add(comp)
        db.session.commit()
        complaint_id = comp.complaint_id

    # Admin of Org 1 attempts to assign User 40 (Org 2)
    response = client.patch(
        f'/api/v1/complaints/{complaint_id}',
        json={'supervisor_id': 40},
    )
    assert response.status_code == 404


# ==================== 5. AUTHORIZATION CONTROLS ====================

def test_student_and_supervisor_cannot_assign_supervisors(test_app, client, monkeypatch):
    """Students and Supervisors calling PATCH with supervisor_id receive 403 Forbidden."""
    with test_app.app_context():
        comp = Complaint(
            organization_id=1,
            student_id=20,
            department_id=1,
            title='Test auth complaint',
            description='Test auth complaint description',
            status='PENDING',
        )
        db.session.add(comp)
        db.session.commit()
        complaint_id = comp.complaint_id

    # Student attempt
    _mock_auth(monkeypatch, user_id=20, org_id=1, role='STUDENT')
    resp_student = client.patch(
        f'/api/v1/complaints/{complaint_id}',
        json={'supervisor_id': 30},
    )
    assert resp_student.status_code == 403

    # Supervisor attempt
    _mock_auth(monkeypatch, user_id=30, org_id=1, role='SUPERVISOR')
    resp_sup = client.patch(
        f'/api/v1/complaints/{complaint_id}',
        json={'supervisor_id': 30},
    )
    assert resp_sup.status_code == 403


# ==================== 6. MANUAL ADMIN ASSIGNMENT FALLBACK ====================

def test_manual_admin_assignment_fallback(test_app, client, monkeypatch):
    """
    An organization admin can manually assign an eligible supervisor to an unassigned complaint:
    - Status transitions to ASSIGNED.
    - Status history is recorded.
    - Both student and supervisor are notified.
    """
    with test_app.app_context():
        comp = Complaint(
            organization_id=1,
            student_id=20,
            department_id=1,
            title='Unassigned Housekeeping Issue',
            description='Trash overflowing near entrance.',
            status='PENDING',
        )
        db.session.add(comp)
        db.session.commit()
        complaint_id = comp.complaint_id

    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')
    response = client.patch(
        f'/api/v1/complaints/{complaint_id}',
        json={'supervisor_id': 30},
    )
    assert response.status_code == 200
    data = response.get_json()['data']
    assert data['supervisor_id'] == 30
    assert data['status'] == 'ASSIGNED'
    assert data['supervisor_name'] == 'Housekeeping Supervisor'

    with test_app.app_context():
        history = ComplaintStatusHistory.query.filter_by(complaint_id=complaint_id).first()
        assert history is not None
        assert history.old_status == 'PENDING'
        assert history.new_status == 'ASSIGNED'
        assert history.updated_by == 10

        sup_notif = Notification.query.filter_by(user_id=30, reference_id=complaint_id).first()
        assert sup_notif is not None


# ==================== 7. DESIGNATING A DEPARTMENT SUPERVISOR AUTO-ASSIGNS PENDING COMPLAINTS ====================

def test_designating_department_supervisor_auto_assigns_unassigned_complaints(test_app, client, monkeypatch):
    """
    When an admin designates an active supervisor for a department that previously had unassigned complaints:
    - The pending complaints in that department are automatically assigned to that supervisor.
    - Status transitions from PENDING to ASSIGNED.
    - Status history is recorded for each complaint.
    - Supervisor receives a single deduplicated summary notification.
    """
    with test_app.app_context():
        # Create a new active supervisor with no department yet
        new_sup = User(
            user_id=35,
            organization_id=1,
            department_id=None,
            full_name='Network Engineer Supervisor',
            email='network_sup@ksit.edu.in',
            firebase_uid='uid_sup_net',
            role='SUPERVISOR',
            is_active=True,
        )
        # Create two unassigned complaints in Network Connectivity (department 4)
        c1 = Complaint(
            organization_id=1,
            student_id=20,
            department_id=4,
            title='Wifi down in Lab 1',
            description='Students cannot access internet.',
            status='PENDING',
        )
        c2 = Complaint(
            organization_id=1,
            student_id=20,
            department_id=4,
            title='Wifi slow in Library',
            description='Internet speed below 1 Mbps.',
            status='PENDING',
        )
        # Create one complaint in Electrical (should NOT be auto-assigned to Network supervisor)
        c3 = Complaint(
            organization_id=1,
            student_id=20,
            department_id=2,
            title='AC not working',
            description='AC in seminar hall is dead.',
            status='PENDING',
        )
        db.session.add_all([new_sup, c1, c2, c3])
        db.session.commit()
        c1_id, c2_id, c3_id = c1.complaint_id, c2.complaint_id, c3.complaint_id

    _mock_auth(monkeypatch, user_id=10, org_id=1, role='ORG_ADMIN')

    # Admin designates User 35 as supervisor for Department 4 (Network Connectivity)
    response = client.post(
        '/api/v1/complaints/departments/4/supervisor',
        json={'supervisor_id': 35},
    )
    assert response.status_code == 200
    res_data = response.get_json()['data']
    assert res_data['assigned_complaints_count'] == 2
    assert set(res_data['assigned_complaint_ids']) == {c1_id, c2_id}

    with test_app.app_context():
        comp1 = db.session.get(Complaint, c1_id)
        comp2 = db.session.get(Complaint, c2_id)
        comp3 = db.session.get(Complaint, c3_id)

        assert comp1.supervisor_id == 35
        assert comp1.status == 'ASSIGNED'

        assert comp2.supervisor_id == 35
        assert comp2.status == 'ASSIGNED'

        # Unrelated Electrical complaint remains unassigned
        assert comp3.supervisor_id is None
        assert comp3.status == 'PENDING'

        # Supervisor receives a single summary notification
        sup_notifications = Notification.query.filter_by(user_id=35).all()
        assert len(sup_notifications) == 1
        assert '2 pending complaint(s)' in sup_notifications[0].message


# ==================== 8. SUPERVISOR COMPLAINT QUEUE VISIBILITY ====================

def test_supervisor_sees_assigned_complaints_in_their_queue(test_app, client, monkeypatch):
    """Supervisors querying GET /api/v1/complaints only see complaints assigned to them."""
    with test_app.app_context():
        # Complaint 1 assigned to Housekeeping Supervisor (30)
        c1 = Complaint(
            organization_id=1,
            student_id=20,
            department_id=1,
            supervisor_id=30,
            title='Assigned to HK',
            description='Clean cafeteria table.',
            status='ASSIGNED',
        )
        # Complaint 2 unassigned
        c2 = Complaint(
            organization_id=1,
            student_id=20,
            department_id=1,
            supervisor_id=None,
            title='Unassigned HK',
            description='Spill in hallway.',
            status='PENDING',
        )
        db.session.add_all([c1, c2])
        db.session.commit()
        c1_id = c1.complaint_id
        c2_id = c2.complaint_id

    # Housekeeping supervisor (30) queries complaints
    _mock_auth(monkeypatch, user_id=30, org_id=1, role='SUPERVISOR')
    response = client.get('/api/v1/complaints')
    assert response.status_code == 200
    items = response.get_json()['data']['data']
    item_ids = [item['complaint_id'] for item in items]

    assert c1_id in item_ids
    assert c2_id not in item_ids
