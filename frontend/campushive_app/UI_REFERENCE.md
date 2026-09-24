
> Read-only inventory of the existing teammate Flutter frontend at `D:/Major_Project/campus_hive/frontend/campushive_flutter`. This document describes observed UI and navigation only. It is not an implementation specification, and the teammate project's mock data is not authoritative backend contract data.

## Scope and Evidence

Inspected source areas:

- `lib/main.dart`
- `lib/core/router/app_router.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/data/mock_data.dart`
- `lib/core/models/`
- `lib/core/widgets/`
- `lib/providers/app_state_provider.dart`
- `lib/features/auth/`
- `lib/features/layout/`
- `lib/features/student/`
- `lib/features/supervisor/`
- `lib/features/admin/`

Actual routed feature files found under `lib/features/`:

- 4 authentication screens
- 9 student routes/screens
- 3 supervisor routes/screens
- 4 organization-admin routes/screens
- 2 shared layout files

The router is the source of truth for what is reachable. There are no routed profile screens, dedicated notification screen, student event list route, admin announcements route, or admin users route in the inspected code.

## Application Bootstrap and Navigation

### Entry point

**File:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/main.dart`

- Calls `WidgetsFlutterBinding.ensureInitialized()`.
- Creates `AppState` with `ChangeNotifierProvider`.
- Runs `CampusHiveApp` using `MaterialApp.router`.
- Uses `AppTheme.light` as the configured theme.
- Supplies `AppRouter.router(appState)`.
- The state provider is local in-memory state; there is no observed persistent session initialization in this entry point.

### Router

**File:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/core/router/app_router.dart`

- Initial location: `/splash`.
- Auth routes are outside the shell: `/splash`, `/landing`, `/login`, `/register`.
- All role routes are inside one `ShellRoute` rendered by `MainScaffold`.
- When `AppState.isAuthenticated` is true and the user visits an auth route, the router redirects to the role home path.
- When unauthenticated users request a protected route, the router redirects to `/landing`.
- `/login` accepts an optional `demo` query parameter and passes it to `LoginScreen`.
- Complaint details use `/student/complaint/:id`.
- Lost-and-found details use `/student/lost-found/:id`.

## AUTHENTICATION

### Splash

**Screen name:** Splash / boot sequence

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/auth/splash_screen.dart`

**User role:** Unauthenticated visitor; shared entry point.

**Purpose:** Branded startup sequence before entering the authentication flow.

**Layout structure:**

- Full-screen dark background.
- Animated mesh-style background.
- Centered, constrained content with a large animated orbital logo treatment.
- Orbiting particles, pulsing logo, glow effects, and shimmer animation.
- Animated boot-log text list.
- An enter action appears after the scripted sequence completes.

**Navigation:**

- Entered from the router's initial `/splash` location.
- The Enter CampusHive button navigates to `/landing`.
- Quick Demo Access chips navigate directly to `/login?demo=student`, `/login?demo=supervisor`, or `/login?demo=admin`.
- Authenticated users are redirected by the router to their role home path.

**Data displayed:**

- Hardcoded boot messages such as kernel initialization, TLS connection, organization registry, ML model loading, FCM initialization, and department schema sync.
- These messages are presentation/demo content, not evidence that the new app must expose those exact states.

**Actions:**

- Delayed boot sequence.
- Enter/continue action after the sequence.

### Landing / login selection

**Screen name:** Landing Login

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/auth/landing_login_screen.dart`

**User role:** Unauthenticated visitor.

**Purpose:** Public landing page and entry point to login or registration.

**Layout structure:**

- Dark, gradient-heavy background with decorative glow orbs.
- Responsive two-column layout on wide screens: hero panel and right-side login/entry panel.
- Stacked hero and entry panels on narrow screens.
- CampusHive logo/name treatment.
- Marketing headline: “Your Campus, Digitally Connected.”
- Supporting description covering complaints, lost and found, news, academic collaboration, and AI priority scoring.
- Role/demo entry options are present in the landing flow according to the login route's `demo` query support.

**Navigation:**

- Entered from `/splash` or unauthenticated redirect.
- Leads to `/login` and `/register`.
- Protected routes redirect back here when unauthenticated.

**Data displayed:**

- Static product copy and visual branding.
- AI, notification, and collaboration claims are descriptive/demo content in this frontend.

**Actions:**

