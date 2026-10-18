"""Announcement routes for CampusHive."""

import os
import uuid
from flask import Blueprint, current_app, g, request
from werkzeug.utils import secure_filename

from app.database import db
from app.middleware.firebase_auth import firebase_login_required, role_required
from app.models import Announcement, AnnouncementAttachment, AnnouncementLike, User
from app.services.notification_service import NotificationService, NotificationServiceError
from app.utils.helpers import error_response, get_pagination_params, paginate_query, success_response


announcement_bp = Blueprint('announcements', __name__)


_ATTACHMENT_TYPES = {'NONE', 'IMAGE', 'PDF', 'LINK'}
_ANNOUNCEMENT_NOTIFICATION_ROLES = {'STUDENT', 'SUPERVISOR'}
_ALLOWED_UPLOAD_IMAGES = {'jpg', 'jpeg', 'png', 'webp', 'gif'}
_ALLOWED_UPLOAD_DOCS = {'pdf'}
_MAX_ATTACHMENT_SIZE = 15 * 1024 * 1024  # 15 MB


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


def _validate_attachment_dict(item):
    if not isinstance(item, dict):
        return None, error_response('validation_error', 'Each attachment must be an object', 400)

    att_type = (item.get('attachment_type') or '').strip().upper()
    if att_type not in {'IMAGE', 'PDF', 'LINK'}:
        return None, error_response('validation_error', 'Attachment type must be IMAGE, PDF, or LINK', 400)

    att_url = (item.get('attachment_url') or '').strip()
    if not att_url:
        return None, error_response('validation_error', 'attachment_url cannot be empty', 400)

    if att_type == 'LINK':
        if not (att_url.startswith('http://') or att_url.startswith('https://')):
            return None, error_response('validation_error', 'LINK attachment URL must start with http:// or https://', 400)
    else:
        if not (att_url.startswith('http://') or att_url.startswith('https://') or att_url.startswith('/uploads/')):
            return None, error_response('validation_error', f'{att_type} attachment URL must start with /uploads/ or http(s)://', 400)

    original_filename = _normalize_text(item.get('original_filename'))
    mime_type = _normalize_text(item.get('mime_type'))
    file_size = item.get('file_size')
    if file_size is not None:
        try:
            file_size = int(file_size)
        except (ValueError, TypeError):
            file_size = None

    attachment_id = item.get('attachment_id')
    if attachment_id is not None:
        try:
            attachment_id = int(attachment_id)
        except (ValueError, TypeError):
            attachment_id = None

    return {
        'attachment_id': attachment_id,
        'attachment_type': att_type,
        'attachment_url': att_url,
        'original_filename': original_filename,
        'mime_type': mime_type,
        'file_size': file_size,
    }, None


def _safe_remove_upload_file(attachment_url):
    """Safely delete an uploaded file from disk if no other record references it."""
    if not attachment_url or not attachment_url.startswith('/uploads/announcements/'):
        return

    other_att = AnnouncementAttachment.query.filter_by(attachment_url=attachment_url).first()
    other_ann = Announcement.query.filter_by(attachment_url=attachment_url).first()
    if other_att is None and other_ann is None:
        filename = attachment_url.split('/uploads/announcements/')[-1]
        upload_dir = os.path.join(current_app.config.get('UPLOAD_FOLDER', './uploads'), 'announcements')
        filepath = os.path.join(upload_dir, filename)
        try:
            if os.path.exists(filepath):
                os.remove(filepath)
        except Exception:
            current_app.logger.warning(f"Could not remove announcement file: {filepath}")


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

        db_attachments = (
            AnnouncementAttachment.query.filter_by(announcement_id=aid)
            .order_by(AnnouncementAttachment.attachment_id.asc())
            .all()
        )
        if db_attachments:
            announcement_data['attachments'] = [a.to_dict() for a in db_attachments]
            first = db_attachments[0]
            announcement_data['attachment_type'] = first.attachment_type
            announcement_data['attachment_url'] = first.attachment_url
        else:
            legacy_url = announcement_data.get('attachment_url')
            legacy_type = announcement_data.get('attachment_type') or 'NONE'
            if legacy_url and legacy_type != 'NONE':
                announcement_data['attachments'] = [
                    {
                        'attachment_id': None,
                        'announcement_id': aid,
                        'attachment_type': legacy_type,
                        'attachment_url': legacy_url,
                        'original_filename': None,
                        'mime_type': None,
                        'file_size': None,
                        'created_at': announcement_data.get('created_at'),
                    }
                ]
            else:
                announcement_data['attachments'] = []
                announcement_data['attachment_type'] = 'NONE'
                announcement_data['attachment_url'] = None
    else:
        announcement_data['like_count'] = 0
        announcement_data['is_liked'] = False
        announcement_data['attachments'] = []
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


