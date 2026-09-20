"""ML complaint-priority retraining batch model."""

from app.database import db
from app.models.base import BaseModel, CreatedAtMixin


class MlRetrainingBatch(BaseModel, CreatedAtMixin):
    """A claimed and evaluated complaint retraining batch."""

    __tablename__ = 'ml_retraining_batches'

    batch_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    eligible_count = db.Column(db.Integer, nullable=False)
    selected_count = db.Column(db.Integer, nullable=False)
    status = db.Column(db.String(20), nullable=False)
    accuracy = db.Column(db.Float)
    macro_precision = db.Column(db.Float)
    macro_recall = db.Column(db.Float)
    macro_f1 = db.Column(db.Float)
    candidate_artifact_path = db.Column(db.String(500))
    error_message = db.Column(db.Text)

    items = db.relationship(
        'MlRetrainingItem',
        back_populates='batch',
        lazy=True,
        cascade='all, delete-orphan',
    )