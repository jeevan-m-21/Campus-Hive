"""
Comprehensive tests for CampusHive complaint status history, notifications,
supervisor authorization, and student feedback/reopening workflows.
"""

from datetime import datetime
from types import SimpleNamespace
import pytest

from app import create_app
from app.database import db
from app.models import (
    Complaint,
    ComplaintChat,
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
        for table in [Complaint, ComplaintChat, ComplaintImage, ComplaintSupport, ComplaintStatusHistory, Notification]:
            for idx in list(table.__table__.indexes):
                idx.name = f"idx_{table.__tablename__}_{idx.name}"

        Organization.__table__.create(db.engine, checkfirst=True)
        Department.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)
        Complaint.__table__.create(db.engine, checkfirst=True)
        ComplaintChat.__table__.create(db.engine, checkfirst=True)
        ComplaintImage.__table__.create(db.engine, checkfirst=True)
        ComplaintSupport.__table__.create(db.engine, checkfirst=True)
        ComplaintStatusHistory.__table__.create(db.engine, checkfirst=True)
        Notification.__table__.create(db.engine, checkfirst=True)

        # Seed Organizations
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

        # Seed Departments
        dept_hk = Department(
            department_id=1,
            organization_id=1,
            department_name='Housekeeping',
            priority_high_hours=24,
            priority_medium_hours=72,
            priority_low_hours=168,
        )
        dept_elec = Department(
            department_id=2,
            organization_id=1,
            department_name='Electrical',
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
        db.session.add_all([dept_hk, dept_elec, dept_org2])
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
        # Students Org 1
        student1 = User(
            user_id=20,
            organization_id=1,
            full_name='Alice Student',
            email='alice@ksit.edu.in',
            firebase_uid='uid_student_alice',
            role='STUDENT',
            is_active=True,
        )
        student2 = User(
            user_id=21,
            organization_id=1,
            full_name='Bob Student',
            email='bob@ksit.edu.in',
            firebase_uid='uid_student_bob',
            role='STUDENT',
            is_active=True,
        )
        # Supervisors Org 1
        sup_hk1 = User(
            user_id=30,
            organization_id=1,
            department_id=1,
            full_name='Harry Housekeeper',
            email='harry@ksit.edu.in',
            firebase_uid='uid_sup_hk1',
            role='SUPERVISOR',
            is_active=True,
        )
        sup_hk2 = User(
            user_id=31,
            organization_id=1,
            department_id=1,
            full_name='Helen Housekeeper',
            email='helen@ksit.edu.in',
            firebase_uid='uid_sup_hk2',
            role='SUPERVISOR',
            is_active=True,
        )
        sup_elec = User(
            user_id=32,
            organization_id=1,
            department_id=2,
            full_name='Eli Electrician',
            email='eli@ksit.edu.in',
            firebase_uid='uid_sup_elec',
            role='SUPERVISOR',
            is_active=True,
        )
        # Org 2 Users
        admin2 = User(
            user_id=50,
            organization_id=2,
            full_name='Other Admin',
            email='admin@other.edu',
            firebase_uid='uid_admin_2',
            role='ORG_ADMIN',
            is_active=True,
        )
        student_org2 = User(
            user_id=51,
            organization_id=2,
            full_name='Other Student',
            email='student@other.edu',
            firebase_uid='uid_student_org2',
            role='STUDENT',
            is_active=True,
        )

        db.session.add_all([
            admin1, student1, student2, sup_hk1, sup_hk2, sup_elec, admin2, student_org2
        ])
        db.session.commit()

    return app


@pytest.fixture
def client(test_app):
    return test_app.test_client()


def mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1):
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


# ==================== 1. STATUS HISTORY SERIALIZATION & RETRIEVAL ====================

