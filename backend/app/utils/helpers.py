"""
Common utility functions and helpers
"""

import uuid
import hashlib
from datetime import datetime, timedelta
from functools import wraps
from flask import jsonify, request


def generate_uuid():
    """Generate UUID"""
    return str(uuid.uuid4())


def hash_password(password):
    """
    Hash password with SHA256
    
    Args:
        password (str): Plain password
        
    Returns:
        str: Hashed password
    """
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(password, password_hash):
    """
    Verify password against hash
    
    Args:
        password (str): Plain password
        password_hash (str): Hashed password
        
    Returns:
        bool: True if password matches hash
    """
    return hash_password(password) == password_hash


def success_response(data=None, message='Success', status_code=200):
    """
    Generate success response
    
    Args:
        data: Response data
        message: Success message
        status_code: HTTP status code
        
    Returns:
        tuple: (response_dict, status_code)
    """
    response = {
        'success': True,
        'message': message,
        'data': data
    }
    return response, status_code


def error_response(error, message='Error', status_code=400):
    """
    Generate error response
    
    Args:
        error: Error message or data
        message: Error message
        status_code: HTTP status code
        
    Returns:
        tuple: (response_dict, status_code)
    """
    response = {
        'success': False,
        'error': error,
        'message': message
    }
    return response, status_code


def calculate_deadline(priority):
    """
    Calculate deadline based on priority
    
    Args:
        priority (str): Priority level (low, medium, high)
        
    Returns:
        datetime: Deadline datetime
    """
    now = datetime.utcnow()
    
    if priority == 'high':
        return now + timedelta(hours=24)
    elif priority == 'medium':
        return now + timedelta(hours=72)
    else:  # low
        return now + timedelta(days=7)


def get_pagination_params(request, default_page=1, default_per_page=20):
    """
    Get pagination parameters from request
    
    Args:
        request: Flask request object
        default_page: Default page number
        default_per_page: Default items per page
        
    Returns:
        tuple: (page, per_page)
    """
    page = request.args.get('page', default_page, type=int)
    per_page = request.args.get('per_page', default_per_page, type=int)
    
    # Ensure valid ranges
    page = max(1, page)
    per_page = min(100, max(1, per_page))
    
    return page, per_page


def paginate_query(query, page, per_page):
    """
    Paginate SQLAlchemy query
    
    Args:
        query: SQLAlchemy query
        page: Page number
        per_page: Items per page
        
    Returns:
        dict: Paginated response with data and metadata
    """
    paginated = query.paginate(page=page, per_page=per_page)
    
    return {
        'data': [item.to_dict() for item in paginated.items],
        'pagination': {
            'page': page,
            'per_page': per_page,
            'total': paginated.total,
            'pages': paginated.pages,
            'has_prev': paginated.has_prev,
            'has_next': paginated.has_next
        }
    }
