"""Complaint management routes for CampusHive."""

from datetime import datetime

from flask import Blueprint, g, request

from app.database import db
from app.middleware.firebase_auth import firebase_login_required, role_required
from app.models import Complaint, ComplaintSupport, ComplaintChat, ComplaintStatusHistory, Department, User
from app.services.notification_service import NotificationService, NotificationServiceError
from app.utils.helpers import error_response, get_pagination_params, paginate_query, success_response


complaint_bp = Blueprint('complaints', __name__)


_STATUS_VALUES = {'PENDING', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'REOPENED', 'ESCALATED', 'CLOSED'}
_PRIORITY_VALUES = {'LOW', 'MEDIUM', 'HIGH'}
_FEEDBACK_VALUES = {'SATISFIED', 'NOT_SATISFIED'}
_ALLOWED_CREATE_ROLES = {'STUDENT'}
_ALLOWED_UPDATE_ROLES = {'SUPER_ADMIN', 'ORG_ADMIN', 'SUPERVISOR'}


def _normalize_value(value):
    if value is None:
        return None
    return str(value).strip().upper()


def _get_request_data():
    return request.get_json(silent=True) or {}


def _get_complaint_or_404(complaint_id):
    complaint = Complaint.query.filter_by(
        complaint_id=complaint_id,
        organization_id=g.current_user.organization_id,
    ).first()

    if complaint is None:
        return None, error_response('not_found', 'Complaint not found', 404)

    return complaint, None


def _serialize_complaint(complaint):
    complaint_data = complaint.to_dict()
    complaint_data['support_count'] = (
        ComplaintSupport.query.filter_by(complaint_id=complaint.complaint_id).count()
    )
    return complaint_data


def _recalculate_support_count(complaint):
    complaint.support_count = ComplaintSupport.query.filter_by(
        complaint_id=complaint.complaint_id,
    ).count()


@complaint_bp.route('', methods=['POST'])
@firebase_login_required
@role_required()
def create_complaint():
    """Create a new complaint."""

    if g.current_user.role.upper() not in _ALLOWED_CREATE_ROLES:
        return error_response('forbidden', 'Only students can create complaints', 403)

    payload = _get_request_data()

    department_id = payload.get('department_id')
    title = (payload.get('title') or '').strip()
    description = (payload.get('description') or '').strip()
    location = payload.get('location')

    if department_id in (None, ''):
        return error_response('validation_error', 'department_id is required', 400)
    try:
        department_id = int(department_id)
    except (TypeError, ValueError):
        return error_response('validation_error', 'department_id must be an integer', 400)

    if not title:
        return error_response('validation_error', 'title is required', 400)
    if not description:
        return error_response('validation_error', 'description is required', 400)

    department = Department.query.filter_by(
        department_id=department_id,
        organization_id=g.current_user.organization_id,
    ).first()
    if department is None:
        return error_response('not_found', 'Department not found for this organization', 404)
    
    # Find the active supervisor for this department
    supervisor = User.query.filter_by(
        organization_id=g.current_user.organization_id,
        department_id=department.department_id,
        role='SUPERVISOR',
        is_active=True,
    ).first()

    complaint = Complaint(
        organization_id=g.current_user.organization_id,
        student_id=g.current_user.user_id,
        department_id=department_id,
        supervisor_id=supervisor.user_id if supervisor else None,
        title=title,
        description=description,
        location=location,
        ml_priority=None,
        final_priority=None,
        status='PENDING',
    )

    if complaint.ml_priority is not None and complaint.ml_priority not in _PRIORITY_VALUES:
        return error_response('validation_error', 'Invalid ml_priority value', 400)
    if complaint.final_priority is not None and complaint.final_priority not in _PRIORITY_VALUES:
        return error_response('validation_error', 'Invalid final_priority value', 400)

    db.session.add(complaint)

    try:
        db.session.flush()

        NotificationService.create_notification(
            complaint.student_id,
            'Complaint Submitted',
            'Your complaint has been submitted successfully.',
            'COMPLAINT',
            complaint.complaint_id,
        )

        if supervisor is not None:
            NotificationService.create_notification(
                supervisor.user_id,
                'New Complaint Assigned',
                f'A new complaint "{complaint.title}" has been assigned to you.',
                'COMPLAINT',
                complaint.complaint_id,
            )

        db.session.commit()
    except NotificationServiceError as exc:
        db.session.rollback()
        return error_response(exc.error_code, exc.message, exc.status_code)
    except Exception:
        db.session.rollback()
        raise

    return success_response(_serialize_complaint(complaint), 'Complaint created successfully', 201)


