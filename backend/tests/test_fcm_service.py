"""Tests for Firebase Cloud Messaging (FCM) service.

Tests cover:
- Sending a push to a user with a valid token
- Skipping users without tokens
- Multiple recipients
- Invalid/unregistered token cleanup
- Transient FCM errors (preserving token)
- Notification dispatch after successful commit
- No dispatch after rollback
- FCM failures do not break the original business operation
- Multiple notifications in one transaction
- No duplicate dispatch
- Safe string-only data payload
- No logging of raw tokens or credentials
"""

from unittest.mock import MagicMock, patch
import pytest

from firebase_admin import exceptions as firebase_exceptions
from firebase_admin import messaging

from app import create_app
from app.database import db
from app.models import (
    Complaint,
    ComplaintStatusHistory,
    Department,
    Notification,
    Organization,
    User,
)
from app.services.auth_service import AuthService
from app.services.fcm_service import FcmService
from app.services.notification_service import NotificationService


@pytest.fixture
def test_app(monkeypatch):
    """Set up test Flask application with in-memory SQLite database."""
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    db.init_app(app)

    with app.app_context():
        # Prevent index name collision in SQLite
        for table in [Complaint, ComplaintStatusHistory, Notification]:
            for idx in list(table.__table__.indexes):
                idx.name = f"idx_{table.__tablename__}_{idx.name}"

        Organization.__table__.create(db.engine, checkfirst=True)
        Department.__table__.create(db.engine, checkfirst=True)
        User.__table__.create(db.engine, checkfirst=True)
        Complaint.__table__.create(db.engine, checkfirst=True)
        ComplaintStatusHistory.__table__.create(db.engine, checkfirst=True)
        Notification.__table__.create(db.engine, checkfirst=True)

        org = Organization(
            organization_id=1,
            organization_name='KSIT',
            organization_code='KSIT',
            email_domain='ksit.edu.in',
            is_active=True,
        )
        dept = Department(
            department_id=1,
            organization_id=1,
            department_name='Maintenance',
        )
        db.session.add_all([org, dept])
        db.session.commit()

        # Ensure listeners are attached for the test session
        FcmService._ensure_listeners()

        yield app

        db.session.rollback()
        db.drop_all()


def _create_user(user_id=1, full_name='Test User', email='test@ksit.edu.in', fcm_token='token_123', role='STUDENT'):
    user = User(
        user_id=user_id,
        organization_id=1,
        full_name=full_name,
        email=email,
        firebase_uid=f'uid_{user_id}',
        fcm_token=fcm_token,
        role=role,
    )
    db.session.add(user)
    db.session.commit()
    return user


def test_send_to_user_with_valid_token(test_app, monkeypatch):
    """Sending a push to a user with a valid token succeeds and formats message correctly."""
    user = _create_user(user_id=1, fcm_token='valid_device_token_xyz')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(return_value='projects/test/messages/msg_123')
    monkeypatch.setattr(messaging, 'send', mock_send)

    result = FcmService.send_to_user(
        user_id=user.user_id,
        title='Complaint Resolved',
        message='Your complaint #42 has been resolved.',
        data={'notification_type': 'COMPLAINT', 'reference_id': 42},
    )

    assert result is True
    assert mock_send.call_count == 1

    fcm_message = mock_send.call_args[0][0]
    assert fcm_message.token == 'valid_device_token_xyz'
    assert fcm_message.notification.title == 'Complaint Resolved'
    assert fcm_message.notification.body == 'Your complaint #42 has been resolved.'
    assert fcm_message.data == {'notification_type': 'COMPLAINT', 'reference_id': '42'}
    assert fcm_message.android.priority == 'high'
    assert fcm_message.android.notification.channel_id == 'campushive_notifications'


def test_skip_user_without_token(test_app, monkeypatch):
    """User without an FCM token is skipped without attempting to send or raising errors."""
    user = _create_user(user_id=2, email='notoken@ksit.edu.in', fcm_token=None)

    mock_send = MagicMock()
    monkeypatch.setattr(messaging, 'send', mock_send)

    result = FcmService.send_to_user(
        user_id=user.user_id,
        title='New Announcement',
        message='Campus closed tomorrow.',
    )

    assert result is False
    mock_send.assert_not_called()


def test_skip_nonexistent_user(test_app, monkeypatch):
    """Non-existent user ID is handled gracefully."""
    mock_send = MagicMock()
    monkeypatch.setattr(messaging, 'send', mock_send)

    result = FcmService.send_to_user(
        user_id=999999,
        title='Title',
        message='Message',
    )

    assert result is False
    mock_send.assert_not_called()