- Navigate to login.
- Navigate to registration.
- May select a role/demo login entry from the landing controls.

### Login

**Screen name:** Login

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/auth/login_screen.dart`

**User role:** Unauthenticated visitor; supports student, supervisor, and admin demo roles.

**Purpose:** Collect credentials and place the in-memory app state into a role-specific authenticated state.

**Layout structure:**

- Dark background with decorative radial glows.
- Centered form in a constrained width.
- Back control to landing.
- Name, email, and password inputs.
- Password visibility control.
- Loading state during submission.
- Validation/error display.
- Demo credential presentation/auto-fill based on the `demoRole` query parameter.

**Navigation:**

- Entered from `/landing` or a demo role link.
- Successful login navigates to `/student/dashboard`, `/supervisor/dashboard`, or `/admin/dashboard`.
- Back navigates to `/landing`.

**Data displayed:**

- Hardcoded demo identities:
  - Student: Arjun Mehta, `arjun.mehta@campushive.edu`, `1HB22CS045`.
  - Supervisor: Priya Sharma, `priya.supervisor@campushive.edu`, `EMP-SUP-214`.
  - Admin: Dr. Rajan Verma, `admin@campushive.edu`, `EMP-ADM-001`.
- These are explicitly demo credentials and must not be treated as backend seed requirements.

**Actions:**

- Validate and submit login form.
- Infer role from a supplied demo role or from email text containing `admin`/`supervisor`; all other inputs become student.
- Update `AppState` using `loginAsStudent`, `loginAsSupervisor`, or `loginAsAdmin`.

**Backend caution:** The role-from-email behavior and delayed fake login are demo logic, not production authentication behavior.

### Register

**Screen name:** Register

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/auth/register_screen.dart`

**User role:** New student, supervisor, or organization-admin applicant.

**Purpose:** Collect registration details and select an intended role.

**Layout structure:**

- Dark background with decorative glow effects.
- Form with name, email, ID/USN, phone, and password.
- Role tab control with three roles: Student, Supervisor, Org Admin.
- Department selector.
- Organization selector.
- Password-strength indicator.
- Terms-of-service checkbox.
- Submit action and validation feedback.

**Navigation:**

- Entered from the landing page.
- Successful submission navigates directly to the selected role dashboard.

**Data displayed:**

- Hardcoded role descriptions.
- Hardcoded department list, including engineering departments, administration, hostel management, security/facilities, and library.
- Hardcoded organization list, including Bangalore University, VTU, RV College, BMS, PESIT, and MSRIT.

**Actions:**

- Switch selected role.
- Choose department and organization.
- Validate password strength.
- Agree to terms.
- Submit registration.

**Backend caution:** Registration currently waits briefly and then calls an `AppState` login helper. It does not create a backend account.

## SHARED AUTHENTICATED LAYOUT

### Main scaffold

**Screen name:** Role-aware application shell

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/layout/main_scaffold.dart`

**User role:** Authenticated student, supervisor, or admin.

**Purpose:** Wrap all protected screens with shared navigation and account controls.

**Layout structure:**

- Responsive breakpoint at approximately 900px.
- Desktop:
  - Top app bar.
  - Fixed left sidebar, approximately 260px wide.
  - Main child content.
- Mobile:
  - Top app bar with menu button.
  - Drawer containing the sidebar.
  - Main child content.
  - Bottom navigation bar.
- App bar includes brand, role switcher, notifications button, theme toggle, and profile popup.
- Notifications open a bottom sheet rather than a route.
- Profile popup displays user identity, ID/email, role, department, and sign-out action.

**Navigation:**

- Sidebar and mobile navigation move between role routes.
- Role switcher changes the in-memory role and redirects to that role's home path.
- Sign out calls `AppState.logout()` and navigates to `/landing`.
- Notification button opens a modal bottom sheet.
- The theme toggle calls `AppState.toggleDarkMode()`; `main.dart` only visibly configures the light theme, so the dark-mode behavior should be treated as legacy/demo behavior to verify before reuse.

### Sidebar

**Screen component:** Role-aware navigation sidebar

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/layout/app_sidebar.dart`

**Layout structure:**

- User profile card at the top with initials, name, ID, and role badge.
- Role-specific section heading.
- Icon-and-label navigation items.
- Selected item uses a filled accent background.
- Some items show numeric badges.
- Sign-out action is fixed at the bottom.

