# CampusHive — Verified MySQL Database Schema

This document represents the authoritative, verified database schema for CampusHive, reflecting the actual models defined in `backend/app/models/`, the base SQL schema in `campushive_db_v1.sql/`, and the incremental migrations in `backend/migrations/`.

---

## Database Overview

* **Engine**: MySQL 8.0+ (InnoDB)
* **Default Charset**: `utf8mb4`
* **Collation**: `utf8mb4_0900_ai_ci` / `utf8mb4_unicode_ci`
* **Default Database Name**: `campushive_db`
* **Primary Key Convention**: Integer Auto-Increment (`<entity>_id INT AUTO_INCREMENT PRIMARY KEY`)
* **Multi-Tenancy**: Organization-scoped data isolation enforced via `organization_id` foreign keys
* **Authentication Integration**: Synchronized with Firebase Authentication via `firebase_uid`

---

## Entity Relationship Overview

```
organizations (1) ────< (M) academic_departments (1) ────< (M) users
      │                                                         │
      ├────< (M) departments (1) ───────────────────────────────┤ (supervisor department)
      │               │                                         │
      │               └────< (M) complaints (1) ────────────────┘ (student / supervisor)
      │                               │
      │                               ├───< (M) complaint_images
      │                               ├───< (M) complaint_supports
      │                               ├───< (M) complaint_chat
      │                               ├───< (M) complaint_status_history
      │                               └───< (1) ml_retraining_items
      │                                              │
      │                                              └──> (M) ml_retraining_batches
      ├────< (M) lost_found (1) ────< (M) lost_found_images
      │             │
      │             └───────────────< (M) lost_found_chat
      │
      ├────< (M) announcements (1) ─< (M) announcement_attachments
      │             │
      │             └───────────────< (M) announcement_likes
      │
      ├────< (M) email_verifications
      │
      └────< (M) notifications (per user)
```

---

## 1. Core Institutional & User Tables

### 1.1 `organizations`
Represents participating collegiate institutions or universities.