@complaint_bp.route('', methods=['GET'])
@firebase_login_required
@role_required()
def list_complaints():
    """List complaints for the current organization."""

    page, per_page = get_pagination_params(request)

    query = Complaint.query.filter_by(organization_id=g.current_user.organization_id)

    if g.current_user.role.upper() == 'STUDENT':
        query = query.filter_by(student_id=g.current_user.user_id)
    elif g.current_user.role.upper() == 'SUPERVISOR':
        query = query.filter_by(supervisor_id=g.current_user.user_id)

    status = request.args.get('status')
    if status:
        normalized_status = _normalize_value(status)
        if normalized_status not in _STATUS_VALUES:
            return error_response('validation_error', 'Invalid status filter', 400)
        query = query.filter_by(status=normalized_status)

    final_priority = request.args.get('final_priority')
    if final_priority:
        normalized_priority = _normalize_value(final_priority)
        if normalized_priority not in _PRIORITY_VALUES:
            return error_response('validation_error', 'Invalid final_priority filter', 400)
        query = query.filter_by(final_priority=normalized_priority)

    department_id = request.args.get('department_id')
    if department_id:
        try:
            query = query.filter_by(department_id=int(department_id))
        except (TypeError, ValueError):
            return error_response('validation_error', 'department_id must be an integer', 400)

    result = paginate_query(query.order_by(Complaint.created_at.desc()), page, per_page)
    for complaint in result['data']:
        complaint['support_count'] = ComplaintSupport.query.filter_by(
            complaint_id=complaint['complaint_id']
        ).count()

    return success_response(result, 'Complaints retrieved', 200)


@complaint_bp.route('/<int:complaint_id>', methods=['GET'])
@firebase_login_required
@role_required()
def get_complaint(complaint_id):
    """Get complaint details."""

    complaint, error = _get_complaint_or_404(complaint_id)
    if error:
        return error

    if g.current_user.role.upper() == 'STUDENT' and complaint.student_id != g.current_user.user_id:
        return error_response('forbidden', 'You cannot access this complaint', 403)
    if g.current_user.role.upper() == 'SUPERVISOR' and complaint.supervisor_id not in (None, g.current_user.user_id):
        return error_response('forbidden', 'You cannot access this complaint', 403)

    return success_response(_serialize_complaint(complaint), 'Complaint retrieved', 200)


@complaint_bp.route('/<int:complaint_id>/comments', methods=['GET'])
@firebase_login_required
@role_required()
def get_complaint_comments(complaint_id):
    """Get all comments for a complaint."""

    complaint, error = _get_complaint_or_404(complaint_id)
    if error:
        return error

    if g.current_user.role.upper() == 'SUPERVISOR' and complaint.supervisor_id not in (None, g.current_user.user_id):
        return error_response('forbidden', 'You cannot access this complaint', 403)

    comments = ComplaintChat.query.filter_by(
        complaint_id=complaint.complaint_id,
    ).order_by(ComplaintChat.sent_at.asc()).all()

    return success_response([chat.to_dict() for chat in comments], 'Comments retrieved', 200)