def test_complaint_status_history_to_dict(test_app):
    """Verify ComplaintStatusHistory.to_dict includes all required fields."""
    with test_app.app_context():
        c = Complaint(
            organization_id=1,
            student_id=20,
            department_id=1,
            title='Leaky tap',
            description='Water leaking in lab',
            status='PENDING',
        )
        db.session.add(c)
        db.session.flush()

        history = ComplaintStatusHistory(
            complaint_id=c.complaint_id,
            updated_by=10,
            old_status='PENDING',
            new_status='ASSIGNED',
            remarks='Assigned by admin',
            updated_at=datetime.utcnow(),
        )
        db.session.add(history)
        db.session.flush()

        data = history.to_dict()
        assert data['history_id'] == history.history_id
        assert data['complaint_id'] == c.complaint_id
        assert data['old_status'] == 'PENDING'
        assert data['new_status'] == 'ASSIGNED'
        assert data['remarks'] == 'Assigned by admin'
        assert data['updated_by'] == 10
        assert data['updater_name'] == 'KSIT Admin'
        assert data['updated_at'] is not None


def test_get_complaint_history_authorized(test_app, client, monkeypatch):
    """Verify authorized student, supervisor, and org admin can retrieve complaint history."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=101,
            organization_id=1,
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='Broken Door',
            description='Room 101 door latch is broken',
            status='ASSIGNED',
        )
        db.session.add(c)
        db.session.flush()

        h1 = ComplaintStatusHistory(
            complaint_id=101,
            updated_by=20,
            old_status=None,
            new_status='PENDING',
            remarks='Created',
        )
        h2 = ComplaintStatusHistory(
            complaint_id=101,
            updated_by=10,
            old_status='PENDING',
            new_status='ASSIGNED',
            remarks='Assigned to Harry',
        )
        db.session.add_all([h1, h2])
        db.session.commit()

    # Student Alice (owner) retrieves history
    mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1)
    res = client.get('/api/v1/complaints/101/history')
    assert res.status_code == 200
    assert len(res.json['data']) == 2
    assert res.json['data'][0]['new_status'] == 'PENDING'
    assert res.json['data'][1]['new_status'] == 'ASSIGNED'

    # Assigned Supervisor Harry retrieves history
    mock_login(monkeypatch, user_id=30, role='SUPERVISOR', org_id=1)
    res = client.get('/api/v1/complaints/101/history')
    assert res.status_code == 200
    assert len(res.json['data']) == 2

    # Org Admin retrieves history
    mock_login(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)
    res = client.get('/api/v1/complaints/101/history')
    assert res.status_code == 200
    assert len(res.json['data']) == 2


def test_get_complaint_history_creator_can_view_own_complaint(test_app, client, monkeypatch):
    """Creator can view the status history of their own complaint."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=102,
            organization_id=1,
            student_id=20,  # Alice
            supervisor_id=30,
            department_id=1,
            title='Alice Broken Chair',
            description='Chair leg broken',
            status='ASSIGNED',
        )
        h = ComplaintStatusHistory(
            complaint_id=102,
            updated_by=20,
            old_status=None,
            new_status='PENDING',
            remarks='Logged by Alice',
        )
        db.session.add_all([c, h])
        db.session.commit()

    mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1)
    res = client.get('/api/v1/complaints/102/history')
    assert res.status_code == 200
    assert len(res.json['data']) == 1
    assert res.json['data'][0]['new_status'] == 'PENDING'


