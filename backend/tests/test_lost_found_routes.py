"""
Unit and regression tests for Lost & Found endpoints:
- Creation with and without images, input validation, and field length boundaries
- URL safety and scheme validation (blocking javascript:, data:, etc.)
- Organization scoping, isolation, and query filtering (mine, status, type, search)
- Owner editing and closing of open listings
- Immutability of closed listings (cannot edit or reopen)
- Authorization and denial for non-owners
- Organization admin moderation (closing, deleting) and notification behavior
- Super admin cross-organization capabilities and None organization handling
- Discussion/comments lifecycle and closed-post blocking
- Image upload and deletion authorization
- Unauthenticated access prevention
"""

import io
import os
from datetime import date, datetime
from types import SimpleNamespace
from PIL import Image
import pytest

from app import create_app
from app.database import db
from app.models import (
    LostFound,
    LostFoundChat,
    LostFoundImage,
    Notification,
    Organization,
    User,
)


@pytest.fixture
def lf_test_app(monkeypatch):
    """Set up test Flask app with in-memory SQLite and sample organizational and lost & found data."""
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    db.init_app(app)

    with app.app_context():
        # Prepend table name to index names to avoid SQLite collisions
        for table in [Organization, User, LostFound, LostFoundImage, LostFoundChat, Notification]:
            for idx in list(table.__table__.indexes):
                idx.name = f"idx_{table.__tablename__}_{idx.name}"

        Organization.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)
        LostFound.__table__.create(db.engine, checkfirst=True)
        LostFoundImage.__table__.create(db.engine, checkfirst=True)
        LostFoundChat.__table__.create(db.engine, checkfirst=True)
        Notification.__table__.create(db.engine, checkfirst=True)

        # Organizations
        org1 = Organization(
            organization_id=1,
            organization_name='Alpha University',
            organization_code='ALPHA',
            email_domain='alpha.edu',
            is_active=True,
        )
        org2 = Organization(
            organization_id=2,
            organization_name='Beta Institute',
            organization_code='BETA',
            email_domain='beta.edu',
            is_active=True,
        )
        db.session.add_all([org1, org2])

        # Users
        student1 = User(
            user_id=10,
            organization_id=1,
            full_name='Student Alice',
            email='alice@alpha.edu',
            firebase_uid='uid-alice',
            role='STUDENT',
            is_active=True,
        )
        student2 = User(
            user_id=11,
            organization_id=1,
            full_name='Student Bob',
            email='bob@alpha.edu',
            firebase_uid='uid-bob',
            role='STUDENT',
            is_active=True,
        )
        admin_org1 = User(
            user_id=20,
            organization_id=1,
            full_name='Admin Alpha',
            email='admin@alpha.edu',
            firebase_uid='uid-admin-org1',
            role='ORG_ADMIN',
            is_active=True,
        )
        supervisor_org1 = User(
            user_id=30,
            organization_id=1,
            full_name='Supervisor Dan',
            email='dan@alpha.edu',
            firebase_uid='uid-sup-org1',
            role='SUPERVISOR',
            is_active=True,
        )
        student_org2 = User(
            user_id=40,
            organization_id=2,
            full_name='Student Charlie',
            email='charlie@beta.edu',
            firebase_uid='uid-charlie',
            role='STUDENT',
            is_active=True,
        )
        admin_org2 = User(
            user_id=50,
            organization_id=2,
            full_name='Admin Beta',
            email='admin@beta.edu',
            firebase_uid='uid-admin-org2',
            role='ORG_ADMIN',
            is_active=True,
        )
        super_admin = User(
            user_id=99,
            organization_id=1,
            full_name='Global Super Admin',
            email='super@system.gov',
            firebase_uid='uid-super-admin',
            role='SUPER_ADMIN',
            is_active=True,
        )
        no_org_student = User(
            user_id=88,
            organization_id=1,
            full_name='Unassigned Student',
            email='unassigned@external.com',
            firebase_uid='uid-no-org',
            role='STUDENT',
            is_active=True,
        )
        db.session.add_all([
            student1,
            student2,
            admin_org1,
            supervisor_org1,
            student_org2,
            admin_org2,
            super_admin,
            no_org_student,
        ])

        # Seed initial Lost & Found items
        # Item 1: Org 1, Student 1, OPEN
        lf1 = LostFound(
            item_id=1,
            organization_id=1,
            posted_by=10,
            item_type='LOST',
            title='Blue Backpack',
            description='Lost near university library reading room',
            category='Personal Belongings',
            location='Library Reading Room',
            date_of_incident=date(2026, 10, 15),
            status='OPEN',
        )
        # Item 2: Org 1, Student 1, CLOSED
        lf2 = LostFound(
            item_id=2,
            organization_id=1,
            posted_by=10,
            item_type='FOUND',
            title='Stainless Steel Bottle',
            description='Found at the main sports complex',
            category='Water Bottles & Flasks',
            location='Sports Complex',
            date_of_incident=date(2026, 10, 14),
            status='CLOSED',
            resolved_at=datetime(2026, 10, 16, 10, 0, 0),
        )
        # Item 3: Org 2, Student Org 2, OPEN
        lf3 = LostFound(
            item_id=3,
            organization_id=2,
            posted_by=40,
            item_type='LOST',
            title='Keys with Red Lanyard',
            description='Lost in dining hall 2',
            category='Keys',
            location='Dining Hall 2',
            date_of_incident=date(2026, 10, 17),
            status='OPEN',
        )
        db.session.add_all([lf1, lf2, lf3])

        # Seed Image for Item 1
        img1 = LostFoundImage(
            image_id=1,
            item_id=1,
            image_url='/uploads/complaints/backpack.jpg',
        )
        db.session.add(img1)

        db.session.commit()

    return app


