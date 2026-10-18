"""Tests for announcement attachments and multi-attachment management."""

import io
import os
import pytest
from types import SimpleNamespace

from app import create_app
from app.database import db
from app.models import Announcement, AnnouncementAttachment, AnnouncementLike, Organization, User


@pytest.fixture
def test_app(monkeypatch):
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    db.init_app(app)

    with app.app_context():
        Organization.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)
        Announcement.__table__.create(db.engine, checkfirst=True)
        AnnouncementAttachment.__table__.create(db.engine, checkfirst=True)
        AnnouncementLike.__table__.create(db.engine, checkfirst=True)
        yield app
        db.session.remove()


@pytest.fixture
def client(test_app):
    return test_app.test_client()


def _mock_auth(monkeypatch, user_id=1, org_id=1, role='ORG_ADMIN'):
    """Mock authentication so requests have an authenticated user with specified role and org."""
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


def test_upload_attachment_success(test_app, client, monkeypatch, tmp_path):
    _mock_auth(monkeypatch, role='ORG_ADMIN')
    test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    data = {
        'file': (io.BytesIO(b'%PDF-1.4 test content'), 'test_doc.pdf'),
    }
    res = client.post(
        '/api/v1/announcements/upload-attachment',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 201
    payload = res.get_json()['data']
    assert payload['attachment_type'] == 'PDF'
    assert payload['attachment_url'].startswith('/uploads/announcements/')
    assert payload['original_filename'] == 'test_doc.pdf'
    assert payload['file_size'] > 0


def test_upload_attachment_rejects_unallowed_extension(test_app, client, monkeypatch, tmp_path):
    _mock_auth(monkeypatch, role='ORG_ADMIN')
    test_app.config['UPLOAD_FOLDER'] = str(tmp_path)

    data = {
        'file': (io.BytesIO(b'malicious script'), 'payload.exe'),
    }
    res = client.post(
        '/api/v1/announcements/upload-attachment',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'File type not allowed' in res.get_json()['message']


def test_upload_attachment_forbidden_for_student(test_app, client, monkeypatch):
    _mock_auth(monkeypatch, role='STUDENT')

    data = {
        'file': (io.BytesIO(b'image data'), 'pic.png'),
    }
    res = client.post(
        '/api/v1/announcements/upload-attachment',
        data=data,
        content_type='multipart/form-data',
    )
    assert res.status_code == 403


def test_create_announcement_with_multiple_attachments(test_app, client, monkeypatch):
    _mock_auth(monkeypatch, user_id=1, org_id=1, role='ORG_ADMIN')

    payload = {
        'title': 'Hackathon 2026',
        'description': 'Register teams before Friday.',
        'is_important': True,
        'attachments': [
            {
                'attachment_type': 'IMAGE',
                'attachment_url': '/uploads/announcements/poster.png',
                'original_filename': 'poster.png',
            },
            {
                'attachment_type': 'PDF',
                'attachment_url': '/uploads/announcements/rules.pdf',
                'original_filename': 'rules.pdf',
            },
            {
                'attachment_type': 'LINK',
                'attachment_url': 'https://example.com/register',
            },
        ],
    }

    res = client.post('/api/v1/announcements', json=payload)
    assert res.status_code == 201
    data = res.get_json()['data']
    assert data['title'] == 'Hackathon 2026'
    assert len(data['attachments']) == 3
    assert data['attachment_type'] == 'IMAGE'
    assert data['attachment_url'] == '/uploads/announcements/poster.png'


def test_update_announcement_syncs_attachments(test_app, client, monkeypatch):
    _mock_auth(monkeypatch, user_id=1, org_id=1, role='ORG_ADMIN')

    with test_app.app_context():
        ann = Announcement(
            organization_id=1,
            created_by=1,
            title='Initial Notice',
            description='Initial description',
            is_important=False,
            attachment_type='NONE',
        )
        db.session.add(ann)
        db.session.commit()
        ann_id = ann.announcement_id

    update_payload = {
        'title': 'Updated Notice',
        'attachments': [
            {
                'attachment_type': 'LINK',
                'attachment_url': 'https://campushive.edu/docs',
            },
        ],
    }

    res = client.patch(f'/api/v1/announcements/{ann_id}', json=update_payload)
    assert res.status_code == 200
    data = res.get_json()['data']
    assert data['title'] == 'Updated Notice'
    assert len(data['attachments']) == 1
    assert data['attachments'][0]['attachment_type'] == 'LINK'
    assert data['attachment_type'] == 'LINK'
    assert data['attachment_url'] == 'https://campushive.edu/docs'


def test_organization_isolation(test_app, client, monkeypatch):
    # User in org 2
    _mock_auth(monkeypatch, user_id=5, org_id=2, role='ORG_ADMIN')

    with test_app.app_context():
        # Announcement in org 1
        ann = Announcement(
            organization_id=1,
            created_by=1,
            title='Org 1 Notice',
            description='Only for Org 1',
        )
        db.session.add(ann)
        db.session.commit()
        ann_id = ann.announcement_id

    # User in org 2 tries to GET or PATCH
    get_res = client.get(f'/api/v1/announcements/{ann_id}')
    assert get_res.status_code == 404

    patch_res = client.patch(f'/api/v1/announcements/{ann_id}', json={'title': 'Hacked'})
    assert patch_res.status_code == 404


def test_legacy_announcement_serialization(test_app, client, monkeypatch):
    _mock_auth(monkeypatch, user_id=1, org_id=1, role='STUDENT')

    with test_app.app_context():
        ann = Announcement(
            organization_id=1,
            created_by=1,
            title='Legacy Circular',
            description='Legacy description with single attachment',
            attachment_type='IMAGE',
            attachment_url='https://example.com/legacy_poster.jpg',
            is_important=False,
        )
        db.session.add(ann)
        db.session.commit()
        ann_id = ann.announcement_id

    res = client.get(f'/api/v1/announcements/{ann_id}')
    assert res.status_code == 200
    data = res.get_json()['data']
    assert data['attachment_type'] == 'IMAGE'
    assert data['attachment_url'] == 'https://example.com/legacy_poster.jpg'
    assert len(data['attachments']) == 1
    assert data['attachments'][0]['attachment_type'] == 'IMAGE'
    assert data['attachments'][0]['attachment_url'] == 'https://example.com/legacy_poster.jpg'
