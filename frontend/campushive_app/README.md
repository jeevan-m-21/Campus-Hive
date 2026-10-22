# CampusHive Flutter Mobile Application (`campushive_app`)

CampusHive is a cross-platform mobile application built with Flutter and Dart, serving as the client interface for students, departmental supervisors, and organization administrators in higher education institutions.

---

## Architecture & Technology Stack

* **Framework**: Flutter (v3.19+, Dart v3.11+)
* **State Management**: [Provider](https://pub.dev/packages/provider) (`MultiProvider`, `ChangeNotifierProvider`)
* **Navigation**: [GoRouter](https://pub.dev/packages/go_router) with declarative route definitions and shell routes
* **Authentication**: [firebase_auth](https://pub.dev/packages/firebase_auth) paired with backend 6-digit email OTP verification
* **Push Notifications**: [firebase_messaging](https://pub.dev/packages/firebase_messaging) with deep linking
* **Secure Storage**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) for cached user profiles and tokens
* **HTTP Client**: Standard Dart `http` package with centralized interceptor logic in `ApiClient`

---

## Role-Based Architecture & Navigation

The application provides specialized shell navigation for three distinct user roles:

1. **Student Shell (`StudentShellScreen`)**:
   * Dashboard (Feed, Quick Actions, Stats)
   * Complaints (Create complaint, upvote peer issues, view details, track remarks)
   * Lost & Found (Browse catalog, report items, mark claimed)
   * Announcements (Official notices with image/PDF circular links, reactions)
   * Profile & Activity (My filed complaints, my reported items, password update)
2. **Supervisor Shell (`SupervisorShellScreen`)**:
   * Task Queue (Assigned complaints filtered by department)
   * Complaint Details (Update status to `IN_PROGRESS`/`RESOLVED`, append resolution remarks)
   * Announcements (Institutional broadcast feed)
   * Supervisor Profile
3. **Organization Admin Shell (`AdminShellScreen`)**:
   * Management Dashboard (Real-time complaint statistics and operational metrics)
   * Universal Complaint Workspace (Assign supervisors, adjust priority, update deadlines)
   * Announcements Workspace (Create broadcast notices, attach files and links)
   * Admin Profile (Account and security settings)

### Global App Header Pattern
All root screens across Student, Supervisor, and Admin shells utilize the standardized `CampusHiveAppBar`:
* **Left**: Official CampusHive branding logo (`assets/logos/campus_hive_header_logo.png`).
* **Right**: Unread notification bell with reactive badge counter, and logout confirmation dialog.
* **Screen Titles**: Displayed cleanly below the global header within the screen body.

---

## Directory Structure

```
frontend/campushive_app/
├── android/                        # Android native configuration
│   └── app/
│       ├── build.gradle            # Build configuration & signing
│       └── google-services.json    # Firebase client configuration
├── assets/
│   └── logos/                      # Official CampusHive logo assets
├── lib/
│   ├── main.dart                   # Application entrypoint
│   ├── firebase_options.dart       # FlutterFire configuration
│   ├── app/
│   │   ├── app.dart                # MaterialApp & Provider setup
│   │   └── routes.dart             # GoRouter route declarations & shell routing
│   ├── core/
│   │   ├── constants/              # AppConstants (API Base URL)
│   │   ├── network/                # ApiClient, ApiEndpoints, ApiException
│   │   ├── storage/                # FlutterSecureStorage service
│   │   ├── theme/                  # AppColors, AppTheme, typography
│   │   └── widgets/                # CampusHiveAppBar, AppButton, AppTextField, etc.
│   ├── features/                   # Feature modules by user role
│   │   ├── auth/                   # Splash, Landing, Login, Register, OTP screens
│   │   ├── student/                # Student shell, dashboard, complaints, lost & found
│   │   ├── supervisor/             # Supervisor shell, queue, complaint resolution
│   │   ├── org_admin/              # Admin shell, dashboard, complaint workspace
│   │   └── shared/                 # Shared notification screens, headers, dialogs
│   ├── models/                     # Client data transfer objects (User, Complaint, etc.)
│   ├── providers/                  # ChangeNotifiers (AuthProvider, NotificationProvider, etc.)
│   └── services/                   # Backend HTTP API and FCM integration services
└── pubspec.yaml                    # Package dependencies and asset manifests
```

---

## Getting Started

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Firebase
Ensure `frontend/campushive_app/android/app/google-services.json` is present and matches your Firebase project configuration.

### 3. Configure API Base URL
The API base URL is defined in `lib/core/constants/app_constants.dart` using Flutter's `String.fromEnvironment`:

```dart
abstract final class AppConstants {
  static const String _defaultApiBaseUrl = 'http://192.168.31.90:5000/api/v1';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
}
```

The default preserves the developer network address for local testing. You can override it at compile or run time:
* **Default local test**: `flutter run`
* **Android Emulator**: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1`
* **Custom LAN device**: `flutter run --dart-define=API_BASE_URL=http://<YOUR_LOCAL_IP>:5000/api/v1`

`ApiClient.buildUri` automatically normalizes trailing slashes and ensures the `/api/v1` prefix is attached without duplication.

### 4. Run Debug Build
```bash
flutter run
```

---

## Production Release Build

To build an optimized production APK or Android App Bundle:

```bash
# Build Release APK with custom production API URL
flutter build apk --release --dart-define=API_BASE_URL=https://api.campushive.institution.edu/api/v1

# Build Android App Bundle (for Play Store)
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.campushive.institution.edu/api/v1
```

The compiled APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.