```sql
CREATE TABLE organizations (
    organization_id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(20) NOT NULL UNIQUE,
    domain VARCHAR(100) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (organization_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 1.2 `academic_departments`
Academic faculties / programs (e.g., Computer Science, Mechanical Engineering) selected by students during registration.

```sql
CREATE TABLE academic_departments (
    academic_department_id INT NOT NULL AUTO_INCREMENT,
    organization_id INT NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    department_code VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (academic_department_id),
    UNIQUE KEY uq_academic_department (organization_id, department_code),
    CONSTRAINT fk_academic_departments_org
        FOREIGN KEY (organization_id)
        REFERENCES organizations (organization_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 1.3 `departments`
Facility, administrative, and maintenance departments (e.g., Hostel Maintenance, Electrical, Plumbing, IT Support) responsible for resolving student grievances.

```sql
CREATE TABLE departments (
    department_id INT NOT NULL AUTO_INCREMENT,
    organization_id INT NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    description TEXT,
    priority_high_hours INT DEFAULT 24,
    priority_medium_hours INT DEFAULT 72,
    priority_low_hours INT DEFAULT 168,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (department_id),
    CONSTRAINT fk_departments_org
        FOREIGN KEY (organization_id)
        REFERENCES organizations (organization_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 1.4 `users`
Unified user account entity representing Students, Supervisors, Organization Admins, and Super Admins.

```sql
CREATE TABLE users (
    user_id INT NOT NULL AUTO_INCREMENT,
    organization_id INT NOT NULL,
    academic_department_id INT NULL,
    department_id INT NULL,
    full_name VARCHAR(100) NOT NULL,
    usn_or_employee_id VARCHAR(30) NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    firebase_uid VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(15) NULL,
    role ENUM('SUPER_ADMIN', 'ORG_ADMIN', 'SUPERVISOR', 'STUDENT') NOT NULL,
    profile_image VARCHAR(255) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    fcm_token TEXT NULL,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_users_org
        FOREIGN KEY (organization_id) REFERENCES organizations (organization_id),
    CONSTRAINT fk_users_academic_dept
        FOREIGN KEY (academic_department_id) REFERENCES academic_departments (academic_department_id) ON DELETE SET NULL,
    CONSTRAINT fk_users_dept
        FOREIGN KEY (department_id) REFERENCES departments (department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 2. Complaint & Issue Tracking Tables

### 2.1 `complaints`
Main complaint submission and grievance lifecycle record.

```sql
CREATE TABLE complaints (
    complaint_id INT NOT NULL AUTO_INCREMENT,
    organization_id INT NOT NULL,
    department_id INT NOT NULL,
    student_id INT NOT NULL,
    supervisor_id INT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    status ENUM('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'REOPENED', 'ESCALATED') DEFAULT 'PENDING',
    priority ENUM('LOW', 'MEDIUM', 'HIGH') DEFAULT 'MEDIUM',
    predicted_priority ENUM('LOW', 'MEDIUM', 'HIGH') NULL,
    ml_confidence FLOAT NULL,
    location VARCHAR(100) NULL,
    support_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    PRIMARY KEY (complaint_id),
    KEY idx_complaints_org (organization_id),
    KEY idx_complaints_status (status),
    KEY idx_complaints_dept (department_id),
    KEY idx_complaints_student (student_id),
    KEY idx_complaints_supervisor (supervisor_id),
    CONSTRAINT fk_complaints_org FOREIGN KEY (organization_id) REFERENCES organizations (organization_id),
    CONSTRAINT fk_complaints_dept FOREIGN KEY (department_id) REFERENCES departments (department_id),
    CONSTRAINT fk_complaints_student FOREIGN KEY (student_id) REFERENCES users (user_id),
    CONSTRAINT fk_complaints_supervisor FOREIGN KEY (supervisor_id) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.2 `complaint_images`
Photo attachments uploaded with a complaint.

```sql
CREATE TABLE complaint_images (
    image_id INT NOT NULL AUTO_INCREMENT,
    complaint_id INT NOT NULL,
    image_url VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (image_id),
    CONSTRAINT fk_complaint_images_complaint
        FOREIGN KEY (complaint_id) REFERENCES complaints (complaint_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.3 `complaint_supports`
Community peer upvotes supporting a complaint.

```sql
CREATE TABLE complaint_supports (
    support_id INT NOT NULL AUTO_INCREMENT,
    complaint_id INT NOT NULL,
    student_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (support_id),
    UNIQUE KEY uq_complaint_student_support (complaint_id, student_id),
    CONSTRAINT fk_complaint_supports_complaint
        FOREIGN KEY (complaint_id) REFERENCES complaints (complaint_id) ON DELETE CASCADE,
    CONSTRAINT fk_complaint_supports_student
        FOREIGN KEY (student_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.4 `complaint_chat`
Interactive discussion messages and remarks on complaints.

```sql
CREATE TABLE complaint_chat (
    chat_id INT NOT NULL AUTO_INCREMENT,
    complaint_id INT NOT NULL,
    sender_id INT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (chat_id),
    CONSTRAINT fk_complaint_chat_complaint
        FOREIGN KEY (complaint_id) REFERENCES complaints (complaint_id) ON DELETE CASCADE,
    CONSTRAINT fk_complaint_chat_sender
        FOREIGN KEY (sender_id) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.5 `complaint_status_history`
Audit log recording every status transition, the acting supervisor/admin, and remarks.

```sql
CREATE TABLE complaint_status_history (
    history_id INT NOT NULL AUTO_INCREMENT,
    complaint_id INT NOT NULL,
    previous_status VARCHAR(20) NULL,
    new_status VARCHAR(20) NOT NULL,
    updated_by INT NOT NULL,
    comment TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (history_id),
    CONSTRAINT fk_complaint_history_complaint
        FOREIGN KEY (complaint_id) REFERENCES complaints (complaint_id) ON DELETE CASCADE,
    CONSTRAINT fk_complaint_history_user
        FOREIGN KEY (updated_by) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 3. Lost & Found Tables

### 3.1 `lost_found`
Listings of lost or found belongings on campus.

```sql
CREATE TABLE lost_found (
    item_id INT NOT NULL AUTO_INCREMENT,
    organization_id INT NOT NULL,
    posted_by INT NOT NULL,
    item_type ENUM('LOST', 'FOUND') NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    status ENUM('OPEN', 'RESOLVED') DEFAULT 'OPEN',
    location VARCHAR(100) NULL,
    contact_info VARCHAR(100) NULL,
    item_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id),
    CONSTRAINT fk_lost_found_org FOREIGN KEY (organization_id) REFERENCES organizations (organization_id),
    CONSTRAINT fk_lost_found_poster FOREIGN KEY (posted_by) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 3.2 `lost_found_images`
Item photographs for verification.

```sql
CREATE TABLE lost_found_images (
    image_id INT NOT NULL AUTO_INCREMENT,
    item_id INT NOT NULL,
    image_url VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (image_id),
    CONSTRAINT fk_lost_found_images_item
        FOREIGN KEY (item_id) REFERENCES lost_found (item_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 3.3 `lost_found_chat`
Inquiries and communication regarding lost/found claims.

```sql
CREATE TABLE lost_found_chat (
    chat_id INT NOT NULL AUTO_INCREMENT,
    item_id INT NOT NULL,
    sender_id INT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (chat_id),
    CONSTRAINT fk_lost_found_chat_item
        FOREIGN KEY (item_id) REFERENCES lost_found (item_id) ON DELETE CASCADE,
    CONSTRAINT fk_lost_found_chat_sender
        FOREIGN KEY (sender_id) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 4. Campus Announcements & Notifications

### 4.1 `announcements`
Broadcast notices posted by Organization Admins.

```sql
CREATE TABLE announcements (
    announcement_id INT NOT NULL AUTO_INCREMENT,
    organization_id INT NOT NULL,
    created_by INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    target_role ENUM('ALL', 'STUDENT', 'SUPERVISOR', 'ORG_ADMIN') DEFAULT 'ALL',
    priority ENUM('LOW', 'NORMAL', 'URGENT') DEFAULT 'NORMAL',
    likes_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (announcement_id),
    CONSTRAINT fk_announcements_org FOREIGN KEY (organization_id) REFERENCES organizations (organization_id),
    CONSTRAINT fk_announcements_creator FOREIGN KEY (created_by) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 4.2 `announcement_attachments`
Remote links, PDF circulars, or images attached to announcements.

```sql
CREATE TABLE announcement_attachments (
    attachment_id INT NOT NULL AUTO_INCREMENT,
    announcement_id INT NOT NULL,
    attachment_type ENUM('IMAGE', 'PDF', 'LINK') NOT NULL,
    attachment_url VARCHAR(500) NOT NULL,
    original_filename VARCHAR(255) NULL,
    file_path VARCHAR(500) NULL,
    mime_type VARCHAR(100) NULL,
    file_size INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attachment_id),
    KEY idx_announcement_attachments_announcement (announcement_id),
    CONSTRAINT fk_announcement_attachments_announcement
        FOREIGN KEY (announcement_id) REFERENCES announcements (announcement_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 4.3 `announcement_likes`
User reaction tracking for campus announcements.

```sql
CREATE TABLE announcement_likes (
    like_id INT NOT NULL AUTO_INCREMENT,
    announcement_id INT NOT NULL,
    user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (like_id),
    UNIQUE KEY announcement_user_like_unique (announcement_id, user_id),
    KEY idx_announcement_likes_announcement (announcement_id),
    KEY idx_announcement_likes_user (user_id),
    CONSTRAINT fk_announcement_likes_announcement
        FOREIGN KEY (announcement_id) REFERENCES announcements (announcement_id) ON DELETE CASCADE,
    CONSTRAINT fk_announcement_likes_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 4.4 `notifications`
In-app notification records for assignments, status changes, and announcements.

```sql
CREATE TABLE notifications (
    notification_id INT NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    reference_id INT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (notification_id),
    KEY idx_notifications_user_read (user_id, is_read),
    CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 5. Registration OTP & Machine Learning Tables

### 5.1 `email_verifications`
Six-digit email OTP verification records generated during student registration.

```sql
CREATE TABLE email_verifications (
    verification_id INT NOT NULL AUTO_INCREMENT,
    email VARCHAR(100) NOT NULL,
    ip_address VARCHAR(45) NULL,
    otp_hash VARCHAR(64) NOT NULL,
    otp_expires_at DATETIME NOT NULL,
    attempts_left INT NOT NULL DEFAULT 3,
    resend_available_at DATETIME NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_at DATETIME NULL,
    verification_token_hash VARCHAR(64) NULL,
    token_expires_at DATETIME NULL,
    is_consumed BOOLEAN NOT NULL DEFAULT FALSE,
    consumed_at DATETIME NULL,
    organization_id INT NOT NULL,
    academic_department_id INT NOT NULL,
    usn_or_employee_id VARCHAR(30) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (verification_id),
    KEY idx_email_verifications_email (email),
    KEY idx_email_verifications_ip (ip_address),
    KEY idx_email_verifications_token_hash (verification_token_hash),
    KEY idx_email_verifications_email_created (email, created_at),
    KEY idx_email_verifications_ip_created (ip_address, created_at),
    CONSTRAINT fk_email_verifications_org
        FOREIGN KEY (organization_id) REFERENCES organizations (organization_id) ON DELETE CASCADE,
    CONSTRAINT fk_email_verifications_academic_dept
        FOREIGN KEY (academic_department_id) REFERENCES academic_departments (academic_department_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 5.2 `ml_retraining_batches`
Tracks execution batches for automated complaint priority model retraining.

```sql
CREATE TABLE ml_retraining_batches (
    batch_id INT NOT NULL AUTO_INCREMENT,
    eligible_count INT NOT NULL,
    selected_count INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    accuracy DOUBLE NULL,
    macro_precision DOUBLE NULL,
    macro_recall DOUBLE NULL,
    macro_f1 DOUBLE NULL,
    candidate_artifact_path VARCHAR(500) NULL,
    error_message TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (batch_id),
    KEY idx_ml_retraining_batches_status (status),
    KEY idx_ml_retraining_batches_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 5.3 `ml_retraining_items`
Complaints selected as training data for a specific retraining batch.

```sql
CREATE TABLE ml_retraining_items (
    item_id INT NOT NULL AUTO_INCREMENT,
    batch_id INT NOT NULL,
    complaint_id INT NOT NULL,
    eligible_at DATETIME NOT NULL,
    description_snapshot TEXT NOT NULL,
    priority_label ENUM('LOW', 'MEDIUM', 'HIGH') NOT NULL,
    source VARCHAR(20) NOT NULL DEFAULT 'REAL',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id),
    UNIQUE KEY uq_ml_retraining_items_complaint (complaint_id),
    KEY idx_ml_retraining_items_batch (batch_id),
    KEY idx_ml_retraining_items_eligible_at (eligible_at),
    CONSTRAINT fk_ml_retraining_items_batch
        FOREIGN KEY (batch_id) REFERENCES ml_retraining_batches (batch_id) ON DELETE CASCADE,
    CONSTRAINT fk_ml_retraining_items_complaint
        FOREIGN KEY (complaint_id) REFERENCES complaints (complaint_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 6. Migration Execution Order

When initializing a fresh database or bringing an existing database up to date, execute migrations in this exact sequence:

1. **Base Tables** (`campushive_db_v1.sql/`):
   * `campushive_db_organizations.sql`
   * `campushive_db_departments.sql`
   * `academic_departments` table
   * `campushive_db_users.sql`
   * `campushive_db_complaints.sql`
   * `campushive_db_complaint_images.sql`
   * `campushive_db_complaint_supports.sql`
   * `campushive_db_complaint_chat.sql`
   * `campushive_db_complaint_status_history.sql`
   * `campushive_db_announcements.sql`
   * `announcement_likes` table
   * `campushive_db_notifications.sql`
   * `campushive_db_lost_found.sql`
   * `campushive_db_lost_found_images.sql`
   * `campushive_db_lost_found_chat.sql`
2. **Migration `20260920_add_ml_retraining_tables.sql`**:
   * Creates `ml_retraining_batches` and `ml_retraining_items`.
3. **Migration `20261019_add_announcement_attachments.sql`**:
   * Creates `announcement_attachments`.
4. **Migration `20261021_add_email_verifications.sql`**:
   * Creates `email_verifications`.