**Role navigation items:**

- Student: Dashboard, Active Complaints, Submit Complaint, Lost & Found, Campus Feed, Academic Forums.
- Supervisor: Supervisor Overview, Task Queue (ML Priority), Complaint Workspace.
- Admin: Campus Overview, Complaint Management, Supervisor Roster, Security & Audit Logs.

## STUDENT

### Student dashboard

**Screen name:** Student Dashboard

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/student_dashboard_screen.dart`

**User role:** Student.

**Purpose:** Summarize personal and campus complaint activity and provide entry points to common student actions.

**Layout structure:**

- Scrollable page with approximately 24px padding.
- Large greeting banner with USN, semester label, greeting, and explanatory copy.
- Primary actions: Report New Issue and Lost & Found.
- Bento-style activity metrics grid.
- Complaint/activity sections and ticket cards below the summary.
- Complaint cards expose status/priority badges and peer-support affordances.

**Navigation:**

- Entered after student login at `/student/dashboard`.
- Report action navigates to `/student/submit-complaint`.
- Lost & Found action navigates to `/student/lost-found`.
- Complaint cards can open `/student/complaint/:id`.

**Data displayed:**

- Current user values from `AppState`.
- Complaint list from `MockData.complaints`.
- Derived counts: open, in-progress, resolved, and supported complaints.
- Static semester label.

**Actions:**

- Toggle support/upvote on a complaint in local state.
- Open complaint details.
- Start a complaint.
- Open lost and found.

**Mock/demo status:** Complaint data and derived metrics are mock-only in this project.

### Active complaints

**Screen name:** Active Campus Complaints

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/active_complaints_screen.dart`

**User role:** Student.

**Purpose:** Search, filter, inspect, and support complaints submitted across departments.

**Layout structure:**

- Header with title, description, and File Complaint button.
- Search field for keyword, room, or location.
- Horizontal filter chips for all, pending, in progress, critical, and escalated.
- Scrollable complaint-card list.
- Empty state when filters match nothing.
- Complaint cards include ID/title, status, priority, category/department/location, description, support count, and support action.

**Navigation:**

- Entered from student sidebar or dashboard.
- File Complaint goes to `/student/submit-complaint`.
- Selecting a complaint goes to `/student/complaint/:id`.

**Data displayed:**

- `MockData.complaints` filtered locally.
- Ticket fields include ID, title, category, department, status, ML priority/score, student identity, assignment, location, time, description, support count, messages, deadlines, and resolution feedback.

**Actions:**

- Search text.
- Apply status/priority filters.
- Toggle support/upvote locally.
- Open complaint timeline.
- Start a new complaint.

### Submit complaint

**Screen name:** Report Campus Issue

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/submit_complaint_screen.dart`

**User role:** Student.

**Purpose:** Create a campus complaint.

**Layout structure:**

- Back control and page heading.
- Centered constrained form card.
- Department and category selectors.
- Title, description, and location fields.
- Urgency control and attachment-related form controls in the remainder of the file.
- Live estimated priority/confidence presentation.
- Submit button with loading state.

**Navigation:**

- Entered from the dashboard, complaints list, or sidebar.
- Back returns to the student dashboard.
- Successful fake submission returns to `/student/complaints`.

**Data displayed:**

- Hardcoded complaint categories and department options.
- Estimated priority and confidence are calculated locally from keywords.

**Actions:**

- Enter title, description, and location.
- Select category and department.
- Mark urgent.
- Submit after validation.
- Display success/error snackbars.

**Mock/demo status:** The submit call is a delayed local action; no backend request is made. The keyword classifier is a demo approximation, not the backend ML contract.

### Complaint timeline/details

**Screen name:** Complaint Timeline

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/complaint_timeline_screen.dart`

**User role:** Student, with ticket conversation content that may include system and supervisor messages.

**Purpose:** Inspect one complaint's status, timeline, resolution, and discussion.

**Layout structure:**

- Back control with complaint ID and title.
- Status stepper/progress bar.
- Detail card with status badge, priority badge, creation time, description, location, and department.
- Conditional resolved section with resolution notes and satisfaction chips.
- Message/timeline area with avatars, sender roles, timestamps, and message content.
- Comment composer for adding a message.

**Navigation:**

- Entered from complaint cards using `/student/complaint/:id`.
- Back returns to `/student/complaints`.

