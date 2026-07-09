"""Complaint support model for CampusHive."""

from app.database import db
from app.models.base import BaseModel


class ComplaintSupport(BaseModel):
    """complaint_supports table."""

    __tablename__ = 'complaint_supports'

    support_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    complaint_id = db.Column(
        db.Integer,
        db.ForeignKey('complaints.complaint_id', ondelete='CASCADE'),
        nullable=False,
    )
    student_id = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id', ondelete='CASCADE'),
        nullable=False,
    )
    supported_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )

    __table_args__ = (
        db.UniqueConstraint('complaint_id', 'student_id', name='complaint_id'),
        db.Index('student_id', 'student_id'),
    )

    def __repr__(self):
        return f'<ComplaintSupport {self.support_id}>'