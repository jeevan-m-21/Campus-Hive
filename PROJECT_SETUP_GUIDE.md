# CampusHive — Developer Setup & Installation Guide

This guide provides end-to-end instructions for setting up a local CampusHive development environment, including the Flask backend, MySQL database, and Flutter mobile application.

---

## Prerequisites

Before starting, ensure you have the following installed on your development machine:

* **Git**: [git-scm.com](https://git-scm.com/)
* **Python**: Version `3.10` or higher (`3.11` recommended)
* **MySQL Server**: Version `8.0` or higher ([dev.mysql.com](https://dev.mysql.com/downloads/mysql/))
* **Flutter SDK**: Version `3.19` or higher, compatible with Dart `3.11+` ([flutter.dev](https://flutter.dev/docs/get-started/install))
* **Android Studio**: With Android SDK command-line tools and an Android Virtual Device (AVD) emulator.
* **Firebase Project**: A Firebase project with Email/Password authentication enabled.

---

## 1. Database Setup (MySQL)

### 1.1 Create the Database
Log into your local MySQL server:
```bash
mysql -u root -p
```

Create the database using `utf8mb4` encoding:
```sql
CREATE DATABASE campushive_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
```

### 1.2 Import Base Schema
Import the modular table definitions from `campushive_db_v1.sql/` in relational sequence:

```bash
# On Linux / macOS / PowerShell:
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_organizations.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_departments.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_users.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_complaints.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_complaint_images.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_complaint_supports.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_complaint_chat.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_complaint_status_history.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_announcements.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_notifications.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_lost_found.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_lost_found_images.sql
mysql -u root -p campushive_db < campushive_db_v1.sql/campushive_db_lost_found_chat.sql
```

### 1.3 Apply Incremental Migrations
Apply the dated migration files from `backend/migrations/`:
```bash
mysql -u root -p campushive_db < backend/migrations/20260920_add_ml_retraining_tables.sql
mysql -u root -p campushive_db < backend/migrations/20261019_add_announcement_attachments.sql
mysql -u root -p campushive_db < backend/migrations/20261021_add_email_verifications.sql
```

Verify that all 19 application tables are present by checking [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md).

---

## 2. Backend Setup (Flask)

### 2.1 Virtual Environment Installation
Open a terminal and navigate to `backend/`:
```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate on Windows (PowerShell):
.\venv\Scripts\Activate.ps1

# Activate on Linux / macOS:
source venv/bin/activate

# Upgrade pip and install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

### 2.2 Environment Configuration
Copy the configuration template:
```bash
cp .env.example .env
```

Edit `backend/.env` with your local settings (see [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md) for variable definitions):
```ini
FLASK_ENV=development
FLASK_APP=app.py
SECRET_KEY=dev-secret-key-campus-hive-local-32c
DATABASE_URL=mysql+pymysql://root:your_mysql_password@localhost:3306/campushive_db
FIREBASE_CREDENTIALS_PATH=./config/firebase-key.json
FIREBASE_STORAGE_BUCKET=campushive-dev.appspot.com
UPLOAD_FOLDER=./uploads
CORS_ORIGINS=http://localhost:3000,http://localhost:8080

# Outgoing SMTP for Registration OTP
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USE_TLS=true
MAIL_USERNAME=your.email@gmail.com
MAIL_PASSWORD=your_16_char_google_app_password
MAIL_DEFAULT_SENDER="CampusHive Dev <your.email@gmail.com>"

LOG_LEVEL=DEBUG
ML_RETRAINING_ENABLED=false
```

### 2.3 Firebase Admin Credentials
1. In the Firebase Console, go to **Project Settings** &rarr; **Service accounts**.
2. Click **Generate new private key** and download the JSON file.
3. Save the file as `backend/config/firebase-key.json`.
4. Ensure `firebase-key.json` is ignored by Git (already configured in `.gitignore`).

### 2.4 Verify SMTP & Database Connectivity
Run the built-in diagnostic command to verify SMTP authentication without sending emails:
```bash
flask test-smtp
```
Expected output:
```
[SUCCESS] SMTP connection and authentication succeeded.
Details: host=smtp.gmail.com:587, tls=True, credentials_configured=True
```

### 2.5 Start the Backend Server
```bash
python app.py
```
The API server starts listening on `http://0.0.0.0:5000`. You can test it by opening `http://localhost:5000/api/v1/organizations/public` in your browser.

---

## 3. Frontend Setup (Flutter)

The mobile client is located at `frontend/campushive_app`.

### 3.1 Install Flutter Dependencies
Navigate to the Flutter app directory and fetch packages:
```bash
cd frontend/campushive_app
flutter pub get
```

### 3.2 Firebase Android Configuration
1. In the Firebase Console, register an Android app with package name `com.example.campushive_app`.
2. Download `google-services.json` and place it in:
   `frontend/campushive_app/android/app/google-services.json`

### 3.3 API Base URL Configuration

The API base URL is configured in `frontend/campushive_app/lib/core/constants/app_constants.dart` using Flutter's `String.fromEnvironment('API_BASE_URL', ...)`:

```dart
abstract final class AppConstants {
  static const String _defaultApiBaseUrl = 'http://192.168.31.90:5000/api/v1';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
}
```

The default preserves the developer network address so existing local testing works out of the box without code edits.

### 3.4 Run the Mobile Application

Launch your Android emulator or connect a physical device, then run:

```bash
# Option A: Run with default local network URL
flutter run

# Option B: Run on Android Emulator (targeting host loopback)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1

# Option C: Run on Physical Device with a custom LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:5000/api/v1
```

---

## 4. Troubleshooting Guide

### 4.1 "Unable to send verification email" during registration
* **Cause**: Incorrect SMTP credentials or port.
* **Fix**: Run `flask test-smtp` in the `backend/` directory. If using Gmail, ensure:
  1. 2-Step Verification is turned **ON** for the Google account.
  2. You generated a dedicated **App Password** under Google Account &rarr; Security &rarr; App Passwords.
  3. You used the 16-character App Password (without spaces) in `MAIL_PASSWORD`.

### 4.2 "Connection Refused" in Flutter App
* **Cause**: The Flutter app cannot reach the backend server.
* **Fix**:
  * If on an **Android Emulator**, use `http://10.0.2.2:5000/api/v1` (do not use `localhost`).
  * If on a **Physical Device**, verify that both device and computer are on the same Wi-Fi network and that port `5000` is permitted through the host firewall.
  * Ensure the Flask server is running on `0.0.0.0:5000`, not `127.0.0.1:5000`.

### 4.3 Firebase Token Verification Errors (401 Unauthorized)
* **Cause**: `firebase-key.json` belongs to a different Firebase project than `google-services.json`.
* **Fix**: Check `project_id` inside both `backend/config/firebase-key.json` and `frontend/campushive_app/android/app/google-services.json` to ensure they match exactly.

### 4.4 MySQL Foreign Key Constraint Failures During Migration
* **Cause**: Running migration scripts out of order.
* **Fix**: Execute migrations strictly in the order documented in [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md).
