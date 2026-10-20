"""Unit and integration tests for Profile Picture Upload:
- Successful upload and persistence for JPEG, PNG, and WebP
- Unauthenticated and inactive user rejection
- Unsupported file extensions
- Spoofed MIME types and malformed images
- Empty and oversized files
- Database update failure and file cleanup
- Old image cleanup after successful update
- Preservation of external, complaint, and Lost & Found image files
- Preservation of profile images referenced by other users
- Isolation ensuring client cannot change another user's profile picture
"""

import io
import os
import pytest
from PIL import Image

from app import create_app
from app.database import db
from app.models import Organization, AcademicDepartment, Department, User
from app.services.auth_service import AuthService


def _create_test_image(format='PNG', size=(100, 100), color='blue'):
    """Helper to generate a valid in-memory image."""
    buf = io.BytesIO()
    img = Image.new('RGB', size, color=color)
    img.save(buf, format=format)
    buf.seek(0)
    return buf.getvalue()


@pytest.fixture
def profile_test_app(monkeypatch, tmp_path):
    """Set up test Flask app with in-memory SQLite and temporary upload directory."""
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['UPLOAD_FOLDER'] = str(tmp_path)
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


# ==================== 1. SUCCESSFUL PROFILE IMAGE UPLOADS ====================

def test_upload_profile_image_png_success(client, profile_test_app):
    """Verify successful upload of a PNG profile picture."""
    img_bytes = _create_test_image('PNG')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img_bytes), 'avatar.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    assert 'image_url' in data['data']
    image_url = data['data']['image_url']
    assert image_url.startswith('/uploads/profile/')
    assert image_url.endswith('.png')
    assert data['data']['user']['profile_image'] == image_url

    # Check database persistence
    with profile_test_app.app_context():
        user = db.session.get(User, 101)
        assert user.profile_image == image_url

    # Check file exists in upload directory
    upload_folder = profile_test_app.config['UPLOAD_FOLDER']
    filename = os.path.basename(image_url)
    saved_path = os.path.join(upload_folder, 'profile', filename)
    assert os.path.exists(saved_path)


def test_upload_profile_image_jpeg_success(client, profile_test_app):
    """Verify successful upload of a JPEG profile picture."""
    img_bytes = _create_test_image('JPEG')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'file': (io.BytesIO(img_bytes), 'photo.jpg', 'image/jpeg')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    image_url = data['data']['image_url']
    assert image_url.startswith('/uploads/profile/')
    assert image_url.endswith('.jpg')


def test_upload_profile_image_webp_success(client, profile_test_app):
    """Verify successful upload of a WebP profile picture."""
    img_bytes = _create_test_image('WEBP')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img_bytes), 'modern.webp', 'image/webp')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 200
    data = res.get_json()
    assert data['success'] is True
    image_url = data['data']['image_url']
    assert image_url.startswith('/uploads/profile/')
    assert image_url.endswith('.webp')


# ==================== 2. AUTHENTICATION & ACCESS CONTROL ====================

def test_upload_profile_image_unauthenticated(client):
    """Verify unauthenticated request returns 401."""
    img_bytes = _create_test_image('PNG')
    res = client.post(
        '/api/v1/auth/profile-image',
        data={'image': (io.BytesIO(img_bytes), 'avatar.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 401


def test_upload_profile_image_inactive_user(client):
    """Verify inactive user cannot upload a profile image."""
    img_bytes = _create_test_image('PNG')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-inactive-103'),
        data={'image': (io.BytesIO(img_bytes), 'avatar.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 403


def test_upload_cannot_modify_another_user(client, profile_test_app):
    """Verify user 101's upload never modifies user 102 even with client-supplied user_id in query or form."""
    img_bytes = _create_test_image('PNG')
    res = client.post(
        '/api/v1/auth/profile-image?user_id=102',
        headers=_auth_header('token-student-101'),
        data={
            'image': (io.BytesIO(img_bytes), 'avatar.png', 'image/png'),
            'user_id': '102',
        },
        content_type='multipart/form-data',
    )
    assert res.status_code == 200

    with profile_test_app.app_context():
        user101 = db.session.get(User, 101)
        user102 = db.session.get(User, 102)
        assert user101.profile_image is not None
        assert user102.profile_image is None


# ==================== 3. VALIDATION & SECURITY ====================

def test_upload_missing_file_key(client):
    """Verify request without file key returns 400."""
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'something_else': 'data'},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'No image file provided' in res.get_json()['message']


def test_upload_empty_filename(client):
    """Verify upload with empty filename returns 400."""
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(b'content'), '', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'No image selected' in res.get_json()['message']


@pytest.mark.parametrize('unsupported_ext', ['avatar.txt', 'script.exe', 'image.gif', 'pic.bmp'])
def test_upload_unsupported_extensions(client, unsupported_ext):
    """Verify unsupported file extensions are rejected."""
    img_bytes = _create_test_image('PNG')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img_bytes), unsupported_ext, 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'File type not allowed' in res.get_json()['message']


def test_upload_spoofed_mime_type(client):
    """Verify spoofed MIME type (e.g. text/plain for a png filename) is rejected."""
    img_bytes = _create_test_image('PNG')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img_bytes), 'avatar.png', 'text/plain')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'Invalid MIME type for image' in res.get_json()['message']


def test_upload_corrupted_image(client):
    """Verify malformed content disguised as PNG is rejected by Pillow validation."""
    fake_bytes = b'NotARealImageFileContentHeader'
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(fake_bytes), 'fake.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'Invalid or corrupted image file' in res.get_json()['message']


def test_upload_empty_file(client):
    """Verify 0-byte file is rejected."""
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(b''), 'empty.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'File cannot be empty' in res.get_json()['message']


def test_upload_oversized_file(client):
    """Verify files larger than 5MB are rejected."""
    # 5MB + 1 byte
    oversized = io.BytesIO(b'x' * (5 * 1024 * 1024 + 1))
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (oversized, 'big.jpg', 'image/jpeg')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 400
    assert 'exceeds 5MB limit' in res.get_json()['message']


# ==================== 4. DATABASE FAILURE & CLEANUP ====================

def test_db_failure_cleans_up_newly_written_file(client, profile_test_app, monkeypatch):
    """Verify that if database commit fails, the newly uploaded image file is deleted."""
    upload_folder = profile_test_app.config['UPLOAD_FOLDER']
    img_bytes = _create_test_image('PNG')

    def fail_commit():
        raise Exception('Simulated database error')

    monkeypatch.setattr(db.session, 'commit', fail_commit)

    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img_bytes), 'avatar.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 500

    profile_dir = os.path.join(upload_folder, 'profile')
    if os.path.exists(profile_dir):
        # No orphan files should remain in the directory
        assert len(os.listdir(profile_dir)) == 0


