"""Complaint priority calculation services."""

import math
import os
from datetime import datetime, timedelta

from sklearn.utils.validation import check_is_fitted

from app.ml.priority_model import ComplaintPriorityModel
from app.models.department import Department


class PriorityService:
    """Calculate complaint priority without adding persisted score columns."""

    SUPPORT_CAP = 10
    ML_SCORES = {'LOW': 0.0, 'MEDIUM': 0.5, 'HIGH': 1.0}

    @staticmethod
    def calculate_support_score(support_count):
        """Normalize support with a capped logarithmic curve."""
        support_count = max(0, int(support_count or 0))
        return min(
            1.0,
            math.log1p(support_count)
            / math.log1p(PriorityService.SUPPORT_CAP),
        )

    @staticmethod
    def calculate_final_priority(ml_priority, support_count):
        """Combine ML and community scores with equal weighting."""
        normalized_priority = str(ml_priority or 'MEDIUM').upper()
        if normalized_priority not in PriorityService.ML_SCORES:
            raise ValueError(f'Unsupported ML priority: {ml_priority}')

        final_score = (
            PriorityService.ML_SCORES[normalized_priority] * 0.5
            + PriorityService.calculate_support_score(support_count) * 0.5
        )
        if final_score <= 0.33:
            return 'LOW'
        if final_score <= 0.66:
            return 'MEDIUM'
        return 'HIGH'

    @staticmethod
    def _fallback_priority(description):
        """Use a deterministic fallback when no trained model exists."""
        text = (description or '').lower()
        high_terms = (
            'danger', 'fire', 'flood', 'outage', 'emergency', 'unsafe',
        )
        medium_terms = (
            'broken', 'leak', 'blocked', 'failure', 'issue', 'problem',
        )
        if any(term in text for term in high_terms):
            return 'HIGH'
        if any(term in text for term in medium_terms):
            return 'MEDIUM'
        return 'LOW'

    @staticmethod
    def calculate_ml_priority(description):
        """Predict ML priority, with an explicit fallback until trained."""
        model_path = os.getenv(
            'CAMPUSHIVE_PRIORITY_MODEL_PATH',
            os.path.join(
                os.path.dirname(__file__), '..', 'ml', 'priority_model.joblib',
            ),
        )
        model = ComplaintPriorityModel(model_path=model_path)
        if not os.path.exists(model_path):
            if os.getenv('FLASK_ENV', 'development').lower() == 'production':
                raise FileNotFoundError(
                    f'No trained priority model found at {model_path}',
                )
            return PriorityService._fallback_priority(description)

        check_is_fitted(model.pipeline)
        result = model.predict(description)
        priority = str(result['priority']).upper()
        if priority not in PriorityService.ML_SCORES:
            raise ValueError(f'Unsupported model priority: {priority}')
        return priority

    @staticmethod
    def calculate_deadline(complaint, final_priority):
        """Calculate a deadline from the complaint department configuration."""
        department = Department.query.filter_by(
            department_id=complaint.department_id,
        ).first()
        if department is None:
            department = complaint.department
        hours_by_priority = {
            'HIGH': department.priority_high_hours,
            'MEDIUM': department.priority_medium_hours,
            'LOW': department.priority_low_hours,
        }
        hours = hours_by_priority[final_priority]
        start_time = complaint.created_at or datetime.utcnow()
        return start_time + timedelta(hours=int(hours))

    @staticmethod
    def update_complaint_priority(complaint, recalculate_ml=False):
        """Update stored categorical priorities and the configured deadline."""
        if recalculate_ml or not complaint.ml_priority:
            complaint.ml_priority = PriorityService.calculate_ml_priority(
                complaint.description,
            )

        previous_final_priority = complaint.final_priority
        complaint.final_priority = PriorityService.calculate_final_priority(
            complaint.ml_priority,
            complaint.support_count,
        )
        if (
            complaint.final_priority != previous_final_priority
            or not complaint.deadline
        ):
            complaint.deadline = PriorityService.calculate_deadline(
                complaint,
                complaint.final_priority,
            )
