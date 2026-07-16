"""Lost and found routes for CampusHive."""

from datetime import date, datetime

from flask import Blueprint, g, request
from sqlalchemy import or_

from app.database import db
from app.middleware.firebase_auth import firebase_login_required, role_required
from app.models import LostFound, LostFoundChat, LostFoundImage
from app.utils.helpers import error_response, get_pagination_params, paginate_query, success_response


lf_bp = Blueprint('lost_found', __name__)

_ITEM_TYPE_VALUES = {'LOST', 'FOUND'}
_STATUS_VALUES = {'OPEN', 'CLOSED'}


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
    try:
        return date.fromisoformat(str(value))
    except ValueError:
        return None


def _get_lost_found_or_404(item_id):
    item = LostFound.query.filter_by(
        item_id=item_id,
        organization_id=g.current_user.organization_id,
    ).first()

    if item is None:
        return None, error_response('not_found', 'Lost and found item not found', 404)

    return item, None


def _get_lost_found_image_or_404(image_id):
    image = LostFoundImage.query.filter_by(image_id=image_id).first()

    if image is None:
        return None, error_response('not_found', 'Lost and found image not found', 404)

    return image, None


def _can_edit_lost_found(item):
    return (
        item.posted_by == g.current_user.user_id
        and item.status == 'OPEN'
    )


def _can_delete_lost_found(item):
    return g.current_user.role.upper() == 'ORG_ADMIN' and item.organization_id == g.current_user.organization_id


def _can_delete_lost_found_image(item):
    return (
        item.posted_by == g.current_user.user_id
        or g.current_user.role.upper() == 'ORG_ADMIN'
    )


def _serialize_lost_found(item):
    return item.to_dict()


@lf_bp.route('', methods=['GET'])
@firebase_login_required
@role_required()
def list_lost_found():
    """List lost and found items."""

    page, per_page = get_pagination_params(request)

    query = LostFound.query.filter_by(organization_id=g.current_user.organization_id)

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

    item_type = _normalize_value(payload.get('item_type'))
    title = (payload.get('title') or '').strip()
    description = (payload.get('description') or '').strip()
    category = (payload.get('category') or '').strip() or None
    location = (payload.get('location') or '').strip() or None
    date_of_incident = _parse_date(payload.get('date_of_incident'))

    if item_type not in _ITEM_TYPE_VALUES:
        return error_response('validation_error', 'Invalid item_type value', 400)
    if not title:
        return error_response('validation_error', 'title is required', 400)
    if not description:
        return error_response('validation_error', 'description is required', 400)
    if payload.get('date_of_incident') not in (None, '') and date_of_incident is None:
        return error_response('validation_error', 'date_of_incident must be a valid ISO date string', 400)

    item = LostFound(
        organization_id=g.current_user.organization_id,
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

    if not _can_edit_lost_found(item):
        return error_response('forbidden', 'You cannot edit this item', 403)

    payload = _get_request_data()

    if 'title' in payload:
        title = (payload.get('title') or '').strip()
        if not title:
            return error_response('validation_error', 'title cannot be empty', 400)
        item.title = title

    if 'description' in payload:
        description = (payload.get('description') or '').strip()
        if not description:
            return error_response('validation_error', 'description cannot be empty', 400)
        item.description = description

    if 'category' in payload:
        item.category = (payload.get('category') or '').strip() or None

    if 'location' in payload:
        item.location = (payload.get('location') or '').strip() or None

    if 'date_of_incident' in payload:
        date_of_incident = _parse_date(payload.get('date_of_incident'))
        if payload.get('date_of_incident') not in (None, '') and date_of_incident is None:
            return error_response('validation_error', 'date_of_incident must be a valid ISO date string', 400)
        item.date_of_incident = date_of_incident

    if 'status' in payload:
        normalized_status = _normalize_value(payload.get('status'))
        if normalized_status not in _STATUS_VALUES:
            return error_response('validation_error', 'Invalid status value', 400)
        if normalized_status == 'CLOSED' and item.status != 'CLOSED':
            item.status = normalized_status
            item.resolved_at = datetime.now()
        else:
            item.status = normalized_status

    try:
        db.session.commit()
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
    message_type = _normalize_value(payload.get('message_type')) or 'TEXT'
    message = (payload.get('message') or '').strip()
    image_url = (payload.get('image_url') or '').strip() or None

    if message_type not in {'TEXT', 'IMAGE'}:
        return error_response('validation_error', 'Invalid message_type value', 400)

    if message_type == 'TEXT' and not message:
        return error_response('validation_error', 'message is required for text comments', 400)
    if message_type == 'IMAGE' and not image_url:
        return error_response('validation_error', 'image_url is required for image comments', 400)

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
        db.session.commit()
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
    
    if item.posted_by != g.current_user.user_id:
        return error_response(
            'forbidden',
            'Only the creator can upload images.',
            403,
        )
    
    if item.status == "CLOSED":
        return error_response(
            "validation_error",
            "Cannot upload images to a closed post.",
            400,
        )

    payload = _get_request_data()
    image_url = (payload.get('image_url') or '').strip()

    if not image_url:
        return error_response('validation_error', 'image_url is required', 400)

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
        return error_response('forbidden', 'You cannot delete this image', 403)

    db.session.delete(image)

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return success_response({}, 'Image deleted', 200)