**Data displayed:**

- Selected ticket from `MockData.complaints`; unknown IDs fall back to the first mock complaint.
- Status, priority, description, location, department, resolution information, and message history.

**Actions:**

- Add a comment locally.
- Choose satisfied/not satisfied for resolved complaints.
- Navigate back to complaints.

**Mock/demo status:** Mutations remain in memory and are not persisted.

### Lost and found gallery

**Screen name:** Campus Lost & Found Hub

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/lost_found_gallery_screen.dart`

**User role:** Student.

**Purpose:** Browse, search, and filter lost/found items.

**Layout structure:**

- Header with Report Item action.
- Search field.
- All Items/Lost/Found segmented filter.
- Horizontal category chips: All, Electronics, Documents/ID, Keys & Wallet, Bags & Clothes, Accessories, Others.
- Responsive grid of image-oriented item cards.
- Empty state for no matches.

**Navigation:**

- Entered from student dashboard or sidebar at `/student/lost-found`.
- Item cards open `/student/lost-found/:id`.

**Data displayed:**

- `MockData.lostItems` with item type, title, category, location, time, description, image URL, status, and contact information.

**Actions:**

- Search by item title/location.
- Filter by lost/found.
- Filter by category.
- Report Item button exists but has no implemented behavior in the inspected code.
- Open item details.

### Lost/found item details

**Screen name:** Lost and Found Item Details

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/item_details_screen.dart`

**User role:** Student.

**Purpose:** Show a single lost/found item and provide a claim/contact action.

**Layout structure:**

- Back to Gallery control.
- Large bordered detail card.
- Hero image area with fallback icon.
- Lost/found badge, category, and relative time.
- Title and location.
- Description section.
- Contact information card with avatar, name, email, and phone.
- Full-width claim/found-it CTA.

**Navigation:**

- Entered from a gallery card using `/student/lost-found/:id`.
- Back returns to `/student/lost-found`.

**Data displayed:**

- Selected item from `MockData.lostItems`; unknown IDs fall back to the first item.
- Network image URLs are hardcoded in mock data.

**Actions:**

- Return to gallery.
- Send a claim request or report that the student found the item; current action only displays a snackbar.

### Campus feed

**Screen name:** Campus Feed & Announcements

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/campus_feed_screen.dart`

**User role:** Student.

**Purpose:** Browse official campus updates, announcements, event broadcasts, and news.

**Layout structure:**

- Constrained single-column feed.
- Header and Official Channel badge.
- Horizontal category chips: All Updates, Official Announcements, Events & Hackathons, Academic Timetables, Club Activities.
- Vertically stacked social/feed cards.
- Feed cards contain author avatar, author identity/role/time, title, content, optional event attachment, and interaction content in the remainder of the file.

**Navigation:**

- Entered from the student sidebar at `/student/feed`.
- No separate post-details route was observed.

**Data displayed:**

- `MockData.feedPosts`.
- Official author flags and event attachment fields are mock model data.

**Actions:**

- Select a feed category.
- Any post-specific actions should be verified in the remainder of the file; no separate route is registered.

### Academic forums

**Screen name:** Academic Discussion Forums

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/academic_forums_screen.dart`

**User role:** Student.

**Purpose:** Browse peer questions, exam tips, and TA-verified discussions.

**Layout structure:**

- Constrained single-column page.
- Header with New Question action.
- Department filter chips: All, Computer Science, Electronics, Mechanical, Civil, Mathematics & Basic Sciences.
- Thread cards with department tag, optional TA Answered badge, timestamp, title, excerpt, author identity, reply count, and view count.

**Navigation:**

- Entered from the student sidebar at `/student/forums`.
- New Question has no implemented route/action in the inspected code.

**Data displayed:**

- `MockData.forumThreads`.

**Actions:**

- Filter by department.
- New Question button exists but has no implemented behavior.

### Events and digital pass

