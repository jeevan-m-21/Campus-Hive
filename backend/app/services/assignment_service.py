"""
Complaint assignment service
Handles automatic supervisor assignment
"""

from app.database import db
from app.models import Complaint, Supervisor, CategoryDepartmentMapping


class AssignmentService:
    """Service for complaint assignment"""
    
    @staticmethod
    def assign_supervisor(complaint):
        """
        Auto-assign supervisor to complaint
        
        Args:
            complaint: Complaint model instance
            
        Returns:
            Supervisor: Assigned supervisor or None
        """
        # Find department for category
        mapping = CategoryDepartmentMapping.query.filter_by(
            organization_id=complaint.organization_id,
            category=complaint.category
        ).first()
        
        if not mapping:
            return None
        
        # Find available supervisor with least workload
        supervisors = Supervisor.query.filter_by(
            organization_id=complaint.organization_id,
            department_id=mapping.department_id,
            is_available=True
        ).all()
        
        if not supervisors:
            return None
        
        # Get supervisor with minimum pending complaints
        supervisor = min(supervisors, key=lambda s: s.current_pending_count)
        
        # Assign
        complaint.supervisor_id = supervisor.id
        db.session.commit()
        
        # TODO: Send FCM notification
        # TODO: Update workload count
        
        return supervisor
