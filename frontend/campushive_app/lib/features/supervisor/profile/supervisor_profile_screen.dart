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
import '../../../models/department.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/supervisor_complaint_provider.dart';
import '../../../services/complaint_service.dart';
import '../../student/home/widgets/feed_card_shell.dart';
import '../widgets/supervisor_app_bar.dart';

class SupervisorProfileScreen extends StatefulWidget {
  const SupervisorProfileScreen({super.key});

  @override
  State<SupervisorProfileScreen> createState() =>
      _SupervisorProfileScreenState();
}

class _SupervisorProfileScreenState extends State<SupervisorProfileScreen> {
  List<Department> _departments = [];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await ComplaintService().fetchDepartments();
      if (mounted) setState(() => _departments = depts);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final user = session?.user ?? const <String, dynamic>{};

    return Scaffold(
      appBar: const SupervisorAppBar(title: 'Supervisor Profile'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: AppDimensions.spacingLarge),
            _ProfileDetails(user: user, departments: _departments),
            const SizedBox(height: AppDimensions.spacingLarge),
            const Text('Your Activity', style: AppTextStyles.headingSmall),
            const SizedBox(height: AppDimensions.spacingSmall),
            const _SupervisorActivityGrid(),
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
                    Icons.badge_outlined,
                    size: 34,
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
                        fullName.isEmpty ? 'Supervisor' : fullName,
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
                      child: const Text(
                        'SUPERVISOR',
                        style: TextStyle(
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
                  Text('ID: $identifier', style: AppTextStyles.label),
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
  const _ProfileDetails({required this.user, required this.departments});

  final Map<String, dynamic> user;
  final List<Department> departments;

  @override
  Widget build(BuildContext context) {
    final deptId = user['department_id'];
    String deptName = '';
    if (deptId != null) {
      final match = departments
          .where(
            (d) =>
                d.departmentId == deptId ||
                d.departmentId.toString() == deptId.toString(),
          )
          .firstOrNull;
      deptName = match?.departmentName ?? 'Department #$deptId';
    }

    final details = <_DetailData>[
      _DetailData('Full name', user['full_name']),
      _DetailData('Employee ID', user['usn_or_employee_id']),
      _DetailData('Email', user['email']),
      _DetailData('Phone', user['phone']),
      _DetailData('Role', 'SUPERVISOR'),
      if (deptName.isNotEmpty) _DetailData('Assigned Department', deptName),
      if (_value(user['organization_name']).isNotEmpty)
        _DetailData('Organization', user['organization_name']),
    ].where((detail) => _value(detail.value).isNotEmpty).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profile Details', style: AppTextStyles.headingSmall),
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
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SupervisorActivityGrid extends StatelessWidget {
  const _SupervisorActivityGrid();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupervisorComplaintProvider>();

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActivityStatTile(
                  label: 'Received / Assigned',
                  count: provider.totalAssigned,
                  color: AppColors.info,
                  icon: Icons.assignment_outlined,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                child: _ActivityStatTile(
                  label: 'Resolved',
                  count: provider.resolvedCount,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              Expanded(
                child: _ActivityStatTile(
                  label: 'In Progress',
                  count: provider.inProgressCount,
                  color: AppColors.primary,
                  icon: Icons.sync_outlined,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                child: _ActivityStatTile(
                  label: 'Pending Action',
                  count: provider.pendingCount,
                  color: AppColors.warning,
                  icon: Icons.pending_actions_outlined,
                ),
              ),
            ],
          ),
          if (provider.reopenedCount > 0 ||
              provider.escalatedCount > 0 ||
              provider.closedCount > 0) ...[
            const SizedBox(height: AppDimensions.spacingSmall),
            Row(
              children: [
                Expanded(
                  child: _ActivityStatTile(
                    label: 'Reopened',
                    count: provider.reopenedCount,
                    color: AppColors.warning,
                    icon: Icons.replay_outlined,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSmall),
                Expanded(
                  child: _ActivityStatTile(
                    label: 'Escalated',
                    count: provider.escalatedCount,
                    color: AppColors.error,
                    icon: Icons.priority_high_outlined,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityStatTile extends StatelessWidget {
  const _ActivityStatTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
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
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