**Screen name:** Events & Digital Pass

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/student/event_details_screen.dart`

**User role:** Student.

**Purpose:** Browse event cards and inspect/register for the featured event.

**Layout structure:**

- Horizontal event-card list near the top.
- Featured event hero image with category and title overlay.
- Metadata chips for date, time, location, and tag.
- Registration card with registered/capacity counts, percentage progress, and CTA.
- Event description.
- Optional agenda list.
- Optional speaker list.

**Navigation:**

- Entered from the student sidebar at `/student/events`.
- No separate event-detail route was observed; this screen itself presents the featured event.

**Data displayed:**

- Featured event is `MockData.events.first`.
- Event list is `MockData.events`.
- Network image URLs and event values are mock data.

**Actions:**

- Select an event card visually; the featured event remains based on the first mock item in the inspected code.
- Toggle registration locally.
- After registration, show a digital-pass-oriented label; no backend registration request is observed.

## SUPERVISOR

### Supervisor dashboard

**Screen name:** Supervisor Overview

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/supervisor/supervisor_dashboard_screen.dart`

**User role:** Supervisor.

**Purpose:** Surface complaint workload, critical tickets, and supervisor team load.

**Layout structure:**

- Welcome banner with pending count.
- Three statistic cards: Pending, In Progress, Critical.
- Critical Tickets section with View All Queue link.
- Compact ticket cards with status and priority badges.
- Team Workload section with supervisor rows, avatars, status, department, and progress bars.

**Navigation:**

- Entered at `/supervisor/dashboard` after supervisor login.
- View All Queue goes to `/supervisor/queue`.
- Selecting a ticket sets `AppState.selectedComplaintId` and opens `/supervisor/workspace`.

**Data displayed:**

- Counts and lists derived from `MockData.complaints` and `MockData.supervisors`.
- ML priority and workload values are mock/demo data.

**Actions:**

- Open full task queue.
- Open a ticket workspace.

### Supervisor task queue

**Screen name:** Task Queue

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/supervisor/supervisor_task_queue_screen.dart`

**User role:** Supervisor.

**Purpose:** View assigned complaints ordered by ML priority or status.

**Layout structure:**

- Header with ticket count and sort dropdown.
- Sort options: By Priority and By Status.
- Scrollable queue cards.
- Each card shows ML score circle, ID, title, department, status, timestamp, description, priority, category, and assignee.
- Critical tickets receive a stronger border treatment.

**Navigation:**

- Entered from supervisor dashboard/sidebar at `/supervisor/queue`.
- Selecting a queue card opens `/supervisor/workspace` after storing the selected complaint ID.

**Data displayed:**

- `MockData.complaints`, locally sorted.

**Actions:**

- Change sort order.
- Select complaint to open workspace.

### Complaint workspace

**Screen name:** Complaint Workspace

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/supervisor/complaint_workspace_screen.dart`

**User role:** Supervisor.

**Purpose:** Review complaint details, update status, and exchange public/internal messages.

**Layout structure:**

- Wide screens: split view with approximately 300px ticket-info panel and expanded message panel.
- Narrow screens: two-tab layout with Details and Messages.
- Details panel includes ticket identity, status/priority badges, ML score card, category, department, assignee, creation time, description, status radio list, and Save Changes CTA.
- Message panel contains existing messages and a reply composer.
- Internal-note toggle is present.

**Navigation:**

- Entered from dashboard or task queue at `/supervisor/workspace`.
- Selected complaint is read from `AppState.selectedComplaintId`.

**Data displayed:**

- Selected complaint from `MockData.complaints`; falls back to the first item if no selection exists.
- ML score, status, messages, assignment, and ticket metadata.

**Actions:**

- Select a new status.
- Save Changes button exists.
- Toggle internal note mode.
- Reply to the ticket.

**Mock/demo status:** Persistence and actual assignment/status APIs were not observed in the inspected portion; verify the remainder before treating any action as a backend contract.

## ORGANIZATION ADMIN

### Admin dashboard

**Screen name:** Campus Overview

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/admin/admin_dashboard_screen.dart`

**User role:** Organization admin.

**Purpose:** Show organization-wide complaint and supervisor metrics.

**Layout structure:**

- Overview heading and supporting description.
- Responsive stats grid: Total Tickets, Critical, Supervisors, Resolved.
- Quick Actions row: Complaint Management, Supervisor Roster, Audit Logs.
- Recent Tickets list.
- Supervisor Load section with avatars, departments, progress bars, and percentages.

**Navigation:**

- Entered at `/admin/dashboard` after admin login.
- Quick actions navigate to `/admin/complaints`, `/admin/roster`, and `/admin/audit`.

**Data displayed:**

- Counts from `MockData.complaints` and `MockData.supervisors`.
- Recent ticket and supervisor data are mock/demo values.

**Actions:**

- Open complaint management.
- Open supervisor roster.
- Open audit logs.

### Complaint management

**Screen name:** Complaint Management

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/admin/admin_complaint_management_screen.dart`

