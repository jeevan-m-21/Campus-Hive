"""Notification model for CampusHive."""

from app.database import db
from app.models.base import BaseModel, CreatedAtMixin


class Notification(BaseModel, CreatedAtMixin):
    """notifications table."""

    __tablename__ = 'notifications'

    notification_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id', ondelete='CASCADE'),
        nullable=False,
    )
    title = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    notification_type = db.Column(
        db.Enum('COMPLAINT', 'ANNOUNCEMENT', 'LOST_FOUND', 'CHAT', 'SYSTEM'),
        nullable=False,
    )
    reference_id = db.Column(db.Integer)
    is_read = db.Column(db.Boolean, server_default=db.text('0'))

    __table_args__ = (
        db.Index('user_id', 'user_id'),
    )

    def __repr__(self):
        return f'<Notification {self.notification_id}>'