def test_get_complaint_history_student_forbidden_for_other_student(test_app, client, monkeypatch):
    """Student A cannot view Student B's complaint history."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=103,
            organization_id=1,
            student_id=20,  # Alice
            supervisor_id=30,
            department_id=1,
            title='Alice Private Complaint',
            description='Personal room radiator issue',
            status='ASSIGNED',
        )
        h = ComplaintStatusHistory(
            complaint_id=103,
            updated_by=10,
            old_status='PENDING',
            new_status='ASSIGNED',
            remarks='Confidential note regarding room inspection',
        )
        db.session.add_all([c, h])
        db.session.commit()

    # Bob (student 21) attempts to view Alice's (student 20) complaint history
    mock_login(monkeypatch, user_id=21, role='STUDENT', org_id=1)
    res = client.get('/api/v1/complaints/103/history')
    assert res.status_code == 403
    assert 'own complaints' in res.json['message']
    assert 'data' not in res.json or res.json['data'] is None


def test_get_complaint_history_assigned_supervisor_can_view(test_app, client, monkeypatch):
    """Assigned supervisor can view the history of complaints assigned to them."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=104,
            organization_id=1,
            student_id=20,
            supervisor_id=30,  # Harry Housekeeper
            department_id=1,
            title='Corridor Spill',
            description='Water spill on 2nd floor',
            status='ASSIGNED',
        )
        h = ComplaintStatusHistory(
            complaint_id=104,
            updated_by=30,
            old_status='PENDING',
            new_status='ASSIGNED',
            remarks='Harry accepted task',
        )
        db.session.add_all([c, h])
        db.session.commit()

    mock_login(monkeypatch, user_id=30, role='SUPERVISOR', org_id=1)
    res = client.get('/api/v1/complaints/104/history')
    assert res.status_code == 200
    assert len(res.json['data']) == 1
    assert res.json['data'][0]['remarks'] == 'Harry accepted task'


def test_get_complaint_history_supervisor_cannot_view_other_supervisor_complaint(test_app, client, monkeypatch):
    """Supervisor A cannot view a complaint history assigned to Supervisor B."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=105,
            organization_id=1,
            student_id=20,
            supervisor_id=30,  # Harry
            department_id=1,
            title='Broken Light',
            description='Light flicker in hall',
            status='ASSIGNED',
        )
        h = ComplaintStatusHistory(
            complaint_id=105,
            updated_by=30,
            old_status='PENDING',
            new_status='ASSIGNED',
            remarks='Assigned to Harry',
        )
        db.session.add_all([c, h])
        db.session.commit()

    # Eli Electrician (supervisor 32) attempts to access Harry's complaint
    mock_login(monkeypatch, user_id=32, role='SUPERVISOR', org_id=1)
    res = client.get('/api/v1/complaints/105/history')
    assert res.status_code == 403
    assert 'assigned to you' in res.json['message']
    assert 'data' not in res.json or res.json['data'] is None


def test_get_complaint_history_supervisor_cannot_view_unassigned_complaint(test_app, client, monkeypatch):
    """Supervisor cannot view history of an unassigned complaint outside their assignment."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=106,
            organization_id=1,
            student_id=20,
            supervisor_id=None,  # Unassigned
            department_id=1,
            title='Unassigned Waste Bins',
            description='Bins need emptying',
            status='PENDING',
        )
        h = ComplaintStatusHistory(
            complaint_id=106,
            updated_by=20,
            old_status=None,
            new_status='PENDING',
            remarks='Awaiting supervisor allocation',
        )
        db.session.add_all([c, h])
        db.session.commit()

    # Harry (supervisor 30) attempts to access history of unassigned complaint
    mock_login(monkeypatch, user_id=30, role='SUPERVISOR', org_id=1)
    res = client.get('/api/v1/complaints/106/history')
    assert res.status_code == 403
    assert 'assigned to you' in res.json['message']
    assert 'data' not in res.json or res.json['data'] is None


def test_get_complaint_history_admin_within_organization(test_app, client, monkeypatch):
    """Admin can view permitted complaints within their authorized organization."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=107,
            organization_id=1,
            student_id=20,
            supervisor_id=None,
            department_id=1,
            title='Admin Oversight Complaint',
            description='Admin review required',
            status='PENDING',
        )
        h = ComplaintStatusHistory(
            complaint_id=107,
            updated_by=20,
            old_status=None,
            new_status='PENDING',
            remarks='Initial submission',
        )
        db.session.add_all([c, h])
        db.session.commit()

    # KSIT Admin (admin 10, org 1) views complaint 107 in org 1
    mock_login(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)
    res = client.get('/api/v1/complaints/107/history')
    assert res.status_code == 200
    assert len(res.json['data']) == 1
    assert res.json['data'][0]['new_status'] == 'PENDING'


def test_get_complaint_history_cross_organization_returns_404(test_app, client, monkeypatch):
    """Users cannot access complaints belonging to another organization (returns 404)."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=108,
            organization_id=1,  # Org 1
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='Window cracked',
            description='Crack in window glass',
            status='ASSIGNED',
        )
        h = ComplaintStatusHistory(
            complaint_id=108,
            updated_by=10,
            old_status='PENDING',
            new_status='ASSIGNED',
            remarks='Window tech assigned',
        )
        db.session.add_all([c, h])
        db.session.commit()

    # Org 2 Admin attempts to access Org 1 complaint history
    mock_login(monkeypatch, user_id=50, role='ORG_ADMIN', org_id=2)
    res = client.get('/api/v1/complaints/108/history')
    assert res.status_code == 404
    assert res.json['error'] == 'not_found'

    # Org 2 Student attempts to access Org 1 complaint history
    mock_login(monkeypatch, user_id=51, role='STUDENT', org_id=2)
    res = client.get('/api/v1/complaints/108/history')
    assert res.status_code == 404
    assert res.json['error'] == 'not_found'


