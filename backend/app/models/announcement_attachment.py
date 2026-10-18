"""Announcement attachment model for CampusHive."""

from app.database import db
from app.models.base import BaseModel


class AnnouncementAttachment(BaseModel):
    """announcement_attachments table."""

    __tablename__ = 'announcement_attachments'

    attachment_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    announcement_id = db.Column(
        db.Integer,
        db.ForeignKey('announcements.announcement_id', ondelete='CASCADE'),
        nullable=False,
    )
    attachment_type = db.Column(
        db.Enum('IMAGE', 'PDF', 'LINK'),
        nullable=False,
    )
    attachment_url = db.Column(db.String(500), nullable=False)
    original_filename = db.Column(db.String(255), nullable=True)
    file_path = db.Column(db.String(500), nullable=True)
    mime_type = db.Column(db.String(100), nullable=True)
    file_size = db.Column(db.Integer, nullable=True)
    created_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )

    __table_args__ = (
        db.Index('idx_announcement_attachments_announcement', 'announcement_id'),
    )

    def to_dict(self):
        return {
            "attachment_id": self.attachment_id,
            "announcement_id": self.announcement_id,
            "attachment_type": self.attachment_type,
            "attachment_url": self.attachment_url,
            "original_filename": self.original_filename,
            "mime_type": self.mime_type,
            "file_size": self.file_size,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f'<AnnouncementAttachment {self.attachment_id}>'
