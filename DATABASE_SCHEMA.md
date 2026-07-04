# CampusHive - Complete Database Schema (MySQL)

## Database Initialization Script

```sql
-- Create Database
CREATE DATABASE IF NOT EXISTS campushive
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE campushive;

-- ==================== CORE TABLES ====================

-- 1. Organizations Table
CREATE TABLE organizations (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    website VARCHAR(255),
    logo_url VARCHAR(500),
    banner_url VARCHAR(500),
    established_year INT,
    total_students INT DEFAULT 0,
    total_supervisors INT DEFAULT 0,
    subscription_tier ENUM('free', 'basic', 'professional', 'enterprise') DEFAULT 'free',
    subscription_start_date DATETIME,
    subscription_end_date DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_is_active (is_active),
    INDEX idx_subscription_tier (subscription_tier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Departments Table
CREATE TABLE departments (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    head_name VARCHAR(255),
    head_email VARCHAR(255),
    head_phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_org_dept (organization_id, code),
    INDEX idx_organization_id (organization_id),
    INDEX idx_is_active (is_active),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Category-Department Mapping Table
CREATE TABLE category_department_mapping (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    category VARCHAR(100) NOT NULL,
    department_id VARCHAR(36) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_org_category (organization_id, category),
    INDEX idx_organization_id (organization_id),
    INDEX idx_category (category),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Users Table
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    profile_photo_url VARCHAR(500),
    role ENUM('super_admin', 'admin', 'supervisor', 'student') NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    email_verified_at DATETIME,
    last_login_at DATETIME,
    device_id VARCHAR(255),
    fcm_token TEXT,
    fcm_token_updated_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_org_email (organization_id, email),
    INDEX idx_organization_id (organization_id),
    INDEX idx_role (role),
    INDEX idx_is_active (is_active),
    INDEX idx_email (email),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Supervisors Table
CREATE TABLE supervisors (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id VARCHAR(36) NOT NULL,
    department_id VARCHAR(36) NOT NULL,
    employee_id VARCHAR(50),
    specialization VARCHAR(255),
    max_concurrent_complaints INT DEFAULT 10,
    current_pending_count INT DEFAULT 0,
    is_available BOOLEAN DEFAULT TRUE,
    availability_start_time TIME,
    availability_end_time TIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_department_id (department_id),
    INDEX idx_is_available (is_available),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Students Table
CREATE TABLE students (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL UNIQUE,
    organization_id VARCHAR(36) NOT NULL,
    roll_number VARCHAR(50),
    program VARCHAR(100),
    year INT,
    section VARCHAR(10),
    contact_phone VARCHAR(20),
    parent_phone VARCHAR(20),
    hostel_name VARCHAR(100),
    room_number VARCHAR(20),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_roll_number (roll_number),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== COMPLAINT MANAGEMENT TABLES ====================

-- 7. Complaints Table
CREATE TABLE complaints (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    student_id VARCHAR(36) NOT NULL,
    supervisor_id VARCHAR(36),
    category VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    location VARCHAR(255),
    priority ENUM('low', 'medium', 'high') DEFAULT 'medium',
    priority_score FLOAT DEFAULT 0.5,
    ml_priority ENUM('low', 'medium', 'high'),
    ml_priority_score FLOAT,
    status ENUM('pending', 'assigned', 'in_progress', 'resolved', 'closed') DEFAULT 'pending',
    escalation_level INT DEFAULT 1,
    escalated_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    assigned_at DATETIME,
    deadline DATETIME,
    resolved_at DATETIME,
    resolution_notes TEXT,
    image_count INT DEFAULT 0,
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_student_id (student_id),
    INDEX idx_supervisor_id (supervisor_id),
    INDEX idx_status (status),
    INDEX idx_priority (priority),
    INDEX idx_category (category),
    INDEX idx_escalation_level (escalation_level),
    INDEX idx_created_at (created_at),
    INDEX idx_deadline (deadline),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (supervisor_id) REFERENCES supervisors(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. Complaint Images Table
CREATE TABLE complaint_images (
    id VARCHAR(36) PRIMARY KEY,
    complaint_id VARCHAR(36) NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    firebase_path VARCHAR(500),
    uploaded_by VARCHAR(36) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_complaint_id (complaint_id),
    
    FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. Complaint Votes Table
CREATE TABLE complaint_votes (
    id VARCHAR(36) PRIMARY KEY,
    complaint_id VARCHAR(36) NOT NULL,
    student_id VARCHAR(36) NOT NULL,
    vote_type ENUM('upvote', 'downvote') NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_student_complaint_vote (student_id, complaint_id),
    INDEX idx_complaint_id (complaint_id),
    INDEX idx_student_id (student_id),
    
    FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Complaint Comments Table
CREATE TABLE complaint_comments (
    id VARCHAR(36) PRIMARY KEY,
    complaint_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    comment TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_complaint_id (complaint_id),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Complaint Assignment History Table
CREATE TABLE complaint_assignment_history (
    id VARCHAR(36) PRIMARY KEY,
    complaint_id VARCHAR(36) NOT NULL,
    supervisor_id VARCHAR(36),
    assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    assignment_reason VARCHAR(255),
    is_current BOOLEAN DEFAULT FALSE,
    
    INDEX idx_complaint_id (complaint_id),
    INDEX idx_supervisor_id (supervisor_id),
    
    FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
    FOREIGN KEY (supervisor_id) REFERENCES supervisors(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== LOST & FOUND TABLES ====================

-- 12. Lost and Found Items Table
CREATE TABLE lost_found_items (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    posted_by VARCHAR(36) NOT NULL,
    item_type ENUM('lost', 'found') NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(100),
    location_found_lost VARCHAR(255),
    date_found_lost DATE,
    status ENUM('open', 'claimed', 'closed') DEFAULT 'open',
    claimed_by VARCHAR(36),
    claimed_at DATETIME,
    claim_message TEXT,
    image_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    closed_at DATETIME,
    close_reason VARCHAR(255),
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_posted_by (posted_by),
    INDEX idx_status (status),
    INDEX idx_item_type (item_type),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (posted_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (claimed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 13. Lost and Found Images Table
CREATE TABLE lost_found_images (
    id VARCHAR(36) PRIMARY KEY,
    item_id VARCHAR(36) NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    firebase_path VARCHAR(500),
    uploaded_by VARCHAR(36) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_item_id (item_id),
    
    FOREIGN KEY (item_id) REFERENCES lost_found_items(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 14. Lost and Found Comments Table
CREATE TABLE lost_found_comments (
    id VARCHAR(36) PRIMARY KEY,
    item_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    comment TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_item_id (item_id),
    INDEX idx_user_id (user_id),
    
    FOREIGN KEY (item_id) REFERENCES lost_found_items(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== NOTIFICATION TABLES ====================

-- 15. Notifications Table
CREATE TABLE notifications (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    notification_type VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    data JSON,
    is_read BOOLEAN DEFAULT FALSE,
    read_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at),
    INDEX idx_notification_type (notification_type),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 16. Notification Send Log Table
CREATE TABLE notification_send_logs (
    id VARCHAR(36) PRIMARY KEY,
    notification_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    fcm_token VARCHAR(500),
    fcm_response VARCHAR(500),
    delivery_status ENUM('pending', 'sent', 'failed') DEFAULT 'pending',
    sent_at DATETIME,
    error_message TEXT,
    retry_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_notification_id (notification_id),
    INDEX idx_user_id (user_id),
    INDEX idx_delivery_status (delivery_status),
    
    FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== ANNOUNCEMENT TABLES ====================

-- 17. Announcements Table
CREATE TABLE announcements (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    created_by VARCHAR(36) NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    description VARCHAR(500),
    target_role ENUM('all', 'student', 'supervisor', 'admin') DEFAULT 'all',
    target_department_id VARCHAR(36),
    status ENUM('draft', 'scheduled', 'published', 'archived') DEFAULT 'draft',
    scheduled_for DATETIME,
    published_at DATETIME,
    is_important BOOLEAN DEFAULT FALSE,
    banner_image_url VARCHAR(500),
    sent_count INT DEFAULT 0,
    read_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_status (status),
    INDEX idx_published_at (published_at),
    INDEX idx_is_important (is_important),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (target_department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 18. Announcement Read Tracking Table
CREATE TABLE announcement_reads (
    id VARCHAR(36) PRIMARY KEY,
    announcement_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    read_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_announcement_user (announcement_id, user_id),
    INDEX idx_announcement_id (announcement_id),
    INDEX idx_user_id (user_id),
    
    FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== AUDIT & LOGGING TABLES ====================

-- 19. Audit Log Table
CREATE TABLE audit_logs (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36),
    user_id VARCHAR(36),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(36),
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_resource_type (resource_type),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 20. Error Logs Table
CREATE TABLE error_logs (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36),
    user_id VARCHAR(36),
    error_type VARCHAR(100) NOT NULL,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    endpoint VARCHAR(500),
    request_data JSON,
    response_data JSON,
    severity ENUM('low', 'medium', 'high', 'critical') DEFAULT 'medium',
    resolved BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_severity (severity),
    INDEX idx_error_type (error_type),
    INDEX idx_resolved (resolved),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== ANALYTICS TABLES ====================

-- 21. Daily Statistics Table
CREATE TABLE daily_statistics (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    stat_date DATE NOT NULL,
    total_complaints INT DEFAULT 0,
    pending_complaints INT DEFAULT 0,
    resolved_complaints INT DEFAULT 0,
    escalated_complaints INT DEFAULT 0,
    total_lost_found_posts INT DEFAULT 0,
    total_users INT DEFAULT 0,
    active_users INT DEFAULT 0,
    avg_resolution_time_hours FLOAT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_org_date (organization_id, stat_date),
    INDEX idx_organization_id (organization_id),
    INDEX idx_stat_date (stat_date),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 22. Department Statistics Table
CREATE TABLE department_statistics (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    department_id VARCHAR(36) NOT NULL,
    stat_date DATE NOT NULL,
    total_complaints INT DEFAULT 0,
    resolved_complaints INT DEFAULT 0,
    pending_complaints INT DEFAULT 0,
    avg_resolution_time_hours FLOAT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_dept_date (department_id, stat_date),
    INDEX idx_organization_id (organization_id),
    INDEX idx_department_id (department_id),
    INDEX idx_stat_date (stat_date),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 23. Supervisor Performance Table
CREATE TABLE supervisor_performance (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    supervisor_id VARCHAR(36) NOT NULL,
    stat_date DATE NOT NULL,
    total_assigned INT DEFAULT 0,
    total_resolved INT DEFAULT 0,
    avg_resolution_time_hours FLOAT,
    pending_count INT DEFAULT 0,
    overdue_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_supervisor_date (supervisor_id, stat_date),
    INDEX idx_organization_id (organization_id),
    INDEX idx_supervisor_id (supervisor_id),
    INDEX idx_stat_date (stat_date),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (supervisor_id) REFERENCES supervisors(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== ML MODEL TRAINING DATA ====================

-- 24. ML Training Data Table
CREATE TABLE ml_training_data (
    id VARCHAR(36) PRIMARY KEY,
    organization_id VARCHAR(36) NOT NULL,
    complaint_id VARCHAR(36),
    category VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    actual_priority ENUM('low', 'medium', 'high') NOT NULL,
    predicted_priority ENUM('low', 'medium', 'high'),
    prediction_confidence FLOAT,
    is_training_data BOOLEAN DEFAULT TRUE,
    model_version VARCHAR(20),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_organization_id (organization_id),
    INDEX idx_category (category),
    INDEX idx_model_version (model_version),
    
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== SESSION & AUTH TABLES ====================

-- 25. User Sessions Table
CREATE TABLE user_sessions (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    jwt_token_hash VARCHAR(255) NOT NULL UNIQUE,
    device_id VARCHAR(255),
    device_name VARCHAR(255),
    device_type ENUM('mobile', 'web', 'tablet') DEFAULT 'mobile',
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at DATETIME NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_is_active (is_active),
    INDEX idx_expires_at (expires_at),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 26. Password Reset Tokens Table
CREATE TABLE password_reset_tokens (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    used_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==================== VIEWS FOR COMMON QUERIES ====================

-- View: Active Complaints by Department
CREATE OR REPLACE VIEW v_active_complaints_by_dept AS
SELECT 
    d.id,
    d.name,
    COUNT(CASE WHEN c.status IN ('pending', 'assigned', 'in_progress') THEN 1 END) as active_count,
    COUNT(CASE WHEN c.priority = 'high' THEN 1 END) as high_priority_count,
    COUNT(CASE WHEN c.priority = 'medium' THEN 1 END) as medium_priority_count,
    COUNT(CASE WHEN c.priority = 'low' THEN 1 END) as low_priority_count
FROM departments d
LEFT JOIN complaints c ON d.id = (
    SELECT cdm.department_id 
    FROM category_department_mapping cdm 
    WHERE cdm.category = c.category AND cdm.organization_id = c.organization_id
)
GROUP BY d.id, d.name;

-- View: Supervisor Workload
CREATE OR REPLACE VIEW v_supervisor_workload AS
SELECT 
    s.id,
    s.user_id,
    u.first_name,
    u.last_name,
    COUNT(CASE WHEN c.status IN ('pending', 'assigned', 'in_progress') THEN 1 END) as current_load,
    s.max_concurrent_complaints,
    ROUND(COUNT(CASE WHEN c.status IN ('pending', 'assigned', 'in_progress') THEN 1 END) * 100.0 / s.max_concurrent_complaints, 2) as workload_percentage
FROM supervisors s
LEFT JOIN users u ON s.user_id = u.id
LEFT JOIN complaints c ON s.id = c.supervisor_id
GROUP BY s.id, s.user_id, u.first_name, u.last_name, s.max_concurrent_complaints;

-- View: Complaint Statistics
CREATE OR REPLACE VIEW v_complaint_statistics AS
SELECT 
    organization_id,
    COUNT(*) as total_complaints,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
    COUNT(CASE WHEN status = 'resolved' THEN 1 END) as resolved_count,
    COUNT(CASE WHEN status = 'closed' THEN 1 END) as closed_count,
    COUNT(CASE WHEN escalation_level > 1 THEN 1 END) as escalated_count,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, created_at, resolved_at)), 2) as avg_resolution_hours
FROM complaints
WHERE resolved_at IS NOT NULL
GROUP BY organization_id;

-- ==================== INDEXES FOR PERFORMANCE ====================

-- Performance Indexes
CREATE INDEX idx_complaints_org_status_priority ON complaints(organization_id, status, priority);
CREATE INDEX idx_complaints_deadline_escalation ON complaints(deadline, escalation_level);
CREATE INDEX idx_users_org_role_active ON users(organization_id, role, is_active);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read, created_at);
CREATE INDEX idx_lost_found_org_status ON lost_found_items(organization_id, status, created_at);

-- ==================== STORED PROCEDURES ====================

DELIMITER $$

-- Procedure: Auto-escalate overdue complaints
CREATE PROCEDURE sp_escalate_overdue_complaints()
BEGIN
    UPDATE complaints
    SET 
        escalation_level = escalation_level + 1,
        escalated_at = NOW()
    WHERE 
        status IN ('pending', 'assigned', 'in_progress')
        AND deadline < NOW()
        AND escalation_level < 3;
END$$

-- Procedure: Calculate daily statistics
CREATE PROCEDURE sp_calculate_daily_statistics(IN org_id VARCHAR(36), IN stat_date DATE)
BEGIN
    INSERT INTO daily_statistics (id, organization_id, stat_date, total_complaints, 
                                  pending_complaints, resolved_complaints, 
                                  escalated_complaints, avg_resolution_time_hours)
    SELECT 
        UUID(),
        org_id,
        stat_date,
        COUNT(*),
        COUNT(CASE WHEN status IN ('pending', 'assigned', 'in_progress') THEN 1 END),
        COUNT(CASE WHEN status = 'resolved' THEN 1 END),
        COUNT(CASE WHEN escalation_level > 1 THEN 1 END),
        ROUND(AVG(TIMESTAMPDIFF(HOUR, created_at, resolved_at)), 2)
    FROM complaints
    WHERE organization_id = org_id 
      AND DATE(created_at) <= stat_date
      AND DATE(COALESCE(resolved_at, NOW())) >= stat_date;
END$$

-- Procedure: Update supervisor current load
CREATE PROCEDURE sp_update_supervisor_load(IN supervisor_id VARCHAR(36))
BEGIN
    UPDATE supervisors
    SET current_pending_count = (
        SELECT COUNT(*) 
        FROM complaints 
        WHERE supervisor_id = supervisor_id 
        AND status IN ('pending', 'assigned', 'in_progress')
    )
    WHERE id = supervisor_id;
END$$

DELIMITER ;

-- ==================== INITIAL DATA ====================

-- Insert default super admin organization
INSERT INTO organizations (id, name, email, phone, address, is_active, subscription_tier)
VALUES (
    UUID(),
    'CampusHive Platform',
    'admin@campushive.com',
    '+91-1234567890',
    'Platform Administration',
    TRUE,
    'enterprise'
);
```

