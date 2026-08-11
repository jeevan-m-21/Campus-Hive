"""Notification service for CampusHive."""

from flask import current_app

from app.database import db
from app.models import Notification
from app.utils.helpers import paginate_query


_NOTIFICATION_TYPES = {'COMPLAINT', 'ANNOUNCEMENT', 'LOST_FOUND', 'CHAT', 'SYSTEM'}


class NotificationServiceError(Exception):
    """Raised when notification operations fail."""

    def __init__(self, message, status_code=400, error_code='validation_error'):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.error_code = error_code


class NotificationService:
    """Reusable notification service."""

    @staticmethod
    def _normalize_type(notification_type):
        if notification_type is None:
            return None

        normalized_type = str(notification_type).strip().upper()
        if normalized_type not in _NOTIFICATION_TYPES:
            raise NotificationServiceError('Invalid notification type', 400, 'validation_error')

        return normalized_type

    @staticmethod
    def _validate_pagination(page, per_page):
        try:
            page = int(page)
            per_page = int(per_page)
        except (TypeError, ValueError):
            raise NotificationServiceError('Invalid pagination parameters', 400, 'validation_error')

        if page < 1 or per_page < 1:
            raise NotificationServiceError('Invalid pagination parameters', 400, 'validation_error')

        if per_page > 100:
            per_page = 100

        return page, per_page

    @staticmethod
    def _get_notification_or_404(notification_id, current_user):
        notification = Notification.query.filter_by(notification_id=notification_id).first()
        if notification is None:
            raise NotificationServiceError('Notification not found', 404, 'not_found')

        if notification.user_id != current_user.user_id:
            raise NotificationServiceError('You cannot access this notification', 403, 'forbidden')

        return notification

    @staticmethod
    def create_notification(user_id, title, message, notification_type, reference_id=None):
        """Create a new notification without committing the transaction."""

        if user_id in (None, ''):
            raise NotificationServiceError('user_id is required', 400, 'validation_error')

        try:
            user_id = int(user_id)
        except (TypeError, ValueError):
            raise NotificationServiceError('user_id must be an integer', 400, 'validation_error')

        if user_id < 1:
            raise NotificationServiceError('user_id must be a positive integer', 400, 'validation_error')

        title = (title or '').strip()
        message = (message or '').strip()
        if not title:
            raise NotificationServiceError('title is required', 400, 'validation_error')
        if not message:
            raise NotificationServiceError('message is required', 400, 'validation_error')

        normalized_type = NotificationService._normalize_type(notification_type)

        if reference_id in ('',):
            reference_id = None
        elif reference_id is not None:
            try:
                reference_id = int(reference_id)
            except (TypeError, ValueError):
                raise NotificationServiceError('reference_id must be an integer', 400, 'validation_error')

        notification = Notification(
            user_id=user_id,
            title=title,
            message=message,
            notification_type=normalized_type,
            reference_id=reference_id,
            is_read=False,
        )

        try:
            db.session.add(notification)
        except Exception as exc:
            current_app.logger.exception('Failed to stage notification creation')
            raise NotificationServiceError('Database failure while creating notification', 500, 'database_error') from exc

        return notification

    @staticmethod
    def get_notifications(current_user, page, per_page, unread_only=False, notification_type=None):
        """Fetch paginated notifications for the logged in user."""

        page, per_page = NotificationService._validate_pagination(page, per_page)
        normalized_type = NotificationService._normalize_type(notification_type)

        query = Notification.query.filter_by(user_id=current_user.user_id)

        if unread_only:
            query = query.filter(Notification.is_read.is_(False))

        if normalized_type:
            query = query.filter_by(notification_type=normalized_type)

        result = paginate_query(
            query.order_by(Notification.created_at.desc(), Notification.notification_id.desc()),
            page,
            per_page,
        )

        return result

    @staticmethod
    def get_unread_count(current_user):
        """Return unread notification count for the current user."""

        return Notification.query.filter_by(user_id=current_user.user_id).filter(
            Notification.is_read.is_(False)
        ).count()

    @staticmethod
    def mark_as_read(notification_id, current_user):
        """Mark one notification as read."""

        try:
            notification = NotificationService._get_notification_or_404(notification_id, current_user)

            if notification.is_read:
                raise NotificationServiceError('Notification is already marked as read', 400, 'validation_error')

            notification.is_read = True
            db.session.commit()
            return notification
        except NotificationServiceError:
            db.session.rollback()
            raise
        except Exception as exc:
            db.session.rollback()
            current_app.logger.exception('Failed to mark notification as read')
            raise NotificationServiceError('Database failure while updating notification', 500, 'database_error') from exc

    @staticmethod
    def mark_all_as_read(current_user):
        """Mark all unread notifications as read."""

        try:
            updated_count = Notification.query.filter_by(user_id=current_user.user_id).filter(
                Notification.is_read.is_(False)
            ).update({'is_read': True}, synchronize_session=False)
            db.session.commit()
            return updated_count
        except Exception as exc:
            db.session.rollback()
            current_app.logger.exception('Failed to mark all notifications as read')
            raise NotificationServiceError('Database failure while updating notifications', 500, 'database_error') from exc

    @staticmethod
    def delete_notification(notification_id, current_user):
        """Delete one notification belonging to the current user."""

        try:
            notification = NotificationService._get_notification_or_404(notification_id, current_user)
            db.session.delete(notification)
            db.session.commit()
            return True
        except NotificationServiceError:
            db.session.rollback()
            raise
        except Exception as exc:
            db.session.rollback()
            current_app.logger.exception('Failed to delete notification')
            raise NotificationServiceError('Database failure while deleting notification', 500, 'database_error') from exc