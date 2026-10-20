"""Firebase Cloud Messaging (FCM) push notification service for CampusHive.

Delivers push notifications to authenticated users' devices via Firebase Admin SDK.
MySQL notification records remain the source of truth.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional, Sequence

import firebase_admin
from firebase_admin import exceptions as firebase_exceptions
from firebase_admin import messaging
from flask import current_app
from sqlalchemy import event
from sqlalchemy.orm import Session

from app.database import db
from app.models import User
from app.services.auth_service import AuthService

logger = logging.getLogger(__name__)


def _log_debug(msg: str, *args: Any) -> None:
    try:
        current_app.logger.debug(msg, *args)
    except Exception:
        logger.debug(msg, *args)


def _log_info(msg: str, *args: Any) -> None:
    try:
        current_app.logger.info(msg, *args)
    except Exception:
        logger.info(msg, *args)


def _log_warning(msg: str, *args: Any) -> None:
    try:
        current_app.logger.warning(msg, *args)
    except Exception:
        logger.warning(msg, *args)


def _log_error(msg: str, *args: Any) -> None:
    try:
        current_app.logger.error(msg, *args)
    except Exception:
        logger.error(msg, *args)


class FcmService:
    """Service for dispatching Firebase Cloud Messaging push notifications."""

    _listeners_attached: bool = False
    _is_dispatching: bool = False
    enabled: bool = True

    @classmethod
    def _ensure_firebase_app(cls) -> None:
        """Initialize Firebase Admin SDK via AuthService if not already initialized."""
        AuthService._ensure_firebase_app()

    @classmethod
    def _ensure_listeners(cls) -> None:
        """Register SQLAlchemy session commit and rollback event listeners once."""
        if cls._listeners_attached:
            return

        if not event.contains(db.session, 'after_commit', cls._on_session_commit):
            event.listen(db.session, 'after_commit', cls._on_session_commit)

        if not event.contains(db.session, 'after_rollback', cls._on_session_rollback):
            event.listen(db.session, 'after_rollback', cls._on_session_rollback)

        if not event.contains(db.session, 'after_soft_rollback', cls._on_session_rollback):
            event.listen(db.session, 'after_soft_rollback', cls._on_session_rollback)

        cls._listeners_attached = True

    @classmethod
    def _on_session_commit(cls, session: Any, *args: Any, **kwargs: Any) -> None:
        """SQLAlchemy after_commit hook: dispatches queued notifications post-commit."""
        pending = session.info.pop('pending_fcm_notifications', None)
        if not pending:
            return

        try:
            cls.dispatch_pending_notifications(pending)
        except Exception as exc:
            _log_warning(
                "Error dispatching pending FCM notifications after commit: %s",
                exc.__class__.__name__,
            )

    @classmethod
    def _on_session_rollback(cls, session: Any, *args: Any, **kwargs: Any) -> None:
        """SQLAlchemy after_rollback hook: discards queued notifications on rollback."""
        session.info.pop('pending_fcm_notifications', None)

    @classmethod
    def stage_notification(
        cls,
        user_id: int,
        title: str,
        message: str,
        notification_type: Optional[str] = None,
        reference_id: Optional[int] = None,
        session: Optional[Any] = None,
    ) -> None:
        """Stage an FCM notification to be dispatched after the transaction commits."""
        cls._ensure_listeners()

        sess = session or db.session
        queue = sess.info.setdefault('pending_fcm_notifications', [])

        item = {
            'user_id': int(user_id),
            'title': str(title).strip(),
            'message': str(message).strip(),
            'notification_type': str(notification_type) if notification_type else None,
            'reference_id': int(reference_id) if reference_id is not None else None,
        }

        # Avoid duplicate queuing for the exact same notification in the same transaction
        if item not in queue:
            queue.append(item)

    @classmethod
    def _is_invalid_or_unregistered_token_error(cls, exc: Exception) -> bool:
        """Check whether the exception indicates that the FCM device token is permanently invalid or unregistered."""
        # Check specific Firebase Admin exception types
        if isinstance(exc, (messaging.UnregisteredError, messaging.SenderIdMismatchError)):
            return True

        if isinstance(exc, (firebase_exceptions.NotFoundError, firebase_exceptions.InvalidArgumentError)):
            return True

        # Check for message strings or error codes returned by FCM
        err_msg = str(exc).lower()
        invalid_patterns = (
            'unregistered',
            'registration-token-not-registered',
            'invalid-registration-token',
            'mismatched-credential',
            'not a valid fcm registration token',
        )
        return any(pattern in err_msg for pattern in invalid_patterns)

    @classmethod
    def _clear_invalid_token(cls, user_id: int, token_used: str) -> None:
        """Clear user's fcm_token using an isolated database session to prevent session corruption or event recursion."""
        try:
            with Session(db.engine) as cleanup_session:
                user = cleanup_session.get(User, user_id)
                if user and user.fcm_token == token_used:
                    user.fcm_token = None
                    cleanup_session.commit()
                    _log_info("Cleared invalid FCM token for user_id=%s", user_id)
        except Exception as exc:
            _log_warning(
                "Failed to clear invalid FCM token for user_id=%s: %s",
                user_id,
                exc.__class__.__name__,
            )
        finally:
            try:
                db.session.expire_all()
            except Exception:
                pass

    @classmethod
    def _build_data_payload(cls, data: Optional[Dict[str, Any]] = None) -> Dict[str, str]:
        """Convert data dictionary keys and values to strings as required by Firebase Admin SDK."""
        payload: Dict[str, str] = {}
        if not data:
            return payload

        for key, value in data.items():
            if value is not None:
                payload[str(key)] = str(value)

        return payload

    @classmethod
    def send_to_user(
        cls,
        user_id: int,
        title: str,
        message: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """Send an FCM push notification to a user's registered device.

        Returns True if the message was sent successfully, or False if skipped/failed.
        Never raises exceptions to callers; pushes fail gracefully.
        Never logs raw tokens or credentials.
        """
        if not cls.enabled:
            return False

        try:
            # Query user using an isolated Session on db.engine so this function can be
            # safely called inside after_commit or when the main session is committed.
            with Session(db.engine) as session:
                user = session.get(User, user_id)
                if not user or not user.fcm_token:
                    _log_debug("Skipping FCM push for user_id=%s (no registered token)", user_id)
                    return False
                token = user.fcm_token
        except Exception as exc:
            _log_warning(
                "Database error looking up user token for user_id=%s: %s",
                user_id,
                exc.__class__.__name__,
            )
            return False

        try:
            cls._ensure_firebase_app()
        except Exception as exc:
            _log_warning("Firebase Admin not configured for FCM push: %s", exc.__class__.__name__)
            return False

        clean_data = cls._build_data_payload(data)

        try:
            fcm_notification = messaging.Notification(
                title=title,
                body=message,
            )
            fcm_message = messaging.Message(
                notification=fcm_notification,
                data=clean_data if clean_data else None,
                token=token,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='campushive_notifications',
                    ),
                ),
            )

            messaging.send(fcm_message)
            _log_info("FCM push sent successfully to user_id=%s", user_id)
            return True

        except Exception as exc:
            _log_warning(
                "FCM push delivery failed for user_id=%s: %s",
                user_id,
                exc.__class__.__name__,
            )
            if cls._is_invalid_or_unregistered_token_error(exc):
                cls._clear_invalid_token(user_id, token)
            return False

    @classmethod
    def send_to_users(
        cls,
        user_ids: Sequence[int],
        title: str,
        message: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, int]:
        """Send an FCM push notification to multiple users.

        Returns a dictionary summarizing the result:
        {'total': int, 'sent': int, 'skipped': int, 'failed': int}
        """
        unique_user_ids = list(dict.fromkeys(user_ids)) if user_ids else []
        stats = {
            'total': len(unique_user_ids),
            'sent': 0,
            'skipped': 0,
            'failed': 0,
        }

        if not unique_user_ids:
            return stats

        for uid in unique_user_ids:
            try:
                with Session(db.engine) as session:
                    user = session.get(User, uid)
                    has_token = bool(user and user.fcm_token)
            except Exception:
                has_token = False

            if not has_token:
                stats['skipped'] += 1
                continue

            success = cls.send_to_user(uid, title, message, data=data)
            if success:
                stats['sent'] += 1
            else:
                stats['failed'] += 1

        return stats

    @classmethod
    def dispatch_pending_notifications(
        cls,
        pending_items: Sequence[Dict[str, Any]],
    ) -> None:
        """Dispatch queued notifications staged during business transactions."""
        if not pending_items or cls._is_dispatching:
            return

        cls._is_dispatching = True
        try:
            for item in pending_items:
                user_id = item.get('user_id')
                title = item.get('title')
                message = item.get('message')
                notification_type = item.get('notification_type')
                reference_id = item.get('reference_id')

                if not user_id or not title or not message:
                    continue

                data: Dict[str, Any] = {}
                if notification_type:
                    data['notification_type'] = notification_type
                if reference_id is not None:
                    data['reference_id'] = reference_id

                try:
                    cls.send_to_user(user_id, title, message, data=data)
                except Exception as exc:
                    _log_warning(
                        "Unexpected failure in dispatch_pending_notifications for user_id=%s: %s",
                        user_id,
                        exc.__class__.__name__,
                    )
        finally:
            cls._is_dispatching = False


# Register event listeners on import
FcmService._ensure_listeners()