# ==================== 5. OLD IMAGE CLEANUP & PRESERVATION ====================

def test_old_profile_image_cleaned_up_after_update(client, profile_test_app):
    """Verify previously uploaded internal profile image is deleted after update."""
    upload_folder = profile_test_app.config['UPLOAD_FOLDER']
    profile_dir = os.path.join(upload_folder, 'profile')
    os.makedirs(profile_dir, exist_ok=True)

    # First upload
    img1 = _create_test_image('PNG', color='red')
    res1 = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img1), 'img1.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res1.status_code == 200
    old_url = res1.get_json()['data']['image_url']
    old_filename = os.path.basename(old_url)
    old_filepath = os.path.join(profile_dir, old_filename)
    assert os.path.exists(old_filepath)

    # Second upload replaces first
    img2 = _create_test_image('JPEG', color='green')
    res2 = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img2), 'img2.jpg', 'image/jpeg')},
        content_type='multipart/form-data',
    )
    assert res2.status_code == 200
    new_url = res2.get_json()['data']['image_url']
    new_filename = os.path.basename(new_url)
    new_filepath = os.path.join(profile_dir, new_filename)

    # Old file is deleted; new file exists
    assert not os.path.exists(old_filepath)
    assert os.path.exists(new_filepath)


def test_external_image_url_preserved(client, profile_test_app):
    """Verify external profile image URLs are not treated as local files to delete."""
    with profile_test_app.app_context():
        user = db.session.get(User, 101)
        user.profile_image = 'https://images.unsplash.com/photo-test-avatar.jpg'
        db.session.commit()

    img = _create_test_image('PNG')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img), 'new.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 200
    # Succeeded without errors attempting to delete external URL


def test_complaints_and_lost_found_image_preserved(client, profile_test_app):
    """Verify complaint or lost & found images are never deleted by profile update."""
    upload_folder = profile_test_app.config['UPLOAD_FOLDER']
    complaints_dir = os.path.join(upload_folder, 'complaints')
    os.makedirs(complaints_dir, exist_ok=True)
    complaint_file = os.path.join(complaints_dir, 'keep_me.jpg')
    with open(complaint_file, 'wb') as f:
        f.write(_create_test_image('JPEG'))

    with profile_test_app.app_context():
        user = db.session.get(User, 101)
        user.profile_image = '/uploads/complaints/keep_me.jpg'
        db.session.commit()

    # Upload new profile image
    img = _create_test_image('PNG')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img), 'new.png', 'image/png')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 200
    # Complaint file must still exist!
    assert os.path.exists(complaint_file)


def test_shared_profile_image_not_deleted(client, profile_test_app):
    """Verify that if two users share the same profile image path, user 101's update does not delete user 102's image."""
    upload_folder = profile_test_app.config['UPLOAD_FOLDER']
    profile_dir = os.path.join(upload_folder, 'profile')
    os.makedirs(profile_dir, exist_ok=True)
    shared_file = os.path.join(profile_dir, 'shared_avatar.png')
    with open(shared_file, 'wb') as f:
        f.write(_create_test_image('PNG'))

    shared_url = '/uploads/profile/shared_avatar.png'
    with profile_test_app.app_context():
        user1 = db.session.get(User, 101)
        user2 = db.session.get(User, 102)
        user1.profile_image = shared_url
        user2.profile_image = shared_url
        db.session.commit()

    # User 101 uploads new image
    img = _create_test_image('JPEG')
    res = client.post(
        '/api/v1/auth/profile-image',
        headers=_auth_header('token-student-101'),
        data={'image': (io.BytesIO(img), 'new.jpg', 'image/jpeg')},
        content_type='multipart/form-data',
    )
    assert res.status_code == 200

    # shared_file must NOT be deleted because user 102 still references it
    assert os.path.exists(shared_file)
