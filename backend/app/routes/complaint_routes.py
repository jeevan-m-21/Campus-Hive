"""
Complaint management routes
Create, update, list complaints
"""

from flask import Blueprint, request, g, current_app
from datetime import datetime

from app.database import db
from app.models import Complaint, ComplaintComment, ComplaintVote, Student
from app.middleware.auth import jwt_required, require_role
from app.utils.helpers import success_response, error_response, get_pagination_params, paginate_query, generate_uuid
from app.utils.validators import (
    ComplaintCreateSchema, ComplaintUpdateSchema, 
    ComplaintCommentSchema, ComplaintVoteSchema, validate_schema
)

complaint_bp = Blueprint('complaints', __name__)


@complaint_bp.route('', methods=['POST'])
@jwt_required
def create_complaint():
    """
    Create new complaint
    POST /api/v1/complaints
    """
    data = request.get_json()
    
    # Validate input
    schema = ComplaintCreateSchema()
    validated_data, errors = validate_schema(schema, data)
    if errors:
        return error_response(errors, 'Validation failed', 400)
    
    # Get student
    student = Student.query.filter_by(user_id=g.current_user.id).first()
    if not student:
        return error_response('not_student', 'Only students can create complaints', 403)
    
    # Create complaint
    complaint = Complaint(
        id=generate_uuid(),
        organization_id=g.current_organization_id,
        student_id=student.id,
        category=validated_data['category'],
        title=validated_data['title'],
        description=validated_data['description'],
        location=validated_data.get('location'),
        status='pending'
    )
    
    db.session.add(complaint)
    db.session.commit()
    
    current_app.logger.info(f'Complaint created: {complaint.id}')
    
    # TODO: Auto-assign supervisor
    # TODO: Send FCM notification
    # TODO: Update dashboard via SocketIO
    
    return success_response(complaint.to_dict(), 'Complaint created successfully', 201)


@complaint_bp.route('', methods=['GET'])
@jwt_required
def list_complaints():
    """
    List complaints for organization
    GET /api/v1/complaints
    """
    page, per_page = get_pagination_params(request)
    
    # Filter by organization
    query = Complaint.query.filter_by(
        organization_id=g.current_organization_id
    )
    
    # Apply role-based filters
    if g.current_user.role == 'student':
        student = Student.query.filter_by(user_id=g.current_user.id).first()
        if student:
            query = query.filter_by(student_id=student.id)
    elif g.current_user.role == 'supervisor':
        # TODO: Filter by assigned supervisor
        pass
    
    # Apply filters
    status = request.args.get('status')
    if status:
        query = query.filter_by(status=status)
    
    category = request.args.get('category')
    if category:
        query = query.filter_by(category=category)
    
    # Paginate and return
    result = paginate_query(query.order_by(Complaint.created_at.desc()), page, per_page)
    
    return success_response(result, 'Complaints retrieved', 200)


@complaint_bp.route('/<complaint_id>', methods=['GET'])
@jwt_required
def get_complaint(complaint_id):
    """
    Get complaint details
    GET /api/v1/complaints/<complaint_id>
    """
    complaint = Complaint.query.filter_by(
        id=complaint_id,
        organization_id=g.current_organization_id
    ).first()
    
    if not complaint:
        return error_response('not_found', 'Complaint not found', 404)
    
    complaint_data = complaint.to_dict()
    complaint_data['votes'] = complaint.get_votes_summary()
    
    return success_response(complaint_data, 'Complaint retrieved', 200)


@complaint_bp.route('/<complaint_id>', methods=['PATCH'])
@jwt_required
@require_role('supervisor', 'admin')
def update_complaint(complaint_id):
    """
    Update complaint status
    PATCH /api/v1/complaints/<complaint_id>
    """
    data = request.get_json()
    
    # Validate input
    schema = ComplaintUpdateSchema()
    validated_data, errors = validate_schema(schema, data)
    if errors:
        return error_response(errors, 'Validation failed', 400)
    
    complaint = Complaint.query.filter_by(
        id=complaint_id,
        organization_id=g.current_organization_id
    ).first()
    
    if not complaint:
        return error_response('not_found', 'Complaint not found', 404)
    
    # Update status
    if 'status' in validated_data:
        old_status = complaint.status
        complaint.status = validated_data['status']
        
        if complaint.status == 'resolved':
            complaint.resolved_at = datetime.utcnow()
        
        current_app.logger.info(f'Complaint {complaint_id} status changed: {old_status} -> {complaint.status}')
    
    # Update resolution notes
    if 'resolution_notes' in validated_data:
        complaint.resolution_notes = validated_data['resolution_notes']
    
    db.session.commit()
    
    # TODO: Send notification to student
    # TODO: Update dashboard via SocketIO
    
    return success_response(complaint.to_dict(), 'Complaint updated', 200)


@complaint_bp.route('/<complaint_id>/comments', methods=['POST'])
@jwt_required
def add_comment(complaint_id):
    """
    Add comment to complaint
    POST /api/v1/complaints/<complaint_id>/comments
    """
    data = request.get_json()
    
    # Validate input
    schema = ComplaintCommentSchema()
    validated_data, errors = validate_schema(schema, data)
    if errors:
        return error_response(errors, 'Validation failed', 400)
    
    complaint = Complaint.query.filter_by(
        id=complaint_id,
        organization_id=g.current_organization_id
    ).first()
    
    if not complaint:
        return error_response('not_found', 'Complaint not found', 404)
    
    # Create comment
    comment = ComplaintComment(
        id=generate_uuid(),
        complaint_id=complaint_id,
        user_id=g.current_user.id,
        comment=validated_data['comment']
    )
    
    db.session.add(comment)
    db.session.commit()
    
    return success_response(comment.to_dict(), 'Comment added', 201)


@complaint_bp.route('/<complaint_id>/vote', methods=['POST'])
@jwt_required
def vote_complaint(complaint_id):
    """
    Vote on complaint priority
    POST /api/v1/complaints/<complaint_id>/vote
    """
    data = request.get_json()
    
    # Validate input
    schema = ComplaintVoteSchema()
    validated_data, errors = validate_schema(schema, data)
    if errors:
        return error_response(errors, 'Validation failed', 400)
    
    # Get student
    student = Student.query.filter_by(user_id=g.current_user.id).first()
    if not student:
        return error_response('not_student', 'Only students can vote', 403)
    
    complaint = Complaint.query.filter_by(
        id=complaint_id,
        organization_id=g.current_organization_id
    ).first()
    
    if not complaint:
        return error_response('not_found', 'Complaint not found', 404)
    
    # Check if already voted
    existing_vote = ComplaintVote.query.filter_by(
        complaint_id=complaint_id,
        student_id=student.id
    ).first()
    
    if existing_vote:
        existing_vote.vote_type = validated_data['vote_type']
    else:
        vote = ComplaintVote(
            id=generate_uuid(),
            complaint_id=complaint_id,
            student_id=student.id,
            vote_type=validated_data['vote_type']
        )
        db.session.add(vote)
    
    db.session.commit()
    
    # TODO: Recalculate priority
    
    return success_response({}, 'Vote recorded', 200)
