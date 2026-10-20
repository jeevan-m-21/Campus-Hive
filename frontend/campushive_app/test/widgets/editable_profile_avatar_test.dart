import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/core/widgets/editable_profile_avatar.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';

class FakeImagePicker extends ImagePicker {
  FakeImagePicker({this.pickedFile, this.shouldThrow = false});

  final XFile? pickedFile;
  final bool shouldThrow;
  int pickImageCallCount = 0;
  ImageSource? lastSource;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickImageCallCount++;
    lastSource = source;
    if (shouldThrow) {
      throw PlatformException(
        code: 'camera_access_denied',
        message: 'Camera permission denied.',
      );
    }
    return pickedFile;
  }
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  MockAuthProvider({Map<String, dynamic>? initialUser})
      : _session = initialUser != null
            ? AuthSession(user: initialUser, role: initialUser['role'] ?? 'STUDENT')
            : null;

  AuthSession? _session;
  int uploadCallCount = 0;
  String? lastUploadedPath;
  bool shouldFailUpload = false;
  bool _isLoading = false;

  @override
  AuthSession? get session => _session;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isAuthenticated => _session != null;

  @override
  bool get isInitialized => true;

  @override
  String? get restoreError => null;

  @override
  Future<AuthSession> uploadProfileImage(String filePath) async {
    uploadCallCount++;
    lastUploadedPath = filePath;
    if (shouldFailUpload) {
      throw const AuthException('Upload failed from backend.');
    }
    final updated = Map<String, dynamic>.from(_session?.user ?? {});
    updated['profile_image'] = '/uploads/profile/updated_mock.png';
    _session = AuthSession(user: updated, role: 'STUDENT');
    notifyListeners();
    return _session!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget buildTestWidget({
    required Widget child,
    required MockAuthProvider authProvider,
  }) {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  testWidgets('EditableProfileAvatar displays fallback icon when imageUrl is empty', (tester) async {
    final mockAuth = MockAuthProvider(
      initialUser: {'full_name': 'Jeevan', 'profile_image': ''},
    );

    await tester.pumpWidget(
      buildTestWidget(
        authProvider: mockAuth,
        child: const EditableProfileAvatar(
          imageUrl: '',
          fallbackIcon: Icons.person_outline,
        ),
      ),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget); // camera badge
  });

  testWidgets('Tapping avatar opens image source picker with Gallery and Camera options', (tester) async {
    final mockAuth = MockAuthProvider(
      initialUser: {'full_name': 'Jeevan', 'profile_image': ''},
    );
    final fakePicker = FakeImagePicker(pickedFile: null);

    await tester.pumpWidget(
      buildTestWidget(
        authProvider: mockAuth,
        child: EditableProfileAvatar(
          imageUrl: '',
          imagePicker: fakePicker,
        ),
      ),
    );

    await tester.tap(find.byType(EditableProfileAvatar));
    await tester.pumpAndSettle();

    expect(find.text('Change Profile Picture'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
    expect(find.text('Take a Photo'), findsOneWidget);
  });

  testWidgets('Selecting Gallery calls image picker and triggers uploadProfileImage', (tester) async {
    final mockAuth = MockAuthProvider(
      initialUser: {'full_name': 'Jeevan', 'profile_image': ''},
    );
    final fakePicker = FakeImagePicker(
      pickedFile: XFile('/mock/storage/avatar.jpg'),
    );

    await tester.pumpWidget(
      buildTestWidget(
        authProvider: mockAuth,
        child: EditableProfileAvatar(
          imageUrl: '',
          imagePicker: fakePicker,
        ),
      ),
    );

    // Tap avatar to open bottom sheet
    await tester.tap(find.byType(EditableProfileAvatar));
    await tester.pumpAndSettle();

    // Select Choose from Gallery
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();

    expect(fakePicker.pickImageCallCount, 1);
    expect(fakePicker.lastSource, ImageSource.gallery);
    expect(mockAuth.uploadCallCount, 1);
    expect(mockAuth.lastUploadedPath, '/mock/storage/avatar.jpg');
    expect(find.text('Profile picture updated successfully.'), findsOneWidget);
  });

  testWidgets('When picker is cancelled, no upload is made and no error shown', (tester) async {
    final mockAuth = MockAuthProvider(
      initialUser: {'full_name': 'Jeevan', 'profile_image': ''},
    );
    final fakePicker = FakeImagePicker(pickedFile: null); // cancelled

    await tester.pumpWidget(
      buildTestWidget(
        authProvider: mockAuth,
        child: EditableProfileAvatar(
          imageUrl: '',
          imagePicker: fakePicker,
        ),
      ),
    );

    await tester.tap(find.byType(EditableProfileAvatar));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take a Photo'));
    await tester.pumpAndSettle();

    expect(fakePicker.pickImageCallCount, 1);
    expect(fakePicker.lastSource, ImageSource.camera);
    expect(mockAuth.uploadCallCount, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('When upload fails, error SnackBar is displayed', (tester) async {
    final mockAuth = MockAuthProvider(
      initialUser: {'full_name': 'Jeevan', 'profile_image': ''},
    )..shouldFailUpload = true;

    final fakePicker = FakeImagePicker(
      pickedFile: XFile('/mock/storage/avatar.jpg'),
    );

    await tester.pumpWidget(
      buildTestWidget(
        authProvider: mockAuth,
        child: EditableProfileAvatar(
          imageUrl: '',
          imagePicker: fakePicker,
        ),
      ),
    );

    await tester.tap(find.byType(EditableProfileAvatar));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();

    expect(mockAuth.uploadCallCount, 1);
    expect(find.text('Upload failed from backend.'), findsOneWidget);
  });
}
