"""
Escalation service
Handles automatic complaint escalation logic
"""

from datetime import datetime
from app.database import db
from app.models import Complaint, Notification
from app.utils.helpers import generate_uuid


class EscalationService:
    """Service for complaint escalation"""
    
    @staticmethod
    def check_escalations():
        """
        Check for complaints that need escalation
        Called periodically by scheduler
        """
        # Find overdue complaints
        overdue_complaints = Complaint.query.filter(
            Complaint.deadline < datetime.utcnow(),
            Complaint.status.in_(['pending', 'assigned', 'in_progress']),
            Complaint.escalation_level < 3
        ).all()
        
        for complaint in overdue_complaints:
            EscalationService.escalate_complaint(complaint)
    
    @staticmethod
    def escalate_complaint(complaint):
        """
        Escalate a complaint to next level
        
        Args:
            complaint: Complaint model instance
        """
        complaint.escalation_level += 1
        complaint.escalated_at = datetime.utcnow()
        db.session.commit()
        
        # TODO: Send notification
        # TODO: Update dashboard
