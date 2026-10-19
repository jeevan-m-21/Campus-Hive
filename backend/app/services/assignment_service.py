"""
Complaint assignment service
Handles automatic category-based supervisor assignment,
missing supervisor admin fallback, and department supervisor designation.
"""

from app.database import db
from app.models import Complaint, ComplaintStatusHistory, Department, User
from app.services.notification_service import NotificationService


class AssignmentService:
    """Service for complaint supervisor assignment."""

    CATEGORY_TO_DEPARTMENT_NAME = {
        # Dataset categories
        'wifi / internet problem': 'Network Connectivity',
        'wifi': 'Network Connectivity',
        'internet': 'Network Connectivity',
        'network connectivity': 'Network Connectivity',
        'network': 'Network Connectivity',

        'classroom infrastructure': 'Infrastructure',
        'library issue': 'Infrastructure',
        'library': 'Infrastructure',
        'lab / computer issue': 'Infrastructure',
        'computer lab': 'Infrastructure',
        'infrastructure': 'Infrastructure',

        'electrical issue': 'Electrical',
        'electrical': 'Electrical',
        'electricity': 'Electrical',

        'cleanliness issue': 'Housekeeping',
        'cleanliness': 'Housekeeping',
        'water leakage': 'Housekeeping',
        'washroom issue': 'Housekeeping',
        'washroom': 'Housekeeping',
        'housekeeping': 'Housekeeping',

        'hostel issue': 'Hostel',
        'hostel': 'Hostel',

        'security / safety issue': 'Security',
        'security': 'Security',
        'safety': 'Security',

        'parking / transport issue': 'Parking & Transportation',
        'parking': 'Parking & Transportation',
        'transport': 'Parking & Transportation',
        'transportation': 'Parking & Transportation',
        'parking & transportation': 'Parking & Transportation',

        'canteen': 'Canteen',
        'canteen / food': 'Canteen',
        'food': 'Canteen',

        'other': 'Others',
        'others': 'Others',
    }

    @classmethod
    def resolve_department(cls, organization_id, department_id=None, category=None):
        """
        Resolve an operational Department for the organization from department_id or category string.

        Args:
            organization_id (int): Organization ID.
            department_id (int, optional): Explicit department ID.
            category (str, optional): Complaint category string.

        Returns:
            Department: Matching Department instance or None.
        """
        if department_id not in (None, ''):
            try:
                dept_id = int(department_id)
                department = Department.query.filter_by(
                    department_id=dept_id,
                    organization_id=organization_id,
                ).first()
                if department:
                    return department
            except (TypeError, ValueError):
                pass

        if category and isinstance(category, str):
            clean_category = category.strip().lower()
            dept_name = cls.CATEGORY_TO_DEPARTMENT_NAME.get(clean_category)
            if dept_name:
                department = Department.query.filter(
                    Department.organization_id == organization_id,
                    db.func.lower(Department.department_name) == dept_name.lower(),
                ).first()
                if department:
                    return department

            # Try direct match with existing department names in this organization
            department = Department.query.filter(
                Department.organization_id == organization_id,
                db.func.lower(Department.department_name) == clean_category,
            ).first()
            if department:
                return department

        return None

    @staticmethod
    def find_active_supervisor_for_department(department_id, organization_id):
        """
        Find an eligible active supervisor responsible for the department within the organization.
        Balances workload if multiple supervisors exist.

        Args:
            department_id (int): Department ID.
            organization_id (int): Organization ID.

        Returns:
            User: Active supervisor User instance or None.
        """
        supervisors = User.query.filter_by(
            organization_id=organization_id,
            department_id=department_id,
            role='SUPERVISOR',
            is_active=True,
        ).all()

        if not supervisors:
            return None

        if len(supervisors) == 1:
            return supervisors[0]

        # Workload balancing: choose supervisor with the fewest active/in-progress complaints
        def _get_workload(sup):
            return Complaint.query.filter(
                Complaint.supervisor_id == sup.user_id,
                Complaint.status.in_(['ASSIGNED', 'IN_PROGRESS']),
            ).count()

        return min(supervisors, key=_get_workload)

    @classmethod
    def auto_assign_complaint(cls, complaint, department):
        """
        Automatically assign complaint to the active supervisor for the department.
        If no supervisor is available, keeps complaint PENDING and notifies organization admins.

        Args:
            complaint (Complaint): The complaint to assign.
            department (Department): The operational department.

        Returns:
            User or None: The assigned supervisor, or None if unassigned.
        """
        complaint.department_id = department.department_id

        supervisor = cls.find_active_supervisor_for_department(
            department_id=department.department_id,
            organization_id=complaint.organization_id,
        )

        if supervisor is not None:
            complaint.supervisor_id = supervisor.user_id
            old_status = complaint.status or 'PENDING'
            complaint.status = 'ASSIGNED'

            history = ComplaintStatusHistory(
                complaint_id=complaint.complaint_id,
                updated_by=complaint.student_id,
                old_status=old_status,
                new_status='ASSIGNED',
                remarks=f'Automatically assigned to supervisor {supervisor.full_name} for department {department.department_name}.',
            )
            db.session.add(history)

            NotificationService.create_notification(
                supervisor.user_id,
                'New Complaint Assigned',
                f'A new complaint "{complaint.title}" has been assigned to you.',
                'COMPLAINT',
                complaint.complaint_id,
            )
            return supervisor

        # No supervisor available for this department
        complaint.supervisor_id = None
        complaint.status = 'PENDING'

        # Notify active organization administrators
        admins = User.query.filter_by(
            organization_id=complaint.organization_id,
            role='ORG_ADMIN',
            is_active=True,
        ).all()
        for admin in admins:
            NotificationService.create_notification(
                admin.user_id,
                'Unassigned Complaint',
                f'Complaint #{complaint.complaint_id} "{complaint.title}" in {department.department_name} has no supervisor assigned.',
                'COMPLAINT',
                complaint.complaint_id,
            )

        return None

    @classmethod
    def designate_department_supervisor(cls, department, supervisor, admin_user):
        """
        Designate a supervisor for an operational department and auto-assign
        all existing unassigned pending complaints in that department.

        Args:
            department (Department): The target department.
            supervisor (User): The supervisor User.
            admin_user (User): The designating admin.

        Returns:
            list[Complaint]: List of complaints newly assigned.
        """
        if department.organization_id != supervisor.organization_id:
            raise ValueError('Department and supervisor must belong to the same organization.')
        if supervisor.role != 'SUPERVISOR' or not supervisor.is_active:
            raise ValueError('Target user must be an active supervisor.')

        supervisor.department_id = department.department_id

        # Find eligible unassigned complaints in this department
        unassigned_complaints = Complaint.query.filter(
            Complaint.organization_id == department.organization_id,
            Complaint.department_id == department.department_id,
            Complaint.supervisor_id.is_(None),
            Complaint.status.in_(['PENDING', 'UNASSIGNED']),
        ).order_by(Complaint.created_at.asc()).all()

        for complaint in unassigned_complaints:
            old_status = complaint.status
            complaint.supervisor_id = supervisor.user_id
            complaint.status = 'ASSIGNED'

            history = ComplaintStatusHistory(
                complaint_id=complaint.complaint_id,
                updated_by=admin_user.user_id,
                old_status=old_status,
                new_status='ASSIGNED',
                remarks=f'Auto-assigned upon designating supervisor {supervisor.full_name} to {department.department_name}.',
            )
            db.session.add(history)

            # Notify student
            NotificationService.create_notification(
                complaint.student_id,
                'Complaint Assigned',
                f'Your complaint "{complaint.title}" has been assigned to a supervisor.',
                'COMPLAINT',
                complaint.complaint_id,
            )

        # Notify supervisor once (deduplicated summary notification)
        if unassigned_complaints:
            NotificationService.create_notification(
                supervisor.user_id,
                'Complaints Assigned',
                f'{len(unassigned_complaints)} pending complaint(s) in {department.department_name} have been assigned to you.',
                'COMPLAINT',
                unassigned_complaints[0].complaint_id,
            )

        return unassigned_complaints

    @classmethod
    def manual_assign_supervisor(cls, complaint, supervisor, admin_user):
        """
        Manually assign an eligible supervisor to a complaint by an administrator.

        Args:
            complaint (Complaint): The complaint.
            supervisor (User): The supervisor.
            admin_user (User): The administering user.

        Returns:
            Complaint: The updated complaint.
        """
        if admin_user.role not in ('ORG_ADMIN', 'SUPER_ADMIN'):
            raise PermissionError('Only administrators can assign supervisors.')
        if supervisor.organization_id != complaint.organization_id:
            raise ValueError('Supervisor does not belong to the same organization as the complaint.')
        if supervisor.role != 'SUPERVISOR' or not supervisor.is_active:
            raise ValueError('Selected user is not an active supervisor.')

        # Ensure supervisor is designated for the complaint's department
        if supervisor.department_id != complaint.department_id:
            raise ValueError(
                f'Supervisor is responsible for department #{supervisor.department_id}, '
                f'not the complaint department #{complaint.department_id}.'
            )

        if complaint.supervisor_id == supervisor.user_id:
            return complaint  # No-op

        old_status = complaint.status
        complaint.supervisor_id = supervisor.user_id

        if complaint.status in ('PENDING', 'UNASSIGNED'):
            complaint.status = 'ASSIGNED'

        history = ComplaintStatusHistory(
            complaint_id=complaint.complaint_id,
            updated_by=admin_user.user_id,
            old_status=old_status,
            new_status=complaint.status,
            remarks=f'Manually assigned to {supervisor.full_name} by administrator.',
        )
        db.session.add(history)

        NotificationService.create_notification(
            complaint.student_id,
            'Complaint Assigned',
            'Your complaint has been assigned to a supervisor.',
            'COMPLAINT',
            complaint.complaint_id,
        )

        NotificationService.create_notification(
            supervisor.user_id,
            'Complaint Assigned',
            f'Complaint "{complaint.title}" has been assigned to you by an administrator.',
            'COMPLAINT',
            complaint.complaint_id,
        )

        return complaint

    @classmethod
    def unassign_supervisor(cls, complaint, admin_user):
        """
        Unassign supervisor from complaint.

        Args:
            complaint (Complaint): The complaint.
            admin_user (User): The administering user.

        Returns:
            Complaint: The updated complaint.
        """
        if admin_user.role not in ('ORG_ADMIN', 'SUPER_ADMIN'):
            raise PermissionError('Only administrators can unassign supervisors.')

        if complaint.supervisor_id is None:
            return complaint

        old_status = complaint.status
        complaint.supervisor_id = None

        if complaint.status == 'ASSIGNED':
            complaint.status = 'PENDING'

        history = ComplaintStatusHistory(
            complaint_id=complaint.complaint_id,
            updated_by=admin_user.user_id,
            old_status=old_status,
            new_status=complaint.status,
            remarks='Supervisor unassigned by administrator.',
        )
        db.session.add(history)

        return complaint
