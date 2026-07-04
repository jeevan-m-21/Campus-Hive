# CampusHive - Complete System Architecture

## Project Overview

CampusHive is a cloud-based, multi-tenant SaaS platform for campus issue management and student interaction. The system enables multiple educational institutions to use the same platform while maintaining complete data isolation.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER (Flutter)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐       │
│  │ Student App  │  │  Admin App   │  │ Supervisor App   │       │
│  └──────────────┘  └──────────────┘  └──────────────────┘       │
└────────────────────────────┬──────────────────────────────────────┘
                             │ REST API + WebSocket
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│               API GATEWAY & LOAD BALANCER                        │
│  (Flask with CORS, JWT Validation, Rate Limiting)               │
└────────────────────────────┬──────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐ ┌──────────────────┐ ┌──────────────┐
│ REST API Layer  │ │ WebSocket Layer  │ │ File Service │
│  (Flask Routes) │ │ (SocketIO)       │ │ (Firebase)   │
└────────┬────────┘ └────────┬─────────┘ └──────┬───────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              BUSINESS LOGIC LAYER (Services)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Auth Service │  │ Complaint    │  │ Notification │          │
│  │              │  │ Service      │  │ Service      │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Lost & Found │  │ Analytics    │  │ ML Service   │          │
│  │ Service      │  │ Service      │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└────────────────────────────┬──────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐ ┌──────────────────┐ ┌──────────────┐
│ Data Access     │ │ Cache Layer      │ │ Task Queue   │
│ Layer (ORM)     │ │ (Redis)          │ │ (Celery)     │
└────────┬────────┘ └──────────────────┘ └──────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DATABASE LAYER (MySQL)                       │
│  ┌────────────────┐  ┌──────────────┐  ┌────────────────┐     │
│  │ Organizations  │  │ Users        │  │ Complaints     │     │
│  │ Departments    │  │ Supervisors  │  │ Votes          │     │
│  │ Announcements  │  │ Lost & Found │  │ Notifications  │     │
│  └────────────────┘  └──────────────┘  └────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
         │
         └─── Automated Backups & Replication
             
┌─────────────────────────────────────────────────────────────────┐
│              EXTERNAL SERVICES                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Firebase     │  │ Firebase     │  │ Email Service│          │
│  │ Cloud        │  │ Storage      │  │ (SMTP)       │          │
│  │ Messaging    │  │              │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Multi-Tenancy Architecture

### Data Isolation Strategy

**Organization-Based Segregation:**

```
┌─────────────────────────────────────┐
│          DATABASE (MySQL)           │
├─────────────────────────────────────┤
│ Tenant 1 (KSIT)   │  Tenant 2 (RVCE)│
│ ─────────────────  │  ──────────────│
│ Users             │  Users          │
│ Complaints        │  Complaints     │
│ Lost & Found      │  Lost & Found   │
│ Announcements     │  Announcements  │
└─────────────────────────────────────┘
```

**Implementation Approach:**
- Every table has `organization_id` foreign key
- Row-level security via JWT token (organization_id embedded)
- Query filters automatically applied at service layer
- Separate database connections possible for enterprise deployments

### JWT Token Structure

```json
{
  "user_id": "user_uuid",
  "organization_id": "org_uuid",
  "role": "student|supervisor|admin|super_admin",
  "email": "user@institution.edu",
  "department_id": "dept_uuid",
  "exp": 1234567890,
  "iat": 1234567890
}
```

---

## Authentication & Authorization

### Authentication Flow

```
User Login
    ▼
Validate Credentials (Database)
    ▼
Verify Organization (Multi-tenant check)
    ▼
Generate JWT Token (with organization_id)
    ▼
Return Token + User Profile
    ▼
Client stores token securely
    ▼
Include in API requests (Authorization: Bearer <token>)
```

### Role-Based Access Control (RBAC)

| Role | Permissions |
|------|-------------|
| **Super Admin** | Create orgs, manage org admins, view platform analytics, global settings |
| **Organization Admin** | Manage students, supervisors, view complaints, escalate, send announcements |
| **Supervisor** | View assigned complaints, update status, communicate with students |
| **Student** | Create complaints, upload images, vote, view status, lost & found posts |

### Route Protection Middleware

```python
@require_auth
@require_role(['admin', 'supervisor'])
@require_organization
def protected_route():
    # Only authenticated users with proper roles in same organization
    pass
```

---

## Core Module Architecture

### 1. Authentication Module

**Endpoints:**
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login with credentials
- `POST /api/auth/refresh` - Refresh JWT token
- `POST /api/auth/logout` - Logout
- `GET /api/auth/verify` - Verify token validity
- `POST /api/auth/password-reset` - Reset password

**Flow:**
```
Request → Validate Credentials → Check Organization → Generate JWT → Store Session
```

### 2. Organization Module

