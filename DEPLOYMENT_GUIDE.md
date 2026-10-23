# CampusHive — Production Deployment Guide

This guide details the complete production deployment procedure for CampusHive, including AWS EC2 (backend), AWS RDS MySQL (database), Firebase Admin SDK & FCM, Nginx with SSL/TLS, and Flutter release builds.

---

## Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │          Flutter Mobile Client         │
                      │          (Android / iOS App)           │
                      └───────────────────┬────────────────────┘
                                          │ HTTPS (Port 443)
                                          ▼
┌───────────────────────────────────────────────────────────────────────────────────────┐
│ AWS EC2 (Ubuntu 22.04 LTS / 24.04 LTS)                                                │
│                                                                                       │
│   ┌───────────────────────────────────────────────────────────────────────────────┐   │
│   │ Nginx (Reverse Proxy & SSL Termination)                                       │   │
│   │ - Handles HTTPS via Let's Encrypt / Certbot                                   │   │
│   │ - Proxies `/uploads/` and `/api/` to Gunicorn Unix Socket                     │   │
│   └───────────────────────────────────────┬───────────────────────────────────────┘   │
│                                           │ Unix Socket / HTTP                        │
│                                           ▼                                           │
│   ┌───────────────────────────────────────────────────────────────────────────────┐   │
│   │ Gunicorn WSGI Server (Managed by systemd: campushive.service)                  │   │
│   │ - Flask Application Factory (`make_app()`)                                    │   │
│   │ - 3–4 Gunicorn Workers (`gevent` / `sync` / `gthread`)                        │   │
│   │ - Environment configuration in `/etc/campushive/campushive.env`               │   │
│   └───────────────────────────────────┬───────────────────────────────────────────┘   │
│                                       │                                               │
│       ┌───────────────────────────────┼───────────────────────────────┬───────────────┤
│       ▼                               ▼                               ▼               ▼
│ ┌───────────────┐           ┌───────────────────┐           ┌───────────────────┐ ┌───────────────┐
│ │ PyMySQL ORM   │           │ Firebase Admin    │           │ Outgoing SMTP     │ │ Boto3 S3      │
│ │ Engine        │           │ (Auth & FCM)      │           │ (Registration OTP)│ │ (EC2 IAM Role)│
│ └───────┬───────┘           └─────────┬─────────┘           └─────────┬─────────┘ └───────┬───────┘
└─────────┼─────────────────────────────┼───────────────────────────────┼───────────────────┼─────────┘
          │ Private VPC (Port 3306)     │ HTTPS Outbound                │ Port 587 (TLS)    │ S3 API
          ▼                             ▼                               ▼                   ▼
