"""Email verification model for registration OTPs."""

from app.database import db
from app.models.base import BaseModel, TimestampMixin


class EmailVerification(BaseModel, TimestampMixin):
    """email_verifications table for registration OTP storage and rate limiting."""

    __tablename__ = 'email_verifications'

    verification_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    email = db.Column(db.String(100), nullable=False, index=True)
    ip_address = db.Column(db.String(45), nullable=True, index=True)
    otp_hash = db.Column(db.String(64), nullable=False)
    otp_expires_at = db.Column(db.DateTime, nullable=False)
    attempts_left = db.Column(db.Integer, nullable=False, default=3)
    resend_available_at = db.Column(db.DateTime, nullable=False)
    is_verified = db.Column(db.Boolean, nullable=False, default=False)
    verified_at = db.Column(db.DateTime, nullable=True)
    verification_token_hash = db.Column(db.String(64), nullable=True, index=True)
    token_expires_at = db.Column(db.DateTime, nullable=True)
    is_consumed = db.Column(db.Boolean, nullable=False, default=False)
    consumed_at = db.Column(db.DateTime, nullable=True)

    # Pending registration data bindings (prevent tampering between OTP verification & registration)
    organization_id = db.Column(
        db.Integer,
        db.ForeignKey('organizations.organization_id', ondelete='CASCADE'),
        nullable=False,
    )
    academic_department_id = db.Column(
        db.Integer,
        db.ForeignKey('academic_departments.academic_department_id', ondelete='CASCADE'),
        nullable=False,
    )
    usn_or_employee_id = db.Column(db.String(30), nullable=False)

    # Relationships
    organization = db.relationship('Organization', lazy=True)
    academic_department = db.relationship('AcademicDepartment', lazy=True)

    __table_args__ = (
        db.Index('idx_email_verif_email_created', 'email', 'created_at'),
        db.Index('idx_email_verif_ip_created', 'ip_address', 'created_at'),
    )

    def to_dict(self):
        return {
            'verification_id': self.verification_id,
            'email': self.email,
            'ip_address': self.ip_address,
            'otp_expires_at': self.otp_expires_at.isoformat() if self.otp_expires_at else None,
            'attempts_left': self.attempts_left,
            'resend_available_at': self.resend_available_at.isoformat() if self.resend_available_at else None,
            'is_verified': self.is_verified,
            'verified_at': self.verified_at.isoformat() if self.verified_at else None,
            'token_expires_at': self.token_expires_at.isoformat() if self.token_expires_at else None,
            'is_consumed': self.is_consumed,
            'consumed_at': self.consumed_at.isoformat() if self.consumed_at else None,
            'organization_id': self.organization_id,
            'academic_department_id': self.academic_department_id,
            'usn_or_employee_id': self.usn_or_employee_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self):
        return f'<EmailVerification id={self.verification_id} email={self.email} verified={self.is_verified}>'
