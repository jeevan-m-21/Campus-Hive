"""
ML model for complaint prioritization
Scikit-Learn based priority prediction
"""

import os
import joblib
from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.utils.validation import check_is_fitted


class ComplaintPriorityModel:
    """ML Model for complaint priority prediction"""

    LABELS = ('low', 'medium', 'high')
    LABEL_TO_ID = {label: index for index, label in enumerate(LABELS)}
    ID_TO_LABEL = dict(enumerate(LABELS))

    def __init__(self, model_path=None):
        """
        Initialize model

        Args:
            model_path: Path to saved model
        """
        self.model_path = model_path
        self.pipeline = None
        self.category_encoder = None

        if model_path and os.path.exists(model_path):
            self.load_model()
        else:
            self.create_pipeline()

    def create_pipeline(self):
        """Create ML pipeline"""
        self.pipeline = Pipeline([
            ('tfidf', TfidfVectorizer(
                max_features=1000,
                ngram_range=(1, 2),
                lowercase=True,
                min_df=1,
            )),
            ('classifier', RandomForestClassifier(
                n_estimators=200,
                random_state=42,
                class_weight='balanced',
            )),
        ])

    def train(self, descriptions, priorities):
        """
        Train model

        Args:
            descriptions: List of complaint descriptions
            priorities: List of priority labels (low, medium, high)
        """
        if descriptions is None or priorities is None:
            raise ValueError('descriptions and priorities are required')

        descriptions = list(descriptions)
        priorities = list(priorities)
        if not descriptions or len(descriptions) != len(priorities):
            raise ValueError(
                'descriptions and priorities must be non-empty and '
                'equal in length',
            )

        normalized_descriptions = [
            '' if description is None else str(description).strip()
            for description in descriptions
        ]
        normalized_priorities = []
        for priority in priorities:
            normalized_priority = str(priority).strip().lower()
            if normalized_priority not in self.LABEL_TO_ID:
                raise ValueError(
                    f'Invalid priority label {priority!r}; '
                    f'expected one of {self.LABELS}',
                )
            normalized_priorities.append(self.LABEL_TO_ID[normalized_priority])

        self.create_pipeline()
        self.pipeline.fit(normalized_descriptions, normalized_priorities)

    def predict(self, description):
        """
        Predict priority for complaint

        Args:
            description (str): Complaint description

        Returns:
            dict: Prediction result with priority and confidence
        """
        if self.pipeline is None:
            raise RuntimeError(
                'ComplaintPriorityModel pipeline is not initialized',
            )
        try:
            check_is_fitted(self.pipeline)
        except (TypeError, ValueError) as exc:
            raise RuntimeError(
                'ComplaintPriorityModel must be trained before prediction',
            ) from exc
        normalized_description = (
            '' if description is None else str(description)
        )
        prediction = self.pipeline.predict([normalized_description])[0]
        probabilities = self.pipeline.predict_proba(
            [normalized_description],
        )[0]

        if prediction not in self.ID_TO_LABEL:
            raise RuntimeError(f'Unknown model prediction: {prediction}')

        return {
            'priority': self.ID_TO_LABEL[prediction],
            'confidence': float(max(probabilities)),
        }

    def save_model(self, model_path):
        """Save model to disk"""
        if self.pipeline is None:
            raise RuntimeError('Cannot save an uninitialized model')
        check_is_fitted(self.pipeline)
        os.makedirs(
            os.path.dirname(os.path.abspath(model_path)),
            exist_ok=True,
        )
        joblib.dump(self.pipeline, model_path)

    def load_model(self):
        """Load model from disk"""
        if not self.model_path or not os.path.exists(self.model_path):
            raise FileNotFoundError(f'Model file not found: {self.model_path}')
        self.pipeline = joblib.load(self.model_path)