**User role:** Organization admin.

**Purpose:** Search and filter all complaints at organization level.

**Layout structure:**

- Header with total count.
- Search field.
- Horizontal chips: All, Pending, In Progress, Critical, Escalated.
- Scrollable complaint rows/cards.
- Each row shows ID, status, priority, title, description excerpt, department, assignee, and ML score pill.

**Navigation:**

- Entered from admin dashboard/sidebar at `/admin/complaints`.
- No complaint-detail route is registered from this admin list.

**Data displayed:**

- `MockData.complaints`, filtered locally.

**Actions:**

- Search by title.
- Filter by status or priority.
- No backend mutation action is visible in the inspected file.

### Supervisor roster

**Screen name:** Supervisor Roster

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/admin/supervisor_roster_screen.dart`

**User role:** Organization admin.

**Purpose:** Review supervisor availability and workload.

**Layout structure:**

- Header with supervisor count and Add button.
- List of supervisor profile cards.
- Avatar with online/overloaded/on-leave status dot.
- Name, department, status badge.
- Stats: total complaints, average response, workload.
- Workload capacity progress bar.
- Message and Assign Ticket buttons.
- Overflow menu button.

**Navigation:**

- Entered from admin dashboard/sidebar at `/admin/roster`.
- Add, Message, Assign Ticket, and overflow actions have no observed backend implementation in the inspected code.

**Data displayed:**

- `MockData.supervisors` with hardcoded names, departments, statuses, counts, percentages, and remote avatar URLs.

### Security audit logs

**Screen name:** Security Audit Logs

**File path:** `D:/Major_Project/campus_hive/frontend/campushive_flutter/lib/features/admin/security_audit_logs_screen.dart`

**User role:** Organization admin.

**Purpose:** Search and filter security/audit events.

**Layout structure:**

- Header with logged-event count.
- Search field for actor or action.
- Severity filters: all, HIGH, MED, LOW.
- Scrollable audit log tiles.
- Empty state when filters produce no results.
- Tiles show severity, action, actor, timestamp, and detailed metadata in the remainder of the file.

**Navigation:**

- Entered from admin dashboard/sidebar at `/admin/audit`.
- No separate audit detail route was observed.

**Data displayed:**

- `MockData.auditLogs` with actor, role, email, severity, timestamp, IP, device, location, details, and JSON payload.

**Actions:**

- Search by actor/action.
- Filter by severity.

## NOT IMPLEMENTED AS ROUTED SCREENS

The following are not actual screens in the inspected teammate router, despite being common product areas or appearing in the broader project setup request:

- Student profile.
- Supervisor profile.
- Organization-admin profile.
- Dedicated notifications screen.
- Dedicated announcements management screen.
- Dedicated users management screen.
- Separate event list/detail route beyond `/student/events`.
- Forum thread detail route.
- Feed post detail route.
- Admin complaint detail route.
- Student bottom-navigation destinations beyond what the shell maps in its mobile navigation.

Notifications are represented by a shared-shell bottom sheet. Profile information is represented by the shared-shell popup/sidebar card.

## NAVIGATION MAP

Observed router flow:

```text
Splash (/splash)
  |
  v
