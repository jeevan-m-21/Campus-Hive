"""User model for CampusHive."""

from app.database import db
from app.models.base import BaseModel, CreatedAtMixin


class User(BaseModel, CreatedAtMixin):
	"""users table."""

	__tablename__ = 'users'

	user_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
	organization_id = db.Column(
		db.Integer,
		db.ForeignKey('organizations.organization_id'),
		nullable=False,
	)
	academic_department_id = db.Column(
		db.Integer,
		db.ForeignKey(
			'academic_departments.academic_department_id',
			ondelete='SET NULL'
		),
		nullable=True
	)
	department_id = db.Column(
		db.Integer,
		db.ForeignKey('departments.department_id'),
	)
	full_name = db.Column(db.String(100), nullable=False)
	usn_or_employee_id = db.Column(db.String(30))
	email = db.Column(db.String(100), unique=True, nullable=False)
	firebase_uid = db.Column(db.String(255), unique=True, nullable=False)
	phone = db.Column(db.String(15))
	role = db.Column(
		db.Enum('SUPER_ADMIN', 'ORG_ADMIN', 'SUPERVISOR', 'STUDENT'),
		nullable=False,
	)
	profile_image = db.Column(db.String(255))
	is_active = db.Column(db.Boolean, server_default=db.text('1'))
	fcm_token = db.Column(db.Text)
	last_login = db.Column(db.TIMESTAMP)

	academic_department = db.relationship(
		'AcademicDepartment',
		back_populates='users',
		lazy=True
	)
	complaints_as_student = db.relationship(
		'Complaint',
		foreign_keys='Complaint.student_id',
		backref='student_user',
		lazy=True,
	)
	complaints_as_supervisor = db.relationship(
		'Complaint',
		foreign_keys='Complaint.supervisor_id',
		backref='supervisor_user',
		lazy=True,
	)
	complaint_supports = db.relationship('ComplaintSupport', backref='student_user', lazy=True)
	complaint_chat_messages = db.relationship('ComplaintChat', backref='sender_user', lazy=True)
	complaint_status_updates = db.relationship('ComplaintStatusHistory', backref='updated_by_user', lazy=True)
	lost_found_posts = db.relationship('LostFound', foreign_keys='LostFound.posted_by', backref='posted_by_user', lazy=True)
	lost_found_claims = db.relationship('LostFound', foreign_keys='LostFound.claimed_by', backref='claimed_by_user', lazy=True)
	lost_found_chat_messages = db.relationship('LostFoundChat', backref='sender_user', lazy=True)
	announcements_created = db.relationship('Announcement', backref='created_by_user', lazy=True)
	notifications = db.relationship('Notification', backref='user', lazy=True)
	def to_dict(self):
		return {
			"user_id": self.user_id,
			"organization_id": self.organization_id,
			"department_id": self.department_id,
			"full_name": self.full_name,
			"usn_or_employee_id": self.usn_or_employee_id,
			"email": self.email,
			"firebase_uid": self.firebase_uid,
			"phone": self.phone,
			"role": self.role,
			"profile_image": self.profile_image,
			"is_active": bool(self.is_active),
			"fcm_token": self.fcm_token,
			"last_login": self.last_login.isoformat() if self.last_login else None,
			"created_at": self.created_at.isoformat() if self.created_at else None,
		}

	def __repr__(self):
		return f'<User {self.full_name}>'
