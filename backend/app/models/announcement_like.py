"""Announcement like model for CampusHive."""

from app.database import db
from app.models.base import BaseModel


class AnnouncementLike(BaseModel):
    """announcement_likes table."""

    __tablename__ = 'announcement_likes'

    like_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    announcement_id = db.Column(
        db.Integer,
        db.ForeignKey('announcements.announcement_id', ondelete='CASCADE'),
        nullable=False,
    )
    user_id = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id', ondelete='CASCADE'),
        nullable=False,
    )
    created_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )

    __table_args__ = (
        db.UniqueConstraint('announcement_id', 'user_id', name='announcement_user_like_unique'),
        db.Index('idx_announcement_likes_announcement', 'announcement_id'),
        db.Index('idx_announcement_likes_user', 'user_id'),
    )

    def __repr__(self):
        return f'<AnnouncementLike {self.like_id}>'
