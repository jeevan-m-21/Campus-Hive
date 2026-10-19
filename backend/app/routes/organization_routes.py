"""
Organization routes
Organization management endpoints
"""

from flask import Blueprint, request, g
from app.models import Organization, AcademicDepartment
from app.middleware.auth import jwt_required, require_role
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
@jwt_required
def get_organization():
    """Get organization details"""
    return success_response({}, 'Organization retrieved', 200)


@org_bp.route('/<org_id>/stats', methods=['GET'])
@jwt_required
@require_role('admin', 'super_admin')
def get_org_stats(org_id):
    """Get organization statistics"""
    return success_response({}, 'Stats retrieved', 200)
