# CampusHive — System Architecture

This document describes the end-to-end system architecture of CampusHive, including its client layer, API gateway, business services, multi-tenant database design, push notifications, and machine-learning prioritization engine.

---

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER (Flutter)                          │
│   ┌───────────────────┐ ┌──────────────────────┐ ┌─────────────────┐   │
│   │   Student Shell   │ │   Supervisor Shell   │ │   Admin Shell   │   │
│   └─────────┬─────────┘ └──────────┬───────────┘ └────────┬────────┘   │
│             └──────────────────────┼──────────────────────┘            │
│                     Provider State Management & GoRouter               │
│                     Firebase Auth & FCM Background Handler             │
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
│  ┌────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │ PriorityService (ML)   │  │ Escalation & Assignment Services     │  │
│  │ - TF-IDF + Rand Forest │  │ - SLA deadline calculation           │  │
│  │ - Support count curve  │  │ - Supervisor queue management        │  │
│  └────────────────────────┘  └──────────────────────────────────────┘  │
│  ┌────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │ EmailService (SMTP)    │  │ FcmService (Push Notifications)      │  │
│  │ - Six-digit OTP        │  │ - Firebase Admin SDK messaging       │  │
│  │ - Verification tokens  │  │ - Status update & circular alerts    │  │
│  └────────────────────────┘  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ RetrainingService & APScheduler (Optional Background Automation) │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ SQLAlchemy ORM / PyMySQL
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     DATABASE LAYER (AWS RDS MySQL)                     │
│  - Multi-tenant data segregation by `organization_id`                  │
│  - 19 Normalized Relational Tables (InnoDB, utf8mb4)                   │
│  - Automated snapshots and automated daily maintenance                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Authentication & Security Architecture

CampusHive implements a hybrid authentication model combining **Firebase Authentication** for identity and session management with an **internal six-digit email OTP flow** for verified student onboarding.

### 1.1 Student Registration Flow

```
Mobile Client                  Flask API Backend             Email (SMTP)          Firebase Auth
      │                                │                          │                      │
      ├── 1. POST /auth/otp/send ────► │                          │                      │
      │   (email, org_id, usn, etc.)   ├── 2. Gen OTP (6 digits)  │                      │
      │                                ├── 3. Save hash in MySQL  │                      │
      │                                ├── 4. Send email ────────►│                      │
      │                                │                          │                      │
      │◄── 5. OTP Sent Response ───────┤                          │                      │
      │                                │                          │                      │
      ├── 6. POST /auth/otp/verify ──► │                          │                      │
      │   (email, otp_code)            ├── 7. Verify attempt & exp│                      │
      │                                ├── 8. Gen verification_   │                      │
      │                                │      token (SHA-256)     │                      │
      │◄── 9. Verification Token ──────┤                          │                      │
      │                                │                          │                      │
      ├── 10. Create Firebase User ─────────────────────────────────────────────────────►│
      │                                                                                  │
      ├── 11. POST /auth/register ───► │                                                 │
      │   (verification_token,         ├── 12. Validate token & consume                  │
      │    firebase_id_token,          ├── 13. Verify Firebase token with Admin SDK       │
      │    profile details)            ├── 14. Create row in MySQL `users` table         │
      │◄── 15. User Profile Created ───┤                                                 │
```

### 1.2 Request Authorization Guard

Every authenticated endpoint is guarded by `@firebase_login_required` and `@role_required` in `backend/app/middleware/firebase_auth.py`:

1. **Bearer Token Extraction**: The client passes `Authorization: Bearer <FIREBASE_ID_TOKEN>`.
2. **Firebase Token Verification**: The backend verifies signature and expiration using `firebase_admin.auth.verify_id_token`.
3. **User Record Resolution**: Extracts `firebase_uid` and loads the user record from MySQL.
4. **Role Enforcement**: Matches the user's role (`STUDENT`, `SUPERVISOR`, `ORG_ADMIN`, `SUPER_ADMIN`) against required role privileges.
5. **Context Binding**: Attaches the user object to `flask.g.current_user` for tenant and permission scoping.

