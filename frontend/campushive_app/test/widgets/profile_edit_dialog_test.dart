import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/core/widgets/app_button.dart';
import 'package:campushive_app/features/student/profile/student_profile_screen.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';

class MockAuthProviderForProfile extends ChangeNotifier implements AuthProvider {
  MockAuthProviderForProfile({required Map<String, dynamic> initialUser})
      : _session = AuthSession(user: Map<String, dynamic>.from(initialUser), role: 'STUDENT');

  AuthSession? _session;
  int updateProfileCallCount = 0;
  String? lastUpdatedName;
  String? lastUpdatedPhone;
  bool shouldThrow = false;
  String errorMessage = 'Failed to update profile';

  @override
  AuthSession? get session => _session;

  @override
  bool get isLoading => false;

  @override
  bool get isRestoring => false;

  @override
  bool get isInitialized => true;

  @override
  String? get restoreError => null;

  @override
  Future<AuthSession> updateProfile({
    String? fullName,
    String? phone,
    String? profileImage,
  }) async {
    updateProfileCallCount++;
    lastUpdatedName = fullName;
    lastUpdatedPhone = phone;

    if (shouldThrow) {
      throw AuthException(errorMessage);
    }

    final updatedMap = Map<String, dynamic>.from(_session!.user);
    if (fullName != null) updatedMap['full_name'] = fullName;
    if (phone != null) updatedMap['phone'] = phone;
    _session = AuthSession(user: updatedMap, role: _session!.role);
    notifyListeners();
    return _session!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget createProfileTestApp(MockAuthProviderForProfile authProvider) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: const MaterialApp(
        home: StudentProfileScreen(),
      ),
    );
  }

  setUp(() {});

  testWidgets('Edit Profile dialog opens with pre-populated name and phone', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockAuth = MockAuthProviderForProfile(
      initialUser: {
        'user_id': 101,
        'full_name': 'Original Student',
        'phone': '9876543210',
        'email': 'student@ksit.edu.in',
        'usn_or_employee_id': '1KS20CS001',
        'role': 'STUDENT',
        'organization_id': 1,
      },
    );

    await tester.pumpWidget(createProfileTestApp(mockAuth));
    await tester.pumpAndSettle();

    expect(find.text('Original Student'), findsWidgets);

    // Tap "Edit Profile" button on the screen
    final editProfileButton = find.widgetWithText(AppButton, 'Edit Profile');
    await tester.ensureVisible(editProfileButton);
    await tester.tap(editProfileButton);
    await tester.pumpAndSettle();

    // Verify dialog is open
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Edit Profile')),
      findsOneWidget,
    );
    expect(find.text('Original Student'), findsWidgets);
    expect(find.text('9876543210'), findsWidgets);
  });

  testWidgets('Saving updated profile calls updateProfile and updates UI immediately', (tester) async {
    final mockAuth = MockAuthProviderForProfile(
      initialUser: {
        'user_id': 101,
        'full_name': 'Original Student',
        'phone': '9876543210',
        'email': 'student@ksit.edu.in',
        'role': 'STUDENT',
      },
    );

    await tester.pumpWidget(createProfileTestApp(mockAuth));
    await tester.pumpAndSettle();

    final editProfileButton = find.widgetWithText(AppButton, 'Edit Profile');
    await tester.ensureVisible(editProfileButton);
    await tester.tap(editProfileButton);
    await tester.pumpAndSettle();

    // Enter new name and phone inside dialog
    final nameField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextFormField, 'Full name'),
    );
    final phoneField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextFormField, 'Phone'),
    );

    await tester.enterText(nameField, 'Jeevan Corrected');
    await tester.enterText(phoneField, '9998887776');
    await tester.pumpAndSettle();

    // Tap Save
    final saveButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(mockAuth.updateProfileCallCount, 1);
    expect(mockAuth.lastUpdatedName, 'Jeevan Corrected');
    expect(mockAuth.lastUpdatedPhone, '9998887776');

    // Dialog dismissed and success SnackBar shown
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Profile updated successfully.'), findsOneWidget);

    // Profile screen immediately displays the updated name
    expect(find.text('Jeevan Corrected'), findsWidgets);
  });

  testWidgets('Validation error is shown when name is empty', (tester) async {
    final mockAuth = MockAuthProviderForProfile(
      initialUser: {
        'user_id': 101,
        'full_name': 'Original Student',
        'phone': '9876543210',
        'role': 'STUDENT',
      },
    );

    await tester.pumpWidget(createProfileTestApp(mockAuth));
    await tester.pumpAndSettle();

    final editProfileButton = find.widgetWithText(AppButton, 'Edit Profile');
    await tester.ensureVisible(editProfileButton);
    await tester.tap(editProfileButton);
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextFormField, 'Full name'),
    );
    await tester.enterText(nameField, '   ');
    await tester.pumpAndSettle();

    final saveButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Full name is required'), findsOneWidget);
    expect(mockAuth.updateProfileCallCount, 0);
  });

  testWidgets('Error message banner is displayed on API failure', (tester) async {
    final mockAuth = MockAuthProviderForProfile(
      initialUser: {
        'user_id': 101,
        'full_name': 'Original Student',
        'phone': '9876543210',
        'role': 'STUDENT',
      },
    );
    mockAuth.shouldThrow = true;
    mockAuth.errorMessage = 'Network error occurred while updating profile.';

    await tester.pumpWidget(createProfileTestApp(mockAuth));
    await tester.pumpAndSettle();

    final editProfileButton = find.widgetWithText(AppButton, 'Edit Profile');
    await tester.ensureVisible(editProfileButton);
    await tester.tap(editProfileButton);
    await tester.pumpAndSettle();

    final saveButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(mockAuth.updateProfileCallCount, 1);
    // Dialog should stay open and display the error message
    expect(find.text('Network error occurred while updating profile.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
