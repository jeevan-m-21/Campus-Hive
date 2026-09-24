"""Complaint image model for CampusHive."""

from app.database import db
from app.models.base import BaseModel


class ComplaintImage(BaseModel):
    """complaint_images table."""

    __tablename__ = 'complaint_images'

    image_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    complaint_id = db.Column(
        db.Integer,
        db.ForeignKey('complaints.complaint_id', ondelete='CASCADE'),
        nullable=False,
    )
    image_url = db.Column(db.String(500), nullable=False)
    uploaded_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )

    __table_args__ = (
        db.Index('complaint_id', 'complaint_id'),
    )

    def to_dict(self):
        return {
            "image_id": self.image_id,
            "complaint_id": self.complaint_id,
            "image_url": self.image_url,
            "uploaded_at": self.uploaded_at.isoformat() if self.uploaded_at else None,
        }

    def __repr__(self):
        return f'<ComplaintImage {self.image_id}>'