---

## 2. Multi-Tenancy Architecture

CampusHive implements a shared-database, shared-schema multi-tenant design:

* **Tenant Key**: Every core entity (`users`, `academic_departments`, `departments`, `complaints`, `lost_found`, `announcements`) includes an `organization_id` foreign key referencing `organizations(organization_id)`.
* **Row-Level Tenant Scoping**: Business services automatically constrain database queries to `organization_id = g.current_user.organization_id`, ensuring strict data isolation across participating institutions.
* **Academic vs. Facility Separation**:
  * `academic_departments`: Represents academic degrees/branches (e.g., Computer Science).
  * `departments`: Represents facility maintenance teams (e.g., Electrical, Plumbing, Hostel Maintenance).

---

## 3. Machine Learning & Prioritization Architecture

Complaint priority (`LOW`, `MEDIUM`, `HIGH`) is calculated using a hybrid algorithmic engine:

```
Complaint Description
        │
        ▼
┌────────────────────────────────────────────────────────┐
│ Scikit-Learn Pipeline (priority_model.joblib)          │
│ - TF-IDF N-Gram Vectorizer (1-2 grams)                 │
│ - Random Forest Classifier                             │
│ - Output: Base Priority + Confidence Score             │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ Upvote Support Normalization (Logarithmic Scale)       │
│ - Raw community support count                          │
│ - Normalized weight: log(1 + supports)                 │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ Priority Decision Engine                               │
│ - Combines ML predicted priority with upvote momentum  │
│ - Keyword heuristic fallback if model confidence low   │
│ - Final Priority: LOW / MEDIUM / HIGH                  │
│ - Sets Departmental SLA Target Resolution Time         │
└────────────────────────────────────────────────────────┘
```

### Automated Retraining Subsystem (`backend/app/services/retraining_service.py`)
* Periodically scans complaints resolved by supervisors after a cooling period (`ML_RETRAINING_DELAY_HOURS`).
* Records candidate training items in `ml_retraining_items` and runs evaluation batches in `ml_retraining_batches`.
* Evaluates accuracy, macro precision, recall, and F1 score before replacing candidate model artifacts.

---

## 4. Push Notification & Real-Time Delivery

CampusHive delivers alerts through Firebase Cloud Messaging (FCM) and an in-app notification center:

```
Event Triggered
(Complaint assigned / Status updated / Urgent announcement)
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│ Backend Notification Dispatcher                        │
│ 1. Creates record in MySQL `notifications` table       │
│ 2. Looks up recipient's registered `fcm_token`         │
│ 3. Dispatches FCM Push Payload via Firebase Admin SDK  │
└─────────────────────┬──────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│ Firebase Cloud Messaging (FCM) Cloud Gateway           │
└─────────────────────┬──────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│ Flutter Client (lib/services/fcm_service.dart)         │
│ - Foreground: Displays notification banner / snackbar  │
│ - Background / Terminated: System tray push alert      │
│ - Deep Link: Tapping routes to specific complaint or   │
│   announcement via GoRouter                            │
└────────────────────────────────────────────────────────┘
```

---

## 5. Flutter Client Architecture

The mobile client is built in Flutter using the **Provider** state management pattern and **GoRouter** declarative routing:

* **Presentation Layer**:
  * Role shells: `StudentShellScreen`, `SupervisorShellScreen`, `AdminShellScreen`.
  * Shared header: `CampusHiveAppBar` providing consistent branding, unread notification badges, and logout confirmation dialogs.
* **State Management**:
  * `AuthProvider`: Manages Firebase sign-in, token storage, and session lifecycle.
  * `NotificationProvider`: Manages unread badge counters, paginated feeds, and mark-as-read state.
  * Feature providers: `SupervisorComplaintProvider`, `AdminComplaintProvider`, `AnnouncementProvider`, `HomeFeedProvider`.
* **Network & Storage Layer**:
  * `ApiClient`: HTTP client wrapper managing Bearer token injection, request headers, and error parsing.
  * `FlutterSecureStorage`: Encrypted device keychain storage for session metadata.
