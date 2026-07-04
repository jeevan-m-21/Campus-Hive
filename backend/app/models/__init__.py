"""
Database models for CampusHive
Complete entity models for all application features
"""

from datetime import datetime, timedelta
from uuid import uuid4
from app.database import db
from app.models.base import BaseModel, OrganizationMixin


# ==================== CORE MODELS ====================

class Organization(BaseModel):
    """Organization/Institution model"""
    __tablename__ = 'organizations'
    
    name = db.Column(db.String(255), unique=True, nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    phone = db.Column(db.String(20))
    address = db.Column(db.Text)
    city = db.Column(db.String(100))
    state = db.Column(db.String(100))
    postal_code = db.Column(db.String(20))
    country = db.Column(db.String(100))
    website = db.Column(db.String(255))
    logo_url = db.Column(db.String(500))
    banner_url = db.Column(db.String(500))
    established_year = db.Column(db.Integer)
    total_students = db.Column(db.Integer, default=0)
    total_supervisors = db.Column(db.Integer, default=0)
    subscription_tier = db.Column(
        db.String(50),
        default='free',
        index=True
    )  # free, basic, professional, enterprise
    subscription_start_date = db.Column(db.DateTime)
    subscription_end_date = db.Column(db.DateTime)
    is_active = db.Column(db.Boolean, default=True, index=True)
    
    # Relationships
    users = db.relationship('User', backref='organization', cascade='all, delete-orphan')
    departments = db.relationship('Department', backref='organization', cascade='all, delete-orphan')
    complaints = db.relationship('Complaint', backref='organization', cascade='all, delete-orphan')
    lost_found_items = db.relationship('LostFoundItem', backref='organization', cascade='all, delete-orphan')
    
    def __repr__(self):
        return f'<Organization {self.name}>'


class Department(BaseModel, OrganizationMixin):
    """Department model"""
    __tablename__ = 'departments'
    
    name = db.Column(db.String(255), nullable=False)
    code = db.Column(db.String(50), nullable=False)
    description = db.Column(db.Text)
    head_name = db.Column(db.String(255))
    head_email = db.Column(db.String(255))
    head_phone = db.Column(db.String(20))
    is_active = db.Column(db.Boolean, default=True, index=True)
    
    # Relationships
    supervisors = db.relationship('Supervisor', backref='department', cascade='all, delete-orphan')
    
    db.UniqueConstraint('organization_id', 'code', name='unique_org_dept')
    
    def __repr__(self):
        return f'<Department {self.name}>'


class CategoryDepartmentMapping(BaseModel, OrganizationMixin):
    """Maps complaint categories to departments"""
    __tablename__ = 'category_department_mapping'
    
    category = db.Column(db.String(100), nullable=False)
    department_id = db.Column(
        db.String(36),
        db.ForeignKey('departments.id', ondelete='CASCADE'),
        nullable=False
    )
    
    db.UniqueConstraint('organization_id', 'category', name='unique_org_category')


class User(BaseModel, OrganizationMixin):
    """User model - stores all user types"""
    __tablename__ = 'users'
    
    email = db.Column(db.String(255), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(100))
    last_name = db.Column(db.String(100))
    phone = db.Column(db.String(20))
    profile_photo_url = db.Column(db.String(500))
    role = db.Column(db.String(50), nullable=False, index=True)  # super_admin, admin, supervisor, student
    is_active = db.Column(db.Boolean, default=True, index=True)
    is_verified = db.Column(db.Boolean, default=False)
    email_verified_at = db.Column(db.DateTime)
    last_login_at = db.Column(db.DateTime)
    device_id = db.Column(db.String(255))
    fcm_token = db.Column(db.Text)  # Firebase Cloud Messaging token
    fcm_token_updated_at = db.Column(db.DateTime)
    
    # Relationships
    supervisor = db.relationship('Supervisor', uselist=False, backref='user')
    student = db.relationship('Student', uselist=False, backref='user')
    complaints = db.relationship('Complaint', backref='student_ref', foreign_keys='Complaint.student_id')
    
    db.UniqueConstraint('organization_id', 'email', name='unique_org_email')
    
    def __repr__(self):
        return f'<User {self.email}>'
    
    @property
    def full_name(self):
        """Get user's full name"""
        parts = [self.first_name, self.last_name]
        return ' '.join(filter(None, parts)) or self.email


class Supervisor(BaseModel, OrganizationMixin):
    """Supervisor model"""
    __tablename__ = 'supervisors'
    
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False,
        unique=True
    )
    department_id = db.Column(
        db.String(36),
        db.ForeignKey('departments.id', ondelete='CASCADE'),
        nullable=False
    )
    employee_id = db.Column(db.String(50))
    specialization = db.Column(db.String(255))
    max_concurrent_complaints = db.Column(db.Integer, default=10)
    current_pending_count = db.Column(db.Integer, default=0)
    is_available = db.Column(db.Boolean, default=True, index=True)
    availability_start_time = db.Column(db.Time)
    availability_end_time = db.Column(db.Time)
    
    # Relationships
    complaints = db.relationship('Complaint', backref='assigned_supervisor', foreign_keys='Complaint.supervisor_id')
    
    def __repr__(self):
        return f'<Supervisor {self.user.full_name}>'


