"""
ML model for complaint prioritization
Scikit-Learn based priority prediction
"""

import os
import joblib
import numpy as np
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import TfidfVectorizer, StandardScaler
from sklearn.ensemble import RandomForestClassifier


class ComplaintPriorityModel:
    """ML Model for complaint priority prediction"""
    
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
            ('tfidf', TfidfVectorizer(max_features=100)),
            ('scaler', StandardScaler()),
            ('classifier', RandomForestClassifier(n_estimators=100, random_state=42))
        ])
    
    def train(self, descriptions, priorities):
        """
        Train model
        
        Args:
            descriptions: List of complaint descriptions
            priorities: List of priority labels (low, medium, high)
        """
        # Encode priority labels
        label_map = {'low': 0, 'medium': 1, 'high': 2}
        y = np.array([label_map.get(p, 1) for p in priorities])
        
        # Train
        self.pipeline.fit(descriptions, y)
    
    def predict(self, description):
        """
        Predict priority for complaint
        
        Args:
            description (str): Complaint description
            
        Returns:
            dict: Prediction result with priority and confidence
        """
        if not self.pipeline:
            return {'priority': 'medium', 'confidence': 0.5}
        
        prediction = self.pipeline.predict([description])[0]
        probabilities = self.pipeline.predict_proba([description])[0]
        
        priority_map = {0: 'low', 1: 'medium', 2: 'high'}
        
        return {
            'priority': priority_map.get(prediction, 'medium'),
            'confidence': max(probabilities)
        }
    
    def save_model(self, model_path):
        """Save model to disk"""
        if self.pipeline:
            joblib.dump(self.pipeline, model_path)
    
    def load_model(self):
        """Load model from disk"""
        if os.path.exists(self.model_path):
            self.pipeline = joblib.load(self.model_path)
