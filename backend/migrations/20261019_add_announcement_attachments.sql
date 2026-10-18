-- CampusHive Announcement Attachments table.
-- Apply after the existing announcements table has been created.

CREATE TABLE IF NOT EXISTS announcement_attachments (
    attachment_id INT NOT NULL AUTO_INCREMENT,
    announcement_id INT NOT NULL,
    attachment_type ENUM('IMAGE', 'PDF', 'LINK') NOT NULL,
    attachment_url VARCHAR(500) NOT NULL,
    original_filename VARCHAR(255) NULL,
    file_path VARCHAR(500) NULL,
    mime_type VARCHAR(100) NULL,
    file_size INT NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attachment_id),
    KEY idx_announcement_attachments_announcement (announcement_id),
    CONSTRAINT fk_announcement_attachments_announcement
        FOREIGN KEY (announcement_id)
        REFERENCES announcements (announcement_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