def test_get_complaint_history_unauthenticated_rejected(test_app, client):
    """Unauthenticated requests are rejected with 401."""
    res = client.get('/api/v1/complaints/101/history')
    assert res.status_code == 401
    assert res.json['success'] is False


def test_get_complaint_history_unauthorized_does_not_leak_details(test_app, client, monkeypatch):
    """Unauthorized requests do not expose history entries, remarks, or updater details."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=109,
            organization_id=1,
            student_id=20,  # Alice
            supervisor_id=30,  # Harry
            department_id=1,
            title='Confidential Lab Safety Issue',
            description='Hazardous chemical spill investigation',
            status='ASSIGNED',
        )
        h = ComplaintStatusHistory(
            complaint_id=109,
            updated_by=10,  # KSIT Admin
            old_status='PENDING',
            new_status='ASSIGNED',
            remarks='DISCIPLINARY_INVESTIGATION_IN_PROGRESS: Dean summoned student for chemical spill.',
        )
        db.session.add_all([c, h])
        db.session.commit()

    # 1. Other student in same org (Bob)
    mock_login(monkeypatch, user_id=21, role='STUDENT', org_id=1)
    res_student = client.get('/api/v1/complaints/109/history')
    assert res_student.status_code == 403
    body_student = res_student.get_data(as_text=True)
    assert 'DISCIPLINARY_INVESTIGATION_IN_PROGRESS' not in body_student
    assert 'KSIT Admin' not in body_student
    assert 'updater_name' not in body_student
    assert 'old_status' not in body_student
    assert 'data' not in res_student.json or res_student.json['data'] is None

    # 2. Other supervisor in same org (Eli)
    mock_login(monkeypatch, user_id=32, role='SUPERVISOR', org_id=1)
    res_sup = client.get('/api/v1/complaints/109/history')
    assert res_sup.status_code == 403
    body_sup = res_sup.get_data(as_text=True)
    assert 'DISCIPLINARY_INVESTIGATION_IN_PROGRESS' not in body_sup
    assert 'KSIT Admin' not in body_sup
    assert 'updater_name' not in body_sup

    # 3. Cross-org user
    mock_login(monkeypatch, user_id=51, role='STUDENT', org_id=2)
    res_cross = client.get('/api/v1/complaints/109/history')
    assert res_cross.status_code == 404
    body_cross = res_cross.get_data(as_text=True)
    assert 'DISCIPLINARY_INVESTIGATION_IN_PROGRESS' not in body_cross
    assert 'KSIT Admin' not in body_cross


# ==================== 2. INITIAL HISTORY & COMPOUND UPDATES ====================

def test_initial_history_recorded_for_unassigned_complaint(test_app, client, monkeypatch):
    """When a complaint has no eligible supervisor, initial PENDING history must be recorded."""
    mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1)

    # Department 2 (Electrical) currently has supervisor 32. Let's make supervisor 32 inactive
    with test_app.app_context():
        s = User.query.filter_by(user_id=32).first()
        s.is_active = False
        db.session.commit()

    payload = {
        'department_id': 2,
        'title': 'Power Outlet Sparking',
        'description': 'Outlet sparks when plug is inserted',
        'location': 'Lab 3',
    }
    res = client.post('/api/v1/complaints', json=payload)
    assert res.status_code == 201
    complaint_id = res.json['data']['complaint_id']

    with test_app.app_context():
        history = ComplaintStatusHistory.query.filter_by(complaint_id=complaint_id).all()
        assert len(history) == 1
        assert history[0].old_status is None
        assert history[0].new_status == 'PENDING'
        assert history[0].updated_by == 20
        assert 'Awaiting supervisor assignment' in history[0].remarks

        # Also check org admin got unassigned complaint notification
        notifs = Notification.query.filter_by(user_id=10, reference_id=complaint_id).all()
        assert any(n.title == 'Unassigned Complaint' for n in notifs)


def test_supervisor_update_authorization(test_app, client, monkeypatch):
    """Verify a supervisor cannot update a complaint unless assigned to it."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=105,
            organization_id=1,
            student_id=20,
            supervisor_id=30,  # Harry
            department_id=1,
            title='Water Leak',
            description='Water leak',
            status='ASSIGNED',
        )
        db.session.add(c)
        db.session.commit()

    # Eli (user 32) tries to update Harry's complaint
    mock_login(monkeypatch, user_id=32, role='SUPERVISOR', org_id=1)
    res = client.patch('/api/v1/complaints/105', json={'status': 'IN_PROGRESS'})
    assert res.status_code == 403
    assert 'assigned to you' in res.json['message']

    # Harry (user 30) updates his assigned complaint
    mock_login(monkeypatch, user_id=30, role='SUPERVISOR', org_id=1)
    res = client.patch('/api/v1/complaints/105', json={'status': 'IN_PROGRESS'})
    assert res.status_code == 200
    assert res.json['data']['status'] == 'IN_PROGRESS'


