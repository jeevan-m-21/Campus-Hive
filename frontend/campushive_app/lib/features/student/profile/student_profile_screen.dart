import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../providers/auth_provider.dart';
import '../student_activity_metrics.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final user = session?.user ?? const <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: AppDimensions.spacingLarge),
            const _ProfileDetails(),
            const SizedBox(height: AppDimensions.spacingLarge),
            const Text('Your activity', style: AppTextStyles.headingSmall),
            const SizedBox(height: AppDimensions.spacingSmall),
            const StudentActivityMetrics(),
            const SizedBox(height: AppDimensions.spacingLarge),
            _ProfileActions(user: user),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _value(user['profile_image']);
    final fullName = _value(user['full_name']);
    final identifier = _value(user['usn_or_employee_id']);
    final email = _value(user['email']);

    return AppCard(
      child: Row(
        children: [
          imageUrl.isEmpty
              ? const CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.divider,
                  child: Icon(
                    Icons.person_outline,
                    size: 34,
                    color: AppColors.textSecondary,
                  ),
                )
              : CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.divider,
                  backgroundImage: NetworkImage(imageUrl),
                ),
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'CampusHive student' : fullName,
                  style: AppTextStyles.headingMedium,
                ),
                if (identifier.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(identifier, style: AppTextStyles.label),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(email, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails();

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthProvider>().session?.user ??
        const <String, dynamic>{};
    final details = <_DetailData>[
      _DetailData('Full name', user['full_name']),
      _DetailData('USN / Employee ID', user['usn_or_employee_id']),
      _DetailData('Email', user['email']),
      _DetailData('Phone', user['phone']),
      _DetailData('Department ID', user['department_id']),
      _DetailData('Organization ID', user['organization_id']),
    ].where((detail) => _value(detail.value).isNotEmpty).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profile details', style: AppTextStyles.headingSmall),
          const SizedBox(height: AppDimensions.spacingSmall),
          for (final detail in details) ...[
            _DetailRow(detail: detail),
            if (detail != details.last)
              const Divider(height: AppDimensions.spacingMedium),
          ],
        ],
      ),
    );
  }
}

class _DetailData {
  const _DetailData(this.label, this.value);

  final String label;
  final Object? value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.detail});

  final _DetailData detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(detail.label, style: AppTextStyles.bodySmall)),
        const SizedBox(width: AppDimensions.spacingMedium),
        Flexible(
          child: Text(
            _value(detail.value),
            textAlign: TextAlign.end,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: 'Edit Profile',
          icon: Icons.edit_outlined,
          variant: AppButtonVariant.outlined,
          expand: true,
          onPressed: () => _showEditProfile(context),
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        AppButton(
          label: 'Change Password',
          icon: Icons.lock_outline,
          variant: AppButtonVariant.outlined,
          expand: true,
          onPressed: () => _showChangePassword(context),
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        AppButton(
          label: 'Log out',
          icon: Icons.logout_outlined,
          variant: AppButtonVariant.outlined,
          expand: true,
          onPressed: () async {
            await context.read<AuthProvider>().signOut();
            if (context.mounted) context.go(AppRoutes.login);
          },
        ),
      ],
    );
  }

  Future<void> _showEditProfile(BuildContext context) async {
    final nameController = TextEditingController(
      text: _value(user['full_name']),
    );
    final phoneController = TextEditingController(text: _value(user['phone']));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: nameController,
              label: 'Full name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            AppTextField(
              controller: phoneController,
              label: 'Phone',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile editing is not available yet.'),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _showChangePassword(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: currentController,
                label: 'Current password',
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                validator: _requiredPassword,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              AppTextField(
                controller: newController,
                label: 'New password',
                obscureText: true,
                prefixIcon: Icons.lock_reset_outlined,
                validator: _newPasswordValidator,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              AppTextField(
                controller: confirmController,
                label: 'Confirm new password',
                obscureText: true,
                prefixIcon: Icons.lock_reset_outlined,
                validator: (value) {
                  if (_requiredPassword(value) != null) {
                    return 'Confirm your new password';
                  }
                  return value == newController.text
                      ? null
                      : 'Passwords do not match';
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final firebaseUser = FirebaseAuth.instance.currentUser;
                final email = firebaseUser?.email;
                if (firebaseUser == null || email == null) {
                  throw FirebaseAuthException(code: 'user-not-found');
                }
                final credential = EmailAuthProvider.credential(
                  email: email,
                  password: currentController.text,
                );
                await firebaseUser.reauthenticateWithCredential(credential);
                await firebaseUser.updatePassword(newController.text);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully.'),
                    ),
                  );
                }
              } on FirebaseAuthException catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(_passwordError(error.code))),
                  );
                }
              }
            },
            child: const Text('Update password'),
          ),
        ],
      ),
    );
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  String _passwordError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your password.';
      default:
        return 'Unable to change password right now.';
    }
  }

  String? _requiredPassword(String? value) =>
      value == null || value.isEmpty ? 'Password is required' : null;

  String? _newPasswordValidator(String? value) {
    if (_requiredPassword(value) != null) return 'New password is required';
    return value!.length < 6 ? 'Use at least 6 characters' : null;
  }
}

String _value(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? '' : text;
}