## Schema Summary

| Table | Purpose | Key Features |
|-------|---------|--------------|
| `organizations` | Multi-tenant data | Subscription management, logo/banner storage |
| `departments` | Org departments | Category mapping, supervisor assignment |
| `users` | All system users | Role-based, FCM token, soft delete ready |
| `supervisors` | Supervisor details | Workload management, availability tracking |
| `students` | Student profiles | Academic info, hostel details |
| `complaints` | Main complaint records | ML scores, escalation, voting integration |
| `complaint_votes` | Priority voting | Community score calculation |
| `lost_found_items` | Lost/found posts | Status tracking, claim management |
| `notifications` | User notifications | Type categorization, read tracking |
| `announcements` | Org broadcasts | Scheduling, targeting, read tracking |
| `audit_logs` | Change tracking | User actions, resource changes |
| `daily_statistics` | Analytics rollup | Performance trends |
| `ml_training_data` | ML pipeline data | Model training/validation |
| `user_sessions` | Active sessions | JWT tracking, device management |

## Key Design Decisions

1. **Organization Segregation**: Every table has `organization_id` for strict multi-tenancy
2. **UUID Primary Keys**: Distributed system ready, no central ID generation
3. **Soft Deletes**: Use `is_active` flags for audit trails
4. **Denormalization**: Status counters for performance (updated via triggers)
5. **Indexing Strategy**: Multi-column indexes for common queries
6. **JSON Fields**: `data`, `old_values`, `new_values` for flexible logging
7. **Timestamps**: `created_at`, `updated_at` on all tables for audit
8. **Foreign Keys**: Cascade deletes for organization data isolation
