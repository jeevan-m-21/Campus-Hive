"""Lost and found routes for CampusHive."""

from datetime import date, datetime
from urllib.parse import urlparse

from flask import Blueprint, g, request
from sqlalchemy import or_

from app.database import db
from app.middleware.firebase_auth import firebase_login_required, role_required
from app.models import LostFound, LostFoundChat, LostFoundImage
from app.services.notification_service import NotificationService, NotificationServiceError
from app.utils.helpers import error_response, get_pagination_params, paginate_query, success_response


lf_bp = Blueprint('lost_found', __name__)

_ITEM_TYPE_VALUES = {'LOST', 'FOUND'}
_STATUS_VALUES = {'OPEN', 'CLOSED'}
_MAX_TITLE_LENGTH = 200
_MAX_CATEGORY_LENGTH = 100
_MAX_LOCATION_LENGTH = 255
_MAX_IMAGE_URL_LENGTH = 500


def _normalize_value(value):
    if value is None:
        return None
    return str(value).strip().upper()


def _get_request_data():
    return request.get_json(silent=True) or {}


def _parse_date(value):
    if value in (None, ''):
        return None
    if isinstance(value, date):
        return value
    if not isinstance(value, str):
        return None
    try:
        return date.fromisoformat(value.strip())
    except (ValueError, TypeError):
        return None


def _is_safe_image_url(url):
    """
    Validate that an image URL uses allowed schemes and prefixes.
    Rejects dangerous schemes like javascript:, data:, vbscript:, file:, etc.,
    protocol-relative URLs (//), path traversal (..), whitespace, and malformed URLs.
    Accepts:
    - /uploads/... or uploads/...
    - http://... or https://... with valid netloc
    """
    if not url or not isinstance(url, str):
        return False
    url_trimmed = url.strip()
    if not url_trimmed:
        return False
    if '..' in url_trimmed:
        return False
    if any(c in url_trimmed for c in ('\r', '\n', '\t', ' ')):
        return False
    lower_url = url_trimmed.lower()
    if lower_url.startswith(('javascript:', 'data:', 'vbscript:', 'file:', '//')):
        return False
    if (
        url_trimmed.startswith('/uploads/')
        or url_trimmed.startswith('uploads/')
    ):
        return True
    if lower_url.startswith(('http://', 'https://')):
        try:
            parsed = urlparse(url_trimmed)
            return bool(parsed.netloc)
        except Exception:
            return False
    return False



def _get_lost_found_or_404(item_id):
    role = getattr(g.current_user, 'role', '').upper()
    if role == 'SUPER_ADMIN':
        item = LostFound.query.filter_by(item_id=item_id).first()
    else:
        org_id = getattr(g.current_user, 'organization_id', None)
        if not org_id:
            return None, error_response('not_found', 'Lost and found item not found', 404)
        item = LostFound.query.filter_by(
            item_id=item_id,
            organization_id=org_id,
        ).first()

    if item is None:
        return None, error_response('not_found', 'Lost and found item not found', 404)

    return item, None


def _get_lost_found_image_or_404(image_id):
    image = LostFoundImage.query.filter_by(image_id=image_id).first()

    if image is None:
        return None, error_response('not_found', 'Lost and found image not found', 404)

    return image, None


def _is_org_admin_for_item(item):
    role = getattr(g.current_user, 'role', '').upper()
    if role == 'SUPER_ADMIN':
        return True
    if role == 'ORG_ADMIN' and getattr(g.current_user, 'organization_id', None) == item.organization_id:
        return True
    return False


def _can_edit_lost_found(item):
    if item.status != 'OPEN':
        return False
    if item.posted_by == g.current_user.user_id:
        return True
    return _is_org_admin_for_item(item)


def _can_delete_lost_found(item):
    return _is_org_admin_for_item(item)


def _can_delete_lost_found_image(item):
    if item.status != 'OPEN':
        return False
    if item.posted_by == g.current_user.user_id:
        return True
    return _is_org_admin_for_item(item)