class Student(BaseModel, OrganizationMixin):
    """Student model"""
    __tablename__ = 'students'
    
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False,
        unique=True
    )
    roll_number = db.Column(db.String(50))
    program = db.Column(db.String(100))
    year = db.Column(db.Integer)
    section = db.Column(db.String(10))
    contact_phone = db.Column(db.String(20))
    parent_phone = db.Column(db.String(20))
    hostel_name = db.Column(db.String(100))
    room_number = db.Column(db.String(20))
    
    def __repr__(self):
        return f'<Student {self.user.full_name}>'


# ==================== COMPLAINT MODELS ====================

class Complaint(BaseModel, OrganizationMixin):
    """Complaint model - main complaint entity"""
    __tablename__ = 'complaints'
    
    student_id = db.Column(
        db.String(36),
        db.ForeignKey('students.id', ondelete='CASCADE'),
        nullable=False
    )
    supervisor_id = db.Column(
        db.String(36),
        db.ForeignKey('supervisors.id', ondelete='SET NULL')
    )
    category = db.Column(db.String(100), nullable=False, index=True)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(255))
    priority = db.Column(db.String(50), default='medium', index=True)  # low, medium, high
    priority_score = db.Column(db.Float, default=0.5)
    ml_priority = db.Column(db.String(50))  # low, medium, high
    ml_priority_score = db.Column(db.Float)
    status = db.Column(
        db.String(50),
        default='pending',
        index=True
    )  # pending, assigned, in_progress, resolved, closed
    escalation_level = db.Column(db.Integer, default=1, index=True)
    escalated_at = db.Column(db.DateTime)
    assigned_at = db.Column(db.DateTime)
    deadline = db.Column(db.DateTime, index=True)
    resolved_at = db.Column(db.DateTime)
    resolution_notes = db.Column(db.Text)
    image_count = db.Column(db.Integer, default=0)
    
    # Relationships
    images = db.relationship('ComplaintImage', backref='complaint', cascade='all, delete-orphan')
    votes = db.relationship('ComplaintVote', backref='complaint', cascade='all, delete-orphan')
    comments = db.relationship('ComplaintComment', backref='complaint', cascade='all, delete-orphan')
    assignment_history = db.relationship('ComplaintAssignmentHistory', backref='complaint', cascade='all, delete-orphan')
    
    def __repr__(self):
        return f'<Complaint {self.id} - {self.title}>'
    
    def is_overdue(self):
        """Check if complaint is overdue"""
        if self.deadline and datetime.utcnow() > self.deadline:
            return True
        return False
    
    def get_votes_summary(self):
        """Get vote summary"""
        upvotes = len([v for v in self.votes if v.vote_type == 'upvote'])
        downvotes = len([v for v in self.votes if v.vote_type == 'downvote'])
        return {'upvotes': upvotes, 'downvotes': downvotes}


class ComplaintImage(BaseModel):
    """Complaint image model"""
    __tablename__ = 'complaint_images'
    
    complaint_id = db.Column(
        db.String(36),
        db.ForeignKey('complaints.id', ondelete='CASCADE'),
        nullable=False
    )
    image_url = db.Column(db.String(500), nullable=False)
    firebase_path = db.Column(db.String(500))
    uploaded_by = db.Column(db.String(36), nullable=False)
    
    def __repr__(self):
        return f'<ComplaintImage {self.id}>'


class ComplaintVote(BaseModel):
    """Vote on complaint priority"""
    __tablename__ = 'complaint_votes'
    
    complaint_id = db.Column(
        db.String(36),
        db.ForeignKey('complaints.id', ondelete='CASCADE'),
        nullable=False
    )
    student_id = db.Column(
        db.String(36),
        db.ForeignKey('students.id', ondelete='CASCADE'),
        nullable=False
    )
    vote_type = db.Column(db.String(20), nullable=False)  # upvote, downvote
    
    db.UniqueConstraint('student_id', 'complaint_id', name='unique_student_complaint_vote')
    
    def __repr__(self):
        return f'<ComplaintVote {self.id}>'


