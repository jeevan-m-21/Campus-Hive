"""Academic department model for CampusHive."""

from app.database import db
from app.models.base import BaseModel, CreatedAtMixin


class AcademicDepartment(BaseModel, CreatedAtMixin):
	"""academic_departments table."""

	__tablename__ = 'academic_departments'
	__table_args__ = (
        db.UniqueConstraint(
            'organization_id',
            'department_code',
            name='uq_academic_department'
        ),
    )

	academic_department_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
	organization_id = db.Column(
		db.Integer,
		db.ForeignKey('organizations.organization_id', ondelete='CASCADE'),
		nullable=False,
	)
	department_name = db.Column(db.String(100), nullable=False)
	department_code = db.Column(db.String(20), nullable=False)
	is_active = db.Column(db.Boolean, server_default=db.text('1'))

	organization = db.relationship('Organization', backref='academic_departments', lazy=True)
	users = db.relationship(
        'User',
        back_populates='academic_department',
        lazy=True
    )
	def to_dict(self):
		return {
            "academic_department_id": self.academic_department_id,
            "organization_id": self.organization_id,
            "department_name": self.department_name,
            "department_code": self.department_code,
            "is_active": self.is_active,
            "created_at": (
                self.created_at.isoformat()
                if self.created_at else None
            )
        }
	def __repr__(self):
		return f'<AcademicDepartment {self.department_name}>'
