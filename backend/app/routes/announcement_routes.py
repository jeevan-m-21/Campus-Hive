"""Announcement routes for CampusHive."""

from flask import Blueprint, current_app, g, request

from app.database import db
from app.middleware.firebase_auth import firebase_login_required, role_required
from app.models import Announcement, AnnouncementLike, User
from app.services.notification_service import NotificationService, NotificationServiceError
from app.utils.helpers import error_response, get_pagination_params, paginate_query, success_response


announcement_bp = Blueprint('announcements', __name__)


_ATTACHMENT_TYPES = {'NONE', 'IMAGE', 'PDF', 'LINK'}
_ANNOUNCEMENT_NOTIFICATION_ROLES = {'STUDENT', 'SUPERVISOR'}


def _get_request_data():
    return request.get_json(silent=True) or {}


def _normalize_text(value):
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _parse_boolean(value, field_name):
    if isinstance(value, bool):
        return value, None

    if value in (None, ''):
        return None, error_response('validation_error', f'{field_name} must be a boolean', 400)

    normalized = str(value).strip().lower()
    if normalized in {'true', '1', 'yes', 'on'}:
        return True, None
    if normalized in {'false', '0', 'no', 'off'}:
        return False, None

    return None, error_response('validation_error', f'{field_name} must be a boolean', 400)


def _normalize_attachment_type(value):
    if value in (None, ''):
        return None

    normalized = str(value).strip().upper()
    if normalized not in _ATTACHMENT_TYPES:
        return None

    return normalized


def _serialize_announcement_dict(announcement_data, current_user_id=None):
    announcement_data['attachment_type'] = announcement_data.get('attachment_type') or 'NONE'
    announcement_data['is_important'] = bool(announcement_data.get('is_important'))
    aid = announcement_data.get('announcement_id')
    if aid:
        announcement_data['like_count'] = AnnouncementLike.query.filter_by(
            announcement_id=aid
        ).count()
        if current_user_id is None and hasattr(g, 'current_user') and g.current_user:
            current_user_id = g.current_user.user_id
        if current_user_id:
            announcement_data['is_liked'] = (
                AnnouncementLike.query.filter_by(
                    announcement_id=aid,
                    user_id=current_user_id,
                ).first() is not None
            )
        else:
            announcement_data['is_liked'] = False
    else:
        announcement_data['like_count'] = 0
        announcement_data['is_liked'] = False
    return announcement_data


def _serialize_announcement(announcement):
    return _serialize_announcement_dict(announcement.to_dict())


def _get_announcement_or_404(announcement_id):
    announcement = Announcement.query.filter_by(
        announcement_id=announcement_id,
        organization_id=g.current_user.organization_id,
    ).first()

    if announcement is None:
        return None, error_response('not_found', 'Announcement not found', 404)

    return announcement, None


def _parse_important_filter():
    important = request.args.get('important')
    if important is None:
        return None, None

    value, error = _parse_boolean(important, 'important')
    if error:
        return None, error

    return value, None


def _get_notification_recipients():
    recipients = (
        User.query.filter(
            User.organization_id == g.current_user.organization_id,
            User.is_active.is_(True),
            User.role.in_(_ANNOUNCEMENT_NOTIFICATION_ROLES),
            User.user_id != g.current_user.user_id,
        )
        .order_by(User.user_id.asc())
        .all()
    )

    unique_recipients = []
    seen_user_ids = set()
    for user in recipients:
        if user.user_id in seen_user_ids:
            continue
        seen_user_ids.add(user.user_id)
        unique_recipients.append(user)

    return unique_recipients


def _create_announcement_notifications(announcement):
    recipients = _get_notification_recipients()
    if not recipients:
        return

    if bool(announcement.is_important):
        notification_title = 'Important Announcement'
        notification_message = f'An important announcement "{announcement.title}" has been published.'
    else:
        notification_title = 'New Announcement'
        notification_message = f'A new announcement "{announcement.title}" has been published.'

    for recipient in recipients:
        NotificationService.create_notification(
            recipient.user_id,
            notification_title,
            notification_message,
            'ANNOUNCEMENT',
            announcement.announcement_id,
        )


def _apply_announcement_changes(announcement, payload, creating=False):
    if 'title' in payload or creating:
        title = _normalize_text(payload.get('title'))
        if not title:
            return error_response('validation_error', 'title cannot be empty', 400)
        announcement.title = title

    if 'description' in payload or creating:
        description = _normalize_text(payload.get('description'))
        if not description:
            return error_response('validation_error', 'description cannot be empty', 400)
        announcement.description = description

    attachment_url_supplied = 'attachment_url' in payload
    attachment_type_supplied = 'attachment_type' in payload

    if attachment_type_supplied:
        attachment_type = _normalize_attachment_type(payload.get('attachment_type'))
        if attachment_type is None:
            return error_response(
                'validation_error',
                'attachment_type must be one of NONE, IMAGE, PDF, or LINK',
                400,
            )
        announcement.attachment_type = attachment_type
    else:
        attachment_type = announcement.attachment_type or 'NONE'

    if attachment_url_supplied:
        announcement.attachment_url = _normalize_text(payload.get('attachment_url'))

    if creating:
        if attachment_type == 'NONE':
            if announcement.attachment_url:
                return error_response(
                    'validation_error',
                    'attachment_url is not allowed when attachment_type is NONE',
                    400,
                )
            announcement.attachment_url = None
        else:
            if not announcement.attachment_url:
                return error_response(
                    'validation_error',
                    'attachment_url is required when attachment_type is IMAGE, PDF, or LINK',
                    400,
                )
    else:
        current_type = announcement.attachment_type or 'NONE'
        if current_type == 'NONE':
            if attachment_url_supplied and announcement.attachment_url:
                return error_response(
                    'validation_error',
                    'attachment_type must be IMAGE, PDF, or LINK when attachment_url is provided',
                    400,
                )
            announcement.attachment_url = None
        elif not announcement.attachment_url:
            return error_response(
                'validation_error',
                'attachment_url is required when attachment_type is IMAGE, PDF, or LINK',
                400,
            )

    important_supplied = 'is_important' in payload
    if important_supplied or creating:
        important_value, error = _parse_boolean(payload.get('is_important', False), 'is_important')
        if error:
            return error
        announcement.is_important = important_value

    return None


