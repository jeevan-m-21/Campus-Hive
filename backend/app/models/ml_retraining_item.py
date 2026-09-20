"""ML complaint-priority retraining item model."""

from app.database import db
from app.models.base import BaseModel, CreatedAtMixin


class MlRetrainingItem(BaseModel, CreatedAtMixin):
    """Immutable complaint snapshot claimed for one retraining batch."""

    __tablename__ = 'ml_retraining_items'

    item_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    batch_id = db.Column(
        db.Integer,
        db.ForeignKey('ml_retraining_batches.batch_id', ondelete='CASCADE'),
        nullable=False,
    )
    complaint_id = db.Column(
        db.Integer,
        db.ForeignKey('complaints.complaint_id', ondelete='RESTRICT'),
        nullable=False,
        unique=True,
    )
    eligible_at = db.Column(db.DateTime, nullable=False)
    description_snapshot = db.Column(db.Text, nullable=False)
    priority_label = db.Column(db.Enum('LOW', 'MEDIUM', 'HIGH'), nullable=False)
    source = db.Column(db.String(20), nullable=False, default='REAL')

    batch = db.relationship('MlRetrainingBatch', back_populates='items')
    complaint = db.relationship('Complaint', backref='ml_retraining_item')