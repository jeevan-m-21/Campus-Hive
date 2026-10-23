# CampusHive — Environment Variable Reference

This document provides a comprehensive, production-ready reference for all configuration options across the CampusHive backend and Flutter mobile application.

---

## Security Principles

> [!CAUTION]
> **Never commit real credentials, service-account private keys, SMTP passwords, or database secrets to version control.**

* **Local Development**: Copy `.env.example` to `.env` in the `backend/` directory. The `.env` file is ignored by Git.
* **Production (AWS EC2)**: Store environment variables in `/etc/campushive/campushive.env` (owned by `www-data:www-data`, permission `600`) or pass them via systemd service environment blocks.
* **Placeholders**: All values shown below are illustrative placeholders.

---

## 1. Backend Environment Variables (`backend/.env`)

The backend configuration is managed in `backend/config.py` using `python-dotenv`.

| Variable Name | Required | Type | Default Value | Target Component | Purpose & Description |
|---|---|---|---|---|---|
| `FLASK_ENV` | Optional | String | `development` | Flask App Factory | Controls configuration profile: `development`, `testing`, or `production`. In `production`, secure cookies and strict security settings are enabled. |
| `FLASK_APP` | Optional | String | `app.py` | Flask CLI | Specifies the application entrypoint for the Flask CLI. Use `app:make_app` or `app.py`. |
| `SECRET_KEY` | **Required in Prod** | String | `dev-secret-key-change-in-production` | Flask Session Security | Cryptographic secret key used by Flask for signing session cookies, CSRF tokens, and internal state. Generate with `openssl rand -hex 32`. |
| `DATABASE_URL` | **Required** | String | `mysql+pymysql://root:password@localhost:3306/campushive` | SQLAlchemy / PyMySQL | Connection URI for the MySQL database. Format: `mysql+pymysql://<DB_USER>:<DB_PASS>@<DB_HOST>:<DB_PORT>/<DB_NAME>`. In production, this points to your AWS RDS MySQL instance. |
| `FIREBASE_CREDENTIALS_PATH` | **Required** | Path / String | `./config/firebase-key.json` | Firebase Admin SDK | Absolute or relative filesystem path to the Firebase Admin SDK service account JSON credentials file. Used for verifying client Firebase ID tokens and sending FCM notifications. |
| `FIREBASE_STORAGE_BUCKET` | Optional | String | `campushive-storage.appspot.com` | Firebase Storage | Name of the Firebase Cloud Storage bucket if remote storage is used instead of local media uploads. |
| `UPLOAD_FOLDER` | Optional | Path / String | `./uploads` (inside `backend/`) | Media Service | Local filesystem directory where complaint photos, lost-and-found images, announcement attachments, and user avatars are stored. Must be writable by the application process. |
| `CORS_ORIGINS` | Optional | Comma-delimited list | `http://localhost:3000,http://localhost:8080` | Flask-CORS / SocketIO | Permitted origins for Cross-Origin Resource Sharing. For web or dev tools, include allowed client URLs. Mobile apps calling the REST API directly do not enforce browser CORS, but local test harnesses do. |
| `MAIL_SERVER` *(or `SMTP_SERVER`)* | **Required for OTP** | String | `smtp.gmail.com` | EmailService | Hostname of the outgoing SMTP server used for sending registration OTP verification emails. |
| `MAIL_PORT` *(or `SMTP_PORT`)* | Optional | Integer | `587` | EmailService | SMTP port. Common ports: `587` for STARTTLS, `465` for SSL, `25` for unencrypted local relays. |
| `MAIL_USE_TLS` *(or `SMTP_USE_TLS`)* | Optional | Boolean | `true` | EmailService | Whether to upgrade the SMTP connection via STARTTLS. Accepts `true`, `false`, `1`, `0`, `yes`, `no`. |
| `MAIL_USERNAME` *(or `SMTP_USERNAME`)* | **Required for OTP** | String | `""` | EmailService | SMTP username or email address (e.g., your institution's Gmail address). |
| `MAIL_PASSWORD` *(or `SMTP_PASSWORD`)* | **Required for OTP** | String | `""` | EmailService | SMTP password or 16-character Google App Password (generated under Google Account &rarr; Security &rarr; 2-Step Verification &rarr; App Passwords). |
| `MAIL_DEFAULT_SENDER` | Optional | String | Falls back to `MAIL_USERNAME` or `campushive.team@gmail.com` | EmailService | Sender address displayed in the `From:` header of outgoing verification emails. Example: `CampusHive Support <support@institution.edu>`. |
| `JWT_SECRET_KEY` | Optional | String | `jwt-secret-key-change-in-production` | Flask-JWT-Extended | Cryptographic signing key used for any auxiliary JWT operations. |
| `LOG_LEVEL` | Optional | String | `INFO` (`DEBUG` in dev) | Logging | Log verbosity level: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. |
| `ML_RETRAINING_ENABLED` | Optional | Boolean | `false` | RetrainingService / Scheduler | Whether to enable the scheduled background worker that inspects resolved complaints and retrains the priority classification model. |
| `ML_RETRAINING_INTERVAL_HOURS` | Optional | Integer | `1` | RetrainingService | Frequency in hours between automated retraining eligibility checks. |
| `ML_RETRAINING_BATCH_SIZE` | Optional | Integer | `10` | RetrainingService | Minimum number of verified resolved complaints required to trigger an ML retraining batch. |
| `ML_RETRAINING_DELAY_HOURS` | Optional | Integer | `24` | RetrainingService | Delay hours after complaint resolution before it becomes eligible as training data (allows time for reopen/dispute). |

---

## 2. Safe Backend `.env` Examples

### Local Development Example (`backend/.env`)

```ini
# Flask Environment
FLASK_ENV=development
FLASK_APP=app.py
SECRET_KEY=dev-secret-key-do-not-use-in-production-32chars

# Database Configuration (Local MySQL)
DATABASE_URL=mysql+pymysql://campushive_user:local_dev_password@localhost:3306/campushive_db

# Firebase Admin SDK Credentials
FIREBASE_CREDENTIALS_PATH=./config/firebase-key.json
FIREBASE_STORAGE_BUCKET=campushive-dev.appspot.com

# File Storage
UPLOAD_FOLDER=./uploads

# CORS (for local testing)
CORS_ORIGINS=http://localhost:3000,http://localhost:8080

# Outgoing Email (Registration OTP Flow)
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USE_TLS=true
MAIL_USERNAME=campus.support@example.edu
MAIL_PASSWORD=abcd-efgh-ijkl-mnop
MAIL_DEFAULT_SENDER="CampusHive Support <campus.support@example.edu>"

# Logging
LOG_LEVEL=DEBUG

# ML Retraining Scheduler
ML_RETRAINING_ENABLED=false
```

### Production Example (AWS EC2 / Systemd Environment File)

```ini
# Production Flask Configuration
FLASK_ENV=production
FLASK_APP=app.py
SECRET_KEY=8f4e2b1c9a7d3f5e6a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f

# Database Configuration (AWS RDS MySQL)
DATABASE_URL=mysql+pymysql://campushive_admin:YourStrongRdsPassword123!@campushive-db.c1234567890.us-east-1.rds.amazonaws.com:3306/campushive_db

# Firebase Admin SDK Credentials
FIREBASE_CREDENTIALS_PATH=/etc/campushive/firebase-key.json
FIREBASE_STORAGE_BUCKET=campushive-prod.appspot.com

# Persistent Upload Storage
UPLOAD_FOLDER=/var/www/campushive/uploads

# CORS (Restrict to official administrative domains if web portal deployed)
CORS_ORIGINS=https://admin.campushive.institution.edu

# Outgoing SMTP (AWS SES or Dedicated Gmail Service Account)
MAIL_SERVER=email-smtp.us-east-1.amazonaws.com
MAIL_PORT=587
MAIL_USE_TLS=true
MAIL_USERNAME=AKIAIOSFODNN7EXAMPLE
MAIL_PASSWORD=BKZz3pQ1234567890ExampleSecretKey
MAIL_DEFAULT_SENDER="CampusHive Notifications <no-reply@institution.edu>"

# Logging & Monitoring
LOG_LEVEL=INFO

# ML Retraining Scheduler
ML_RETRAINING_ENABLED=true
ML_RETRAINING_INTERVAL_HOURS=6
ML_RETRAINING_BATCH_SIZE=25
ML_RETRAINING_DELAY_HOURS=48
```

---

## 3. Flutter Client Configuration

The Flutter mobile application (`frontend/campushive_app`) connects to the backend REST API and Firebase services.

### API Base URL Configuration

The base URL is declared in `frontend/campushive_app/lib/core/constants/app_constants.dart`.

#### Development vs. Production Endpoints:

* **Android Emulator (Local Machine Host)**: `http://10.0.2.2:5000/api/v1`
* **iOS Simulator (Local Machine Host)**: `http://127.0.0.1:5000/api/v1`
* **Physical Device (Local Wi-Fi LAN)**: `http://<YOUR_LOCAL_IP>:5000/api/v1` (e.g., `http://192.168.1.100:5000/api/v1`)
* **Production Deployment**: `https://api.campushive.institution.edu/api/v1` or `http://<EC2_PUBLIC_IP>:5000/api/v1` (with HTTPS recommended)

#### Production Dynamic Base URL Support:

To avoid hardcoding IP addresses in source code, configure `AppConstants` with Dart environment definitions:

```dart
abstract final class AppConstants {
  static const String _defaultApiBaseUrl = 'http://192.168.31.90:5000/api/v1';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
}
```

This allows compilation with custom environments:
```bash
# Debug run with local dev server
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:5000/api/v1

# Release build with production backend
flutter build apk --release --dart-define=API_BASE_URL=https://api.campushive.institution.edu/api/v1
```

### Firebase Client Configuration Files

Client-side Firebase requires platform-specific configuration files:

1. **Android**: `frontend/campushive_app/android/app/google-services.json`
   * Downloaded from the Firebase Console (Project Settings &rarr; Your apps &rarr; Android app).
   * Contains API keys, project ID, client ID, and storage bucket for the Android app.
   * Matches package name `com.example.campushive_app`.
2. **Dart Options**: `frontend/campushive_app/lib/firebase_options.dart`
   * Generated via the FlutterFire CLI (`flutterfire configure`).

---

## 4. Verification and Diagnostics

### Safe SMTP Configuration Verification

The backend includes a built-in CLI command to verify SMTP connectivity and authentication **without** sending a test email or exposing passwords:

```bash
cd backend
flask test-smtp
```

**Successful Output:**
```
[SUCCESS] SMTP connection and authentication succeeded.
Details: host=smtp.gmail.com:587, tls=True, credentials_configured=True
```

**Failed Output Example:**
```
[FAILED] Failed during stage: 'authentication'
Host: smtp.gmail.com:587, TLS: True, Credentials configured: True
Error class: SMTPAuthenticationError
SMTP code: 535
Error message: (535, b'5.7.8 Username and Password not accepted.')
```

### Database Connection Verification

Verify MySQL connectivity from the backend virtual environment:

```bash
cd backend
python -c "from app import make_app; from app.database import db; app = make_app(); app.app_context().push(); print('Database connected successfully!' if db.session.execute(db.text('SELECT 1')).scalar() == 1 else 'Connection failed.')"
```
