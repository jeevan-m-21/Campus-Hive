"""
Organization routes
Organization management endpoints
"""

from flask import Blueprint, request, g
from app.models import (
    AcademicDepartment,
    Announcement,
    Complaint,
    Department,
    LostFound,
    Organization,
    User,
)
from app.middleware.firebase_auth import firebase_login_required, role_required
from app.utils.helpers import success_response, error_response

org_bp = Blueprint('organizations', __name__)


@org_bp.route('/public', methods=['GET'])
def get_public_organizations():
    """Get active organizations for public discovery (e.g., student registration)."""
    organizations = (
        Organization.query.filter_by(is_active=True)
        .order_by(Organization.organization_name.asc())
        .all()
    )
    data = [
        {
            'organization_id': org.organization_id,
            'organization_name': org.organization_name,
            'organization_code': org.organization_code,
            'email_domain': org.email_domain,
        }
        for org in organizations
    ]
    return success_response(data, 'Active organizations fetched successfully.', 200)


@org_bp.route('/<int:organization_id>/academic-departments', methods=['GET'])
def get_public_academic_departments(organization_id):
    """Get active academic departments for a specific organization."""
    org = Organization.query.filter_by(
        organization_id=organization_id,
        is_active=True,
    ).first()
    if org is None:
        return error_response('not_found', 'Organization not found.', 404)

    departments = (
        AcademicDepartment.query.filter_by(
            organization_id=organization_id,
            is_active=True,
        )
        .order_by(AcademicDepartment.department_name.asc())
        .all()
    )
    data = [
        {
            'academic_department_id': dept.academic_department_id,
            'organization_id': dept.organization_id,
            'department_name': dept.department_name,
            'department_code': dept.department_code,
        }
        for dept in departments
    ]
    return success_response(data, 'Academic departments fetched successfully.', 200)


@org_bp.route('', methods=['GET'])
@org_bp.route('/', methods=['GET'])
@org_bp.route('/<int:organization_id>', methods=['GET'])
@firebase_login_required
def get_organization(organization_id=None):
    """Get organization details for the current user or by authorized organization_id."""
    target_id = organization_id
    if target_id is None:
        raw_param = request.args.get('organization_id')
        if raw_param:
            try:
                target_id = int(raw_param)
            except (TypeError, ValueError):
                return error_response('validation_error', 'organization_id must be an integer.', 400)

    user_role = g.current_user.role.upper() if hasattr(g, 'current_user') and g.current_user else ''

    if target_id is None:
        target_id = g.current_user.organization_id

    # Enforce organization boundaries
    if user_role != 'SUPER_ADMIN' and target_id != g.current_user.organization_id:
        return error_response('forbidden', 'You do not have permission to access another organization.', 403)

    org = Organization.query.filter_by(organization_id=target_id).first()
    if org is None:
        return error_response('not_found', 'Organization not found.', 404)

    org_data = org.to_dict()
    org_data['departments_count'] = Department.query.filter_by(organization_id=org.organization_id).count()
    return success_response(org_data, 'Organization retrieved', 200)


@org_bp.route('/<int:organization_id>/stats', methods=['GET'])
@org_bp.route('/stats', methods=['GET'])
@firebase_login_required
@role_required('ORG_ADMIN', 'SUPER_ADMIN')
def get_org_stats(organization_id=None):
    """Get organization statistics for authorized administrators."""
    target_id = organization_id
    if target_id is None:
        raw_param = request.args.get('organization_id')
        if raw_param:
            try:
                target_id = int(raw_param)
            except (TypeError, ValueError):
                return error_response('validation_error', 'organization_id must be an integer.', 400)

    user_role = g.current_user.role.upper() if hasattr(g, 'current_user') and g.current_user else ''

    if target_id is None:
        target_id = g.current_user.organization_id

    # Enforce organization boundaries
    if user_role != 'SUPER_ADMIN' and target_id != g.current_user.organization_id:
        return error_response('forbidden', 'You do not have permission to access another organization\'s statistics.', 403)

    org = Organization.query.filter_by(organization_id=target_id).first()
    if org is None:
        return error_response('not_found', 'Organization not found.', 404)

    # Complaint metrics
    total_complaints = Complaint.query.filter_by(organization_id=target_id).count()
    pending = Complaint.query.filter_by(organization_id=target_id, status='PENDING').count()
    assigned = Complaint.query.filter_by(organization_id=target_id, status='ASSIGNED').count()
    in_progress = Complaint.query.filter_by(organization_id=target_id, status='IN_PROGRESS').count()
    resolved = Complaint.query.filter_by(organization_id=target_id, status='RESOLVED').count()
    reopened = Complaint.query.filter_by(organization_id=target_id, status='REOPENED').count()
    escalated = Complaint.query.filter_by(organization_id=target_id, status='ESCALATED').count()
    closed = Complaint.query.filter_by(organization_id=target_id, status='CLOSED').count()

    high_priority = Complaint.query.filter_by(organization_id=target_id, final_priority='HIGH').count()
    medium_priority = Complaint.query.filter_by(organization_id=target_id, final_priority='MEDIUM').count()
    low_priority = Complaint.query.filter_by(organization_id=target_id, final_priority='LOW').count()

    active_high_priority = Complaint.query.filter(
        Complaint.organization_id == target_id,
        Complaint.final_priority == 'HIGH',
        ~Complaint.status.in_(['RESOLVED', 'CLOSED']),
    ).count()

    # User metrics
    total_users = User.query.filter_by(organization_id=target_id, is_active=True).count()
    students_count = User.query.filter_by(organization_id=target_id, role='STUDENT', is_active=True).count()
    supervisors_count = User.query.filter_by(organization_id=target_id, role='SUPERVISOR', is_active=True).count()
    admins_count = User.query.filter_by(organization_id=target_id, role='ORG_ADMIN', is_active=True).count()

    # Operational metrics
    departments_count = Department.query.filter_by(organization_id=target_id).count()
    total_lf = LostFound.query.filter_by(organization_id=target_id).count()
    open_lf = LostFound.query.filter_by(organization_id=target_id, status='OPEN').count()
    closed_lf = LostFound.query.filter_by(organization_id=target_id, status='CLOSED').count()
    announcements_count = Announcement.query.filter_by(organization_id=target_id).count()

    stats_data = {
        'organization_id': org.organization_id,
        'organization_name': org.organization_name,
        'organization_code': org.organization_code,
        # Flattened top-level counts matching AdminDashboardStats conventions
        'total': total_complaints,
        'pending': pending,
        'assigned': assigned,
        'in_progress': in_progress,
        'resolved': resolved,
        'reopened': reopened,
        'escalated': escalated,
        'closed': closed,
        'high_priority': high_priority,
        'medium_priority': medium_priority,
        'low_priority': low_priority,
        'active_high_priority': active_high_priority,
        # Granular categorized subsections
        'complaints': {
            'total': total_complaints,
            'pending': pending,
            'assigned': assigned,
            'in_progress': in_progress,
            'resolved': resolved,
            'reopened': reopened,
            'escalated': escalated,
            'closed': closed,
            'high_priority': high_priority,
            'medium_priority': medium_priority,
            'low_priority': low_priority,
            'active_high_priority': active_high_priority,
        },
        'users': {
            'total': total_users,
            'students': students_count,
            'supervisors': supervisors_count,
            'admins': admins_count,
        },
        'departments_count': departments_count,
        'lost_found': {
            'total': total_lf,
            'open': open_lf,
            'closed': closed_lf,
        },
        'announcements_count': announcements_count,
    }

    return success_response(stats_data, 'Stats retrieved', 200)
