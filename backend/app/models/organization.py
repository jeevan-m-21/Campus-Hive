"""Organization model for CampusHive."""

from app.database import db
from app.models.base import BaseModel, CreatedAtMixin


class Organization(BaseModel, CreatedAtMixin):
    """organizations table."""

    __tablename__ = 'organizations'

    organization_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    organization_name = db.Column(db.String(150), unique=True, nullable=False)
    organization_code = db.Column(db.String(20), unique=True, nullable=False)
    email = db.Column(db.String(100))
    phone = db.Column(db.String(20))
    address = db.Column(db.Text)
    city = db.Column(db.String(100))
    state = db.Column(db.String(100))
    country = db.Column(db.String(100))
    logo_url = db.Column(db.String(255))
    is_active = db.Column(db.Boolean, server_default=db.text('1'))
    email_domain = db.Column(db.String(100), unique=True)

    users = db.relationship('User', backref='organization', lazy=True)
    departments = db.relationship('Department', backref='organization', lazy=True)
    complaints = db.relationship('Complaint', backref='organization', lazy=True)
    lost_found_items = db.relationship('LostFound', backref='organization', lazy=True)
    announcements = db.relationship('Announcement', backref='organization', lazy=True)

    def __repr__(self):
        return f'<Organization {self.organization_name}>'