class ComplaintComment(BaseModel):
    """Comment on complaint"""
    __tablename__ = 'complaint_comments'
    
    complaint_id = db.Column(
        db.String(36),
        db.ForeignKey('complaints.id', ondelete='CASCADE'),
        nullable=False
    )
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    comment = db.Column(db.Text, nullable=False)
    
    # Relationship
    user = db.relationship('User')
    
    def __repr__(self):
        return f'<ComplaintComment {self.id}>'


class ComplaintAssignmentHistory(BaseModel):
    """Assignment history for complaints"""
    __tablename__ = 'complaint_assignment_history'
    
    complaint_id = db.Column(
        db.String(36),
        db.ForeignKey('complaints.id', ondelete='CASCADE'),
        nullable=False
    )
    supervisor_id = db.Column(
        db.String(36),
        db.ForeignKey('supervisors.id', ondelete='SET NULL')
    )
    assignment_reason = db.Column(db.String(255))
    is_current = db.Column(db.Boolean, default=False)
    
    def __repr__(self):
        return f'<ComplaintAssignmentHistory {self.id}>'


# ==================== LOST & FOUND MODELS ====================

class LostFoundItem(BaseModel, OrganizationMixin):
    """Lost and found item model"""
    __tablename__ = 'lost_found_items'
    
    posted_by = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    item_type = db.Column(db.String(20), nullable=False)  # lost, found
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=False)
    category = db.Column(db.String(100))
    location_found_lost = db.Column(db.String(255))
    date_found_lost = db.Column(db.Date)
    status = db.Column(db.String(50), default='open', index=True)  # open, claimed, closed
    claimed_by = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='SET NULL'))
    claimed_at = db.Column(db.DateTime)
    claim_message = db.Column(db.Text)
    image_count = db.Column(db.Integer, default=0)
    closed_at = db.Column(db.DateTime)
    close_reason = db.Column(db.String(255))
    
    # Relationships
    images = db.relationship('LostFoundImage', backref='item', cascade='all, delete-orphan')
    comments = db.relationship('LostFoundComment', backref='item', cascade='all, delete-orphan')
    poster = db.relationship('User', foreign_keys=[posted_by], backref='posted_items')
    claimer = db.relationship('User', foreign_keys=[claimed_by], backref='claimed_items')
    
    def __repr__(self):
        return f'<LostFoundItem {self.title}>'


class LostFoundImage(BaseModel):
    """Lost and found item image"""
    __tablename__ = 'lost_found_images'
    
    item_id = db.Column(
        db.String(36),
        db.ForeignKey('lost_found_items.id', ondelete='CASCADE'),
        nullable=False
    )
    image_url = db.Column(db.String(500), nullable=False)
    firebase_path = db.Column(db.String(500))
    uploaded_by = db.Column(db.String(36), nullable=False)
    
    def __repr__(self):
        return f'<LostFoundImage {self.id}>'


class LostFoundComment(BaseModel):
    """Comment on lost/found item"""
    __tablename__ = 'lost_found_comments'
    
    item_id = db.Column(
        db.String(36),
        db.ForeignKey('lost_found_items.id', ondelete='CASCADE'),
        nullable=False
    )
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    comment = db.Column(db.Text, nullable=False)
    
    # Relationship
    user = db.relationship('User')
    
    def __repr__(self):
        return f'<LostFoundComment {self.id}>'


# ==================== NOTIFICATION MODELS ====================

class Notification(BaseModel, OrganizationMixin):
    """Notification model"""
    __tablename__ = 'notifications'
    
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    notification_type = db.Column(db.String(100), nullable=False, index=True)
    title = db.Column(db.String(255), nullable=False)
    body = db.Column(db.Text)
    data = db.Column(db.JSON)
    is_read = db.Column(db.Boolean, default=False, index=True)
    read_at = db.Column(db.DateTime)
    
    # Relationship
    user = db.relationship('User')
    
    def __repr__(self):
        return f'<Notification {self.id}>'


