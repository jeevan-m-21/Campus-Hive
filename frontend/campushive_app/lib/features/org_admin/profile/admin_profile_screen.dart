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
import '../../../providers/admin_complaint_provider.dart';
import '../../../providers/announcement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../student/home/widgets/feed_card_shell.dart';
import '../widgets/admin_app_bar.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final user = session?.user ?? const <String, dynamic>{};

    return Scaffold(
      appBar: const AdminAppBar(title: 'Admin Profile'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: AppDimensions.spacingLarge),
            _ProfileDetails(user: user),
            const SizedBox(height: AppDimensions.spacingLarge),
            const Text(
              'Administrative Overview',
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            const _AdminOverviewGrid(),
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
    final role = _value(user['role']);

    return AppCard(
      child: Row(
        children: [
          imageUrl.isEmpty
              ? const CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.divider,
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 36,
                    color: AppColors.primary,
                  ),
                )
              : CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.divider,
                  backgroundImage: NetworkImage(resolveImageUrl(imageUrl)),
                ),
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fullName.isEmpty ? _formatRole(role) : fullName,
                        style: AppTextStyles.headingMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _roleBadgeLabel(role),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (identifier.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Employee ID: $identifier', style: AppTextStyles.label),
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
  const _ProfileDetails({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final orgId = user['organization_id'];
    final deptName = _value(user['academic_department_name']);
    final role = _value(user['role']);
    final isActive =
        user['is_active'] == true ||
        user['is_active'] == 1 ||
        user['is_active'] == 'true';

    final details = <_DetailData>[
      _DetailData('Full Name', user['full_name']),
      _DetailData('Employee ID', user['usn_or_employee_id']),
      _DetailData('Email', user['email']),
      _DetailData('Phone', user['phone']),
      _DetailData('Administrative Role', _formatRole(role)),
      if (orgId != null && _value(orgId).isNotEmpty)
        _DetailData('Organization ID', 'Organization #$orgId'),
      if (deptName.isNotEmpty) _DetailData('Department', deptName),
      _DetailData('Account Status', isActive ? 'Active' : 'Inactive'),
    ].where((detail) => _value(detail.value).isNotEmpty).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Information', style: AppTextStyles.headingSmall),
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
    final isStatus = detail.label == 'Account Status';
    final isRole = detail.label == 'Administrative Role';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(detail.label, style: AppTextStyles.bodySmall)),
        const SizedBox(width: AppDimensions.spacingMedium),
        Flexible(
          child: isStatus
              ? Builder(
                  builder: (context) {
                    final isActive = detail.value == 'Active';
                    final color = isActive
                        ? AppColors.success
                        : AppColors.error;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _value(detail.value),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    );
                  },
                )
              : isRole
              ? Text(
                  _value(detail.value),
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  _value(detail.value),
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

class _AdminOverviewGrid extends StatelessWidget {
  const _AdminOverviewGrid();

  @override
  Widget build(BuildContext context) {
    final complaintProvider = context.watch<AdminComplaintProvider>();
    final announcementProvider = context.watch<AnnouncementProvider>();

    final totalComplaints =
        complaintProvider.dashboardStats?.total ??
        complaintProvider.complaints.length;
    final pendingComplaints =
        complaintProvider.dashboardStats?.pending ??
        complaintProvider.complaints
            .where((c) => c.status.toUpperCase() == 'PENDING')
            .length;
    final totalAnnouncements = announcementProvider.total;
    final totalDepartments = complaintProvider.departments.length;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _OverviewStatTile(
                  label: 'Total Complaints',
                  count: totalComplaints,
                  color: AppColors.primary,
                  icon: Icons.assignment_outlined,
                  onTap: () => context.go(AppRoutes.adminComplaints),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                child: _OverviewStatTile(
                  label: 'Pending Action',
                  count: pendingComplaints,
                  color: AppColors.warning,
                  icon: Icons.pending_actions_outlined,
                  onTap: () => context.go(AppRoutes.adminComplaints),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              Expanded(
                child: _OverviewStatTile(
                  label: 'Announcements',
                  count: totalAnnouncements,
                  color: AppColors.info,
                  icon: Icons.campaign_outlined,
                  onTap: () => context.go(AppRoutes.adminAnnouncements),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                child: _OverviewStatTile(
                  label: 'Departments',
                  count: totalDepartments,
                  color: AppColors.success,
                  icon: Icons.apartment_outlined,
                  onTap: () => context.go(AppRoutes.adminDashboard),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStatTile extends StatelessWidget {
  const _OverviewStatTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: color),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Institutional settings and account details are managed through institutional administrative services. Use password management below to secure your credentials.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
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
          onPressed: () => _confirmSignOut(context),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text(
          'Are you sure you want to end your administrative session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
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
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } on FirebaseAuthException catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(_passwordError(error.code)),
                      backgroundColor: AppColors.error,
                    ),
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
        return 'Choose a stronger password (at least 6 characters).';
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

String _formatRole(String? role) {
  if (role == null || role.isEmpty) return 'Administrator';
  switch (role.toUpperCase()) {
    case 'SUPER_ADMIN':
      return 'Super Admin';
    case 'ORG_ADMIN':
      return 'Organization Admin';
    default:
      return role.replaceAll('_', ' ');
  }
}

String _roleBadgeLabel(String? role) {
  if (role == null || role.isEmpty) return 'ADMIN';
  switch (role.toUpperCase()) {
    case 'SUPER_ADMIN':
      return 'SUPER ADMIN';
    case 'ORG_ADMIN':
      return 'ORG ADMIN';
    default:
      return role.replaceAll('_', ' ').toUpperCase();
  }
}
