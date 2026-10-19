"""Complaint status history model for CampusHive."""

from app.database import db
from app.models.base import BaseModel


class ComplaintStatusHistory(BaseModel):
    """complaint_status_history table."""

    __tablename__ = 'complaint_status_history'

    history_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    complaint_id = db.Column(
        db.Integer,
        db.ForeignKey('complaints.complaint_id', ondelete='CASCADE'),
        nullable=False,
    )
    updated_by = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id'),
        nullable=False,
    )
    old_status = db.Column(db.Enum('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'REOPENED', 'ESCALATED', 'CLOSED'))
    new_status = db.Column(
        db.Enum('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'REOPENED', 'ESCALATED', 'CLOSED'),
        nullable=False,
    )
    remarks = db.Column(db.Text)
    updated_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )

    __table_args__ = (
        db.Index('complaint_id', 'complaint_id'),
        db.Index('updated_by', 'updated_by'),
    )

    def to_dict(self):
        return {
            'history_id': self.history_id,
            'complaint_id': self.complaint_id,
            'old_status': self.old_status,
            'new_status': self.new_status,
            'remarks': self.remarks,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'updated_by': self.updated_by,
            'updater_name': self.updated_by_user.full_name if self.updated_by_user else None,
        }

    def __repr__(self):
        return f'<ComplaintStatusHistory {self.history_id}>'