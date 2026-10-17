# CampusHive — Smart Campus Complaint & Lost-and-Found Management System

CampusHive is an enterprise-grade, multi-tenant campus management platform designed to streamline issue reporting, departmental resolution workflows, lost-and-found recovery, and campus-wide communications for higher education institutions.

Built with a cross-platform **Flutter** mobile client, a **Python/Flask** RESTful API, a relational **MySQL** database, and **Firebase Authentication**, CampusHive centralizes student grievances and administrative operations into a secure, role-based ecosystem.

---

## Table of Contents

- [Problem Statement](#problem-statement)
- [Proposed Solution](#proposed-solution)
- [Key Features](#key-features)
- [User Roles & Permissions](#user-roles--permissions)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Database Setup](#1-database-setup)
  - [Backend Setup](#2-backend-setup)
  - [Frontend Setup](#3-frontend-setup)
  - [Device & Network Configuration](#4-device--network-configuration)
- [Environment Configuration & Security](#environment-configuration--security)
- [Current Implementation Status](#current-implementation-status)
- [Future Enhancements](#future-enhancements)
- [Project Documentation](#project-documentation)
- [Contribution & Guidelines](#contribution--guidelines)

---

## Problem Statement

Educational campuses operate across large physical infrastructures serving thousands of students, faculty, and administrative personnel. Traditional campus management processes face significant hurdles:

1. **Fragmented Issue Reporting**: Maintenance and facility grievances (electrical hazards, plumbing leaks, laboratory equipment failures, sanitation problems) are typically reported through informal channels, handwritten registers, or unmonitored email threads.
2. **Lack of Transparency & SLA Tracking**: Students have no visibility into the status of their complaints, who is assigned to resolve them, or expected resolution deadlines. Supervisors lack standardized tools to manage workloads and document remarks.
3. **Inefficient Lost & Found Management**: Lost personal belongings rely on physical bulletin boards, scattered security desks, or unofficial social media groups, resulting in low recovery rates and uncatalogued items.
4. **Communication Gaps**: Urgent campus circulars and departmental announcements get buried in crowded inboxes or missed entirely on physical noticeboards.
5. **Data Silos**: Campus administrators lack centralized analytics to identify recurring departmental bottlenecks, prioritize critical maintenance, and monitor operational efficiency across institutions.

---

## Proposed Solution

CampusHive addresses these operational challenges through a unified mobile and backend platform:

- **Centralized Grievance Lifecycle**: Students submit geotagged and photo-documented complaints mapped to specific academic and facility departments. Issues progress through a structured lifecycle with real-time status transitions.
- **Data-Driven Priority Engine**: Combines community support (upvoting) with machine-learning-assisted classification to surface urgent campus issues and assign automated resolution deadlines based on departmental SLAs.
- **Digital Lost & Found Marketplace**: A searchable repository where students report lost or found items with images, descriptions, and resolution tracking.
- **Institutional Broadcasts**: Administrators publish official campus notices with priority indicators and direct links to media or document circulars.
- **Multi-Tenant SaaS Architecture**: A single deployment securely isolates data across multiple educational organizations while enabling standardized departmental structures and role-based workflows.

---

## Key Features

### 1. Complaint Reporting & Resolution Lifecycle
- **Rich Complaint Submission**: Students file complaints categorized by department, accompanied by titles, descriptions, specific campus locations, and optional photo attachments.
- **Structured Status Workflow**: Complaints transition through strictly enforced states: `PENDING` &rarr; `ASSIGNED` &rarr; `IN_PROGRESS` &rarr; `RESOLVED` &rarr; `CLOSED` (or `REOPENED` / `ESCALATED`).
- **Departmental SLA Deadlines**: Automatically calculates completion deadlines based on priority and departmental configuration.
- **Internal & Public Remarks**: Supervisors and administrators append resolution notes and internal comments for accountability.

### 2. Community Upvoting & Support
- **Issue Validation**: Students can support/upvote complaints submitted by peers to highlight widespread campus problems.
- **Algorithmic Weighting**: Upvote counts feed into the complaint prioritization formula to escalate heavily supported issues.

### 3. Departmental Supervisor Management
- **Filtered Task Queue**: Supervisors view tickets scoped to their assigned departments.
- **Direct Status Management**: Supervisors accept assigned tasks, update progress status, add operational remarks, and resolve issues within set deadlines.
- **Workload Summary**: Dedicated supervisor dashboard tracking active, pending, and resolved workloads.

### 4. Organization Administration & Analytics
- **Live Institutional KPI Dashboard**: Organization administrators monitor real-time complaint resolution metrics, departmental distribution, high-priority ticket alerts, and recent activities.
- **Universal Complaint Workspace**: Organization-wide complaint inspection, manual supervisor assignment, priority overrides, and deadline adjustments.
- **Broadcast Management**: Full announcement CRUD operations with urgent priority flags, media/document attachments, and real-time feed updates.
- **Administrator Profile**: Account credential management with direct Firebase password updates and session controls.

### 5. Lost & Found Management
- **Categorized Listings**: Filter and browse items marked as `LOST` or `FOUND`.
- **Photo & Detail Verification**: Attach photographs, item descriptions, and last-seen locations.
- **Claim & Status Resolution**: Post creators can mark items as resolved or claimed once recovered.

### 6. Campus Announcements & Notifications
- **Broadcast Notices**: Official campus announcements with importance badges (`IMPORTANT`) and support for remote image, PDF document, and web link attachments.
- **Community Likes**: Users can react to campus announcements with persistent like counters.
- **In-App Notification Center**: Unread badge indicators on app bars, filterable notification feeds (`All` vs `Unread Only`), single/bulk mark-as-read actions, deletion confirmation, and contextual routing to complaints or announcements.

### 7. Prioritization System
- **Scikit-Learn Classifier**: TF-IDF text vectorizer paired with a Random Forest model trained to classify complaint urgency based on issue descriptions.
- **Logarithmic Support Curve**: Upvote normalization using logarithmic scaling combined with model output to derive final issue priority (`LOW`, `MEDIUM`, `HIGH`).
- **Heuristic Fallback**: Deterministic keyword-based classification fallback ensuring resilient priority calculation in all environments.

---

## User Roles & Permissions

CampusHive enforces strict Role-Based Access Control (RBAC) across all client interfaces and API endpoints:

| Role | Target Interface | Core Responsibilities |
|---|---|---|
| **Student** | Student Shell | File complaints, upvote peer issues, report lost/found items, view announcements, track personal activity history, and receive notification updates. |
| **Department Supervisor** | Supervisor Shell | Access department-specific complaint queues, review complaint details, update progress status, document resolution remarks, and track assigned deadlines. |
| **Organization Admin** | Admin Shell | Monitor organization-wide complaint analytics, reassign supervisors, adjust priority/deadlines, publish campus announcements, and manage account credentials. |
| **Super Admin** | System / Backend | Global platform administration, institution onboarding, organization lifecycle management, and system-wide audit logging. |

---

## Technology Stack

### Frontend Application
- **Framework**: [Flutter](https://flutter.dev/) (v3.x) with [Dart](https://dart.dev/) (v3.11+)
- **State Management**: [Provider](https://pub.dev/packages/provider) (`ChangeNotifierProvider`, `MultiProvider`)
- **Navigation & Routing**: [GoRouter](https://pub.dev/packages/go_router) (declarative, URL-aware routing with shell branches)
- **Networking**: [http](https://pub.dev/packages/http) client with unified interceptor-style `ApiClient`
- **Authentication**: [firebase_auth](https://pub.dev/packages/firebase_auth) & [firebase_core](https://pub.dev/packages/firebase_core)
- **Secure Storage**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) for JWT and session tokens
- **Hardware Integration**: [image_picker](https://pub.dev/packages/image_picker) for camera and gallery photo uploads

### Backend API
- **Framework**: [Flask](https://flask.palletsprojects.com/) (v3.0.3)
- **ORM & Migrations**: [Flask-SQLAlchemy](https://flask-sqlalchemy.palletsprojects.com/) & [Flask-Migrate](https://flask-migrate.readthedocs.io/) ([SQLAlchemy](https://www.sqlalchemy.org/) 2.0)
- **Database Driver**: [PyMySQL](https://pymysql.readthedocs.io/)
- **Security & Token Validation**: [firebase-admin](https://firebase.google.com/docs/admin/setup) SDK, [PyJWT](https://pyjwt.readthedocs.io/), [bcrypt](https://pypi.org/project/bcrypt/)
- **Serialization & Validation**: [Marshmallow](https://marshmallow.readthedocs.io/)
- **CORS Handling**: [Flask-CORS](https://flask-cors.readthedocs.io/)
- **Task Scheduling**: [APScheduler](https://apscheduler.readthedocs.io/)
- **Production Server**: [Gunicorn](https://gunicorn.org/)

### Machine Learning
- **Libraries**: [scikit-learn](https://scikit-learn.org/), [NumPy](https://numpy.org/), [Pandas](https://pandas.pydata.org/), [Joblib](https://joblib.readthedocs.io/)
- **Model Pipeline**: TF-IDF N-gram vectorizer + Random Forest Classifier trained on campus grievance semantics (`priority_model.joblib`)

### Persistence & Storage
- **Database**: [MySQL 8.0](https://www.mysql.com/) (Relational schema, foreign key constraints, composite indexes, timestamp triggers)
- **Media Storage**: Local multi-part storage (`/uploads/complaints/`) with support for remote Cloud Storage bucket URLs

---

## System Architecture

CampusHive follows a layered client-server architecture with strict separation between presentation, API routing, business services, and persistence:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER (Flutter)                          │
│   ┌───────────────────┐ ┌──────────────────────┐ ┌─────────────────┐   │
│   │   Student Shell   │ │   Supervisor Shell   │ │   Admin Shell   │   │
│   └─────────┬─────────┘ └──────────┬───────────┘ └────────┬────────┘   │
│             └──────────────────────┼──────────────────────┘            │
│                     Provider State Management & GoRouter               │
└────────────────────────────────────┼───────────────────────────────────┘
                                     │ HTTPS / REST (JSON)
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        API GATEWAY / FLASK APP                         │
│  - CORS Middleware      - Firebase ID Token Verification (Auth Guard)  │
│  - Role Verification    - Centralized Error Handling & JSON Responses  │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          ▼                          ▼                          ▼
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│  Auth Blueprints │       │ Complaint Routes │       │ Announcements &  │
│  & Organizations │       │ & Lost-and-Found │       │ Notifications    │
└─────────┬────────┘       └─────────┬────────┘       └─────────┬────────┘
          │                          │                          │
          └──────────────────────────┼──────────────────────────┘
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     BUSINESS SERVICES LAYER                            │
│  ┌────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │ PriorityService (ML)   │  │ Escalation & Assignment Services     │  │
│  └──────────┬─────────────┘  └──────────────────┬───────────────────┘  │
│             │                                   │                      │
│             ▼                                   ▼                      │
│   Scikit-Learn Pipeline             NotificationService                │
│   (TF-IDF + Random Forest)                                             │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ SQLAlchemy ORM
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        DATA LAYER (MySQL 8.0)                          │
│   organizations │ departments │ users │ complaints │ complaint_images  │
│   complaint_supports │ announcements │ lost_found │ notifications     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
campus_hive/
├── DATABASE_SCHEMA.md                 # Complete MySQL schema reference & documentation
├── PHASE_1_COMPLETION.md              # Phase 1 architectural summary and deliverables
├── PROJECT_SETUP_GUIDE.md             # In-depth setup instructions and troubleshooting
├── README.md                          # Main project documentation (this file)
├── SYSTEM_ARCHITECTURE.md             # Architectural specifications and module flows
│
├── campushive_db_v1.sql/              # Modular MySQL initialization dump scripts
│   ├── campushive_db_organizations.sql
│   ├── campushive_db_departments.sql
│   ├── campushive_db_users.sql
│   ├── campushive_db_complaints.sql
│   ├── campushive_db_complaint_images.sql
│   ├── campushive_db_complaint_supports.sql
│   ├── campushive_db_complaint_status_history.sql
│   ├── campushive_db_announcements.sql
│   ├── campushive_db_notifications.sql
│   ├── campushive_db_lost_found.sql
│   └── ...
│
├── backend/                           # Python / Flask REST API
│   ├── app.py                         # Application entrypoint
│   ├── config.py                      # Multi-environment configuration
│   ├── requirements.txt               # Backend dependencies
│   ├── .env.example                   # Environment configuration template
│   └── app/
│       ├── __init__.py                # Flask application factory
│       ├── database.py                # Database instance & session management
│       ├── middleware/
│       │   └── firebase_auth.py       # Firebase authentication & RBAC decorators
│       ├── ml/
│       │   ├── priority_model.py      # Scikit-Learn TF-IDF + Random Forest model
│       │   ├── priority_model.joblib  # Serialized trained model weights
│       │   └── train_priority_model.py
│       ├── models/                    # SQLAlchemy declarative models
│       │   ├── base.py
│       │   ├── user.py
│       │   ├── complaint.py
│       │   ├── department.py
│       │   ├── announcement.py
│       │   ├── notification.py
│       │   ├── lost_found.py
│       │   └── organization.py
│       ├── routes/                    # API route blueprints
│       │   ├── auth_routes.py
│       │   ├── complaint_routes.py
│       │   ├── announcement_routes.py
│       │   ├── notification_routes.py
│       │   ├── lost_found_routes.py
│       │   ├── organization_routes.py
│       │   └── analytics_routes.py
│       ├── services/                  # Business logic services
│       │   ├── auth_service.py
│       │   ├── priority_service.py    # Hybrid ML + support priority calculator
│       │   ├── notification_service.py
│       │   └── assignment_service.py
│       └── utils/
│           └── helpers.py             # Pagination, formatting, and responses
│
└── frontend/
    └── campushive_app/                # Active Flutter mobile application
        ├── pubspec.yaml               # Flutter package configuration & assets
        └── lib/
            ├── main.dart              # Flutter application entrypoint
            ├── app/
            │   ├── app.dart           # Root MaterialApp & MultiProvider configuration
            │   └── routes.dart        # GoRouter routes and shell builders
            ├── core/
            │   ├── constants/         # AppConstants (API base URL)
            │   ├── network/           # ApiClient, ApiEndpoints, ApiException
            │   ├── storage/           # FlutterSecureStorage wrapper
            │   ├── theme/             # AppColors, AppDimensions, AppTextStyles, AppTheme
            │   └── widgets/           # AppButton, AppCard, AppLoader, AppTextField, EmptyState
            ├── models/                # Client domain models
            │   ├── user.dart
            │   ├── complaint.dart
            │   ├── department.dart
            │   ├── announcement.dart
            │   └── notification.dart
            ├── providers/             # State management providers
            │   ├── auth_provider.dart
            │   ├── home_feed_provider.dart
            │   ├── supervisor_complaint_provider.dart
            │   ├── admin_complaint_provider.dart
            │   ├── announcement_provider.dart
            │   └── notification_provider.dart
            ├── services/              # Client networking services
            │   ├── auth_service.dart
            │   ├── complaint_service.dart
            │   ├── announcement_service.dart
            │   └── notification_service.dart
            └── features/              # Feature modules by user role
                ├── auth/              # Splash, Landing, Login, Register screens
                ├── student/           # Student shell, dashboard, complaints, lost & found, profile
                ├── supervisor/        # Supervisor shell, queue, complaint detail, profile
                └── org_admin/         # Admin shell, dashboard, complaints, workspace,
                                       # announcements, notifications, profile
```

---

## Getting Started

### Prerequisites

Ensure you have the following installed on your development machine:
- **Git**: For version control.
- **Python**: Version 3.10 or higher.
- **Flutter SDK**: Version 3.19 or higher (compatible with Dart 3.11+).
- **MySQL Server**: Version 8.0 or higher.
- **Firebase Project**: A configured Firebase project with Email/Password authentication enabled.

---

### 1. Database Setup

1. Log into your MySQL console:
   ```bash
   mysql -u root -p
   ```

2. Create the `campushive` database:
   ```sql
   CREATE DATABASE campushive CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

3. Import the database schema tables from `campushive_db_v1.sql/` in relational order:
   ```bash
   # Run the individual SQL scripts or initialize schema tables
   mysql -u root -p campushive < campushive_db_v1.sql/campushive_db_organizations.sql
   mysql -u root -p campushive < campushive_db_v1.sql/campushive_db_departments.sql
   mysql -u root -p campushive < campushive_db_v1.sql/campushive_db_users.sql
   mysql -u root -p campushive < campushive_db_v1.sql/campushive_db_complaints.sql
   # Continue with remaining tables (images, supports, announcements, notifications, lost_found)
   ```
   *(For full schema definitions, consult [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)).*

---

### 2. Backend Setup

1. Open a terminal and navigate to the `backend/` directory:
   ```bash
   cd backend
   ```

2. Create and activate a Python virtual environment:
   ```bash
   # Windows (PowerShell)
   python -m venv venv
   .\venv\Scripts\Activate.ps1

   # Linux / macOS
   python3 -m venv venv
   source venv/bin/activate
   ```

3. Install required Python packages:
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

4. Create your local environment configuration from the template:
   ```bash
   cp .env.example .env
   ```

5. Configure your `.env` file with your local MySQL credentials and secret keys:
   ```ini
   FLASK_ENV=development
   FLASK_APP=app.py
   SECRET_KEY=your_development_secret_key
   DATABASE_URL=mysql+pymysql://root:your_mysql_password@localhost:3306/campushive
   FIREBASE_CREDENTIALS_PATH=./config/firebase-key.json
   ITEMS_PER_PAGE=20
   ```

6. Place your Firebase Admin SDK service account key at `backend/config/firebase-key.json`.

7. Start the Flask development server:
   ```bash
   python app.py
   ```
   *The API will start listening at `http://0.0.0.0:5000`.*

---

### 3. Frontend Setup

1. Open a new terminal and navigate to the active Flutter project:
   ```bash
   cd frontend/campushive_app
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Configure the backend API host in `lib/core/constants/app_constants.dart`:
   ```dart
   abstract final class AppConstants {
     // Use http://10.0.2.2:5000/api/v1 for Android Emulator
     // Use http://localhost:5000/api/v1 for iOS Simulator / Web / Desktop
     // Use http://<YOUR_LAN_IP>:5000/api/v1 for Physical Devices
     static const String apiBaseUrl = 'http://10.0.2.2:5000/api/v1';
   }
   ```

4. Run the Flutter application on your target device or emulator:
   ```bash
   flutter run
   ```

---

### 4. Device & Network Configuration

- **Android Emulator**: Uses `10.0.2.2` as an alias to the host machine's loopback interface (`127.0.0.1`).
- **Physical Devices**: Both the mobile device and development workstation must be on the same Wi-Fi network. Point `apiBaseUrl` to your workstation's local IP address (e.g., `http://192.168.1.50:5000/api/v1`) and ensure port `5000` is open on your firewall.

For additional platform-specific details and commands, refer to the [PROJECT_SETUP_GUIDE.md](PROJECT_SETUP_GUIDE.md).

---

## Environment Configuration & Security

CampusHive strictly follows secure credential handling best practices:

- **Zero Secrets in Version Control**: Actual environment files (`.env`), private keys, passwords, and service account credentials (`firebase-key.json`) are ignored via `.gitignore` and must never be committed to git.
- **Template-Based Configuration**: Use `backend/.env.example` as the source of truth for required configuration variables.
- **Firebase Token Verification**: Passwords are handled exclusively by Firebase Authentication. Client requests pass cryptographically signed Firebase ID tokens via the `Authorization: Bearer <ID_TOKEN>` header, which the Flask backend verifies using the `firebase-admin` SDK before admitting access.
- **Data Isolation**: All database queries enforce tenant isolation via `organization_id` extracted from the authenticated user's session record.

---

## Current Implementation Status

| Feature / Module | Status | Notes |
|---|---|---|
| **Student Module** | Complete | Complaint creation, photo upload, upvoting, lost & found, feed, profile, notifications. |
| **Supervisor Module** | Complete | Queue management, task details, status transitions, remarks, deadlines, profile. |
| **Organization Admin Module** | Complete | Live KPI dashboard, complaint queue & workspace, announcement management, notifications, profile. |
| **Authentication & RBAC** | Complete | Firebase sign-in, token validation, secure session storage, and role enforcement. |
| **Complaint REST APIs** | Complete | Full CRUD, upvoting, supervisor assignment, comments, deadlines, status history. |
| **Announcements System** | Complete | Full CRUD, importance flags, media URL attachments, like counters, feed synchronization. |
| **Notification Center** | Complete | Unread badge, paginated feeds, filter by unread, single/bulk mark-as-read, delete. |
| **Priority Calculation** | Complete | Hybrid system combining Scikit-Learn TF-IDF model with logarithmic support curves and keyword fallback. |
| **Super Admin Web Console** | Planned | Global multi-organization management and institution onboarding portal. |
| **Push Notifications (FCM)** | In Development | Backend services structured; background client FCM handlers planned. |
| **Automated ML Retraining** | Planned | Continuous learning pipeline based on verified supervisor resolution history. |

---

## Future Enhancements

1. **Automated ML Retraining Pipeline**: Scheduled background workers to periodically retrain the priority prediction model using historical complaint resolution times and supervisor adjustments.
2. **Deep NLP Categorization & Sentiment Analysis**: Natural language understanding to automatically suggest appropriate academic or facility departments from unstructured complaint text.
3. **Background Push Notifications**: Native Firebase Cloud Messaging background receivers for instant ticket assignment alerts and emergency campus broadcasts.
4. **Real-Time In-App Chat**: Interactive communication channels between students and assigned supervisors for active complaint clarification.
5. **Interactive Campus GIS Mapping**: Interactive campus floor plans and maps for precision issue location tagging.
6. **Web Administration Portal**: Responsive desktop web dashboard for campus facility managers and executive leadership.

---

## Project Documentation

For deeper architectural, database, and setup details, explore the dedicated documentation files:

- **[SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)** — Architectural design, module interaction flows, security architecture, and multi-tenant specifications.
- **[DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)** — Comprehensive MySQL table structures, foreign keys, indexes, triggers, and initialization commands.
- **[PROJECT_SETUP_GUIDE.md](PROJECT_SETUP_GUIDE.md)** — Step-by-step developer setup, dependency management, and troubleshooting guide.
- **[PHASE_1_COMPLETION.md](PHASE_1_COMPLETION.md)** — Phase 1 architectural completion review and deliverables verification.

---

## Contribution & Guidelines

CampusHive is developed as an academic major project.

- Contributions should follow clean architecture principles, maintaining separation between presentation widgets, state providers, networking services, and domain models.
- Code must be formatted using `dart format` for Flutter and `black` / `flake8` for Python.
- All code modifications must pass static analysis (`flutter analyze` with 0 issues).
