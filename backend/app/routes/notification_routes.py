"""Notification routes for CampusHive."""

from flask import Blueprint, g, request

from app.middleware.firebase_auth import firebase_login_required, role_required
from app.services.notification_service import NotificationService, NotificationServiceError
from app.utils.helpers import error_response, success_response


notif_bp = Blueprint('notifications', __name__)


def _parse_pagination_args():
    page_value = request.args.get('page', '1')
    per_page_value = request.args.get('per_page', '20')

    try:
        page = int(page_value)
        per_page = int(per_page_value)
    except (TypeError, ValueError):
        return None, None, error_response('validation_error', 'Invalid pagination parameters', 400)

    if page < 1 or per_page < 1:
        return None, None, error_response('validation_error', 'Invalid pagination parameters', 400)

    return page, per_page, None


@notif_bp.route('', methods=['GET'])
@firebase_login_required
@role_required()
def get_notifications():
    """Get the current user's notifications."""

    page, per_page, error = _parse_pagination_args()
    if error:
        return error

    unread_only = str(request.args.get('unread_only', '')).strip().lower() in {'true', '1', 'yes', 'on'}
    notification_type = request.args.get('type')

    try:
        result = NotificationService.get_notifications(
            g.current_user,
            page,
            per_page,
            unread_only=unread_only,
            notification_type=notification_type,
        )
    except NotificationServiceError as exc:
        return error_response(exc.error_code, exc.message, exc.status_code)

    return success_response(result, 'Notifications retrieved', 200)


@notif_bp.route('/unread-count', methods=['GET'])
@firebase_login_required
@role_required()
def get_unread_count():
    """Get unread notification count for the current user."""

    count = NotificationService.get_unread_count(g.current_user)
    return success_response({'count': count}, 'Unread notifications count retrieved', 200)


@notif_bp.route('/<int:notification_id>/read', methods=['PATCH'])
@firebase_login_required
@role_required()
def mark_notification_read(notification_id):
    """Mark one notification as read."""

    try:
        notification = NotificationService.mark_as_read(notification_id, g.current_user)
    except NotificationServiceError as exc:
        return error_response(exc.error_code, exc.message, exc.status_code)

    return success_response(notification.to_dict(), 'Notification marked as read', 200)


@notif_bp.route('/read-all', methods=['PATCH'])
@firebase_login_required
@role_required()
def mark_all_notifications_read():
    """Mark all unread notifications as read."""

    try:
        updated_count = NotificationService.mark_all_as_read(g.current_user)
    except NotificationServiceError as exc:
        return error_response(exc.error_code, exc.message, exc.status_code)

    return success_response({'updated_count': updated_count}, 'All notifications marked as read', 200)


@notif_bp.route('/<int:notification_id>', methods=['DELETE'])
@firebase_login_required
@role_required()
def delete_notification(notification_id):
    """Delete one notification belonging to the current user."""

    try:
        NotificationService.delete_notification(notification_id, g.current_user)
    except NotificationServiceError as exc:
        return error_response(exc.error_code, exc.message, exc.status_code)

    return success_response({}, 'Notification deleted', 200)