┌───────────────────────┐   ┌───────────────────────┐       ┌───────────────────┐   ┌───────────────────────┐
│ AWS RDS (MySQL 8.0)   │   │ Firebase Services     │       │ SMTP Server       │   │ Amazon S3 Bucket      │
│ Multi-AZ / Automated  │   │ (Auth, FCM Messaging) │       │ (AWS SES / Gmail) │   │ campushive-media-2026 │
│ Daily Snapshots       │   │                       │       │                   │   │ (Private / IAM Role)  │
└───────────────────────┘   └───────────────────────┘       └───────────────────┘   └───────────────────────┘
```

---

## 1. AWS Infrastructure Setup

### 1.1 VPC & Subnet Layout
1. Deploy both EC2 and RDS inside the **same AWS Region** (e.g., `ap-south-1` or `us-east-1`) and within the same Virtual Private Cloud (VPC).
2. Configure at least two subnets across two Availability Zones for RDS Multi-AZ support.

### 1.2 Security Groups Configuration

Strictly isolate database access so that MySQL is **never** accessible from the public internet.

#### A. Database Security Group (`campushive-rds-sg`):
* **Inbound Rules**:
  * Type: `MySQL/Aurora` (Port `3306`)
  * Protocol: `TCP`
  * Source: Custom &rarr; Select `campushive-ec2-sg` (Security Group ID of the EC2 instance).
* **Outbound Rules**:
  * Default (Allow all outbound).

#### B. Backend EC2 Security Group (`campushive-ec2-sg`):
* **Inbound Rules**:
  * `SSH` (Port `22`): Restrict to your specific administrator IP address (`<YOUR_OFFICE_IP>/32`). Do **not** open to `0.0.0.0/0`.
  * `HTTP` (Port `80`): Allow `0.0.0.0/0` (for ACME Let's Encrypt verification and HTTP-to-HTTPS redirect).
  * `HTTPS` (Port `443`): Allow `0.0.0.0/0` (public traffic from the mobile application).
* **Outbound Rules**:
  * Default (Allow all outbound traffic for Firebase, SMTP, and package updates).

### 1.3 AWS RDS MySQL Instance Provisioning
1. **Engine**: MySQL Community Server `8.0.x`.
2. **Instance Class**: `db.t3.micro` or `db.t3.small` (Free tier eligible or low cost).
3. **Storage**: 20 GB gp3 with Auto-scaling enabled up to 100 GB.
4. **Settings**:
   * DB Instance Identifier: `campushive-mysql-prod`
   * Master Username: `campushive_admin` (avoid using generic `root` or `admin`)
   * Master Password: Generate a high-entropy 32-character password.
   * Initial Database Name: `campushive_db`
5. **Connectivity**:
   * Virtual Private Cloud (VPC): Select your application VPC.
   * Public Access: **No** (Strict requirement).
   * VPC Security Group: `campushive-rds-sg`.
6. **Database Options**:
   * Character set: `utf8mb4`
   * Collation: `utf8mb4_0900_ai_ci` or `utf8mb4_unicode_ci`
7. **Maintenance & Backup**:
   * Automated Backups: Enabled (Retention: 7 days minimum).
   * Backup Window: Off-peak hours.

### 1.4 AWS EC2 Instance Provisioning
1. **AMI**: Ubuntu Server 22.04 LTS or 24.04 LTS (x86_64).
2. **Instance Type**: `t3.small` (2 vCPU, 2 GB RAM minimum recommended for running Gunicorn + ML Scikit-Learn model in memory).
3. **Key Pair**: Download and securely store your `.pem` key.
4. **Storage**: 25–30 GB gp3 EBS Volume.
5. **Network**: Attach Elastic IP to ensure the public IP address remains static across restarts.

---

## 2. Database Initialization & Safety Protocol

> [!IMPORTANT]
> **Strict Safety Rules for Database Management:**
> 1. Always generate a snapshot or backup before executing any migrations on an existing production database.
> 2. Never drop or recreate an active production database.
> 3. Verify whether each migration table or column already exists (`SHOW TABLES;` and `SHOW COLUMNS;`) before running scripts.
> 4. Distinctly separate a **fresh setup** from an **in-place database upgrade**.

### 2.1 Backup Existing Database (Before Any Changes)
```bash
# Run from an authorized EC2 terminal:
mysqldump -h <RDS_ENDPOINT> -u campushive_admin -p \
  --single-transaction \
  --routines \
  --triggers \
  campushive_db > backup_campushive_$(date +%Y%m%d_%H%M%S).sql
```

### 2.2 Fresh Database Setup (New Installation)

Connect to the RDS instance via MySQL CLI:
```bash
mysql -h <RDS_ENDPOINT> -u campushive_admin -p campushive_db
```

#### Step 1: Base Tables Initialization
Execute the base table schemas in relational order. The repository provides these in `campushive_db_v1.sql/`:

1. `campushive_db_organizations.sql`
2. `campushive_db_departments.sql`
3. `campushive_db_users.sql` (Creates users table, roles, foreign keys)
4. `campushive_db_complaints.sql`
5. `campushive_db_complaint_images.sql`
6. `campushive_db_complaint_supports.sql`
7. `campushive_db_complaint_chat.sql`
8. `campushive_db_complaint_status_history.sql`
9. `campushive_db_announcements.sql`
10. `campushive_db_notifications.sql`
11. `campushive_db_lost_found.sql`
12. `campushive_db_lost_found_images.sql`
13. `campushive_db_lost_found_chat.sql`

#### Step 2: Incremental Schema Migrations
Apply the dated migration files from `backend/migrations/` in strict chronological sequence:

1. **ML Retraining Infrastructure**:
   ```sql
   -- File: backend/migrations/20260920_add_ml_retraining_tables.sql
   -- Adds ml_retraining_batches and ml_retraining_items tables
   ```
2. **Announcement Attachments**:
   ```sql
   -- File: backend/migrations/20261019_add_announcement_attachments.sql
   -- Adds announcement_attachments table (supports IMAGE, PDF, LINK)
   ```
3. **Student Email OTP Verifications**:
   ```sql
   -- File: backend/migrations/20261021_add_email_verifications.sql
   -- Adds email_verifications table for six-digit registration OTP verification
   ```

#### Step 3: Verify Schema Integrity
Verify that all 19 application tables are present:
```sql
SHOW TABLES;
```
Expected table list:
* `academic_departments`
* `announcement_attachments`
* `announcement_likes`
* `announcements`
* `complaint_chat`
* `complaint_images`
* `complaint_status_history`
* `complaint_supports`
* `complaints`
* `departments`
* `email_verifications`
* `lost_found`
* `lost_found_chat`
* `lost_found_images`
* `ml_retraining_batches`
* `ml_retraining_items`
* `notifications`
* `organizations`
* `users`

---

## 3. Backend EC2 Server Configuration

### 3.1 OS Packages & System Dependencies
SSH into the EC2 instance and update system packages:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-pip python3-venv python3-dev \
    build-essential libssl-dev libffi-dev \
    nginx git curl pkg-config default-libmysqlclient-dev
```