def test_send_to_multiple_recipients(test_app, monkeypatch):
    """Multiple recipients are handled: tokens sent, missing tokens skipped, tallies returned."""
    user1 = _create_user(user_id=10, email='u10@ksit.edu.in', fcm_token='tok_10')
    user2 = _create_user(user_id=11, email='u11@ksit.edu.in', fcm_token=None)
    user3 = _create_user(user_id=12, email='u12@ksit.edu.in', fcm_token='tok_12')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(return_value='msg_ok')
    monkeypatch.setattr(messaging, 'send', mock_send)

    stats = FcmService.send_to_users(
        user_ids=[user1.user_id, user2.user_id, user3.user_id],
        title='Notice',
        message='Meeting at 3 PM',
        data={'notification_type': 'ANNOUNCEMENT', 'reference_id': 99},
    )

    assert stats == {'total': 3, 'sent': 2, 'skipped': 1, 'failed': 0}
    assert mock_send.call_count == 2


def test_invalid_unregistered_token_cleanup(test_app, monkeypatch):
    """Unregistered device tokens are cleared from the User record in MySQL."""
    user = _create_user(user_id=20, email='unreg@ksit.edu.in', fcm_token='invalid_stale_token')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(side_effect=messaging.UnregisteredError('The registration token is not registered'))
    monkeypatch.setattr(messaging, 'send', mock_send)

    result = FcmService.send_to_user(
        user_id=user.user_id,
        title='Alert',
        message='Update available',
    )

    assert result is False
    assert mock_send.call_count == 1

    db.session.expire_all()
    refreshed_user = db.session.get(User, user.user_id)
    assert refreshed_user.fcm_token is None


def test_sender_id_mismatch_cleans_token(test_app, monkeypatch):
    """Tokens with sender ID mismatch are detected and cleared."""
    user = _create_user(user_id=21, email='mismatch@ksit.edu.in', fcm_token='mismatched_token')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(side_effect=messaging.SenderIdMismatchError('Sender ID does not match'))
    monkeypatch.setattr(messaging, 'send', mock_send)

    result = FcmService.send_to_user(
        user_id=user.user_id,
        title='Alert',
        message='Test',
    )

    assert result is False
    db.session.expire_all()
    refreshed_user = db.session.get(User, user.user_id)
    assert refreshed_user.fcm_token is None


def test_transient_error_preserves_valid_token(test_app, monkeypatch):
    """Transient network/server errors do not clear valid device tokens."""
    user = _create_user(user_id=30, email='transient@ksit.edu.in', fcm_token='valid_token_30')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(side_effect=firebase_exceptions.UnavailableError('FCM service temporarily unavailable'))
    monkeypatch.setattr(messaging, 'send', mock_send)

    result = FcmService.send_to_user(
        user_id=user.user_id,
        title='Alert',
        message='Test',
    )

    assert result is False
    db.session.expire_all()
    refreshed_user = db.session.get(User, user.user_id)
    assert refreshed_user.fcm_token == 'valid_token_30'


def test_post_commit_dispatch_via_notification_service(test_app, monkeypatch):
    """Notifications are queued during transaction and dispatched only after commit."""
    user = _create_user(user_id=40, email='postcommit@ksit.edu.in', fcm_token='token_40')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(return_value='msg_ok')
    monkeypatch.setattr(messaging, 'send', mock_send)

    # 1. Create notification inside transaction
    notif = NotificationService.create_notification(
        user_id=user.user_id,
        title='Complaint Assigned',
        message='A supervisor was assigned to complaint #10.',
        notification_type='COMPLAINT',
        reference_id=10,
    )
    assert notif is not None

    # Before commit, no push must be sent
    mock_send.assert_not_called()

    # 2. Commit transaction
    db.session.commit()

    # After commit, push must be dispatched
    assert mock_send.call_count == 1
    sent_msg = mock_send.call_args[0][0]
    assert sent_msg.token == 'token_40'
    assert sent_msg.notification.title == 'Complaint Assigned'
    assert sent_msg.data['reference_id'] == '10'


