import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/supervisor.dart';
import '../../../providers/admin_complaint_provider.dart';
import '../../../services/complaint_service.dart';
import '../widgets/admin_app_bar.dart';

class AdminSupervisorsScreen extends StatefulWidget {
  const AdminSupervisorsScreen({super.key});

  @override
  State<AdminSupervisorsScreen> createState() => _AdminSupervisorsScreenState();
}

class _AdminSupervisorsScreenState extends State<AdminSupervisorsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminComplaintProvider>();
      provider.loadSupervisors();
      provider.loadDepartments();
    });
  }

  Future<void> _openAddSupervisorDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _AddSupervisorDialog(),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supervisor account created successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminComplaintProvider>();
    final supervisors = provider.supervisors;
    final isLoading = provider.isLoadingSupervisors;
    final error = provider.supervisorsErrorMessage;

    return Scaffold(
      appBar: const AdminAppBar(
        title: 'Supervisor Management',
        showBack: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_supervisor_fab'),
        onPressed: _openAddSupervisorDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Supervisor'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              provider.loadSupervisors(force: true),
              provider.loadDepartments(),
            ]);
          },
          child: Builder(
            builder: (context) {
              if (isLoading && supervisors.isEmpty) {
                return const Center(child: AppLoader());
              }

              if (error != null && supervisors.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(
                      AppDimensions.screenHorizontalPadding,
                    ),
                    child: EmptyState(
                      title: 'Unable to load supervisors',
                      message: error,
                      actionLabel: 'Retry',
                      onAction: () => provider.loadSupervisors(force: true),
                    ),
                  ),
                );
              }

              if (supervisors.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: EmptyState(
                        icon: Icons.badge_outlined,
                        title: 'No Supervisors Yet',
                        message:
                            'Add supervisors to oversee department operations and resolve complaints.',
                        actionLabel: 'Add Supervisor',
                        onAction: _openAddSupervisorDialog,
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenHorizontalPadding,
                  AppDimensions.spacingMedium,
                  AppDimensions.screenHorizontalPadding,
                  88, // bottom padding for FAB
                ),
                itemCount: supervisors.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppDimensions.spacingMedium),
                itemBuilder: (context, index) {
                  final supervisor = supervisors[index];
                  return _SupervisorCard(supervisor: supervisor);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SupervisorCard extends StatelessWidget {
  const _SupervisorCard({required this.supervisor});

  final Supervisor supervisor;

  @override
  Widget build(BuildContext context) {
    final initials = supervisor.fullName.trim().isNotEmpty
        ? supervisor.fullName
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0] : '')
              .join()
              .toUpperCase()
        : 'S';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
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
                            supervisor.fullName,
                            style: AppTextStyles.headingSmall,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: supervisor.isActive
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            supervisor.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: supervisor.isActive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (supervisor.departmentName != null &&
                            supervisor.departmentName!.isNotEmpty)
                          _InfoBadge(
                            icon: Icons.apartment_outlined,
                            label: supervisor.departmentName!,
                            color: AppColors.primary,
                          ),
                        if (supervisor.employeeId != null &&
                            supervisor.employeeId!.isNotEmpty)
                          _InfoBadge(
                            icon: Icons.badge_outlined,
                            label: supervisor.employeeId!,
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  supervisor.email,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (supervisor.phone != null && supervisor.phone!.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  supervisor.phone!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSupervisorDialog extends StatefulWidget {
  const _AddSupervisorDialog();

  @override
  State<_AddSupervisorDialog> createState() => _AddSupervisorDialogState();
}

class _AddSupervisorDialogState extends State<_AddSupervisorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  int? _selectedDepartmentId;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _employeeIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartmentId == null) {
      setState(() => _errorMessage = 'Please select a department.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await context.read<AdminComplaintProvider>().createSupervisor(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        employeeId: _employeeIdController.text.trim(),
        departmentId: _selectedDepartmentId!,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final msg = error is ComplaintException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isSubmitting = false;
        _errorMessage = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = context.watch<AdminComplaintProvider>().departments;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.standardCardPadding),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Supervisor',
                      style: AppTextStyles.headingMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Create a new department supervisor account with Firebase credentials.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMedium),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(
                      bottom: AppDimensions.spacingMedium,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Full Name
                AppTextField(
                  key: const Key('supervisor_name_field'),
                  controller: _nameController,
                  label: 'Full Name *',
                  hint: 'e.g. John Doe',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Full name is required';
                    if (text.length > 100) return 'Max 100 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingMedium),

                // Employee ID
                AppTextField(
                  key: const Key('supervisor_employee_id_field'),
                  controller: _employeeIdController,
                  label: 'Employee ID *',
                  hint: 'e.g. EMP_ELEC_01',
                  prefixIcon: Icons.badge_outlined,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Employee ID is required';
                    if (text.length > 30) return 'Max 30 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingMedium),

                // Email
                AppTextField(
                  key: const Key('supervisor_email_field'),
                  controller: _emailController,
                  label: 'Email Address *',
                  hint: 'supervisor@institution.edu',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email is required';
                    if (!text.contains('@') || !text.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingMedium),

                // Password
                AppTextField(
                  key: const Key('supervisor_password_field'),
                  controller: _passwordController,
                  label: 'Password *',
                  hint: 'Minimum 6 characters',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingMedium),

                // Department Dropdown
                DropdownButtonFormField<int>(
                  key: const Key('supervisor_department_dropdown'),
                  initialValue: _selectedDepartmentId,
                  decoration: const InputDecoration(
                    labelText: 'Department *',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  items: [
                    for (final dept in departments)
                      DropdownMenuItem<int>(
                        value: dept.departmentId,
                        child: Text(dept.departmentName),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartmentId = value;
                      if (value != null) _errorMessage = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select a department' : null,
                ),
                const SizedBox(height: AppDimensions.spacingMedium),

                // Phone
                AppTextField(
                  key: const Key('supervisor_phone_field'),
                  controller: _phoneController,
                  label: 'Phone Number (Optional)',
                  hint: 'e.g. 9876543210',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isNotEmpty && text.length > 15) {
                      return 'Max 15 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingLarge),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.outlined,
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppDimensions.spacingSmall),
                    AppButton(
                      key: const Key('submit_supervisor_button'),
                      label: 'Create Account',
                      icon: Icons.check,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