### 3.2 Directory Structure & Permissions
Create a dedicated deployment directory:
```bash
sudo mkdir -p /var/www/campushive
sudo mkdir -p /var/www/campushive/uploads
sudo mkdir -p /etc/campushive
sudo chown -R ubuntu:ubuntu /var/www/campushive
sudo chmod -R 775 /var/www/campushive/uploads
```

### 3.3 Clone Repository & Python Environment Setup
```bash
cd /var/www/campushive
git clone https://github.com/jeevan-m-21/Campus-Hive.git .

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r backend/requirements.txt
```

### 3.4 Secure Credentials Setup
1. **Firebase Service Account Key**:
   Copy your production Firebase Admin SDK JSON key to `/etc/campushive/firebase-key.json`:
   ```bash
   sudo cp /path/to/firebase-admin-key.json /etc/campushive/firebase-key.json
   sudo chmod 600 /etc/campushive/firebase-key.json
   sudo chown -R www-data:www-data /etc/campushive
   ```

2. **Environment File**:
   Create `/etc/campushive/campushive.env` with restricted permissions:
   ```bash
   sudo nano /etc/campushive/campushive.env
   ```
   Populate it with production values (refer to [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)):
   ```ini
   FLASK_ENV=production
   FLASK_APP=app.py
   SECRET_KEY=generate_with_openssl_rand_hex_32
   DATABASE_URL=mysql+pymysql://campushive_admin:YourStrongPassword@campushive-mysql-prod.c1234567890.rds.amazonaws.com:3306/campushive_db
   FIREBASE_CREDENTIALS_PATH=/etc/campushive/firebase-key.json
   FIREBASE_STORAGE_BUCKET=campushive-prod.appspot.com
   UPLOAD_FOLDER=/var/www/campushive/uploads
   CORS_ORIGINS=https://admin.campushive.institution.edu
   MAIL_SERVER=smtp.gmail.com
   MAIL_PORT=587
   MAIL_USE_TLS=true
   MAIL_USERNAME=campus.notifications@institution.edu
   MAIL_PASSWORD=your_16_char_google_app_password
   MAIL_DEFAULT_SENDER="CampusHive Admin <campus.notifications@institution.edu>"
   LOG_LEVEL=INFO
   ML_RETRAINING_ENABLED=true
   ML_RETRAINING_INTERVAL_HOURS=6
   ML_RETRAINING_BATCH_SIZE=25
   ML_RETRAINING_DELAY_HOURS=48
   ```
   Set permissions:
   ```bash
   sudo chmod 600 /etc/campushive/campushive.env
   sudo chown www-data:www-data /etc/campushive/campushive.env
   ```

### 3.5 Test Credentials & Outgoing Email
Verify database connectivity and SMTP credentials using the built-in Flask CLI command:
```bash
cd /var/www/campushive/backend
export $(sudo cat /etc/campushive/campushive.env | xargs)
/var/www/campushive/venv/bin/flask test-smtp
```
Ensure you receive:
```
[SUCCESS] SMTP connection and authentication succeeded.
```

### 3.6 Configure systemd Service for Gunicorn

Create the systemd service file:
```bash
sudo nano /etc/systemd/system/campushive.service
```

Paste the following configuration:
```ini
[Unit]
Description=CampusHive Gunicorn Application Service
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/campushive/backend
EnvironmentFile=/etc/campushive/campushive.env
ExecStart=/var/www/campushive/venv/bin/gunicorn \
    --workers 4 \
    --worker-class gthread \
    --threads 2 \
    --bind unix:/var/www/campushive/campushive.sock \
    --umask 007 \
    --timeout 60 \
    --access-logfile /var/log/campushive/access.log \
    --error-logfile /var/log/campushive/error.log \
    "app:make_app()"

Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Create log directories:
```bash
sudo mkdir -p /var/log/campushive
sudo chown -R www-data:www-data /var/log/campushive
```

Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable campushive
sudo systemctl start campushive
sudo systemctl status campushive
```

---

## 4. Reverse Proxy & SSL (Nginx & Let's Encrypt)