def test_combined_supervisor_assignment_and_status_update(test_app, client, monkeypatch):
    """Verify compound update with both supervisor_id and status records both transitions and notifications."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=106,
            organization_id=1,
            student_id=20,
            supervisor_id=None,
            department_id=1,
            title='Desk repair',
            description='Broken desk in class 201',
            status='PENDING',
        )
        db.session.add(c)
        db.session.commit()

    # Admin passes both supervisor_id (Harry: 30) and status ('IN_PROGRESS')
    mock_login(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)
    payload = {
        'supervisor_id': 30,
        'status': 'IN_PROGRESS',
        'remarks': 'Assigned and started work immediately',
    }
    res = client.patch('/api/v1/complaints/106', json=payload)
    assert res.status_code == 200
    assert res.json['data']['status'] == 'IN_PROGRESS'
    assert res.json['data']['supervisor_id'] == 30

    with test_app.app_context():
        history = ComplaintStatusHistory.query.filter_by(
            complaint_id=106
        ).order_by(ComplaintStatusHistory.history_id.asc()).all()
        # Should record: 1. PENDING -> ASSIGNED (from assignment), 2. ASSIGNED -> IN_PROGRESS (from status change)
        assert len(history) == 2
        assert history[0].old_status == 'PENDING'
        assert history[0].new_status == 'ASSIGNED'
        assert history[1].old_status == 'ASSIGNED'
        assert history[1].new_status == 'IN_PROGRESS'
        assert history[1].remarks == 'Assigned and started work immediately'

        # Check notifications
        student_notifs = Notification.query.filter_by(user_id=20, reference_id=106).all()
        # Student got Complaint Assigned notification and Complaint In Progress notification
        assert any('Assigned' in n.title for n in student_notifs)
        assert any('In Progress' in n.title for n in student_notifs)


def test_duplicate_same_status_history_prevention(test_app, client, monkeypatch):
    """Reassigning supervisor on an already IN_PROGRESS complaint must not create redundant same-status history."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=107,
            organization_id=1,
            student_id=20,
            supervisor_id=30,  # Harry
            department_id=1,
            title='Corridor Cleaning',
            description='Dust in corridor',
            status='IN_PROGRESS',
        )
        db.session.add(c)
        db.session.commit()

    # Reassign to Helen (31) without changing status
    mock_login(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)
    res = client.patch('/api/v1/complaints/107', json={'supervisor_id': 31})
    assert res.status_code == 200
    assert res.json['data']['supervisor_id'] == 31
    assert res.json['data']['status'] == 'IN_PROGRESS'

    with test_app.app_context():
        # No history entry should have old_status == new_status == 'IN_PROGRESS'
        history = ComplaintStatusHistory.query.filter_by(complaint_id=107).all()
        same_status_entries = [h for h in history if h.old_status == h.new_status]
        assert len(same_status_entries) == 0

        # Previous supervisor Harry should receive 'Complaint Reassigned' notification
        harry_notif = Notification.query.filter_by(user_id=30, reference_id=107).first()
        assert harry_notif is not None
        assert harry_notif.title == 'Complaint Reassigned'


