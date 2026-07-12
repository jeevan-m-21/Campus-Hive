"""Complaint model for CampusHive."""

from app.database import db
from app.models.base import BaseModel, TimestampMixin


class Complaint(BaseModel, TimestampMixin):
    """complaints table."""

    __tablename__ = 'complaints'

    complaint_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    organization_id = db.Column(
        db.Integer,
        db.ForeignKey('organizations.organization_id'),
        nullable=False,
    )
    student_id = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id'),
        nullable=False,
    )
    supervisor_id = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id'),
    )
    department_id = db.Column(
        db.Integer,
        db.ForeignKey('departments.department_id'),
        nullable=False,
    )
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(255))
    ml_priority = db.Column(db.Enum('LOW', 'MEDIUM', 'HIGH'))
    final_priority = db.Column(db.Enum('LOW', 'MEDIUM', 'HIGH'))
    status = db.Column(
        db.Enum('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'REOPENED', 'ESCALATED', 'CLOSED'),
        server_default=db.text("'PENDING'"),
    )
    support_count = db.Column(db.Integer, server_default=db.text('0'))
    deadline = db.Column(db.DateTime)
    resolved_at = db.Column(db.DateTime)
    student_feedback = db.Column(db.Enum('SATISFIED', 'NOT_SATISFIED'))

    __table_args__ = (
        db.Index('organization_id', 'organization_id'),
        db.Index('student_id', 'student_id'),
        db.Index('supervisor_id', 'supervisor_id'),
        db.Index('department_id', 'department_id'),
    )

    images = db.relationship('ComplaintImage', backref='complaint', lazy=True, cascade='all, delete-orphan')
    supports = db.relationship('ComplaintSupport', backref='complaint', lazy=True, cascade='all, delete-orphan')
    chat_messages = db.relationship('ComplaintChat', backref='complaint', lazy=True, cascade='all, delete-orphan')
    status_history = db.relationship('ComplaintStatusHistory', backref='complaint', lazy=True, cascade='all, delete-orphan')
    student = db.relationship(
        "User",
        foreign_keys=[student_id],
        backref="complaints_created"
    )
    supervisor = db.relationship(
        "User",
        foreign_keys=[supervisor_id],
        backref="assigned_complaints"
    )
    department = db.relationship(
        "Department",
        back_populates="complaints"
    )
    def to_dict(self):
        return {
            "complaint_id": self.complaint_id,
            "organization_id": self.organization_id,
            "student_id": self.student_id,
            "department_id": self.department_id,
            "supervisor_id": self.supervisor_id,
            "title": self.title,
            "description": self.description,
            "location": self.location,
            "ml_priority": self.ml_priority,
            "final_priority": self.final_priority,
            "status": self.status,
            "support_count": self.support_count,
            "deadline": self.deadline.isoformat() if self.deadline else None,
            "resolved_at": self.resolved_at.isoformat() if self.resolved_at else None,
            "student_feedback": self.student_feedback,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "student_name": self.student.full_name if self.student else None,
            "department_name": self.department.department_name if self.department else None,
        }

    def __repr__(self):
        return f'<Complaint {self.complaint_id}>'