Landing (/landing)
  |-- Login (/login or /login?demo=student|supervisor|admin)
  |     |-- Student Dashboard (/student/dashboard)
  |     |-- Supervisor Dashboard (/supervisor/dashboard)
  |     `-- Admin Dashboard (/admin/dashboard)
  |
  `-- Register (/register)
        |-- Student Dashboard (/student/dashboard)
        |-- Supervisor Dashboard (/supervisor/dashboard)
        `-- Admin Dashboard (/admin/dashboard)

Authenticated shared shell (MainScaffold)
  |
  |-- STUDENT
  |     |-- Dashboard (/student/dashboard)
  |     |     |-- Submit Complaint (/student/submit-complaint)
  |     |     `-- Lost & Found (/student/lost-found)
  |     |-- Active Complaints (/student/complaints)
  |     |     |-- Complaint Timeline (/student/complaint/:id)
  |     |     `-- Submit Complaint (/student/submit-complaint)
  |     |-- Lost & Found (/student/lost-found)
  |     |     `-- Item Details (/student/lost-found/:id)
  |     |-- Campus Feed (/student/feed)
  |     |-- Academic Forums (/student/forums)
  |     `-- Events & Digital Pass (/student/events)
  |
  |-- SUPERVISOR
  |     |-- Dashboard (/supervisor/dashboard)
  |     |     |-- Task Queue (/supervisor/queue)
  |     |     `-- Complaint Workspace (/supervisor/workspace)
  |     |-- Task Queue (/supervisor/queue)
  |     |     `-- Complaint Workspace (/supervisor/workspace)
  |     `-- Complaint Workspace (/supervisor/workspace)
  |
  `-- ADMIN
        |-- Campus Overview (/admin/dashboard)
        |     |-- Complaint Management (/admin/complaints)
        |     |-- Supervisor Roster (/admin/roster)
        |     `-- Security Audit Logs (/admin/audit)
        |-- Complaint Management (/admin/complaints)
        |-- Supervisor Roster (/admin/roster)
        `-- Security Audit Logs (/admin/audit)

Any authenticated shell
  |-- Notification bell -> bottom-sheet modal
  |-- Profile popup -> identity details / sign out
  |-- Role switcher -> another role's home path (demo behavior)
  `-- Sign out -> Landing (/landing)
