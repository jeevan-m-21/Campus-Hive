-- CampusHive ML retraining tracking tables.
-- Apply after the existing complaints table has been created.

CREATE TABLE IF NOT EXISTS ml_retraining_batches (
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
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (batch_id),
    KEY idx_ml_retraining_batches_status (status),
    KEY idx_ml_retraining_batches_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ml_retraining_items (
    item_id INT NOT NULL AUTO_INCREMENT,
    batch_id INT NOT NULL,
    complaint_id INT NOT NULL,
    eligible_at DATETIME NOT NULL,
    description_snapshot TEXT NOT NULL,
    priority_label ENUM('LOW', 'MEDIUM', 'HIGH') NOT NULL,
    source VARCHAR(20) NOT NULL DEFAULT 'REAL',
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id),
    UNIQUE KEY uq_ml_retraining_items_complaint (complaint_id),
    KEY idx_ml_retraining_items_batch (batch_id),
    KEY idx_ml_retraining_items_eligible_at (eligible_at),
    CONSTRAINT fk_ml_retraining_items_batch
        FOREIGN KEY (batch_id)
        REFERENCES ml_retraining_batches (batch_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_ml_retraining_items_complaint
        FOREIGN KEY (complaint_id)
        REFERENCES complaints (complaint_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
