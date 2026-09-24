"""Complaint chat model for CampusHive."""

from app.database import db
from app.models.base import BaseModel


class ComplaintChat(BaseModel):
    """complaint_chat table."""

    __tablename__ = 'complaint_chat'

    message_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    complaint_id = db.Column(
        db.Integer,
        db.ForeignKey('complaints.complaint_id', ondelete='CASCADE'),
        nullable=False,
    )
    sender_id = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id', ondelete='CASCADE'),
        nullable=False,
    )
    message = db.Column(db.Text, nullable=False)
    image_url = db.Column(db.String(500))
    is_read = db.Column(db.Boolean, server_default=db.text('0'))
    sent_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )

    __table_args__ = (
        db.Index('complaint_id', 'complaint_id'),
        db.Index('sender_id', 'sender_id'),
    )

    def to_dict(self):
        return {
            "message_id": self.message_id,
            "complaint_id": self.complaint_id,
            "sender_id": self.sender_id,
            "sender_name": self.sender_user.full_name if self.sender_user else None,
            "message": self.message,
            "image_url": self.image_url,
            "sent_at": self.sent_at.isoformat() if self.sent_at else None,
        }
    def __repr__(self):
        return f'<ComplaintChat {self.message_id}>'