```

## REUSABLE UI PATTERNS

### App bars and shell navigation

- Shared `MainScaffold` app bar is approximately 66px high.
- Desktop uses brand + online status on the left and role/profile controls on the right.
- Mobile replaces desktop branding/sidebar access with a menu button and bottom navigation.
- Shell content is role-aware and sidebar labels change by role.

### Profile identity blocks

- Sidebar profile card: initials avatar, name, ID/USN, role badge.
- App-bar popup: name, ID/email, role, department, and sign-out.
- Supervisor roster cards: network avatar, status dot, department, workload.

### Cards

- Most cards are white/light surfaces with rounded corners, thin borders, and subtle shadows or no shadow.
- Complaint cards combine compact metadata rows, status/priority badges, title, description, and actions.
- Dashboard stat cards use an icon, large metric, label, and semantic color.
- Feed/forum cards use an author header followed by title/content and metadata.
- Image-heavy cards are used for lost/found and events.

### Complaint patterns

- Status badge and priority badge appear together repeatedly.
- Complaint filters use search plus horizontal chips.
- ML priority is visualized as a score, priority badge, confidence text, or gradient pill.
- Complaint detail uses a status stepper, metadata fields, description, message timeline, and feedback.
- Supervisor workspace changes from split pane on desktop to Details/Messages tabs on narrow screens.

### Event and media patterns

- Event cards use image backgrounds, rounded clipping, category overlays, and title overlays.
- Event details use horizontal discovery cards followed by a featured image, metadata chips, progress, and registration CTA.
- Lost/found uses a responsive image grid and a full-width hero image on detail.

### Filters and search

- Search fields generally include a leading search icon.
- Filters are horizontal, scrollable chips or segmented controls.
- Complaint filters combine status and priority.
- Lost/found combines type toggle and category chips.
- Audit logs combine severity chips and text search.

### Forms

- Auth and complaint creation use centered, constrained forms.
- Inputs are rounded and filled, with visible validation and loading states.
- Registration uses tabs for role selection and dropdowns for department/organization.
- Complaint form updates estimated priority while text is entered.

### Buttons and actions

- Filled accent buttons for primary actions.
- Outlined buttons for secondary actions.
- Text buttons for low-emphasis navigation.
- Frequent icon-plus-label actions: report, add, register, assign, message, save, claim.
- Several visible buttons are placeholders with empty callbacks; these should not be treated as implemented workflows.

### Empty, loading, and feedback states

- Empty states use a centered icon, message, and sometimes no action.
- Forms show loading by replacing or disabling the submit action.
- Success/error feedback commonly uses `SnackBar`.
- Screen entry uses fade/slide/scale animations from `flutter_animate`.

### Dialogs and bottom sheets

- Notifications use a bottom sheet with a title, Clear all text action, and notification rows.
- Profile uses a popup menu.
- No broad modal/dialog workflow was confirmed beyond these shell patterns in the inspected files.

## MOCK, DEMO, AND PLACEHOLDER CONTENT

Treat all of the following as non-authoritative:

- `core/data/mock_data.dart` supplies complaints, supervisors, audit logs, lost items, feed posts, forum threads, and events.
- Hardcoded identities such as Arjun Mehta, Priya Sharma, and Dr. Rajan Verma.
- Demo login credentials and role inference from email text.
- In-memory `AppState` authentication, selected IDs, role switching, and logout.
- Delayed fake login, registration, and complaint submission.
- Local keyword-based ML priority estimation in the complaint form.
- Static department and organization lists.
- Static semester label and notification text.
- Static ML scores, complaint counts, supervisor workloads, audit records, event capacities, and forum counts.
- Unsplash/network avatar and item/event images.
- Empty callbacks for Report Item, New Question, Add supervisor, Message, Assign Ticket, overflow actions, and some registration/detail actions.
- Fallback behavior that silently displays the first mock complaint/item when an unknown route ID is supplied.

These values describe demo presentation, not required production seed data, validation rules, or API responses.

## BACKEND-RELEVANT UI INFORMATION

The teammate UI suggests the following information categories that the new app may need to request from the Flask backend. These are UI observations only and must be reconciled with the backend schema and routes before implementation.

### Identity and roles

- Display name, email, initials/avatar.
- Role: student, supervisor, organization admin.
- Backend role key shown by the demo provider: `STUDENT`, `SUPERVISOR`, `ORG_ADMIN`.
- Student identifier shown as USN; staff identifiers shown as employee IDs.
- Organization and department labels.

### Complaints

UI displays or edits:

- Complaint ID.
- Title and description.
- Category and department.
- Status: pending, in progress, resolved, escalated, and other enum values used by the local model.
- ML priority and score/confidence.
- Final priority/priority badge.
- Student name and USN.
- Assigned supervisor/team.
- Location and relative/created timestamps.
- Support/upvote count and whether the current user supported it.
- Deadline, resolved timestamp, resolution notes, and student feedback.
- Message timeline with sender name, sender role/avatar, timestamp, content, and internal-note flag.

Potential UI operations:

- List/search/filter complaints.
- Create complaint.
- View complaint detail/timeline.
- Support/upvote.
- Add comment/message.
- Supervisor status update and assignment/workspace actions.
- Admin-level filtering and oversight.

### Lost and found

UI displays or implies:

- Item ID, lost/found type, title, category, location, time, description, image URL, status.
- Contact name, email, and phone.
- Claim/found-it action.
- Search, type filtering, category filtering, and item detail.

### Events

UI displays or implies:

- Event title, image, category/tag, date, time, location.
- Registration count, capacity, percentage full.
- Description, agenda, speakers.
- Registration toggle and possible digital pass state.

### Feed and forums

UI displays or implies:

- Feed author name, role, avatar, official flag, time, title, content.
- Optional event attachment data: date, location, attendees, capacity.
- Forum department, title, content, author, role, timestamp, TA-answered state, replies, and views.

### Supervisor administration

UI displays or implies:

- Supervisor ID, name, department, avatar, availability status.
- Complaint count, average response hours, workload percentage.
- Assignment/message actions.

### Audit logs

UI displays or implies:

- Audit event ID, action title, actor name/role/email.
- Severity, timestamp, IP address, device, location context.
- Human-readable details and structured JSON payload.
- Search and severity filtering.

### Backend integration cautions

- The teammate frontend's `core/data/mock_data.dart` and local model fields are presentation references only.
- The new app must use the existing Flask backend and database schema as the contract.
- Do not copy demo IDs, names, email addresses, image URLs, enum assumptions, ML values, or fake credentials into production code.
- Confirm exact endpoint names, authentication method, pagination/filter syntax, status values, role values, and response shapes against the Flask backend before implementing services or providers.
- The teammate app contains no verified backend service layer under the inspected `lib` tree; observed local actions are not evidence of working API integration.

## Reference Takeaways for the New App

- Preserve the useful information hierarchy: role dashboard -> filtered lists -> detail/workspace.
- Preserve responsive behavior: desktop sidebar/split views and mobile drawer/tabs/bottom navigation.
- Preserve repeated patterns: compact metadata, semantic badges, search/filter controls, image-first cards, progress indicators, and explicit empty/loading states.
- Do not preserve the teammate's dark/glow/gradient-heavy visual treatment; the new app's separate light design system intentionally defines a different visual language.
- Treat every data shape in this document as a UI observation pending verification against the Flask backend.