@pytest.fixture
def client(lf_test_app):
    return lf_test_app.test_client()


def mock_auth(monkeypatch, user_id, role, org_id):
    """Mock authentication helper returning a verified user with role and organization."""
    mock_user = SimpleNamespace(
        user_id=user_id,
        organization_id=org_id,
        role=role,
        is_active=True,
        full_name=f'User {user_id}',
    )

    def fake_authenticate(force=False):
        from flask import g
        g.current_user = mock_user
        g.firebase_claims = {'firebase_uid': f'uid-{user_id}'}
        return mock_user

    monkeypatch.setattr('app.middleware.firebase_auth._authenticate_request', fake_authenticate)
    return mock_user


# ==================== 1. CREATION & INPUT VALIDATION ====================

def test_create_listing_success_with_image(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    payload = {
        'item_type': 'LOST',
        'title': 'Orbit Graphing Calculator',
        'description': 'Left on desk in physics lab room 204.',
        'category': 'Electronics',
        'location': 'Physics Lab 204',
        'date_of_incident': '2026-10-18',
        'image_url': '/uploads/complaints/calc_image_123.jpg',
    }
    res = client.post('/api/v1/lost-found', json=payload)
    assert res.status_code == 201
    data = res.get_json()['data']
    assert data['title'] == 'Orbit Graphing Calculator'
    assert data['item_type'] == 'LOST'
    assert data['status'] == 'OPEN'
    assert data['organization_id'] == 1
    assert data['posted_by'] == 10
    assert data['image_count'] == 1
    assert data['images'][0]['image_url'] == '/uploads/complaints/calc_image_123.jpg'


def test_create_listing_success_without_image(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    payload = {
        'item_type': 'FOUND',
        'title': 'Black Umbrella',
        'description': 'Found by the main auditorium entrance.',
    }
    res = client.post('/api/v1/lost-found', json=payload)
    assert res.status_code == 201
    data = res.get_json()['data']
    assert data['title'] == 'Black Umbrella'
    assert data['item_type'] == 'FOUND'
    assert data['image_count'] == 0


def test_create_listing_missing_required_fields(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    # Missing item_type
    res = client.post('/api/v1/lost-found', json={'title': 'Test', 'description': 'Desc'})
    assert res.status_code == 400
    assert 'item_type is required' in res.get_json()['message']

    # Missing title
    res = client.post('/api/v1/lost-found', json={'item_type': 'LOST', 'description': 'Desc'})
    assert res.status_code == 400
    assert 'title is required' in res.get_json()['message']

    # Missing description
    res = client.post('/api/v1/lost-found', json={'item_type': 'LOST', 'title': 'Title'})
    assert res.status_code == 400
    assert 'description is required' in res.get_json()['message']


def test_create_listing_invalid_item_type(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found', json={
        'item_type': 'STOLEN',
        'title': 'Bike',
        'description': 'Stolen bike',
    })
    assert res.status_code == 400
    assert 'Invalid item_type value' in res.get_json()['message']


def test_create_listing_field_length_limits(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    # Title exceeds 200 chars
    res = client.post('/api/v1/lost-found', json={
        'item_type': 'LOST',
        'title': 'A' * 201,
        'description': 'Valid desc',
    })
    assert res.status_code == 400
    assert 'title cannot exceed 200 characters' in res.get_json()['message']

    # Category exceeds 100 chars
    res = client.post('/api/v1/lost-found', json={
        'item_type': 'LOST',
        'title': 'Valid title',
        'description': 'Valid desc',
        'category': 'C' * 101,
    })
    assert res.status_code == 400
    assert 'category cannot exceed 100 characters' in res.get_json()['message']

    # Location exceeds 255 chars
    res = client.post('/api/v1/lost-found', json={
        'item_type': 'LOST',
        'title': 'Valid title',
        'description': 'Valid desc',
        'location': 'L' * 256,
    })
    assert res.status_code == 400
    assert 'location cannot exceed 255 characters' in res.get_json()['message']


def test_create_listing_title_boundary_200_chars_succeeds(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found', json={
        'item_type': 'LOST',
        'title': 'T' * 200,
        'description': 'Valid desc',
    })
    assert res.status_code == 201
    assert len(res.get_json()['data']['title']) == 200


def test_create_listing_invalid_date_format_rejected(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found', json={
        'item_type': 'LOST',
        'title': 'Lost Glasses',
        'description': 'Black frame glasses',
        'date_of_incident': '18-10-2026',  # Not ISO YYYY-MM-DD
    })
    assert res.status_code == 400
    assert 'date_of_incident must be a valid ISO date string' in res.get_json()['message']


def test_create_listing_unsafe_image_url_schemes_rejected(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    dangerous_urls = [
        'javascript:alert(document.cookie)',
        'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
        'vbscript:MsgBox("Exploit")',
        'file:///etc/passwd',
        'ftp://malicious.org/pic.jpg',
    ]

    for bad_url in dangerous_urls:
        res = client.post('/api/v1/lost-found', json={
            'item_type': 'LOST',
            'title': 'Calculator',
            'description': 'Lost calculator',
            'image_url': bad_url,
        })
        assert res.status_code == 400
        assert 'Invalid or unsafe image URL' in res.get_json()['message']


def test_create_listing_user_without_org_rejected(client, monkeypatch):
    mock_auth(monkeypatch, user_id=88, role='STUDENT', org_id=None)
    res = client.post('/api/v1/lost-found', json={
        'item_type': 'LOST',
        'title': 'Wallet',
        'description': 'Lost leather wallet',
    })
    assert res.status_code == 400
    assert 'User is not assigned to an organization' in res.get_json()['message']


# ==================== 2. SCOPING, ISOLATION & FILTERS ====================

def test_list_listings_strictly_scoped_to_organization(client, monkeypatch):
    # Student in Org 1 should see only Org 1 items (items 1 and 2), not Org 2 (item 3)
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found')
    assert res.status_code == 200
    data = res.get_json()['data']['data']
    item_ids = [item['item_id'] for item in data]
    assert 1 in item_ids
    assert 2 in item_ids
    assert 3 not in item_ids


def test_list_listings_filter_by_mine(client, monkeypatch):
    # Student 1 posted items 1 and 2; Student 2 has posted nothing yet
    mock_auth(monkeypatch, user_id=11, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found?mine=true')
    assert res.status_code == 200
    assert res.get_json()['data']['pagination']['total'] == 0

    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found?mine=true')
    assert res.status_code == 200
    assert res.get_json()['data']['pagination']['total'] == 2


def test_list_listings_filter_by_status(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    # OPEN items only
    res = client.get('/api/v1/lost-found?status=OPEN')
    assert res.status_code == 200
    items = res.get_json()['data']['data']
    assert all(i['status'] == 'OPEN' for i in items)
    assert len(items) == 1
    assert items[0]['item_id'] == 1

    # CLOSED items only
    res = client.get('/api/v1/lost-found?status=CLOSED')
    assert res.status_code == 200
    items = res.get_json()['data']['data']
    assert all(i['status'] == 'CLOSED' for i in items)
    assert len(items) == 1
    assert items[0]['item_id'] == 2


def test_list_listings_filter_by_item_type(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found?item_type=LOST')
    assert res.status_code == 200
    items = res.get_json()['data']['data']
    assert len(items) == 1
    assert items[0]['item_type'] == 'LOST'


def test_list_listings_filter_by_search(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found?search=backpack')
    assert res.status_code == 200
    items = res.get_json()['data']['data']
    assert len(items) == 1
    assert items[0]['title'] == 'Blue Backpack'


def test_list_listings_invalid_filter_returns_400(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found?status=INVALID_STATUS')
    assert res.status_code == 400
    assert 'Invalid status filter' in res.get_json()['message']

    res = client.get('/api/v1/lost-found?item_type=INVALID_TYPE')
    assert res.status_code == 400
    assert 'Invalid item_type filter' in res.get_json()['message']


def test_get_listing_detail_same_org_success(client, monkeypatch):
    mock_auth(monkeypatch, user_id=11, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found/1')
    assert res.status_code == 200
    assert res.get_json()['data']['title'] == 'Blue Backpack'


def test_get_listing_detail_cross_org_returns_404(client, monkeypatch):
    # Student in Org 1 attempting to view Org 2 item (id=3)
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found/3')
    assert res.status_code == 404
    assert 'Lost and found item not found' in res.get_json()['message']


# ==================== 3. EDITING, CLOSING & IMMUTABILITY ====================

def test_creator_can_edit_open_listing(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.patch('/api/v1/lost-found/1', json={
        'title': 'Blue Navy Backpack (Updated)',
        'location': 'Library 2nd Floor',
    })
    assert res.status_code == 200
    data = res.get_json()['data']
    assert data['title'] == 'Blue Navy Backpack (Updated)'
    assert data['location'] == 'Library 2nd Floor'


def test_creator_can_close_open_listing(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.patch('/api/v1/lost-found/1', json={'status': 'CLOSED'})
    assert res.status_code == 200
    data = res.get_json()['data']
    assert data['status'] == 'CLOSED'
    assert data['resolved_at'] is not None


def test_closed_listing_cannot_be_edited(client, monkeypatch):
    # Item 2 is already CLOSED
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.patch('/api/v1/lost-found/2', json={'title': 'Attempt to Edit Closed'})
    assert res.status_code == 400
    assert 'Closed listings cannot be modified or reopened' in res.get_json()['message']


def test_closed_listing_cannot_be_reopened(client, monkeypatch):
    # Item 2 is CLOSED; attempting to reopen it with status=OPEN must fail
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.patch('/api/v1/lost-found/2', json={'status': 'OPEN'})
    assert res.status_code == 400
    assert 'Closed listings cannot be modified or reopened' in res.get_json()['message']


def test_non_owner_update_denied_403(client, monkeypatch):
    # Student 2 trying to update Student 1's listing (item 1)
    mock_auth(monkeypatch, user_id=11, role='STUDENT', org_id=1)
    res = client.patch('/api/v1/lost-found/1', json={'title': 'Hacked Title'})
    assert res.status_code == 403
    assert 'You cannot edit this item' in res.get_json()['message']


# ==================== 4. MODERATION & NOTIFICATIONS ====================

def test_org_admin_can_close_listing_and_creator_is_notified(client, monkeypatch, lf_test_app):
    # Admin of Org 1 closes Student 1's open listing (item 1)
    mock_auth(monkeypatch, user_id=20, role='ORG_ADMIN', org_id=1)
    res = client.patch('/api/v1/lost-found/1', json={'status': 'CLOSED'})
    assert res.status_code == 200
    assert res.get_json()['data']['status'] == 'CLOSED'

    # Verify notification sent to Student 1 (user_id=10)
    with lf_test_app.app_context():
        notif = Notification.query.filter_by(user_id=10, notification_type='LOST_FOUND').first()
        assert notif is not None
        assert notif.title == 'Item Closed'
        assert notif.reference_id == 1


def test_creator_closing_own_listing_does_not_send_duplicate_self_notification(client, monkeypatch, lf_test_app):
    with lf_test_app.app_context():
        Notification.query.delete()
        db.session.commit()

    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.patch('/api/v1/lost-found/1', json={'status': 'CLOSED'})
    assert res.status_code == 200

    with lf_test_app.app_context():
        notifs = Notification.query.filter_by(user_id=10).all()
        assert len(notifs) == 0


def test_org_admin_cannot_moderate_other_org_listing_404(client, monkeypatch):
    # Org Admin 1 trying to close Org 2's item (item 3)
    mock_auth(monkeypatch, user_id=20, role='ORG_ADMIN', org_id=1)
    res = client.patch('/api/v1/lost-found/3', json={'status': 'CLOSED'})
    assert res.status_code == 404
    assert 'Lost and found item not found' in res.get_json()['message']


def test_org_admin_can_delete_listing_within_org(client, monkeypatch, lf_test_app):
    mock_auth(monkeypatch, user_id=20, role='ORG_ADMIN', org_id=1)
    res = client.delete('/api/v1/lost-found/1')
    assert res.status_code == 200
    assert 'Lost and found item deleted' in res.get_json()['message']

    with lf_test_app.app_context():
        assert LostFound.query.filter_by(item_id=1).first() is None


def test_student_cannot_delete_listing_403(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.delete('/api/v1/lost-found/1')
    assert res.status_code == 403
    assert 'You cannot delete this item' in res.get_json()['message']


def test_org_admin_cannot_delete_other_org_listing_404(client, monkeypatch):
    mock_auth(monkeypatch, user_id=20, role='ORG_ADMIN', org_id=1)
    res = client.delete('/api/v1/lost-found/3')
    assert res.status_code == 404


# ==================== 5. SUPER ADMIN CAPABILITIES ====================

def test_super_admin_can_view_listing_across_organizations(client, monkeypatch):
    mock_auth(monkeypatch, user_id=99, role='SUPER_ADMIN', org_id=None)
    # Can access item in Org 1
    res1 = client.get('/api/v1/lost-found/1')
    assert res1.status_code == 200
    # Can access item in Org 2
    res2 = client.get('/api/v1/lost-found/3')
    assert res2.status_code == 200


def test_super_admin_can_filter_by_organization_id(client, monkeypatch):
    mock_auth(monkeypatch, user_id=99, role='SUPER_ADMIN', org_id=None)
    res = client.get('/api/v1/lost-found?organization_id=2')
    assert res.status_code == 200
    items = res.get_json()['data']['data']
    assert len(items) == 1
    assert items[0]['organization_id'] == 2


def test_super_admin_with_none_org_can_moderate_and_delete(client, monkeypatch, lf_test_app):
    mock_auth(monkeypatch, user_id=99, role='SUPER_ADMIN', org_id=None)
    # Can close item in Org 2
    res = client.patch('/api/v1/lost-found/3', json={'status': 'CLOSED'})
    assert res.status_code == 200
    assert res.get_json()['data']['status'] == 'CLOSED'

    # Can delete item in Org 2
    res_del = client.delete('/api/v1/lost-found/3')
    assert res_del.status_code == 200

    with lf_test_app.app_context():
        assert LostFound.query.filter_by(item_id=3).first() is None


# ==================== 6. COMMENTS & DISCUSSION ====================

def test_add_comment_success_notifies_creator(client, monkeypatch, lf_test_app):
    with lf_test_app.app_context():
        Notification.query.delete()
        db.session.commit()

    # Student 2 comments on Student 1's open listing (item 1)
    mock_auth(monkeypatch, user_id=11, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found/1/comments', json={
        'message': 'I think I saw this near table 4 in reading room.',
        'message_type': 'TEXT',
    })
    assert res.status_code == 201
    assert res.get_json()['data']['message'] == 'I think I saw this near table 4 in reading room.'

    # Notification sent to Student 1 (user_id=10)
    with lf_test_app.app_context():
        notif = Notification.query.filter_by(user_id=10, notification_type='LOST_FOUND').first()
        assert notif is not None
        assert notif.title == 'New Comment'
        assert notif.reference_id == 1


def test_creator_commenting_on_own_listing_does_not_generate_notification(client, monkeypatch, lf_test_app):
    with lf_test_app.app_context():
        Notification.query.delete()
        db.session.commit()

    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found/1/comments', json={
        'message': 'Adding extra detail about the backpack keychains.',
    })
    assert res.status_code == 201

    with lf_test_app.app_context():
        assert Notification.query.filter_by(user_id=10).count() == 0


def test_commenting_blocked_on_closed_listing_400(client, monkeypatch):
    # Item 2 is CLOSED
    mock_auth(monkeypatch, user_id=11, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found/2/comments', json={
        'message': 'Is this still available?',
    })
    assert res.status_code == 400
    assert 'Comments are not allowed on closed posts' in res.get_json()['message']


def test_comment_unsafe_image_url_rejected(client, monkeypatch):
    mock_auth(monkeypatch, user_id=11, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found/1/comments', json={
        'message_type': 'IMAGE',
        'image_url': 'javascript:alert("XSS")',
    })
    assert res.status_code == 400
    assert 'Invalid or unsafe image URL' in res.get_json()['message']


def test_get_comments_success(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found/1/comments')
    assert res.status_code == 200
    assert isinstance(res.get_json()['data'], list)


# ==================== 7. IMAGES LIFECYCLE ====================

def test_add_image_creator_success(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found/1/images', json={
        'image_url': '/uploads/complaints/extra_angle.jpg',
    })
    assert res.status_code == 201
    assert res.get_json()['data']['image_url'] == '/uploads/complaints/extra_angle.jpg'


def test_add_image_non_creator_forbidden_403(client, monkeypatch):
    mock_auth(monkeypatch, user_id=11, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found/1/images', json={
        'image_url': '/uploads/complaints/sneaky.jpg',
    })
    assert res.status_code == 403
    assert 'Only the creator can upload images' in res.get_json()['message']


def test_add_image_blocked_on_closed_listing_400(client, monkeypatch):
    # Item 2 is CLOSED
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found/2/images', json={
        'image_url': '/uploads/complaints/late.jpg',
    })
    assert res.status_code == 400
    assert 'Cannot upload images to a closed post' in res.get_json()['message']


def test_delete_image_creator_success(client, monkeypatch, lf_test_app):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.delete('/api/v1/lost-found/images/1')
    assert res.status_code == 200

    with lf_test_app.app_context():
        assert LostFoundImage.query.filter_by(image_id=1).first() is None


def test_delete_image_non_creator_non_admin_forbidden_403(client, monkeypatch):
    mock_auth(monkeypatch, user_id=11, role='STUDENT', org_id=1)
    res = client.delete('/api/v1/lost-found/images/1')
    assert res.status_code == 403
    assert 'You cannot delete this image' in res.get_json()['message']


def test_delete_image_org_admin_success(client, monkeypatch, lf_test_app):
    mock_auth(monkeypatch, user_id=20, role='ORG_ADMIN', org_id=1)
    res = client.delete('/api/v1/lost-found/images/1')
    assert res.status_code == 200


def test_delete_image_on_closed_listing_blocked_400(client, monkeypatch, lf_test_app):
    with lf_test_app.app_context():
        closed_img = LostFoundImage(
            image_id=2,
            item_id=2,  # Item 2 is CLOSED
            image_url='/uploads/complaints/closed.jpg',
        )
        db.session.add(closed_img)
        db.session.commit()

    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.delete('/api/v1/lost-found/images/2')
    assert res.status_code == 400
    assert 'Cannot modify images of a closed post' in res.get_json()['message']


# ==================== 8. MISSING & UNAUTHENTICATED ====================

def test_missing_listing_returns_404(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.get('/api/v1/lost-found/9999')
    assert res.status_code == 404


def test_missing_image_returns_404(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.delete('/api/v1/lost-found/images/9999')
    assert res.status_code == 404


def test_unauthenticated_requests_return_401(client):
    res = client.get('/api/v1/lost-found')
    assert res.status_code == 401


# ==================== 9. ADVANCED DATA TYPES & URL ROBUSTNESS ====================

def test_non_string_values_in_create_rejected_with_400(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    # Non-string title
    res = client.post('/api/v1/lost-found', json={'item_type': 'LOST', 'title': 12345, 'description': 'Valid desc'})
    assert res.status_code == 400
    assert 'title is required and must be a string' in res.get_json()['message']

    # Non-string description
    res = client.post('/api/v1/lost-found', json={'item_type': 'LOST', 'title': 'Valid', 'description': ['bad', 'desc']})
    assert res.status_code == 400
    assert 'description is required and must be a string' in res.get_json()['message']

    # Non-string category
    res = client.post('/api/v1/lost-found', json={'item_type': 'LOST', 'title': 'Valid', 'description': 'Valid', 'category': 999})
    assert res.status_code == 400
    assert 'category must be a string' in res.get_json()['message']

    # Non-string location
    res = client.post('/api/v1/lost-found', json={'item_type': 'LOST', 'title': 'Valid', 'description': 'Valid', 'location': True})
    assert res.status_code == 400
    assert 'location must be a string' in res.get_json()['message']

    # Non-string date_of_incident
    res = client.post('/api/v1/lost-found', json={'item_type': 'LOST', 'title': 'Valid', 'description': 'Valid', 'date_of_incident': 20261018})
    assert res.status_code == 400
    assert 'date_of_incident must be a valid ISO date string' in res.get_json()['message']

    # Non-string image_url
    res = client.post('/api/v1/lost-found', json={'item_type': 'LOST', 'title': 'Valid', 'description': 'Valid', 'image_url': {'url': 'bad'}})
    assert res.status_code == 400
    assert 'image_url must be a string' in res.get_json()['message']


def test_non_string_values_in_update_rejected_with_400(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    res = client.patch('/api/v1/lost-found/1', json={'title': 999})
    assert res.status_code == 400
    assert 'title must be a string' in res.get_json()['message']

    res = client.patch('/api/v1/lost-found/1', json={'description': False})
    assert res.status_code == 400
    assert 'description must be a string' in res.get_json()['message']

    res = client.patch('/api/v1/lost-found/1', json={'status': 123})
    assert res.status_code == 400
    assert 'status must be a string' in res.get_json()['message']


def test_non_string_values_in_comment_and_image_rejected_with_400(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    # Comment with non-string message
    res = client.post('/api/v1/lost-found/1/comments', json={'message': 12345})
    assert res.status_code == 400
    assert 'message must be a string' in res.get_json()['message']

    # Add image with non-string image_url
    res = client.post('/api/v1/lost-found/1/images', json={'image_url': 12345})
    assert res.status_code == 400
    assert 'image_url is required and must be a string' in res.get_json()['message']


def test_image_url_traversal_and_malformed_schemes_rejected(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    bad_urls = [
        '/uploads/../etc/passwd',
        '/uploads/complaints/../../secrets.txt',
        'http://',
        'https://',
        '//cdn.example.com/exploit.jpg',
        '/var/www/uploads/pic.png',
        '/uploads/image with space.jpg',
        '/uploads/image\nnewline.jpg',
    ]

    for bad_url in bad_urls:
        res = client.post('/api/v1/lost-found', json={
            'item_type': 'LOST',
            'title': 'Test Item',
            'description': 'Valid description',
            'image_url': bad_url,
        })
        assert res.status_code == 400
        assert 'Invalid or unsafe image URL' in res.get_json()['message']


def test_valid_external_https_image_url_accepted(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    res = client.post('/api/v1/lost-found', json={
        'item_type': 'LOST',
        'title': 'Test Item With Valid HTTPS',
        'description': 'Valid description',
        'image_url': 'https://images.unsplash.com/photo-1546776310-eef45dd6d63c.jpg',
    })
    assert res.status_code == 201
    assert res.get_json()['data']['images'][0]['image_url'] == 'https://images.unsplash.com/photo-1546776310-eef45dd6d63c.jpg'


# ==================== 10. DEDICATED UPLOAD AND CLEANUP ====================

def _create_test_image(format='PNG'):
    buf = io.BytesIO()
    img = Image.new('RGB', (30, 30), color='teal')
    img.save(buf, format=format)
    buf.seek(0)
    return buf


def test_upload_lost_found_image_png_success(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    img_bytes = _create_test_image(format='PNG')
    data = {
        'image': (img_bytes, 'valid_lost_item.png', 'image/png'),
    }
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 201
    payload = res.get_json()['data']
    assert payload['image_url'].startswith('/uploads/lost_found/')
    assert payload['image_url'].endswith('.png')
    assert payload['mime_type'] == 'image/png'
    assert payload['file_size'] > 0

    filename = payload['image_url'].split('/uploads/lost_found/')[-1]
    saved_file = tmp_path / 'lost_found' / filename
    assert saved_file.exists()
    assert saved_file.stat().st_size == payload['file_size']


def test_upload_lost_found_image_jpeg_success(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    img_bytes = _create_test_image(format='JPEG')
    data = {
        'file': (img_bytes, 'photo.jpg', 'image/jpeg'),
    }
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 201
    payload = res.get_json()['data']
    assert payload['image_url'].startswith('/uploads/lost_found/')
    assert payload['image_url'].endswith('.jpg')
    assert payload['mime_type'] == 'image/jpeg'


def test_upload_lost_found_image_webp_success(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    img_bytes = _create_test_image(format='WEBP')
    data = {
        'image': (img_bytes, 'item_snap.webp', 'image/webp'),
    }
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 201
    payload = res.get_json()['data']
    assert payload['image_url'].startswith('/uploads/lost_found/')
    assert payload['image_url'].endswith('.webp')
    assert payload['mime_type'] == 'image/webp'


def test_upload_lost_found_image_unauthenticated_401(client):
    img_bytes = _create_test_image(format='PNG')
    data = {
        'image': (img_bytes, 'valid_lost_item.png', 'image/png'),
    }
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 401


def test_upload_lost_found_image_missing_file_400(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    # Empty form data
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data={},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'No image file provided' in res.get_json()['message']

    # Empty filename
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data={'image': (io.BytesIO(b''), '')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'No image selected' in res.get_json()['message']


def test_upload_lost_found_image_invalid_extension_400(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    bad_files = ['doc.pdf', 'script.sh', 'hack.exe', 'animation.gif']
    for bad_name in bad_files:
        res = client.post(
            '/api/v1/lost-found/upload-image',
            data={'image': (io.BytesIO(b'fake content'), bad_name)},
            content_type='multipart/form-data',
        )
        assert res.status_code == 400
        assert 'File type not allowed' in res.get_json()['message']


def test_upload_lost_found_image_spoofed_mime_type_400(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    # Non-image content with an image extension and image MIME
    data = {
        'image': (io.BytesIO(b'#!/bin/bash\necho Malicious executable script'), 'virus.jpg', 'image/jpeg'),
    }
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'Invalid or corrupted image file' in res.get_json()['message']


def test_upload_lost_found_image_mismatched_client_mime_400(client, monkeypatch):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)

    img_bytes = _create_test_image(format='PNG')
    data = {
        'image': (img_bytes, 'valid.png', 'application/pdf'),
    }
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'Invalid MIME type' in res.get_json()['message']


def test_upload_lost_found_image_oversized_400(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    # Create dummy bytes stream exceeding 10MB
    oversized_buf = io.BytesIO(b'0' * (10 * 1024 * 1024 + 1024))
    data = {
        'image': (oversized_buf, 'huge.jpg', 'image/jpeg'),
    }
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'File size exceeds 10MB limit' in res.get_json()['message']


def test_uploaded_lost_found_image_serves_200(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    img_bytes = _create_test_image(format='PNG')
    data = {
        'image': (img_bytes, 'test_serve.png', 'image/png'),
    }
    res = client.post(
        '/api/v1/lost-found/upload-image',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 201
    image_url = res.get_json()['data']['image_url']

    # Now verify the global /uploads/<path:filename> route serves this image
    serve_res = client.get(image_url)
    assert serve_res.status_code == 200
    assert serve_res.content_type == 'image/png'
    assert len(serve_res.data) > 0


def test_delete_lost_found_image_cleans_up_disk_file(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    # Upload image
    img_bytes = _create_test_image(format='PNG')
    upload_res = client.post(
        '/api/v1/lost-found/upload-image',
        data={'image': (img_bytes, 'to_delete.png', 'image/png')},
        content_type='multipart/form-data',
    )
    image_url = upload_res.get_json()['data']['image_url']
    filename = image_url.split('/uploads/lost_found/')[-1]
    saved_file = tmp_path / 'lost_found' / filename
    assert saved_file.exists()

    # Associate image with item 1
    add_res = client.post('/api/v1/lost-found/1/images', json={'image_url': image_url})
    assert add_res.status_code == 201
    image_id = add_res.get_json()['data']['image_id']

    # Delete the image
    del_res = client.delete(f'/api/v1/lost-found/images/{image_id}')
    assert del_res.status_code == 200

    # Physical file should be safely removed
    assert not saved_file.exists()


def test_delete_lost_found_item_cleans_up_all_item_files(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    # Upload two images
    img1_bytes = _create_test_image(format='PNG')
    up1 = client.post('/api/v1/lost-found/upload-image', data={'image': (img1_bytes, 'i1.png', 'image/png')}, content_type='multipart/form-data')
    url1 = up1.get_json()['data']['image_url']
    file1 = tmp_path / 'lost_found' / url1.split('/')[-1]

    img2_bytes = _create_test_image(format='JPEG')
    up2 = client.post('/api/v1/lost-found/upload-image', data={'file': (img2_bytes, 'i2.jpg', 'image/jpeg')}, content_type='multipart/form-data')
    url2 = up2.get_json()['data']['image_url']
    file2 = tmp_path / 'lost_found' / url2.split('/')[-1]

    assert file1.exists()
    assert file2.exists()

    # Create listing with url1
    create_res = client.post('/api/v1/lost-found', json={
        'item_type': 'LOST',
        'title': 'Item with Multiple Images',
        'description': 'Testing cleanup on item deletion',
        'image_url': url1,
    })
    assert create_res.status_code == 201
    new_item_id = create_res.get_json()['data']['item_id']

    # Add url2 as second image
    add2_res = client.post(f'/api/v1/lost-found/{new_item_id}/images', json={'image_url': url2})
    assert add2_res.status_code == 201

    # Delete the item as Org Admin (moderation role authorized to delete listings)
    mock_auth(monkeypatch, user_id=20, role='ORG_ADMIN', org_id=1)
    del_res = client.delete(f'/api/v1/lost-found/{new_item_id}')
    assert del_res.status_code == 200

    # Both files on disk must be unlinked
    assert not file1.exists()
    assert not file2.exists()


def test_delete_image_preserves_file_if_referenced_elsewhere(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    img_bytes = _create_test_image(format='PNG')
    up = client.post('/api/v1/lost-found/upload-image', data={'image': (img_bytes, 'shared.png', 'image/png')}, content_type='multipart/form-data')
    shared_url = up.get_json()['data']['image_url']
    saved_file = tmp_path / 'lost_found' / shared_url.split('/')[-1]
    assert saved_file.exists()

    # Associate shared_url with Item 1
    add1 = client.post('/api/v1/lost-found/1/images', json={'image_url': shared_url})
    img1_id = add1.get_json()['data']['image_id']

    # Also associate shared_url in a chat comment on Item 1
    comment_res = client.post('/api/v1/lost-found/1/comments', json={
        'message_type': 'IMAGE',
        'image_url': shared_url,
    })
    assert comment_res.status_code == 201

    # Delete the image row from Item 1
    del_res = client.delete(f'/api/v1/lost-found/images/{img1_id}')
    assert del_res.status_code == 200

    # Physical file MUST still exist because the chat comment still references it!
    assert saved_file.exists()


def test_delete_never_deletes_complaint_or_external_urls(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    # Seeded image 1 on Item 1 has image_url='/uploads/complaints/backpack.jpg'
    complaint_dir = tmp_path / 'complaints'
    complaint_dir.mkdir(parents=True, exist_ok=True)
    fake_complaint_file = complaint_dir / 'backpack.jpg'
    fake_complaint_file.write_bytes(b'complaint image content')
    assert fake_complaint_file.exists()

    # Delete image 1
    del_res = client.delete('/api/v1/lost-found/images/1')
    assert del_res.status_code == 200

    # Complaint file must NOT be deleted
    assert fake_complaint_file.exists()


def test_delete_database_failure_preserves_physical_files(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    img_bytes = _create_test_image(format='PNG')
    up = client.post('/api/v1/lost-found/upload-image', data={'image': (img_bytes, 'rollback_test.png', 'image/png')}, content_type='multipart/form-data')
    image_url = up.get_json()['data']['image_url']
    saved_file = tmp_path / 'lost_found' / image_url.split('/')[-1]
    assert saved_file.exists()

    add_res = client.post('/api/v1/lost-found/1/images', json={'image_url': image_url})
    img_id = add_res.get_json()['data']['image_id']

    # Simulate database commit error
    def fail_commit():
        raise RuntimeError("Database connection terminated")

    monkeypatch.setattr(db.session, 'commit', fail_commit)

    with pytest.raises(RuntimeError):
        client.delete(f'/api/v1/lost-found/images/{img_id}')

    # Physical file must still exist after rollback
    assert saved_file.exists()


def test_create_lost_found_with_dedicated_upload_url(client, monkeypatch, lf_test_app, tmp_path):
    mock_auth(monkeypatch, user_id=10, role='STUDENT', org_id=1)
    lf_test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    img_bytes = _create_test_image(format='JPEG')
    up = client.post('/api/v1/lost-found/upload-image', data={'image': (img_bytes, 'flow.jpg', 'image/jpeg')}, content_type='multipart/form-data')
    assert up.status_code == 201
    image_url = up.get_json()['data']['image_url']

    create_res = client.post('/api/v1/lost-found', json={
        'item_type': 'FOUND',
        'title': 'Found Sports Watch',
        'description': 'Found near the cricket pitch',
        'category': 'Electronics',
        'location': 'Cricket Ground',
        'image_url': image_url,
    })
    assert create_res.status_code == 201
    created_item = create_res.get_json()['data']
    assert created_item['images'][0]['image_url'] == image_url

    # Check detail endpoint
    get_res = client.get(f"/api/v1/lost-found/{created_item['item_id']}")
    assert get_res.status_code == 200
    assert get_res.get_json()['data']['images'][0]['image_url'] == image_url