**Endpoints:**
- `POST /api/organizations` (Super Admin only)
- `GET /api/organizations` (Organization Admin)
- `PATCH /api/organizations/:id` (Organization Admin)
- `GET /api/organizations/:id/stats` (Organization Admin)

**Features:**
- Complete organization profile
- Department management
- Admin assignments
- Organization settings

### 3. Complaint Management Module

**Endpoints:**
- `POST /api/complaints` - Create complaint
- `GET /api/complaints` - List complaints (filtered by org)
- `GET /api/complaints/:id` - Get complaint details
- `PATCH /api/complaints/:id` - Update complaint status
- `POST /api/complaints/:id/vote` - Vote on priority
- `POST /api/complaints/:id/comments` - Add comment
- `POST /api/complaints/:id/escalate` - Escalate complaint

**Automatic Flow After Creation:**
```
1. Store complaint in DB
   ├─ organization_id (from JWT)
   ├─ student_id
   ├─ category
   ├─ description
   └─ images

2. Identify Supervisor
   ├─ Map category → department
   └─ Select available supervisor

3. Auto-Assign
   ├─ Update complaint.supervisor_id
   ├─ Set complaint.status = "Assigned"
   └─ Set created_at + deadline

4. Send Notifications
   ├─ FCM to supervisor
   ├─ Update dashboard via SocketIO
   └─ Log notification in DB

5. Trigger Escalation Scheduler
   └─ Set escalation check timer
```

**Categories & Mapping:**
| Category | Department Supervisor |
|----------|----------------------|
| Electrical | Electrical Supervisor |
| Housekeeping | Housekeeping Supervisor |
| Transport | Transport Supervisor |
| Hostel | Hostel Supervisor |
| Internet | IT Supervisor |
| Security | Security Supervisor |
| Other | General Supervisor |

**Priority System:**

ML Prediction + Voting Formula:
```
Final Priority = (ML_Score × 0.5) + (Voting_Score × 0.5)

Where:
- ML_Score: Scikit-Learn model output (normalized 0-1)
- Voting_Score: Community votes (normalized 0-1)

Classification:
- 0.0 - 0.33 = Low (Deadline: 7 days)
- 0.34 - 0.66 = Medium (Deadline: 72 hours)
- 0.67 - 1.0 = High (Deadline: 24 hours)
```

**Status Lifecycle:**
```
Pending → Assigned → In Progress → Resolved → Closed
         (Auto)                               (Manual/Auto after 30 days)
```

### 4. Supervisor Assignment System

**Automatic Assignment Rules:**

```python
class ComplaintAssignmentEngine:
    def assign_supervisor(complaint):
        # 1. Map category to department
        department = get_department_for_category(complaint.category)
        
        # 2. Find available supervisors in that department
        supervisors = get_active_supervisors_for_department(
            department_id=department.id,
            organization_id=complaint.organization_id
        )
        
        # 3. Load balancing: assign to supervisor with least pending complaints
        supervisor = min(supervisors, key=lambda s: s.pending_complaint_count)
        
        # 4. Create assignment
        complaint.supervisor_id = supervisor.id
        complaint.assigned_at = now()
        complaint.deadline = calculate_deadline(complaint.priority)
        
        # 5. Notify supervisor via FCM
        send_fcm_notification(supervisor, complaint)
        
        # 6. Broadcast via SocketIO to admin dashboard
        emit_dashboard_update(complaint.organization_id, complaint)
```

### 5. Escalation System

**Escalation Logic:**

```
Every complaint has:
├─ created_at (timestamp)
├─ deadline (based on priority)
├─ escalation_level (1-3)
└─ escalated_at (timestamp)

Escalation Rules:
├─ Level 1 (Initial): Supervisor handles
├─ Level 2 (24h late): Escalate to Org Admin
└─ Level 3 (72h late): Escalate to Super Admin

Automated Check (runs every 15 minutes):
if (now - created_at) > deadline AND status != 'Resolved':
    ├─ Update escalation_level
    ├─ Change assigned_to (if applicable)
    ├─ Send notification to new owner
    └─ Update dashboard in real-time
```

**Scheduler Implementation:**
```python
# APScheduler or Celery beat
@periodic_task(run_every=crontab(minute=0, hour='*/1'))
def check_escalations():
    """Check every hour for complaints that need escalation"""
    overdue_complaints = Complaint.query.filter(
        (now() - Complaint.created_at) > Complaint.deadline,
        Complaint.status.in_(['Pending', 'Assigned', 'In Progress']),
        Complaint.escalation_level < 3
    ).all()
    
    for complaint in overdue_complaints:
        escalate_complaint(complaint)
```

### 6. Community Voting System

**Endpoints:**
- `POST /api/complaints/:id/vote` - Submit vote (Upvote/Downvote)
- `GET /api/complaints/:id/votes` - Get vote stats

