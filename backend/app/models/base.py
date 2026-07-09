"""Shared SQLAlchemy base helpers for CampusHive models."""

from datetime import datetime

from app.database import db


class BaseModel(db.Model):
    """Abstract base model with shared utility methods only."""

    __abstract__ = True

    def to_dict(self, include=None, exclude=None):
        result = {}

        for column in self.__table__.columns:
            value = getattr(self, column.name)

            if isinstance(value, datetime):
                value = value.isoformat()

            if include and column.name not in include:
                continue
            if exclude and column.name in exclude:
                continue

            result[column.name] = value

        return result

    def to_json(self):
        return self.to_dict()

    def save(self):
        db.session.add(self)
        db.session.commit()
        return self

    def delete(self):
        db.session.delete(self)
        db.session.commit()

    @staticmethod
    def commit():
        db.session.commit()

    @staticmethod
    def rollback():
        db.session.rollback()


class CreatedAtMixin:
    created_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )


class TimestampMixin:
    created_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )
    updated_at = db.Column(
        db.TIMESTAMP,
        server_default=db.text('CURRENT_TIMESTAMP'),
        onupdate=db.text('CURRENT_TIMESTAMP'),
        nullable=True,
    )
