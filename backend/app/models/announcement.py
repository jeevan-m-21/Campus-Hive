"""Announcement model for CampusHive."""

from app.database import db
from app.models.base import BaseModel, TimestampMixin


class Announcement(BaseModel, TimestampMixin):
    """announcements table."""

    __tablename__ = 'announcements'

    announcement_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    organization_id = db.Column(
        db.Integer,
        db.ForeignKey('organizations.organization_id'),
        nullable=False,
    )
    created_by = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id'),
        nullable=False,
    )
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    attachment_url = db.Column(db.String(500))
    attachment_type = db.Column(
        db.Enum('NONE', 'IMAGE', 'PDF', 'LINK'),
        server_default=db.text("'NONE'"),
    )
    is_important = db.Column(db.Boolean, server_default=db.text('0'))

    __table_args__ = (
        db.Index('organization_id', 'organization_id'),
        db.Index('created_by', 'created_by'),
    )

    def __repr__(self):
        return f'<Announcement {self.announcement_id}>'