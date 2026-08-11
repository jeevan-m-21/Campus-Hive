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
        db.Index('idx_notifications_user_read_created_at', 'user_id', 'is_read', 'created_at'),
    )

    def to_dict(self):
        return {
            "notification_id": self.notification_id,
            "user_id": self.user_id,
            "title": self.title,
            "message": self.message,
            "notification_type": str(self.notification_type),
            "reference_id": self.reference_id,
            "is_read": self.is_read,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f'<Notification {self.notification_id}>'