@complaint_bp.route('/<int:complaint_id>', methods=['PATCH'])
@firebase_login_required
@role_required()
def update_complaint(complaint_id):
    """Update complaint status or other mutable complaint fields."""

    if g.current_user.role.upper() not in _ALLOWED_UPDATE_ROLES:
        return error_response('forbidden', 'You do not have permission to update complaints', 403)

    payload = _get_request_data()
    complaint, error = _get_complaint_or_404(complaint_id)
    if error:
        return error

    old_status = complaint.status
    old_supervisor_id = complaint.supervisor_id

    if 'status' in payload:
        normalized_status = _normalize_value(payload.get('status'))
        if normalized_status not in _STATUS_VALUES:
            return error_response('validation_error', 'Invalid status value', 400)
        if normalized_status != complaint.status:
            complaint.status = normalized_status
            if normalized_status == 'RESOLVED' and complaint.resolved_at is None:
                complaint.resolved_at = datetime.utcnow()

    if 'ml_priority' in payload:
        normalized_priority = _normalize_value(payload.get('ml_priority'))
        if normalized_priority not in _PRIORITY_VALUES:
            return error_response('validation_error', 'Invalid ml_priority value', 400)
        complaint.ml_priority = normalized_priority

    if 'final_priority' in payload:
        normalized_priority = _normalize_value(payload.get('final_priority'))
        if normalized_priority not in _PRIORITY_VALUES:
            return error_response('validation_error', 'Invalid final_priority value', 400)
        complaint.final_priority = normalized_priority

    if 'student_feedback' in payload:
        normalized_feedback = _normalize_value(payload.get('student_feedback'))
        if normalized_feedback not in _FEEDBACK_VALUES:
            return error_response('validation_error', 'Invalid student_feedback value', 400)
        complaint.student_feedback = normalized_feedback

    if 'deadline' in payload:
        deadline = payload.get('deadline')
        if deadline in (None, ''):
            complaint.deadline = None
        else:
            try:
                complaint.deadline = datetime.fromisoformat(str(deadline))
            except ValueError:
                return error_response('validation_error', 'deadline must be an ISO datetime string', 400)

    if 'title' in payload:
        title = (payload.get('title') or '').strip()
        if not title:
            return error_response('validation_error', 'title cannot be empty', 400)
        complaint.title = title

    if 'description' in payload:
        description = (payload.get('description') or '').strip()
        if not description:
            return error_response('validation_error', 'description cannot be empty', 400)
        complaint.description = description

    if 'supervisor_id' in payload:
        supervisor_id = payload.get('supervisor_id')
        if supervisor_id in (None, ''):
            complaint.supervisor_id = None
        else:
            try:
                supervisor_id = int(supervisor_id)
            except (TypeError, ValueError):
                return error_response('validation_error', 'supervisor_id must be an integer', 400)

            supervisor = User.query.filter_by(
                user_id=supervisor_id,
                organization_id=g.current_user.organization_id,
                role='SUPERVISOR',
                is_active=True,
            ).first()
            if supervisor is None:
                return error_response('not_found', 'Supervisor not found for this organization', 404)

            complaint.supervisor_id = supervisor_id

    if 'location' in payload:
        complaint.location = payload.get('location')

    if 'department_id' in payload:
        try:
            department_id = int(payload.get('department_id'))
        except (TypeError, ValueError):
            return error_response('validation_error', 'department_id must be an integer', 400)

        department = Department.query.filter_by(
            department_id=department_id,
            organization_id=g.current_user.organization_id,
        ).first()
        if department is None:
            return error_response('not_found', 'Department not found for this organization', 404)
        complaint.department_id = department_id

    should_notify_assigned = complaint.supervisor_id != old_supervisor_id and complaint.supervisor_id is not None
    status_changed = complaint.status != old_status

    if status_changed:
        status_history = ComplaintStatusHistory(
            complaint_id=complaint.complaint_id,
            updated_by=g.current_user.user_id,
            old_status=old_status,
            new_status=complaint.status,
            remarks=payload.get('remarks') or payload.get('resolution_notes'),
        )
        db.session.add(status_history)

    try:
        if should_notify_assigned:
            NotificationService.create_notification(
                complaint.student_id,
                'Complaint Assigned',
                'Your complaint has been assigned to a supervisor.',
                'COMPLAINT',
                complaint.complaint_id,
            )

        if status_changed:
            notification_title = 'Complaint Resolved' if complaint.status == 'RESOLVED' else 'Complaint Status Updated'
            notification_message = (
                'Your complaint has been resolved.'
                if complaint.status == 'RESOLVED'
                else 'Your complaint status has been updated.'
            )
            NotificationService.create_notification(
                complaint.student_id,
                notification_title,
                notification_message,
                'COMPLAINT',
                complaint.complaint_id,
            )

        db.session.commit()
    except NotificationServiceError as exc:
        db.session.rollback()
        return error_response(exc.error_code, exc.message, exc.status_code)
    except Exception:
        db.session.rollback()
        raise

    return success_response(_serialize_complaint(complaint), 'Complaint updated', 200)


