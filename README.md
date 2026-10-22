# CampusHive — Smart Campus Issue & Community Management Platform

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.0.3-green.svg)](https://flask.palletsprojects.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.19%2B-02569B.svg)](https://flutter.dev/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-orange.svg)](https://www.mysql.com/)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20FCM-FFCA28.svg)](https://firebase.google.com/)

CampusHive is an enterprise-grade, multi-tenant campus issue management and interaction platform designed for collegiate institutions. It unifies student grievance reporting, supervisor resolution queues, administrative analytics, lost-and-found recovery, and institutional announcements into a secure, role-based mobile and cloud ecosystem.

---

## Table of Contents

- [Project Overview & Problem Statement](#project-overview--problem-statement)
- [Core Features](#core-features)
- [User Roles & Permissions](#user-roles--permissions)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
  - [1. Database Initialization (MySQL)](#1-database-initialization-mysql)
  - [2. Backend Setup (Flask)](#2-backend-setup-flask)
  - [3. Mobile Client Setup (Flutter)](#3-mobile-client-setup-flutter)
- [Email OTP Verification & SMTP Diagnostics](#email-otp-verification--smtp-diagnostics)
- [Push Notifications & Firebase Setup](#push-notifications--firebase-setup)
- [API Reference](#api-reference)
- [Environment Configuration](#environment-configuration)
- [Deployment Overview](#deployment-overview)
- [Testing & Quality Assurance](#testing--quality-assurance)
- [Security Considerations](#security-considerations)
- [Documentation Index](#documentation-index)

---

## Project Overview & Problem Statement

Collegiate campuses operate across extensive physical infrastructures serving thousands of students, faculty, and administrative staff. Traditional campus maintenance and grievance processes suffer from:

1. **Fragmented Reporting**: Facility issues (electrical, plumbing, IT, sanitation, laboratories) are reported via paper registers or informal social channels without tracking.
2. **Lack of SLA Accountability**: Students lack visibility into complaint status, assigned supervisors, or resolution timelines.
3. **Inefficient Lost & Found**: Personal belongings rely on physical notice boards, resulting in low recovery rates.
4. **Broadcast Fatigue**: Critical notices are lost in unread email circulars.

CampusHive resolves these issues through a unified platform featuring **data-driven machine learning prioritization**, **community support weighting**, **SLA deadline enforcement**, **secure student email OTP verification**, and **push notifications**.

---

## Core Features

### 1. Grievance Lifecycle & SLA Management
* **Rich Complaint Creation**: Categorized by department with titles, descriptions, location details, and multi-image attachments.
* **Structured Status Transitions**: `PENDING` &rarr; `ASSIGNED` &rarr; `IN_PROGRESS` &rarr; `RESOLVED` &rarr; `CLOSED` (with `REOPENED` and `ESCALATED` states).
* **Departmental Resolution SLAs**: Configurable resolution deadlines (`priority_high_hours`, `priority_medium_hours`, `priority_low_hours`).
* **Remarks & Status Auditing**: Every status update logs timestamped remarks and the acting supervisor/admin in `complaint_status_history`.

### 2. Prioritization Engine (ML & Community Upvoting)
* **Scikit-Learn NLP Model**: TF-IDF N-Gram Vectorizer + Random Forest classifier (`priority_model.joblib`) predicts issue severity (`LOW`, `MEDIUM`, `HIGH`).
* **Community Support Curve**: Logarithmic scaling of student peer upvotes (`log(1 + supports)`) amplifies pressing community grievances.
* **Heuristic Fallback**: Keyword rule-based fallback guarantees consistent priority calculations even without ML inference.
* **Automated Model Retraining**: Optional background pipeline (`RetrainingService`) periodically trains candidate models on resolved complaint history.

### 3. Departmental Supervisor Queues
* **Department-Scoped Tasks**: Supervisors access tickets assigned to their operational departments.
* **Workflow Tools**: Accept complaints, update progress status, document resolution remarks, and monitor approaching deadlines.

### 4. Organization Administration & Analytics
* **Live KPI Dashboard**: Real-time breakdown of open vs. resolved complaints, high-priority alerts, and departmental performance.
* **Ticket Management Workspace**: Override priorities, manually assign/reassign supervisors, and monitor resolution remarks.
* **Broadcast Announcements**: Publish circulars with `LOW`, `NORMAL`, or `URGENT` flags, including remote links, PDF documents, or image attachments.

### 5. Campus Lost & Found
* **Categorized Listings**: Filterable catalog of `LOST` and `FOUND` personal belongings.
* **Item Verification**: Photos, descriptions, dates, and locations. Item posters can mark listings as resolved or claimed.

### 6. Notifications & In-App Notification Center
* **Firebase Cloud Messaging (FCM)**: Push notifications delivered to registered device tokens upon assignment, status update, or circular publication.
* **Unified Notification Feed**: Standardized notification center with `All` vs. `Unread` filters, unread badge counters, single/bulk mark-as-read, and deep-link routing.

---

## User Roles & Permissions

| Role | Interface | Permissions & Capabilities |
|---|---|---|
| **Student** (`STUDENT`) | Student Shell | File complaints, upvote peers, report lost/found items, view circulars, receive FCM alerts, track personal complaint activity history. |
| **Department Supervisor** (`SUPERVISOR`) | Supervisor Shell | Access department task queues, review complaint details, advance statuses, record resolution remarks, resolve complaints. |
| **Organization Admin** (`ORG_ADMIN`) | Admin Shell | Institution-wide analytics, assign supervisors, adjust priorities/deadlines, post announcements, manage administrative credentials. |
| **Super Admin** (`SUPER_ADMIN`) | System / Backend | Global platform administration, institution onboarding, organization lifecycle management. |

---

## Technology Stack

### Frontend Mobile Client (`frontend/campushive_app`)
* **Framework**: Flutter 3.19+ (Dart 3.11+)
* **State Management**: Provider (`MultiProvider`, `ChangeNotifierProvider`)
* **Navigation**: GoRouter with declarative shell routes
* **Authentication**: Firebase Authentication (`firebase_auth`) + backend OTP token verification
* **Push Notifications**: Firebase Cloud Messaging (`firebase_messaging`)
* **Local Security**: `flutter_secure_storage` for token and profile persistence
* **HTTP Client**: Standard Dart `http` library with centralized `ApiClient`

### Backend REST API (`backend/`)
* **Framework**: Flask 3.0.3 (Application factory pattern)
* **Database Driver & ORM**: PyMySQL 1.1.1, SQLAlchemy 2.0.36, Flask-SQLAlchemy 3.1.1
* **Token Verification**: Firebase Admin SDK 6.6.0 (`app.middleware.firebase_auth`)
* **Machine Learning**: Scikit-Learn 1.5.2, NumPy 2.1.3, Pandas 2.2.3, Joblib 1.4.2
* **Email & OTP**: Python `smtplib`, `email.mime`, SHA-256 HMAC tokens
* **Task Scheduling**: APScheduler 3.10.4
* **Production WSGI**: Gunicorn 23.0.0

### Persistence & Cloud Services
* **Database**: MySQL 8.0+ (19 relational tables, InnoDB, foreign keys, composite indexes)
* **Target Cloud**: AWS EC2 (Ubuntu Linux) + AWS RDS MySQL
* **Reverse Proxy & SSL**: Nginx + Let's Encrypt / Certbot

---

## System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER (Flutter)                          │
│   ┌───────────────────┐ ┌──────────────────────┐ ┌─────────────────┐   │
│   │   Student Shell   │ │   Supervisor Shell   │ │   Admin Shell   │   │
│   └─────────┬─────────┘ └──────────┬───────────┘ └────────┬────────┘   │
│             └──────────────────────┼──────────────────────┘            │
│                     Provider State Management & GoRouter               │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ HTTPS / REST (JSON)
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│               WEB REVERSE PROXY & API GATEWAY (EC2)                    │
│  - Nginx: SSL Termination (Let's Encrypt), Static `/uploads/` Serving │
│  - Gunicorn WSGI Server: Process supervision & worker management       │
│  - Flask Middleware: Firebase ID Token Guard & Role-Based Access       │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          ▼                          ▼                          ▼
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│  Auth & OTP APIs │       │ Complaint Routes │       │ Announcements &  │
│  & Organizations │       │ & Lost-and-Found │       │ Notifications    │
└─────────┬────────┘       └─────────┬────────┘       └─────────┬────────┘
          │                          │                          │
          └──────────────────────────┼──────────────────────────┘
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     BUSINESS SERVICES LAYER                            │
│  PriorityService (ML) │ EscalationService │ EmailService │ FcmService  │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ SQLAlchemy ORM / PyMySQL
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     DATABASE LAYER (AWS RDS MySQL)                     │
│  - Multi-tenant data segregation by `organization_id`                  │
│  - 19 Normalized Relational Tables (InnoDB, utf8mb4)                   │
└────────────────────────────────────────────────────────────────────────┘
```

For complete architectural specifications, see [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md).

---

## Repository Structure

```
campus_hive/
├── DATABASE_SCHEMA.md                 # Verified 19-table MySQL schema & migrations reference
├── DEPLOYMENT_GUIDE.md                # Production guide (AWS EC2, RDS, Nginx, SSL, Gunicorn)
├── ENVIRONMENT_VARIABLES.md           # Exhaustive environment variable reference
├── PROJECT_SETUP_GUIDE.md             # In-depth local developer installation guide
├── README.md                          # Main repository overview & reference (this document)
├── SYSTEM_ARCHITECTURE.md             # End-to-end system and security architecture
├── PHASE_1_COMPLETION.md              # Historical Phase 1 milestone report (Archived)
│
├── campushive_db_v1.sql/              # Modular MySQL base table initialization dumps
│   ├── campushive_db_organizations.sql
│   ├── campushive_db_departments.sql
│   ├── campushive_db_users.sql
│   ├── campushive_db_complaints.sql
│   └── ...
│
├── backend/                           # Flask Python RESTful Backend API
│   ├── app.py                         # Application entrypoint & CLI runner
│   ├── config.py                      # Multi-environment configuration manager
│   ├── requirements.txt               # Backend dependencies
│   ├── .env.example                   # Environment configuration template
│   ├── migrations/                    # Chronological SQL schema migrations
│   │   ├── 20260920_add_ml_retraining_tables.sql
│   │   ├── 20261019_add_announcement_attachments.sql
│   │   └── 20261021_add_email_verifications.sql
│   └── app/
│       ├── __init__.py                # Flask application factory (`create_app`, `make_app`)
│       ├── database.py                # SQLAlchemy database initialization
│       ├── middleware/
│       │   └── firebase_auth.py       # Firebase ID token validation & role decorators
│       ├── ml/                        # ML priority model, vectorizer & joblib weights
│       ├── models/                    # 19 SQLAlchemy declarative models
│       ├── routes/                    # API route blueprints (Auth, Complaints, Orgs, etc.)
│       └── services/                  # Business services (Auth, Email, FCM, Priority)
│
└── frontend/
    └── campushive_app/                # Active Flutter Mobile Application
        ├── pubspec.yaml               # Flutter package configuration & assets
        ├── android/                   # Native Android configuration & google-services.json
        └── lib/
            ├── main.dart              # Flutter application bootstrap
            ├── app/                   # App widget, theme, and GoRouter routes
            ├── core/                  # ApiClient, AppConstants, widgets, and storage
            ├── features/              # Feature modules by role (Student, Supervisor, Admin)
            ├── models/                # Client DTO models
            ├── providers/             # State management providers
            └── services/              # API networking and FCM push notification services
```

---

## Prerequisites

* **Python 3.10+** (3.11 recommended)
* **Flutter SDK 3.19+** (compatible with Dart 3.11+)
* **MySQL 8.0+**
* **Git**
* **Firebase Project** with Email/Password authentication enabled

---

## Local Development Setup

### 1. Database Initialization (MySQL)

1. Log into your local MySQL CLI:
   ```bash
   mysql -u root -p
   ```
2. Create the database:
   ```sql
   CREATE DATABASE campushive_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
3. Import the base table scripts from `campushive_db_v1.sql/`:
   ```bash
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
4. Apply the chronological migrations:
   ```bash
   mysql -u root -p campushive_db < backend/migrations/20260920_add_ml_retraining_tables.sql
   mysql -u root -p campushive_db < backend/migrations/20261019_add_announcement_attachments.sql
   mysql -u root -p campushive_db < backend/migrations/20261021_add_email_verifications.sql
   ```

*(See [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) for table definitions).*

---

### 2. Backend Setup (Flask)

1. Navigate to `backend/` and create a Python virtual environment:
   ```bash
   cd backend
   python -m venv venv

   # Activate environment:
   # Windows:
   .\venv\Scripts\Activate.ps1
   # Linux / macOS:
   source venv/bin/activate
   ```
2. Install Python dependencies:
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```
3. Create your `.env` configuration file:
   ```bash
   cp .env.example .env
   ```
4. Place your Firebase Admin SDK service account key at `backend/config/firebase-key.json`.
5. Verify SMTP credentials safely using the CLI diagnostic command:
   ```bash
   flask test-smtp
   ```
6. Start the development server:
   ```bash
   python app.py
   ```
   *Backend starts listening at `http://0.0.0.0:5000`.*

---

### 3. Mobile Client Setup (Flutter)

1. Navigate to the mobile app directory:
   ```bash
   cd frontend/campushive_app
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Ensure `frontend/campushive_app/android/app/google-services.json` is present.
4. Run the mobile application (uses local developer network URL by default):
   ```bash
   flutter run
   ```
   Or specify a target environment at runtime via `--dart-define`:
   * **Android Emulator**: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1`
   * **Custom LAN Device**: `flutter run --dart-define=API_BASE_URL=http://<YOUR_LOCAL_IP>:5000/api/v1`
   * **Production Release Build**: `flutter build apk --release --dart-define=API_BASE_URL=https://<YOUR_DOMAIN>/api/v1`

*(See [frontend/campushive_app/README.md](frontend/campushive_app/README.md) for details).*

---

## Email OTP Verification & SMTP Diagnostics

During student registration, CampusHive enforces six-digit email OTP verification before creating the Firebase identity.

* **Security Controls**:
  * 6-digit OTP hashed using SHA-256 before database insertion (`email_verifications`).
  * 10-minute expiration window and 60-second resend cooldown.
  * Maximum 3 verification attempts per OTP.
  * Successful verification produces a single-use SHA-256 verification token required by `POST /auth/register`.
* **Testing Tool**:
  Run `flask test-smtp` from the `backend/` directory to test SMTP handshake, STARTTLS, and authentication without triggering an email send.

---

## Push Notifications & Firebase Setup

* **Client Device Registration**: Flutter obtains the FCM registration token on startup and sends it to the backend via `POST /api/v1/auth/update-fcm-token`.
* **Push Delivery**: When a complaint status changes or circular is published, `FcmService` sends data and notification payloads via the Firebase Admin SDK.
* **Deep Linking**: Tapping an FCM notification opens the specific complaint or circular via GoRouter navigation.

---

## API Reference

The backend registers 6 core blueprints prefixed under `/api/v1`:

### 1. Authentication & Users (`/api/v1/auth`)
* `POST /otp/send-registration-otp` — Generate and email a 6-digit OTP.
* `POST /otp/verify-registration-otp` — Verify OTP and receive registration token.
* `POST /register` — Complete registration with verification token & Firebase ID token.
* `POST /login` — Synchronize profile and update login timestamp.
* `GET /me` — Retrieve authenticated user profile.
* `PATCH /me` / `PATCH /profile` — Update phone or profile details.
* `POST /update-fcm-token` — Update device FCM push token.
* `POST /profile-image` — Upload avatar image.
* `POST /supervisors` — Create supervisor profile (Admin only).

### 2. Complaints (`/api/v1/complaints`)
* `GET /` — List complaints (filterable by status, department, category).
* `POST /` — File a new complaint with location, category, and optional images.
* `GET /<id>` — Fetch detailed complaint metadata.
* `PATCH /<id>` — Update complaint status, assign supervisor, or add remarks.
* `POST /<id>/support` — Toggle student peer upvote.
* `GET /<id>/history` — Audit trail of status transitions.
* `GET /<id>/comments` / `POST /<id>/comments` — Discussion messages.
* `POST /<id>/feedback` — Submit student resolution rating & feedback.
* `POST /<id>/reopen` — Reopen an unsatisfied resolved complaint.
* `GET /departments` — List complaint resolution departments.
* `GET /supervisors` — List supervisors.
* `POST /upload-image` — Upload complaint photo attachment.

### 3. Organizations (`/api/v1/organizations`)
* `GET /public` — List active institutions for student registration.
* `GET /<id>/academic-departments` — List academic programs for registration.
* `GET /stats` / `GET /<id>/stats` — Organization KPI analytics dashboard.

### 4. Lost & Found (`/api/v1/lost-found`)
* `GET /` — Browse lost and found items.
* `POST /` — Report a lost or found article.
* `GET /<id>` — View item details.
* `PATCH /<id>` — Update listing status (e.g., mark as `RESOLVED`).
* `DELETE /<id>` — Delete listing.
* `GET /<id>/comments` / `POST /<id>/comments` — Discussion on item claims.
* `POST /upload-image` — Upload item photo.

### 5. Campus Announcements (`/api/v1/announcements`)
* `GET /` — List campus announcements with importance badges.
* `POST /` — Publish a new announcement (Admin only).
* `GET /<id>` — View announcement details.
* `PATCH /<id>` / `DELETE /<id>` — Edit or remove announcement.
* `POST /<id>/like` — React to announcement.
* `POST /upload-attachment` — Upload document circular or image.
* `POST /<id>/attachments` — Attach file/link to announcement.

### 6. Notifications (`/api/v1/notifications`)
* `GET /` — List notifications for authenticated user.
* `GET /unread-count` — Count unread notifications.
* `PATCH /<id>/read` — Mark notification as read.
* `PATCH /read-all` — Bulk mark all notifications as read.
* `DELETE /<id>` — Remove notification.

---

## Environment Configuration

Configuration is managed via environment variables. For an exhaustive, safe variable reference, see **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)**.

> [!CAUTION]
> **Zero Secrets in Version Control**: `.env` and `firebase-key.json` are ignored by Git. Never commit real credentials.

---

## Deployment Overview

CampusHive is architected for deployment on AWS:
* **Backend**: AWS EC2 (Ubuntu Linux) running Gunicorn behind an Nginx reverse proxy with Let's Encrypt SSL/TLS certificates.
* **Database**: AWS RDS MySQL 8.0 isolated in a private security group with automated backups.
* **Mobile Client**: Production release APK compiled with `--dart-define=API_BASE_URL=https://api.campushive.institution.edu/api/v1`.

For step-by-step production setup, systemd services, Nginx configurations, and release build instructions, consult **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**.

---

## Testing & Quality Assurance

* **Flutter Code Analysis**:
  ```bash
  cd frontend/campushive_app
  flutter analyze
  ```
* **Flutter Unit & Widget Tests**:
  ```bash
  cd frontend/campushive_app
  flutter test
  ```
* **Backend Pytest Suite**:
  ```bash
  cd backend
  pytest
  ```
* **SMTP Diagnostics**:
  ```bash
  cd backend
  flask test-smtp
  ```

---

## Security Considerations

1. **Firebase Authentication Guard**: All private API endpoints verify cryptographically signed Firebase ID tokens via the Firebase Admin SDK.
2. **Tenant Isolation**: Queries enforce `organization_id` row-level scoping extracted from the authenticated user.
3. **Registration Anti-Abuse**: Email OTPs enforce attempt rate-limiting, IP recording, 10-minute expiry windows, and single-use verification tokens.
4. **Restricted Database Access**: Production RDS MySQL instances must reside in private subnets, accepting connections exclusively from the backend EC2 security group.

---

## Documentation Index

| Document | Purpose |
|---|---|
| **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** | Production deployment on AWS EC2, RDS MySQL, Nginx, Let's Encrypt, and Flutter release. |
| **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** | Complete reference of backend environment variables, Flutter compile flags, and defaults. |
| **[DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)** | Verified 19-table MySQL database schema, columns, foreign keys, indexes, and migrations. |
| **[PROJECT_SETUP_GUIDE.md](PROJECT_SETUP_GUIDE.md)** | Developer onboarding, local MySQL setup, backend installation, and Flutter setup. |
| **[SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)** | Detailed system, security, multi-tenancy, and machine learning architecture specifications. |
| **[frontend/campushive_app/README.md](frontend/campushive_app/README.md)** | Flutter client architecture, navigation shells, Provider state management, and build steps. |
| **[PHASE_1_COMPLETION.md](PHASE_1_COMPLETION.md)** | *Archived* Phase 1 architectural completion review. |
| **[frontend/campushive_app/UI_REFERENCE.md](frontend/campushive_app/UI_REFERENCE.md)** | *Archived* prototype UI inventory for reference. |