def _serialize_lost_found(item):
    return item.to_dict()


@lf_bp.route('', methods=['GET'])
@firebase_login_required
@role_required()
def list_lost_found():
    """List lost and found items."""

    page, per_page = get_pagination_params(request)

    role = getattr(g.current_user, 'role', '').upper()
    if role == 'SUPER_ADMIN':
        org_id = request.args.get('organization_id', type=int)
        if org_id:
            query = LostFound.query.filter_by(organization_id=org_id)
        elif getattr(g.current_user, 'organization_id', None):
            query = LostFound.query.filter_by(organization_id=g.current_user.organization_id)
        else:
            query = LostFound.query
    else:
        user_org_id = getattr(g.current_user, 'organization_id', None)
        if not user_org_id:
            return success_response({
                'data': [],
                'pagination': {
                    'page': page,
                    'per_page': per_page,
                    'total': 0,
                    'pages': 0,
                    'has_prev': False,
                    'has_next': False,
                }
            }, 'Lost and found items retrieved', 200)
        query = LostFound.query.filter_by(organization_id=user_org_id)

    mine = request.args.get('mine')
    if mine and mine.strip().lower() in ('true', '1', 'yes'):
        query = query.filter_by(posted_by=g.current_user.user_id)

    status = request.args.get('status')
    if status:
        normalized_status = _normalize_value(status)
        if normalized_status not in _STATUS_VALUES:
            return error_response('validation_error', 'Invalid status filter', 400)
        query = query.filter_by(status=normalized_status)

    item_type = request.args.get('item_type')
    if item_type:
        normalized_item_type = _normalize_value(item_type)
        if normalized_item_type not in _ITEM_TYPE_VALUES:
            return error_response('validation_error', 'Invalid item_type filter', 400)
        query = query.filter_by(item_type=normalized_item_type)

    category = request.args.get('category')
    if category:
        query = query.filter_by(category=category.strip())

    title = request.args.get('title')
    if title:
        query = query.filter(LostFound.title.ilike(f'%{title.strip()}%'))

    location = request.args.get('location')
    if location:
        query = query.filter(LostFound.location.ilike(f'%{location.strip()}%'))

    search = request.args.get('search')
    if search:
        search_value = search.strip()
        query = query.filter(
            or_(
                LostFound.title.ilike(f'%{search_value}%'),
                LostFound.description.ilike(f'%{search_value}%'),
                LostFound.location.ilike(f'%{search_value}%'),
            )
        )

    result = paginate_query(query.order_by(LostFound.created_at.desc()), page, per_page)
    return success_response(result, 'Lost and found items retrieved', 200)