@complaint_bp.route('/<int:complaint_id>/comments', methods=['POST'])
@firebase_login_required
@role_required()
def add_comment(complaint_id):
    """Add a chat message to a complaint."""

    payload = _get_request_data()
    message = (payload.get('message') or payload.get('comment') or '').strip()
    image_url = payload.get('image_url')

    if not message:
        return error_response('validation_error', 'message is required', 400)

    complaint, error = _get_complaint_or_404(complaint_id)
    if error:
        return error
    
    # Other students can comment only once.
    # Complaint owner and staff can comment multiple times.
    if (
        g.current_user.role.upper() == "STUDENT"
        and complaint.student_id != g.current_user.user_id
    ):
        existing_comment = ComplaintChat.query.filter_by(
            complaint_id=complaint.complaint_id,
            sender_id=g.current_user.user_id,
        ).first()

        if existing_comment:
            return error_response(
                "validation_error",
                "You can comment only once on this complaint.",
                400,
            )

    chat_message = ComplaintChat(
        complaint_id=complaint.complaint_id,
        sender_id=g.current_user.user_id,
        message=message,
        image_url=image_url,
    )
    db.session.add(chat_message)

    try:
        if g.current_user.role.upper() == 'SUPERVISOR' and complaint.student_id != g.current_user.user_id:
            NotificationService.create_notification(
                complaint.student_id,
                'New Supervisor Update',
                'A supervisor added a new update to your complaint.',
                'COMPLAINT',
                complaint.complaint_id,
            )

        db.session.commit()
    except NotificationServiceError as exc:
        db.session.rollback()
        return error_response(exc.error_code, exc.message, exc.status_code)
    except Exception:
        db.session.rollback()
        raise

    return success_response(chat_message.to_dict(), 'Comment added', 201)


@complaint_bp.route('/<int:complaint_id>/support', methods=['POST'])
@firebase_login_required
@role_required()
def support_complaint(complaint_id):
    """Support a complaint using the ComplaintSupport table."""

    if g.current_user.role.upper() != 'STUDENT':
        return error_response('forbidden', 'Only students can support complaints', 403)

    complaint, error = _get_complaint_or_404(complaint_id)
    if error:
        return error
    # Prevent students from supporting their own complaint
    if complaint.student_id == g.current_user.user_id:
        return error_response(
            "validation_error",
            "You cannot support your own complaint",
            400
        )
    existing_support = ComplaintSupport.query.filter_by(
        complaint_id=complaint.complaint_id,
        student_id=g.current_user.user_id,
    ).first()

    if existing_support:
        return error_response(
            "validation_error",
            "You have already supported this complaint",
            400
        )

    support = ComplaintSupport(
        complaint_id=complaint.complaint_id,
        student_id=g.current_user.user_id,
    )

    db.session.add(support)

    _recalculate_support_count(complaint)
    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return success_response(
        {
            'complaint_id': complaint.complaint_id,
            'support_count': complaint.support_count,
            'supported': True,
        },
        'Complaint supported',
        200,
    )