class NotificationSendLog(BaseModel):
    """FCM notification send log"""
    __tablename__ = 'notification_send_logs'
    
    notification_id = db.Column(
        db.String(36),
        db.ForeignKey('notifications.id', ondelete='CASCADE'),
        nullable=False
    )
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    fcm_token = db.Column(db.String(500))
    fcm_response = db.Column(db.String(500))
    delivery_status = db.Column(db.String(50), default='pending', index=True)  # pending, sent, failed
    sent_at = db.Column(db.DateTime)
    error_message = db.Column(db.Text)
    retry_count = db.Column(db.Integer, default=0)
    
    def __repr__(self):
        return f'<NotificationSendLog {self.id}>'


# ==================== ANNOUNCEMENT MODELS ====================

class Announcement(BaseModel, OrganizationMixin):
    """Announcement model"""
    __tablename__ = 'announcements'
    
    created_by = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    title = db.Column(db.String(255), nullable=False)
    content = db.Column(db.Text, nullable=False)
    description = db.Column(db.String(500))
    target_role = db.Column(db.String(50), default='all')  # all, student, supervisor, admin
    target_department_id = db.Column(db.String(36), db.ForeignKey('departments.id', ondelete='SET NULL'))
    status = db.Column(db.String(50), default='draft', index=True)  # draft, scheduled, published, archived
    scheduled_for = db.Column(db.DateTime)
    published_at = db.Column(db.DateTime, index=True)
    is_important = db.Column(db.Boolean, default=False, index=True)
    banner_image_url = db.Column(db.String(500))
    sent_count = db.Column(db.Integer, default=0)
    read_count = db.Column(db.Integer, default=0)
    
    # Relationships
    creator = db.relationship('User')
    target_department = db.relationship('Department')
    read_by = db.relationship('AnnouncementRead', backref='announcement', cascade='all, delete-orphan')
    
    def __repr__(self):
        return f'<Announcement {self.title}>'


class AnnouncementRead(BaseModel):
    """Track who read announcements"""
    __tablename__ = 'announcement_reads'
    
    announcement_id = db.Column(
        db.String(36),
        db.ForeignKey('announcements.id', ondelete='CASCADE'),
        nullable=False
    )
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    
    db.UniqueConstraint('announcement_id', 'user_id', name='unique_announcement_user')
    
    def __repr__(self):
        return f'<AnnouncementRead {self.id}>'


# ==================== AUDIT MODELS ====================

class AuditLog(BaseModel):
    """Audit log for tracking changes"""
    __tablename__ = 'audit_logs'
    
    organization_id = db.Column(db.String(36), db.ForeignKey('organizations.id', ondelete='SET NULL'))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='SET NULL'))
    action = db.Column(db.String(100), nullable=False, index=True)
    resource_type = db.Column(db.String(100), nullable=False, index=True)
    resource_id = db.Column(db.String(36))
    old_values = db.Column(db.JSON)
    new_values = db.Column(db.JSON)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    
    def __repr__(self):
        return f'<AuditLog {self.action} on {self.resource_type}>'


class ErrorLog(BaseModel):
    """Error logging"""
    __tablename__ = 'error_logs'
    
    organization_id = db.Column(db.String(36), db.ForeignKey('organizations.id', ondelete='SET NULL'))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='SET NULL'))
    error_type = db.Column(db.String(100), nullable=False, index=True)
    error_message = db.Column(db.Text, nullable=False)
    stack_trace = db.Column(db.Text)
    endpoint = db.Column(db.String(500))
    request_data = db.Column(db.JSON)
    response_data = db.Column(db.JSON)
    severity = db.Column(db.String(50), default='medium', index=True)  # low, medium, high, critical
    resolved = db.Column(db.Boolean, default=False, index=True)
    
    def __repr__(self):
        return f'<ErrorLog {self.error_type}>'


# ==================== SESSION MODELS ====================

class UserSession(BaseModel):
    """User session tracking"""
    __tablename__ = 'user_sessions'
    
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    jwt_token_hash = db.Column(db.String(255), unique=True, nullable=False)
    device_id = db.Column(db.String(255))
    device_name = db.Column(db.String(255))
    device_type = db.Column(db.String(50), default='mobile')  # mobile, web, tablet
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    expires_at = db.Column(db.DateTime, nullable=False)
    is_active = db.Column(db.Boolean, default=True, index=True)
    
    def __repr__(self):
        return f'<UserSession {self.id}>'


class PasswordResetToken(BaseModel):
    """Password reset tokens"""
    __tablename__ = 'password_reset_tokens'
    
    user_id = db.Column(
        db.String(36),
        db.ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False
    )
    token_hash = db.Column(db.String(255), unique=True, nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    is_used = db.Column(db.Boolean, default=False)
    used_at = db.Column(db.DateTime)
    
    def __repr__(self):
        return f'<PasswordResetToken {self.id}>'
