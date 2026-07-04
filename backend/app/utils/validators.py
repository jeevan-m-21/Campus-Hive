"""
Validation utilities and schemas
Input validation and data serialization
"""

from marshmallow import Schema, fields, validate, ValidationError
from datetime import datetime


class BaseSchema(Schema):
    """Base schema with common fields"""
    id = fields.Str(dump_only=True)
    created_at = fields.DateTime(dump_only=True)
    updated_at = fields.DateTime(dump_only=True)


# ==================== AUTH SCHEMAS ====================

class UserRegisterSchema(Schema):
    """User registration validation"""
    email = fields.Email(required=True)
    password = fields.Str(
        required=True,
        validate=validate.Length(min=8, error='Password must be at least 8 characters')
    )
    first_name = fields.Str(required=True)
    last_name = fields.Str()
    phone = fields.Str()
    organization_id = fields.Str(required=True)
    role = fields.Str(
        validate=validate.OneOf(['student', 'supervisor', 'admin']),
        missing='student'
    )


class UserLoginSchema(Schema):
    """User login validation"""
    email = fields.Email(required=True)
    password = fields.Str(required=True)
    device_id = fields.Str()
    fcm_token = fields.Str()


class UserUpdateSchema(Schema):
    """User update validation"""
    first_name = fields.Str()
    last_name = fields.Str()
    phone = fields.Str()
    profile_photo_url = fields.Url()
    fcm_token = fields.Str()


# ==================== COMPLAINT SCHEMAS ====================

class ComplaintCreateSchema(Schema):
    """Create complaint validation"""
    category = fields.Str(
        required=True,
        validate=validate.OneOf([
            'electrical', 'housekeeping', 'transport',
            'hostel', 'internet', 'security', 'other'
        ])
    )
    title = fields.Str(required=True, validate=validate.Length(min=5))
    description = fields.Str(required=True, validate=validate.Length(min=10))
    location = fields.Str()


class ComplaintUpdateSchema(Schema):
    """Update complaint validation"""
    status = fields.Str(
        validate=validate.OneOf([
            'pending', 'assigned', 'in_progress', 'resolved', 'closed'
        ])
    )
    resolution_notes = fields.Str()


class ComplaintVoteSchema(Schema):
    """Vote on complaint"""
    vote_type = fields.Str(
        required=True,
        validate=validate.OneOf(['upvote', 'downvote'])
    )


class ComplaintCommentSchema(Schema):
    """Comment on complaint"""
    comment = fields.Str(required=True, validate=validate.Length(min=1))


# ==================== LOST & FOUND SCHEMAS ====================

class LostFoundCreateSchema(Schema):
    """Create lost/found post validation"""
    item_type = fields.Str(
        required=True,
        validate=validate.OneOf(['lost', 'found'])
    )
    title = fields.Str(required=True, validate=validate.Length(min=5))
    description = fields.Str(required=True, validate=validate.Length(min=10))
    category = fields.Str()
    location_found_lost = fields.Str()
    date_found_lost = fields.Date()


class LostFoundClaimSchema(Schema):
    """Claim lost/found item"""
    claim_message = fields.Str()


class LostFoundCommentSchema(Schema):
    """Comment on lost/found item"""
    comment = fields.Str(required=True, validate=validate.Length(min=1))


# ==================== ANNOUNCEMENT SCHEMAS ====================

class AnnouncementCreateSchema(Schema):
    """Create announcement validation"""
    title = fields.Str(required=True, validate=validate.Length(min=5))
    content = fields.Str(required=True, validate=validate.Length(min=10))
    description = fields.Str()
    target_role = fields.Str(
        validate=validate.OneOf(['all', 'student', 'supervisor', 'admin']),
        missing='all'
    )
    target_department_id = fields.Str()
    is_important = fields.Boolean(missing=False)
    scheduled_for = fields.DateTime()


def validate_schema(schema, data):
    """
    Validate data against schema
    
    Args:
        schema: Marshmallow schema
        data: Data to validate
        
    Returns:
        tuple: (valid_data, errors) where errors is empty dict if valid
    """
    try:
        result = schema.load(data)
        return result, {}
    except ValidationError as err:
        return None, err.messages