def test_no_dispatch_after_rollback(test_app, monkeypatch):
    """Queued pushes are discarded when a transaction rolls back."""
    user = _create_user(user_id=50, email='rollback@ksit.edu.in', fcm_token='token_50')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(return_value='msg_ok')
    monkeypatch.setattr(messaging, 'send', mock_send)

    # Stage notification
    NotificationService.create_notification(
        user_id=user.user_id,
        title='Will Rollback',
        message='This should never be pushed.',
        notification_type='COMPLAINT',
        reference_id=999,
    )

    mock_send.assert_not_called()

    # Roll back transaction
    db.session.rollback()

    mock_send.assert_not_called()

    # Even a subsequent unrelated commit must not dispatch the rolled back notification
    db.session.commit()
    mock_send.assert_not_called()


def test_fcm_failure_does_not_break_business_operation(test_app, monkeypatch):
    """FCM delivery failures post-commit never break business operations or throw exceptions."""
    user = _create_user(user_id=60, email='failure_safe@ksit.edu.in', fcm_token='token_60')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(side_effect=RuntimeError('Fatal FCM unexpected failure'))
    monkeypatch.setattr(messaging, 'send', mock_send)

    NotificationService.create_notification(
        user_id=user.user_id,
        title='Important Update',
        message='Complaint created.',
        notification_type='COMPLAINT',
        reference_id=55,
    )

    # Must commit cleanly without raising RuntimeError
    db.session.commit()

    # Notification record in database exists and is valid
    saved_notif = Notification.query.filter_by(user_id=user.user_id).first()
    assert saved_notif is not None
    assert saved_notif.title == 'Important Update'


def test_multiple_notifications_in_one_transaction(test_app, monkeypatch):
    """Multiple notifications created in one transaction are all dispatched post-commit."""
    user1 = _create_user(user_id=71, email='m1@ksit.edu.in', fcm_token='token_71')
    user2 = _create_user(user_id=72, email='m2@ksit.edu.in', fcm_token='token_72')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(return_value='msg_ok')
    monkeypatch.setattr(messaging, 'send', mock_send)

    NotificationService.create_notification(
        user_id=user1.user_id,
        title='Notification 1',
        message='Message for user 1',
        notification_type='COMPLAINT',
        reference_id=101,
    )
    NotificationService.create_notification(
        user_id=user2.user_id,
        title='Notification 2',
        message='Message for user 2',
        notification_type='COMPLAINT',
        reference_id=101,
    )

    mock_send.assert_not_called()

    db.session.commit()

    assert mock_send.call_count == 2
    sent_tokens = {call[0][0].token for call in mock_send.call_args_list}
    assert sent_tokens == {'token_71', 'token_72'}


def test_no_duplicate_dispatch_on_subsequent_commits(test_app, monkeypatch):
    """Queued notifications are popped and dispatched exactly once."""
    user = _create_user(user_id=80, email='nodup@ksit.edu.in', fcm_token='token_80')

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(return_value='msg_ok')
    monkeypatch.setattr(messaging, 'send', mock_send)

    NotificationService.create_notification(
        user_id=user.user_id,
        title='Single Push',
        message='Only send once',
        notification_type='ANNOUNCEMENT',
        reference_id=200,
    )

    db.session.commit()
    assert mock_send.call_count == 1

    # Subsequent unrelated commit in the same session
    db.session.commit()
    assert mock_send.call_count == 1


def test_data_payload_formatting():
    """Data payload stringifies supported types and drops None values."""
    raw_data = {
        'notification_type': 'COMPLAINT',
        'reference_id': 123,
        'extra_flag': True,
        'ignored_none': None,
    }
    payload = FcmService._build_data_payload(raw_data)
    assert payload == {
        'notification_type': 'COMPLAINT',
        'reference_id': '123',
        'extra_flag': 'True',
    }


def test_no_raw_tokens_or_credentials_logged(test_app, monkeypatch, caplog):
    """Raw FCM tokens and credentials must never appear in log messages."""
    secret_token = 'secret_raw_device_token_super_private_999'
    user = _create_user(user_id=90, email='nolog@ksit.edu.in', fcm_token=secret_token)

    monkeypatch.setattr(AuthService, '_ensure_firebase_app', lambda: None)
    mock_send = MagicMock(side_effect=messaging.UnregisteredError('Device unregistered'))
    monkeypatch.setattr(messaging, 'send', mock_send)

    with caplog.at_level('DEBUG'):
        FcmService.send_to_user(
            user_id=user.user_id,
            title='Test',
            message='Test body',
        )

    log_output = caplog.text
    assert secret_token not in log_output
    assert 'Cleared invalid FCM token for user_id=90' in log_output