**Logic:**
```python
def calculate_community_score(complaint_id):
    votes = ComplaintVote.query.filter_by(complaint_id=complaint_id).all()
    
    upvotes = sum(1 for v in votes if v.vote_type == 'upvote')
    downvotes = sum(1 for v in votes if v.vote_type == 'downvote')
    total_votes = len(votes)
    
    if total_votes == 0:
        return 0.5  # Default to neutral
    
    # Normalize to 0-1
    score = upvotes / total_votes
    return score

def calculate_final_priority(complaint_id):
    ml_score = get_ml_prediction(complaint_id)
    voting_score = calculate_community_score(complaint_id)
    
    final_score = (ml_score * 0.5) + (voting_score * 0.5)
    
    # Update complaint
    complaint = Complaint.query.get(complaint_id)
    complaint.priority_score = final_score
    complaint.priority = classify_priority(final_score)
    db.session.commit()
    
    return complaint.priority
```

### 7. Lost & Found Module

**Endpoints:**
- `POST /api/lost-found` - Create post
- `GET /api/lost-found` - List posts
- `GET /api/lost-found/:id` - Get post details
- `POST /api/lost-found/:id/comments` - Add comment
- `POST /api/lost-found/:id/claim` - Claim item
- `PATCH /api/lost-found/:id` - Update post status

**Statuses:**
- `Open` - Available for claims
- `Claimed` - Someone claimed it
- `Closed` - Item found/resolved

**Features:**
- Image upload (Firebase Storage)
- Comment system
- Claim process with messaging
- Auto-close after 30 days if no claims

### 8. Notification System

**Using Firebase Cloud Messaging (FCM)**

**Notification Triggers:**

| Event | Recipients | Payload |
|-------|-----------|---------|
| Complaint Assigned | Supervisor | `{type: 'complaint.assigned', complaint_id, category, priority}` |
| Status Updated | Student | `{type: 'complaint.status', status, complaint_id}` |
| Escalated | Admin | `{type: 'complaint.escalated', level, complaint_id}` |
| Lost Item Matched | Both Users | `{type: 'lost_found.matched', post_id}` |
| New Announcement | All Students | `{type: 'announcement.new', title, content}` |
| Comment Added | Relevant Users | `{type: 'comment.new', post_id, commenter}` |

**Implementation:**
```python
def send_fcm_notification(user_id, notification_data):
    user = User.query.get(user_id)
    if not user.fcm_token:
        return
    
    message = messaging.Message(
        notification=messaging.Notification(
            title=notification_data['title'],
            body=notification_data['body'],
        ),
        data=notification_data['data'],
        token=user.fcm_token,
    )
    
    response = messaging.send(message)
    
    # Log notification
    log_notification(user_id, notification_data, response)
```

### 9. Announcement Module

**Endpoints:**
- `POST /api/announcements` (Org Admin only)
- `GET /api/announcements` - Get org's announcements
- `PATCH /api/announcements/:id` (Org Admin)
- `DELETE /api/announcements/:id` (Org Admin)

**Features:**
- Organization-scoped broadcasts
- Target specific departments/roles
- Schedule announcements
- FCM notification integration
- Read receipt tracking

### 10. Analytics Module

**Admin Dashboard Metrics:**

```
Complaint Analytics:
├─ Total complaints (all time, this month, this week)
├─ Pending complaints (count + %)
├─ Resolved complaints (count + %)
├─ Average resolution time
├─ Department-wise breakdown (charts)
├─ Category-wise breakdown (pie chart)
└─ Trending categories (line chart)

Lost & Found Analytics:
├─ Total posts
├─ Claimed vs unclaimed
└─ Category distribution

User Analytics:
├─ Total students
├─ Total supervisors
├─ Active users (last 30 days)
└─ Engagement metrics

Performance Metrics:
├─ API response times
├─ Database query times
├─ Escalation percentage
└─ Supervisor average resolution time
```

**Endpoints:**
- `GET /api/analytics/complaints` - Complaint stats
- `GET /api/analytics/departments` - Department stats
- `GET /api/analytics/users` - User stats
- `GET /api/analytics/dashboard` - Complete dashboard data

---

## Machine Learning Module

### Complaint Prioritization Model

**Features:**
```
Input Features:
├─ complaint_category (categorical)
├─ description_text (text - TF-IDF)
├─ complaint_word_count (numerical)
├─ department_workload (numerical)
├─ student_past_complaints (numerical)
└─ historical_similar_complaints_priority (categorical)

Output:
└─ priority_level: Low, Medium, High
```

**Model Training:**