@lf_bp.route('', methods=['POST'])
@firebase_login_required
@role_required()
def create_lost_found():
    """Create a lost and found item."""

    payload = _get_request_data()

    role = getattr(g.current_user, 'role', '').upper()
    organization_id = getattr(g.current_user, 'organization_id', None)
    if not organization_id and role == 'SUPER_ADMIN':
        organization_id = payload.get('organization_id')
    if not organization_id:
        return error_response('validation_error', 'User is not assigned to an organization', 400)

    raw_item_type = payload.get('item_type')
    if not raw_item_type:
        return error_response('validation_error', 'item_type is required', 400)
    if not isinstance(raw_item_type, str):
        return error_response('validation_error', 'item_type must be a string', 400)
    item_type = _normalize_value(raw_item_type)
    if item_type not in _ITEM_TYPE_VALUES:
        return error_response('validation_error', 'Invalid item_type value', 400)

    raw_title = payload.get('title')
    if raw_title is None or not isinstance(raw_title, str):
        return error_response('validation_error', 'title is required and must be a string', 400)
    title = raw_title.strip()
    if not title:
        return error_response('validation_error', 'title is required', 400)
    if len(title) > _MAX_TITLE_LENGTH:
        return error_response('validation_error', f'title cannot exceed {_MAX_TITLE_LENGTH} characters', 400)

    raw_description = payload.get('description')
    if raw_description is None or not isinstance(raw_description, str):
        return error_response('validation_error', 'description is required and must be a string', 400)
    description = raw_description.strip()
    if not description:
        return error_response('validation_error', 'description is required', 400)

    raw_category = payload.get('category')
    category = None
    if raw_category is not None:
        if not isinstance(raw_category, str):
            return error_response('validation_error', 'category must be a string', 400)
        category = raw_category.strip() or None
        if category and len(category) > _MAX_CATEGORY_LENGTH:
            return error_response('validation_error', f'category cannot exceed {_MAX_CATEGORY_LENGTH} characters', 400)

    raw_location = payload.get('location')
    location = None
    if raw_location is not None:
        if not isinstance(raw_location, str):
            return error_response('validation_error', 'location must be a string', 400)
        location = raw_location.strip() or None
        if location and len(location) > _MAX_LOCATION_LENGTH:
            return error_response('validation_error', f'location cannot exceed {_MAX_LOCATION_LENGTH} characters', 400)

    raw_date = payload.get('date_of_incident')
    date_of_incident = None
    if raw_date not in (None, ''):
        date_of_incident = _parse_date(raw_date)
        if date_of_incident is None:
            return error_response('validation_error', 'date_of_incident must be a valid ISO date string (YYYY-MM-DD)', 400)

    raw_image_url = payload.get('image_url')
    image_url = None
    if raw_image_url is not None:
        if not isinstance(raw_image_url, str):
            return error_response('validation_error', 'image_url must be a string', 400)
        image_url = raw_image_url.strip() or None
        if image_url:
            if not _is_safe_image_url(image_url) or len(image_url) > _MAX_IMAGE_URL_LENGTH:
                return error_response('validation_error', 'Invalid or unsafe image URL', 400)

    item = LostFound(
        organization_id=organization_id,
        posted_by=g.current_user.user_id,
        item_type=item_type,
        title=title,
        description=description,
        category=category,
        location=location,
        date_of_incident=date_of_incident,
        status='OPEN',
    )

    db.session.add(item)
    db.session.flush()

    if image_url:
        image = LostFoundImage(
            item_id=item.item_id,
            image_url=image_url,
        )
        db.session.add(image)

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return success_response(_serialize_lost_found(item), 'Lost and found item created', 201)


@lf_bp.route('/<int:item_id>', methods=['GET'])
@firebase_login_required
@role_required()
def get_lost_found(item_id):
    """Get a lost and found item."""

    item, error = _get_lost_found_or_404(item_id)
    if error:
        return error

    return success_response(_serialize_lost_found(item), 'Lost and found item retrieved', 200)


