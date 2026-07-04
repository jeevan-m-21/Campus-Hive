"""
Base model with common fields and methods
All other models inherit from this
"""

from datetime import datetime
from uuid import uuid4
from app.database import db


class BaseModel(db.Model):
    """
    Abstract base model with common fields
    All models inherit from this
    """
    __abstract__ = True
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid4()))
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False
    )
    
    def to_dict(self, include=None, exclude=None):
        """
        Convert model to dictionary
        
        Args:
            include (list): Fields to include
            exclude (list): Fields to exclude
            
        Returns:
            dict: Model as dictionary
        """
        result = {}
        
        for column in self.__table__.columns:
            value = getattr(self, column.name)
            
            # Handle datetime
            if isinstance(value, datetime):
                value = value.isoformat()
            
            # Check include/exclude
            if include and column.name not in include:
                continue
            if exclude and column.name in exclude:
                continue
            
            result[column.name] = value
        
        return result
    
    def to_json(self):
        """Convert model to JSON-serializable dictionary"""
        return self.to_dict()
    
    def save(self):
        """Save model to database"""
        db.session.add(self)
        db.session.commit()
        return self
    
    def delete(self):
        """Delete model from database"""
        db.session.delete(self)
        db.session.commit()
    
    @staticmethod
    def commit():
        """Commit current database transaction"""
        db.session.commit()
    
    @staticmethod
    def rollback():
        """Rollback current database transaction"""
        db.session.rollback()


class TimestampMixin:
    """Mixin for timestamp fields"""
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False
    )


class OrganizationMixin:
    """Mixin for organization-scoped models"""
    organization_id = db.Column(
        db.String(36),
        db.ForeignKey('organizations.id', ondelete='CASCADE'),
        nullable=False
    )
