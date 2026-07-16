"""Lost and found model for CampusHive."""

from app.database import db
from app.models.base import BaseModel, TimestampMixin


class LostFound(BaseModel, TimestampMixin):
    """lost_found table."""

    __tablename__ = 'lost_found'

    item_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    organization_id = db.Column(
        db.Integer,
        db.ForeignKey('organizations.organization_id'),
        nullable=False,
    )
    posted_by = db.Column(
        db.Integer,
        db.ForeignKey('users.user_id'),
        nullable=False,
    )
    item_type = db.Column(db.Enum('LOST', 'FOUND'), nullable=False)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    category = db.Column(db.String(100))
    location = db.Column(db.String(255))
    date_of_incident = db.Column(db.Date)
    resolved_at = db.Column(db.DateTime)
    status = db.Column(
        db.Enum('OPEN', 'CLOSED'),
        server_default=db.text("'OPEN'"),
    )

    __table_args__ = (
        db.Index('organization_id', 'organization_id'),
        db.Index('posted_by', 'posted_by'),
    )

    images = db.relationship('LostFoundImage', backref='item', lazy=True, cascade='all, delete-orphan')
    chat_messages = db.relationship('LostFoundChat', backref='item', lazy=True, cascade='all, delete-orphan')

    def to_dict(self):
        return {
            "item_id": self.item_id,
            "organization_id": self.organization_id,
            "posted_by": self.posted_by,
            "poster_name": self.posted_by_user.full_name if self.posted_by_user else None,
            "item_type": str(self.item_type),
            "title": self.title,
            "description": self.description,
            "category": self.category,
            "location": self.location,
            "date_of_incident": self.date_of_incident.isoformat() if self.date_of_incident else None,
            "status": str(self.status),
            "resolved_at": self.resolved_at.isoformat() if self.resolved_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "image_count": len(self.images) if self.images else 0,
            "images": [
                image.to_dict()
                for image in self.images
            ]
        }

    def __repr__(self):
        return f'<LostFound {self.item_id}>'