```python
# pipeline.py
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier

class ComplaintPriorityModel:
    def __init__(self):
        self.pipeline = Pipeline([
            ('tfidf', TfidfVectorizer(max_features=100)),
            ('scaler', StandardScaler()),
            ('classifier', RandomForestClassifier(n_estimators=100))
        ])
        self.category_encoder = LabelEncoder()
        
    def train(self, X_train, y_train):
        self.pipeline.fit(X_train, y_train)
        
    def predict(self, complaint_data):
        features = self.extract_features(complaint_data)
        prediction = self.pipeline.predict([features])
        probability = self.pipeline.predict_proba([features])
        
        return {
            'priority': prediction[0],
            'confidence': max(probability[0])
        }
```

**Integration:**

```python
@app.route('/api/complaints', methods=['POST'])
@require_auth
def create_complaint():
    data = request.json
    
    # Create complaint
    complaint = Complaint(**data, organization_id=current_user.organization_id)
    db.session.add(complaint)
    db.session.commit()
    
    # Get ML prediction
    ml_result = ml_service.predict(complaint)
    complaint.ml_priority_score = ml_result['confidence']
    complaint.ml_priority = ml_result['priority']
    db.session.commit()
    
    # Assign supervisor and notify
    assignment_engine.assign_and_notify(complaint)
    
    return jsonify(complaint.to_dict()), 201
```

---

## Real-Time Communication (SocketIO)

**Events:**

```python
# Complaint updates
@socketio.on('complaint_update')
def handle_complaint_update(data):
    # Broadcast to admin dashboard
    emit('complaint_updated', data, 
         room=f"org_{data['organization_id']}_admins")

# Status changes
@socketio.on('status_change')
def handle_status_change(data):
    emit('status_changed', data, 
         room=f"complaint_{data['complaint_id']}")

# Notifications
@socketio.on('new_assignment')
def handle_new_assignment(data):
    emit('assignment_received', data, 
         room=f"user_{data['supervisor_id']}")
```

---

## Security Architecture

### Data Protection

```
┌─────────────────────────────────────┐
│  Encryption at Rest (AES-256)      │
│  - Database                         │
│  - File Storage                     │
└─────────────────────────────────────┘
         ▼
┌─────────────────────────────────────┐
│  Encryption in Transit (TLS 1.3)   │
│  - API calls                        │
│  - WebSocket connections            │
└─────────────────────────────────────┘
         ▼
┌─────────────────────────────────────┐
│  Access Control                     │
│  - JWT tokens                       │
│  - RBAC                             │
│  - Organization segregation         │
└─────────────────────────────────────┘
```

### API Security

```python
# Rate limiting
RATELIMIT_STORAGE_URL = "redis://localhost:6379"

@app.route('/api/complaints', methods=['POST'])
@limiter.limit("100 per hour")
@require_auth
def create_complaint():
    pass

# CORS
CORS(app, 
     origins=["https://campushive.app"],
     methods=["GET", "POST", "PATCH", "DELETE"],
     allow_headers=["Authorization", "Content-Type"])

# Input validation
@app.route('/api/complaints/:id', methods=['PATCH'])
@require_auth
def update_complaint(complaint_id):
    schema = ComplaintUpdateSchema()
    errors = schema.validate(request.json)
    if errors:
        return jsonify(errors), 400
    # Process...
```

---

## Deployment Architecture

```
┌─────────────────────────────────────────┐
│  Client Layer (CDN)                    │
│  - Flutter APK/IPA (Firebase Hosting)  │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────────────────────────────┐
│  API Layer (Docker Containers)          │
│  - Load Balancer (Nginx)                │
│  - Flask API Servers (3+ instances)     │
│  - WebSocket Gateway                    │
└──────────────────┬───────────────────────┘
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
   ┌────────┐ ┌───────┐ ┌───────┐
   │ MySQL  │ │ Redis │ │ Queue │
   │ Master │ │Cache  │ │(Celery)
   └────┬───┘ └───────┘ └───────┘
        │
   ┌────▼───────────────┐
   │ MySQL Replica      │
   │ (Read scaling)     │
   └────────────────────┘
```

---

## Development Phases

### Phase 1: Foundation (Week 1-2)
- [x] Database schema
- [x] Backend scaffolding
- [x] Flutter structure
- [ ] Authentication APIs
- [ ] Database models

### Phase 2: Core Features (Week 3-4)
- [ ] Complaint management
- [ ] Assignment system
- [ ] Escalation system
- [ ] Basic frontend screens

### Phase 3: Advanced Features (Week 5-6)
- [ ] ML module
- [ ] Notifications (FCM)
- [ ] Real-time updates (SocketIO)
- [ ] Analytics dashboard

### Phase 4: Production (Week 7-8)
- [ ] Testing & QA
- [ ] Performance optimization
- [ ] Deployment & DevOps
- [ ] Documentation

---

## Next Steps

1. Database schema implementation (MySQL)
2. Backend project structure setup
3. Flutter project structure organization
4. JWT authentication implementation
5. Database models with SQLAlchemy
