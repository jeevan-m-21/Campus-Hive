"""Department model for CampusHive."""

from app.database import db
from app.models.base import BaseModel, CreatedAtMixin


class Department(BaseModel, CreatedAtMixin):
    """departments table."""

    __tablename__ = 'departments'

    department_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    organization_id = db.Column(
        db.Integer,
        db.ForeignKey('organizations.organization_id', ondelete='CASCADE'),
        nullable=False,
    )
    department_name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    priority_high_hours = db.Column(db.Integer, server_default=db.text('24'))
    priority_medium_hours = db.Column(db.Integer, server_default=db.text('72'))
    priority_low_hours = db.Column(db.Integer, server_default=db.text('168'))

    users = db.relationship('User', backref='department', lazy=True)
    complaints = db.relationship(
        'Complaint',
        back_populates='department',
        lazy=True
    )

    def to_dict(self):
        return {
            "department_id": self.department_id,
            "organization_id": self.organization_id,
            "department_name": self.department_name,
            "description": self.description,
        }

    def __repr__(self):
        return f'<Department {self.department_name}>'
