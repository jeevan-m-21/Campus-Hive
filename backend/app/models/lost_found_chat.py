"""Lost and found chat model for CampusHive."""

from app.database import db
from app.models.base import BaseModel


class LostFoundChat(BaseModel):
    """lost_found_chat table."""

    __tablename__ = 'lost_found_chat'

    message_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    item_id = db.Column(
        db.Integer,
        db.ForeignKey('lost_found.item_id', ondelete='CASCADE'),
        nullable=False,
    )
    sender_id = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id', ondelete='CASCADE'),
        nullable=False,
    )
    message = db.Column(db.Text, nullable=False)
    message_type = db.Column(
        db.Enum('TEXT', 'IMAGE'),
        server_default=db.text("'TEXT'"),
    )
    image_url = db.Column(db.String(500))
    is_read = db.Column(db.Boolean, server_default=db.text('0'))
    sent_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )

    __table_args__ = (
        db.Index('item_id', 'item_id'),
        db.Index('sender_id', 'sender_id'),
    )

    def __repr__(self):
        return f'<LostFoundChat {self.message_id}>'