### 4.1 Nginx Configuration
Create `/etc/nginx/sites-available/campushive`:
```bash
sudo nano /etc/nginx/sites-available/campushive
```

Paste the server configuration:
```nginx
server {
    listen 80;
    server_name api.campushive.institution.edu;

    client_max_body_size 50M;

    # Media retrieval (/uploads/) served securely from Amazon S3 via Flask
    location /uploads/ {
        include proxy_params;
        proxy_pass http://unix:/var/www/campushive/campushive.sock;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_connect_timeout 60s;
        proxy_read_timeout 120s;
    }

    # Proxy API requests to Gunicorn
    location / {
        include proxy_params;
        proxy_pass http://unix:/var/www/campushive/campushive.sock;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

Enable the configuration:
```bash
sudo ln -s /etc/nginx/sites-available/campushive /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

### 4.2 Obtain SSL Certificate via Certbot
Install Certbot:
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.campushive.institution.edu
```
Certbot automatically provisions the Let's Encrypt TLS certificate and configures an automatic 301 redirect from HTTP to HTTPS.

---

## 5. Firebase & FCM Configuration

### 5.1 Firebase Console Setup
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Select your project and navigate to **Authentication** &rarr; **Sign-in method**.
3. Enable **Email/Password**.
4. In **Project Settings** &rarr; **Service accounts**, generate a new private key for the Firebase Admin SDK.
5. In **Cloud Messaging**, note your Sender ID and Server Key / API Credentials.

### 5.2 FCM Push Notifications Setup
* When users log in, the Flutter client calls `POST /api/v1/auth/update-fcm-token` with their device token.
* When complaint status changes, supervisors are assigned, or announcements are posted, `app.services.fcm_service.send_push_notification` automatically delivers push notifications to the registered tokens.

---

## 6. Flutter Release Build & Distribution

### 6.1 Configure Production API Base URL via Build Flag
`AppConstants.apiBaseUrl` in `frontend/campushive_app/lib/core/constants/app_constants.dart` uses `String.fromEnvironment('API_BASE_URL', ...)`:

```dart
abstract final class AppConstants {
  static const String _defaultApiBaseUrl = 'http://192.168.31.90:5000/api/v1';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
}
```

The production backend URL is supplied at build time using `--dart-define=API_BASE_URL=<PRODUCTION_API_URL>` without editing source code files. `ApiClient.buildUri` automatically normalizes trailing slashes and ensures the `/api/v1` prefix is attached without duplication.

### 6.2 Android Keystore Signing Configuration
1. Generate an upload keystore (if not already created):
   ```bash
   keytool -genkey -v -keystore campushive-release-key.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias campushive
   ```
2. Place the keystore outside version control and create `frontend/campushive_app/android/key.properties`:
   ```properties
   storePassword=YourStorePassword
   keyPassword=YourKeyPassword
   keyAlias=campushive
   storeFile=/path/to/campushive-release-key.jks
   ```
3. Ensure `google-services.json` is present in `frontend/campushive_app/android/app/`.

### 6.3 Build the Production Release APK / App Bundle
```bash
cd frontend/campushive_app

# Fetch dependencies
flutter pub get

# Build Release APK
flutter build apk --release --dart-define=API_BASE_URL=https://api.campushive.institution.edu/api/v1

# Build Android App Bundle (for Google Play Store)
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.campushive.institution.edu/api/v1
```
The output file is generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 7. Post-Deployment Verification & Smoke Testing

Perform these verification checks immediately following deployment:

1. **Service Status**:
   ```bash
   sudo systemctl status campushive
   sudo systemctl status nginx
   ```
2. **Health Check**:
   ```bash
   curl -i https://api.campushive.institution.edu/api/v1/organizations/public
   ```
   Should return HTTP `200 OK` with JSON array of active organizations.
3. **Registration & OTP Flow**:
   * Open the app, choose an organization and academic department.
   * Enter student credentials and trigger OTP.
   * Verify receipt of the 6-digit OTP email in inbox.
   * Enter the OTP, complete registration, and verify successful login.
4. **Complaint Submission**:
   * Create a complaint with an image attachment.
   * Verify that the image is accessible via `https://api.campushive.institution.edu/uploads/...`.
   * Verify priority calculation (`LOW`, `MEDIUM`, `HIGH`).
5. **Supervisor Workflow**:
   * Log into Supervisor account.
   * View task queue, update status to `IN_PROGRESS`, add a remark, resolve complaint.
6. **Admin Dashboard**:
   * Log into Organization Admin account.
   * Verify complaint statistics and post an announcement with an attachment.
7. **Push Notifications**:
   * Verify that device receives background / foreground FCM push notification when a complaint is assigned or updated.
