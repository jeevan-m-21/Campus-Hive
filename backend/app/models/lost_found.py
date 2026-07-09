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
    status = db.Column(
        db.Enum('OPEN', 'CLAIM_REQUESTED', 'CLAIMED', 'CLOSED'),
        server_default=db.text("'OPEN'"),
    )
    claimed_by = db.Column(db.Integer, db.ForeignKey('users.user_id'))

    __table_args__ = (
        db.Index('organization_id', 'organization_id'),
        db.Index('posted_by', 'posted_by'),
        db.Index('claimed_by', 'claimed_by'),
    )

    images = db.relationship('LostFoundImage', backref='item', lazy=True, cascade='all, delete-orphan')
    chat_messages = db.relationship('LostFoundChat', backref='item', lazy=True, cascade='all, delete-orphan')

    def __repr__(self):
        return f'<LostFound {self.item_id}>'