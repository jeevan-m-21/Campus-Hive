"""Lost and found image model for CampusHive."""

from app.database import db
from app.models.base import BaseModel


class LostFoundImage(BaseModel):
    """lost_found_images table."""

    __tablename__ = 'lost_found_images'

    image_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    item_id = db.Column(
        db.Integer,
        db.ForeignKey('lost_found.item_id', ondelete='CASCADE'),
        nullable=False,
    )
    image_url = db.Column(db.String(500), nullable=False)
    uploaded_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )

    __table_args__ = (
        db.Index('item_id', 'item_id'),
    )

    def to_dict(self):
        return {
            "image_id": self.image_id,
            "item_id": self.item_id,
            "image_url": self.image_url,
            "uploaded_at": self.uploaded_at.isoformat() if self.uploaded_at else None,
        }

    def __repr__(self):
        return f'<LostFoundImage {self.image_id}>'