def test_unassignment_notifications_and_history(test_app, client, monkeypatch):
    """Unassigning supervisor must notify previous supervisor, student, and admins."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=108,
            organization_id=1,
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='Classroom Fan',
            description='Fan wobbling',
            status='ASSIGNED',
        )
        db.session.add(c)
        db.session.commit()

    # Admin unassigns supervisor
    mock_login(monkeypatch, user_id=10, role='ORG_ADMIN', org_id=1)
    res = client.patch('/api/v1/complaints/108', json={'supervisor_id': None})
    assert res.status_code == 200
    assert res.json['data']['supervisor_id'] is None
    assert res.json['data']['status'] == 'PENDING'

    with test_app.app_context():
        # History recorded ASSIGNED -> PENDING
        history = ComplaintStatusHistory.query.filter_by(complaint_id=108).first()
        assert history.old_status == 'ASSIGNED'
        assert history.new_status == 'PENDING'

        # Check notifications
        sup_notif = Notification.query.filter_by(user_id=30, reference_id=108).first()
        assert sup_notif is not None
        assert sup_notif.title == 'Supervisor Unassigned'

        student_notif = Notification.query.filter_by(user_id=20, reference_id=108).first()
        assert student_notif is not None
        assert student_notif.title == 'Supervisor Unassigned'

        admin_notif = Notification.query.filter_by(user_id=10, reference_id=108).first()
        assert admin_notif is not None
        assert admin_notif.title == 'Unassigned Complaint'


# ==================== 3. COMMENT NOTIFICATIONS ====================

def test_student_comment_notifies_assigned_supervisor(test_app, client, monkeypatch):
    """When a student posts a comment, the assigned supervisor must be notified."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=109,
            organization_id=1,
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='Projector Issue',
            description='Projector not turning on',
            status='IN_PROGRESS',
        )
        db.session.add(c)
        db.session.commit()

    mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1)
    res = client.post('/api/v1/complaints/109/comments', json={'message': 'Any update on this?'})
    assert res.status_code == 201

    with test_app.app_context():
        notif = Notification.query.filter_by(user_id=30, reference_id=109).first()
        assert notif is not None
        assert notif.title == 'New Student Comment'
        assert 'added a comment' in notif.message