@lf_bp.route('/<int:item_id>', methods=['PATCH'])
@firebase_login_required
@role_required()
def update_lost_found(item_id):
    """Update a lost and found item."""

    item, error = _get_lost_found_or_404(item_id)
    if error:
        return error

    # 1. Authorization: creator or authorized admin
    is_owner = (item.posted_by == g.current_user.user_id)
    is_admin = _is_org_admin_for_item(item)
    if not (is_owner or is_admin):
        return error_response('forbidden', 'You cannot edit this item', 403)

    # 2. Immutability: closed listings cannot be modified or reopened
    if item.status == 'CLOSED':
        return error_response('validation_error', 'Closed listings cannot be modified or reopened', 400)

    payload = _get_request_data()
    old_status = item.status

    if 'title' in payload:
        raw_title = payload.get('title')
        if not isinstance(raw_title, str):
            return error_response('validation_error', 'title must be a string', 400)
        title = raw_title.strip()
        if not title:
            return error_response('validation_error', 'title cannot be empty', 400)
        if len(title) > _MAX_TITLE_LENGTH:
            return error_response('validation_error', f'title cannot exceed {_MAX_TITLE_LENGTH} characters', 400)
        item.title = title

    if 'description' in payload:
        raw_desc = payload.get('description')
        if not isinstance(raw_desc, str):
            return error_response('validation_error', 'description must be a string', 400)
        description = raw_desc.strip()
        if not description:
            return error_response('validation_error', 'description cannot be empty', 400)
        item.description = description

    if 'category' in payload:
        raw_cat = payload.get('category')
        if raw_cat is not None and not isinstance(raw_cat, str):
            return error_response('validation_error', 'category must be a string', 400)
        category = (raw_cat or '').strip() or None
        if category and len(category) > _MAX_CATEGORY_LENGTH:
            return error_response('validation_error', f'category cannot exceed {_MAX_CATEGORY_LENGTH} characters', 400)
        item.category = category

    if 'location' in payload:
        raw_loc = payload.get('location')
        if raw_loc is not None and not isinstance(raw_loc, str):
            return error_response('validation_error', 'location must be a string', 400)
        location = (raw_loc or '').strip() or None
        if location and len(location) > _MAX_LOCATION_LENGTH:
            return error_response('validation_error', f'location cannot exceed {_MAX_LOCATION_LENGTH} characters', 400)
        item.location = location

    if 'date_of_incident' in payload:
        raw_date = payload.get('date_of_incident')
        if raw_date in (None, ''):
            item.date_of_incident = None
        else:
            date_of_incident = _parse_date(raw_date)
            if date_of_incident is None:
                return error_response('validation_error', 'date_of_incident must be a valid ISO date string (YYYY-MM-DD)', 400)
            item.date_of_incident = date_of_incident

    if 'status' in payload:
        raw_status = payload.get('status')
        if not isinstance(raw_status, str):
            return error_response('validation_error', 'status must be a string', 400)
        normalized_status = _normalize_value(raw_status)
        if normalized_status not in _STATUS_VALUES:
            return error_response('validation_error', 'Invalid status value', 400)
        if normalized_status == 'CLOSED':
            item.status = 'CLOSED'
            item.resolved_at = datetime.now()
        else:
            item.status = normalized_status

    try:
        if (
            old_status != 'CLOSED'
            and item.status == 'CLOSED'
            and item.posted_by != g.current_user.user_id
        ):
            NotificationService.create_notification(
                item.posted_by,
                'Item Closed',
                'Your lost and found item has been closed.',
                'LOST_FOUND',
                item.item_id,
            )

        db.session.commit()
    except NotificationServiceError as exc:
        db.session.rollback()
        return error_response(exc.error_code, exc.message, exc.status_code)
    except Exception:
        db.session.rollback()
        raise

    return success_response(_serialize_lost_found(item), 'Lost and found item updated', 200)


@lf_bp.route('/<int:item_id>', methods=['DELETE'])
@firebase_login_required
@role_required()
def delete_lost_found(item_id):
    """Delete a lost and found item."""

    item, error = _get_lost_found_or_404(item_id)
    if error:
        return error

    if not _can_delete_lost_found(item):
        return error_response('forbidden', 'You cannot delete this item', 403)

    db.session.delete(item)

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return success_response({}, 'Lost and found item deleted', 200)


@lf_bp.route('/<int:item_id>/comments', methods=['GET'])
@firebase_login_required
@role_required()
def get_lost_found_comments(item_id):
    """Get comments for a lost and found item."""

    item, error = _get_lost_found_or_404(item_id)
    if error:
        return error

    comments = LostFoundChat.query.filter_by(
        item_id=item.item_id,
    ).order_by(LostFoundChat.sent_at.asc()).all()

    return success_response([comment.to_dict() for comment in comments], 'Comments retrieved', 200)