@announcement_bp.route('', methods=['POST'])
@firebase_login_required
@role_required('ORG_ADMIN')
def create_announcement():
    """Create a new announcement for the current organization."""

    payload = _get_request_data()

    announcement = Announcement(
        organization_id=g.current_user.organization_id,
        created_by=g.current_user.user_id,
    )

    error = _apply_announcement_changes(announcement, payload, creating=True)
    if error:
        db.session.rollback()
        return error

    db.session.add(announcement)

    try:
        db.session.flush()
        _create_announcement_notifications(announcement)
        db.session.commit()
    except NotificationServiceError as exc:
        db.session.rollback()
        return error_response(exc.error_code, exc.message, exc.status_code)
    except Exception:
        db.session.rollback()
        current_app.logger.exception('Failed to create announcement')
        return error_response('database_error', 'Database failure while creating announcement', 500)

    return success_response(_serialize_announcement(announcement), 'Announcement created successfully', 201)


@announcement_bp.route('', methods=['GET'])
@firebase_login_required
@role_required('ORG_ADMIN', 'SUPERVISOR', 'STUDENT')
def get_announcements():
    """List announcements for the current organization."""

    page, per_page = get_pagination_params(request)
    important, error = _parse_important_filter()
    if error:
        return error

    query = Announcement.query.filter_by(organization_id=g.current_user.organization_id)
    if important is True:
        query = query.filter_by(is_important=True)

    result = paginate_query(
        query.order_by(Announcement.created_at.desc(), Announcement.announcement_id.desc()),
        page,
        per_page,
    )
    result['data'] = [_serialize_announcement_dict(item) for item in result['data']]

    return success_response(result, 'Announcements retrieved', 200)


@announcement_bp.route('/<int:announcement_id>', methods=['GET'])
@firebase_login_required
@role_required('ORG_ADMIN', 'SUPERVISOR', 'STUDENT')
def get_announcement(announcement_id):
    """Get one announcement by ID within the current organization."""

    announcement, error = _get_announcement_or_404(announcement_id)
    if error:
        return error

    return success_response(_serialize_announcement(announcement), 'Announcement retrieved', 200)


@announcement_bp.route('/<int:announcement_id>', methods=['PATCH'])
@firebase_login_required
@role_required('ORG_ADMIN')
def update_announcement(announcement_id):
    """Update an announcement belonging to the current organization."""

    announcement, error = _get_announcement_or_404(announcement_id)
    if error:
        return error

    payload = _get_request_data()
    error = _apply_announcement_changes(announcement, payload, creating=False)
    if error:
        db.session.rollback()
        return error

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        current_app.logger.exception('Failed to update announcement')
        return error_response('database_error', 'Database failure while updating announcement', 500)

    return success_response(_serialize_announcement(announcement), 'Announcement updated successfully', 200)


@announcement_bp.route('/<int:announcement_id>', methods=['DELETE'])
@firebase_login_required
@role_required('ORG_ADMIN')
def delete_announcement(announcement_id):
    """Delete an announcement belonging to the current organization."""

    announcement, error = _get_announcement_or_404(announcement_id)
    if error:
        return error

    try:
        db.session.delete(announcement)
        db.session.commit()
    except Exception:
        db.session.rollback()
        current_app.logger.exception('Failed to delete announcement')
        return error_response('database_error', 'Database failure while deleting announcement', 500)

    return success_response({}, 'Announcement deleted successfully', 200)


@announcement_bp.route('/<int:announcement_id>/like', methods=['POST'])
@firebase_login_required
@role_required('ORG_ADMIN', 'SUPERVISOR', 'STUDENT')
def toggle_announcement_like(announcement_id):
    """Toggle like/unlike on an announcement."""
    announcement, error = _get_announcement_or_404(announcement_id)
    if error:
        return error

    existing_like = AnnouncementLike.query.filter_by(
        announcement_id=announcement.announcement_id,
        user_id=g.current_user.user_id,
    ).first()

    if existing_like:
        db.session.delete(existing_like)
        is_liked = False
        message = 'Announcement unliked'
    else:
        new_like = AnnouncementLike(
            announcement_id=announcement.announcement_id,
            user_id=g.current_user.user_id,
        )
        db.session.add(new_like)
        is_liked = True
        message = 'Announcement liked'

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    like_count = AnnouncementLike.query.filter_by(
        announcement_id=announcement.announcement_id,
    ).count()

    return success_response(
        {
            'announcement_id': announcement.announcement_id,
            'is_liked': is_liked,
            'like_count': like_count,
        },
        message,
        200,
    )