def _sync_announcement_attachments(announcement):
    if not hasattr(announcement, '_pending_attachments'):
        return []

    pending = announcement._pending_attachments
    existing = AnnouncementAttachment.query.filter_by(
        announcement_id=announcement.announcement_id
    ).all()

    existing_by_id = {att.attachment_id: att for att in existing}
    retained_ids = set()
    files_to_check = []

    for item in pending:
        att_id = item.get('attachment_id')
        if att_id and att_id in existing_by_id:
            att = existing_by_id[att_id]
            att.attachment_type = item['attachment_type']
            att.attachment_url = item['attachment_url']
            if item.get('original_filename') is not None:
                att.original_filename = item['original_filename']
            if item.get('mime_type') is not None:
                att.mime_type = item['mime_type']
            if item.get('file_size') is not None:
                att.file_size = item['file_size']
            retained_ids.add(att_id)
        else:
            new_att = AnnouncementAttachment(
                announcement_id=announcement.announcement_id,
                attachment_type=item['attachment_type'],
                attachment_url=item['attachment_url'],
                original_filename=item.get('original_filename'),
                mime_type=item.get('mime_type'),
                file_size=item.get('file_size'),
            )
            db.session.add(new_att)

    for att in existing:
        if att.attachment_id not in retained_ids:
            if att.attachment_url and att.attachment_url.startswith('/uploads/announcements/'):
                files_to_check.append(att.attachment_url)
            db.session.delete(att)

    return files_to_check


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

    important_supplied = 'is_important' in payload
    if important_supplied or creating:
        important_value, error = _parse_boolean(payload.get('is_important', False), 'is_important')
        if error:
            return error
        announcement.is_important = important_value

    if 'attachments' in payload:
        raw_attachments = payload.get('attachments')
        if not isinstance(raw_attachments, list):
            return error_response('validation_error', 'attachments must be a list', 400)

        validated_items = []
        for raw in raw_attachments:
            val, err = _validate_attachment_dict(raw)
            if err:
                return err
            validated_items.append(val)

        announcement._pending_attachments = validated_items
        if validated_items:
            first = validated_items[0]
            announcement.attachment_type = first['attachment_type']
            announcement.attachment_url = first['attachment_url']
        else:
            announcement.attachment_type = 'NONE'
            announcement.attachment_url = None
    else:
        # Legacy single-attachment payload support
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

        if announcement.attachment_type != 'NONE' and announcement.attachment_url:
            announcement._pending_attachments = [
                {
                    'attachment_type': announcement.attachment_type,
                    'attachment_url': announcement.attachment_url,
                    'original_filename': None,
                    'mime_type': None,
                    'file_size': None,
                }
            ]
        elif announcement.attachment_type == 'NONE':
            announcement._pending_attachments = []

    return None