@lf_bp.route('/<int:item_id>/comments', methods=['POST'])
@firebase_login_required
@role_required()
def add_lost_found_comment(item_id):
    """Add a comment to a lost and found item."""

    item, error = _get_lost_found_or_404(item_id)
    if error:
        return error
    if item.status == "CLOSED":
        return error_response(
            "validation_error",
            "Comments are not allowed on closed posts.",
            400,
        )
    payload = _get_request_data()
    raw_message_type = payload.get('message_type')
    if raw_message_type is not None and not isinstance(raw_message_type, str):
        return error_response('validation_error', 'message_type must be a string', 400)
    message_type = _normalize_value(raw_message_type) if raw_message_type else 'TEXT'

    raw_message = payload.get('message')
    if raw_message is not None and not isinstance(raw_message, str):
        return error_response('validation_error', 'message must be a string', 400)
    message = (raw_message or '').strip()

    raw_image_url = payload.get('image_url')
    if raw_image_url is not None and not isinstance(raw_image_url, str):
        return error_response('validation_error', 'image_url must be a string', 400)
    image_url = (raw_image_url or '').strip() or None

    if message_type not in {'TEXT', 'IMAGE'}:
        return error_response('validation_error', 'Invalid message_type value', 400)

    if message_type == 'TEXT' and not message:
        return error_response('validation_error', 'message is required for text comments', 400)
    if message_type == 'IMAGE':
        if not image_url:
            return error_response('validation_error', 'image_url is required for image comments', 400)
        if not _is_safe_image_url(image_url) or len(image_url) > _MAX_IMAGE_URL_LENGTH:
            return error_response('validation_error', 'Invalid or unsafe image URL', 400)

    if image_url and (not _is_safe_image_url(image_url) or len(image_url) > _MAX_IMAGE_URL_LENGTH):
        return error_response('validation_error', 'Invalid or unsafe image URL', 400)

    if not message:
        message = image_url or ''

    comment = LostFoundChat(
        item_id=item.item_id,
        sender_id=g.current_user.user_id,
        message=message,
        message_type=message_type,
        image_url=image_url,
    )

    db.session.add(comment)

    try:
        if item.posted_by != g.current_user.user_id:
            NotificationService.create_notification(
                item.posted_by,
                'New Comment',
                'A new comment was added to your lost and found item.',
                'LOST_FOUND',
                item.item_id,
            )
        db.session.commit()
    except NotificationServiceError as exc:
        db.session.rollback()
        return error_response(exc.error_code, exc.message, exc.status_code)
    except Exception:
        db.session.rollback()
        raise

    return success_response(comment.to_dict(), 'Comment added', 201)


@lf_bp.route('/<int:item_id>/images', methods=['POST'])
@firebase_login_required
@role_required()
def add_lost_found_image(item_id):
    """Add an image to a lost and found item."""

    item, error = _get_lost_found_or_404(item_id)
    if error:
        return error

    if item.status == "CLOSED":
        return error_response(
            "validation_error",
            "Cannot upload images to a closed post.",
            400,
        )

    if item.posted_by != g.current_user.user_id:
        return error_response(
            'forbidden',
            'Only the creator can upload images.',
            403,
        )

    payload = _get_request_data()
    raw_image_url = payload.get('image_url')
    if raw_image_url is None or not isinstance(raw_image_url, str):
        return error_response('validation_error', 'image_url is required and must be a string', 400)
    image_url = raw_image_url.strip()

    if not image_url:
        return error_response('validation_error', 'image_url is required', 400)

    if not _is_safe_image_url(image_url) or len(image_url) > _MAX_IMAGE_URL_LENGTH:
        return error_response('validation_error', 'Invalid or unsafe image URL', 400)

    image = LostFoundImage(
        item_id=item.item_id,
        image_url=image_url,
    )

    db.session.add(image)

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return success_response(image.to_dict(), 'Image added', 201)


@lf_bp.route('/images/<int:image_id>', methods=['DELETE'])
@firebase_login_required
@role_required()
def delete_lost_found_image(image_id):
    """Delete a lost and found image."""

    image, error = _get_lost_found_image_or_404(image_id)
    if error:
        return error

    item, item_error = _get_lost_found_or_404(image.item_id)
    if item_error:
        return item_error

    if not _can_delete_lost_found_image(item):
        if item.status == 'CLOSED':
            return error_response('validation_error', 'Cannot modify images of a closed post', 400)
        return error_response('forbidden', 'You cannot delete this image', 403)

    db.session.delete(image)

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return success_response({}, 'Image deleted', 200)