def test_supervisor_comment_notifies_student(test_app, client, monkeypatch):
    """When a supervisor posts a comment, the student must be notified."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=110,
            organization_id=1,
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='AC Filter',
            description='Filter needs replacement',
            status='IN_PROGRESS',
        )
        db.session.add(c)
        db.session.commit()

    mock_login(monkeypatch, user_id=30, role='SUPERVISOR', org_id=1)
    res = client.post('/api/v1/complaints/110/comments', json={'message': 'Replacement filter ordered.'})
    assert res.status_code == 201

    with test_app.app_context():
        notif = Notification.query.filter_by(user_id=20, reference_id=110).first()
        assert notif is not None
        assert notif.title == 'New Supervisor Update'


def test_supervisor_cannot_comment_on_complaint_assigned_to_other_supervisor(test_app, client, monkeypatch):
    """Supervisor A cannot comment on a complaint assigned to Supervisor B."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=120,
            organization_id=1,
            student_id=20,  # Alice
            supervisor_id=30,  # Harry Housekeeper (Supervisor B)
            department_id=1,
            title='Corridor Light Broken',
            description='Light flickers in corridor',
            status='ASSIGNED',
        )
        db.session.add(c)
        db.session.commit()

        initial_comments_count = ComplaintChat.query.filter_by(complaint_id=120).count()
        initial_notifs_count = Notification.query.count()

    # Eli Electrician (supervisor 32 - Supervisor A) attempts to comment on Harry's complaint
    mock_login(monkeypatch, user_id=32, role='SUPERVISOR', org_id=1)
    res = client.post('/api/v1/complaints/120/comments', json={'message': 'I will take over this job.'})
    assert res.status_code == 403
    assert 'assigned to you' in res.json['message']

    with test_app.app_context():
        # Unauthorized attempts create neither a comment nor a notification
        final_comments_count = ComplaintChat.query.filter_by(complaint_id=120).count()
        final_notifs_count = Notification.query.count()
        assert final_comments_count == initial_comments_count
        assert final_notifs_count == initial_notifs_count


def test_supervisor_cannot_comment_on_unassigned_complaint(test_app, client, monkeypatch):
    """A supervisor cannot comment on an unassigned complaint."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=121,
            organization_id=1,
            student_id=20,
            supervisor_id=None,  # Unassigned
            department_id=1,
            title='Unassigned Water Cooler',
            description='Water cooler leaking continuously',
            status='PENDING',
        )
        db.session.add(c)
        db.session.commit()

        initial_comments_count = ComplaintChat.query.filter_by(complaint_id=121).count()
        initial_notifs_count = Notification.query.count()

    # Harry Housekeeper (supervisor 30) attempts to comment on unassigned complaint
    mock_login(monkeypatch, user_id=30, role='SUPERVISOR', org_id=1)
    res = client.post('/api/v1/complaints/121/comments', json={'message': 'I can inspect this cooler.'})
    assert res.status_code == 403
    assert 'assigned to you' in res.json['message']

    with test_app.app_context():
        # Unauthorized attempts create neither a comment nor a notification
        final_comments_count = ComplaintChat.query.filter_by(complaint_id=121).count()
        final_notifs_count = Notification.query.count()
        assert final_comments_count == initial_comments_count
        assert final_notifs_count == initial_notifs_count


def test_assigned_supervisor_can_comment_successfully(test_app, client, monkeypatch):
    """The assigned supervisor can still comment successfully and notify the student."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=122,
            organization_id=1,
            student_id=20,
            supervisor_id=30,  # Harry
            department_id=1,
            title='Classroom Fan',
            description='Fan wobbles at high speed',
            status='IN_PROGRESS',
        )
        db.session.add(c)
        db.session.commit()

    # Harry (supervisor 30) posts comment on complaint 122 assigned to him
    mock_login(monkeypatch, user_id=30, role='SUPERVISOR', org_id=1)
    res = client.post('/api/v1/complaints/122/comments', json={'message': 'Technician dispatched with replacement blade.'})
    assert res.status_code == 201
    assert res.json['data']['message'] == 'Technician dispatched with replacement blade.'

    with test_app.app_context():
        comment = ComplaintChat.query.filter_by(complaint_id=122, sender_id=30).first()
        assert comment is not None
        assert comment.message == 'Technician dispatched with replacement blade.'

        notif = Notification.query.filter_by(user_id=20, reference_id=122).first()
        assert notif is not None
        assert notif.title == 'New Supervisor Update'


# ==================== 4. STUDENT FEEDBACK & REOPENING ====================

