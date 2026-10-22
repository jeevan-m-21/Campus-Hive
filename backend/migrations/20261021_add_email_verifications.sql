-- CampusHive Email Verifications table for student registration OTP verification.
-- Apply after organizations and academic_departments tables exist.

CREATE TABLE IF NOT EXISTS email_verifications (
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
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (verification_id),
    KEY idx_email_verifications_email (email),
    KEY idx_email_verifications_ip (ip_address),
    KEY idx_email_verifications_token_hash (verification_token_hash),
    KEY idx_email_verifications_email_created (email, created_at),
    KEY idx_email_verifications_ip_created (ip_address, created_at),
    CONSTRAINT fk_email_verifications_org
        FOREIGN KEY (organization_id)
        REFERENCES organizations (organization_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_email_verifications_academic_dept
        FOREIGN KEY (academic_department_id)
        REFERENCES academic_departments (academic_department_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