@announcement_bp.route('/upload-attachment', methods=['POST'])
@firebase_login_required
@role_required('ORG_ADMIN')
def upload_announcement_attachment():
    """Upload an attachment file (image or PDF) for an announcement."""
    if 'file' not in request.files and 'attachment' not in request.files:
        return error_response('validation_error', 'No file provided', 400)

    file = request.files.get('file') or request.files.get('attachment')
    if not file or not file.filename:
        return error_response('validation_error', 'No file selected', 400)

    original_filename = secure_filename(file.filename)
    ext = file.filename.rsplit('.', 1)[-1].lower() if '.' in file.filename else ''

    if ext in _ALLOWED_UPLOAD_IMAGES:
        att_type = 'IMAGE'
    elif ext in _ALLOWED_UPLOAD_DOCS:
        att_type = 'PDF'
    else:
        allowed_all = sorted(_ALLOWED_UPLOAD_IMAGES | _ALLOWED_UPLOAD_DOCS)
        return error_response(
            'validation_error',
            f'File type not allowed. Allowed extensions: {", ".join(allowed_all)}',
            400,
        )

    file.seek(0, os.SEEK_END)
    file_size = file.tell()
    file.seek(0)

    if file_size > _MAX_ATTACHMENT_SIZE:
        return error_response('validation_error', 'File size exceeds 15MB limit', 400)

    mime_type = file.mimetype or 'application/octet-stream'

    upload_dir = os.path.join(current_app.config.get('UPLOAD_FOLDER', './uploads'), 'announcements')
    os.makedirs(upload_dir, exist_ok=True)

    filename = f"{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(upload_dir, filename)

    try:
        file.save(filepath)
    except Exception:
        current_app.logger.exception('Failed to save announcement upload')
        if os.path.exists(filepath):
            try:
                os.remove(filepath)
            except Exception:
                pass
        return error_response('server_error', 'Failed to save attachment file', 500)

    attachment_url = f"/uploads/announcements/{filename}"

    return success_response(
        {
            'attachment_type': att_type,
            'attachment_url': attachment_url,
            'original_filename': original_filename,
            'file_size': file_size,
            'mime_type': mime_type,
        },
        'Attachment uploaded successfully',
        201,
    )


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
        files_to_check = _sync_announcement_attachments(announcement)
        _create_announcement_notifications(announcement)
        db.session.commit()
        for f_url in files_to_check:
            _safe_remove_upload_file(f_url)
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
        files_to_check = _sync_announcement_attachments(announcement)
        db.session.commit()
        for f_url in files_to_check:
            _safe_remove_upload_file(f_url)
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

    attachments = AnnouncementAttachment.query.filter_by(
        announcement_id=announcement.announcement_id
    ).all()
    files_to_check = [
        a.attachment_url for a in attachments if a.attachment_url and a.attachment_url.startswith('/uploads/announcements/')
    ]
    if announcement.attachment_url and announcement.attachment_url.startswith('/uploads/announcements/'):
        files_to_check.append(announcement.attachment_url)

    try:
        db.session.delete(announcement)
        db.session.commit()
        for f_url in files_to_check:
            _safe_remove_upload_file(f_url)
    except Exception:
        db.session.rollback()
        current_app.logger.exception('Failed to delete announcement')
        return error_response('database_error', 'Database failure while deleting announcement', 500)

    return success_response({}, 'Announcement deleted successfully', 200)


@announcement_bp.route('/<int:announcement_id>/attachments', methods=['POST'])
@firebase_login_required
@role_required('ORG_ADMIN')
def add_announcement_attachment(announcement_id):
    """Add a single attachment to an existing announcement."""
    announcement, error = _get_announcement_or_404(announcement_id)
    if error:
        return error

    payload = _get_request_data()
    val, err = _validate_attachment_dict(payload)
    if err:
        return err

    attachment = AnnouncementAttachment(
        announcement_id=announcement.announcement_id,
        attachment_type=val['attachment_type'],
        attachment_url=val['attachment_url'],
        original_filename=val.get('original_filename'),
        mime_type=val.get('mime_type'),
        file_size=val.get('file_size'),
    )
    db.session.add(attachment)

    if announcement.attachment_type == 'NONE' or not announcement.attachment_url:
        announcement.attachment_type = val['attachment_type']
        announcement.attachment_url = val['attachment_url']

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        current_app.logger.exception('Failed to add attachment')
        return error_response('database_error', 'Database failure while adding attachment', 500)

    return success_response(attachment.to_dict(), 'Attachment added successfully', 201)


@announcement_bp.route('/<int:announcement_id>/attachments/<int:attachment_id>', methods=['DELETE'])
@firebase_login_required
@role_required('ORG_ADMIN')
def delete_announcement_attachment(announcement_id, attachment_id):
    """Delete a single attachment from an announcement."""
    announcement, error = _get_announcement_or_404(announcement_id)
    if error:
        return error

    attachment = AnnouncementAttachment.query.filter_by(
        attachment_id=attachment_id,
        announcement_id=announcement.announcement_id,
    ).first()
    if not attachment:
        return error_response('not_found', 'Attachment not found', 404)

    file_url = attachment.attachment_url
    db.session.delete(attachment)

    try:
        db.session.flush()
        remaining = (
            AnnouncementAttachment.query.filter_by(announcement_id=announcement.announcement_id)
            .order_by(AnnouncementAttachment.attachment_id.asc())
            .all()
        )
        if remaining:
            announcement.attachment_type = remaining[0].attachment_type
            announcement.attachment_url = remaining[0].attachment_url
        else:
            announcement.attachment_type = 'NONE'
            announcement.attachment_url = None

        db.session.commit()
        _safe_remove_upload_file(file_url)
    except Exception:
        db.session.rollback()
        current_app.logger.exception('Failed to delete attachment')
        return error_response('database_error', 'Database failure while deleting attachment', 500)

    return success_response({}, 'Attachment deleted successfully', 200)


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