def test_student_feedback_satisfied_closes_complaint(test_app, client, monkeypatch):
    """Student providing SATISFIED feedback closes resolved complaint and notifies supervisor."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=111,
            organization_id=1,
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='Board Cleaning',
            description='Smart board marker ink stuck',
            status='RESOLVED',
        )
        db.session.add(c)
        db.session.commit()

    mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1)
    payload = {'feedback': 'SATISFIED', 'remarks': 'Cleaned very well, thank you!'}
    res = client.post('/api/v1/complaints/111/feedback', json=payload)
    assert res.status_code == 200
    assert res.json['data']['status'] == 'CLOSED'
    assert res.json['data']['student_feedback'] == 'SATISFIED'

    with test_app.app_context():
        history = ComplaintStatusHistory.query.filter_by(complaint_id=111).first()
        assert history.old_status == 'RESOLVED'
        assert history.new_status == 'CLOSED'
        assert history.updated_by == 20

        # Supervisor notified
        notif = Notification.query.filter_by(user_id=30, reference_id=111).first()
        assert notif is not None
        assert notif.title == 'Complaint Closed'


def test_student_feedback_rejected_on_pending_complaint(test_app, client, monkeypatch):
    """Student feedback is rejected if complaint is not resolved."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=112,
            organization_id=1,
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='Test Complaint',
            description='Test description',
            status='IN_PROGRESS',
        )
        db.session.add(c)
        db.session.commit()

    mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1)
    res = client.post('/api/v1/complaints/112/feedback', json={'feedback': 'SATISFIED'})
    assert res.status_code == 400
    assert 'resolved complaints' in res.json['message']


def test_student_feedback_forbidden_for_non_owner(test_app, client, monkeypatch):
    """Another student cannot submit feedback on a complaint they do not own."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=113,
            organization_id=1,
            student_id=20,  # Alice
            supervisor_id=30,
            department_id=1,
            title='Test Complaint',
            description='Test description',
            status='RESOLVED',
        )
        db.session.add(c)
        db.session.commit()

    # Bob (user 21) tries to submit feedback
    mock_login(monkeypatch, user_id=21, role='STUDENT', org_id=1)
    res = client.post('/api/v1/complaints/113/feedback', json={'feedback': 'SATISFIED'})
    assert res.status_code == 403
    assert 'your own complaints' in res.json['message']


def test_student_reopen_complaint_workflow(test_app, client, monkeypatch):
    """Student reopening a resolved complaint updates status to REOPENED, records history, and notifies supervisor."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=114,
            organization_id=1,
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='Lab Tap Dripping',
            description='Tap is dripping continuously',
            status='RESOLVED',
        )
        db.session.add(c)
        db.session.commit()

    mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1)
    res = client.post('/api/v1/complaints/114/reopen', json={'remarks': 'The tap is still leaking from the base.'})
    assert res.status_code == 200
    assert res.json['data']['status'] == 'REOPENED'
    assert res.json['data']['student_feedback'] == 'NOT_SATISFIED'

    with test_app.app_context():
        history = ComplaintStatusHistory.query.filter_by(complaint_id=114).first()
        assert history.old_status == 'RESOLVED'
        assert history.new_status == 'REOPENED'
        assert history.remarks == 'The tap is still leaking from the base.'
        assert history.updated_by == 20

        # Supervisor notified
        sup_notif = Notification.query.filter_by(user_id=30, reference_id=114).first()
        assert sup_notif is not None
        assert sup_notif.title == 'Complaint Reopened'

        # Student confirmation notified
        student_notif = Notification.query.filter_by(user_id=20, reference_id=114).first()
        assert student_notif is not None
        assert student_notif.title == 'Complaint Reopened'


def test_student_cannot_call_update_complaint(test_app, client, monkeypatch):
    """Verify that students cannot bypass workflow and call PATCH /complaints directly."""
    with test_app.app_context():
        c = Complaint(
            complaint_id=115,
            organization_id=1,
            student_id=20,
            supervisor_id=30,
            department_id=1,
            title='Bypass test',
            description='Test bypass',
            status='PENDING',
        )
        db.session.add(c)
        db.session.commit()

    mock_login(monkeypatch, user_id=20, role='STUDENT', org_id=1)
    res = client.patch('/api/v1/complaints/115', json={'status': 'RESOLVED'})
    assert res.status_code == 403
    assert 'permission to update complaints' in res.json['message']
