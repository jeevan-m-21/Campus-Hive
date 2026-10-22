import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/academic_department.dart';
import '../../models/email_verification.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'auth_shell.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<Organization> _organizations = [];
  List<AcademicDepartment> _departments = [];
  Organization? _selectedOrganization;
  AcademicDepartment? _selectedDepartment;

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isLoadingOrgs = false;
  bool _isLoadingDepts = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrganizations();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _isLoadingOrgs = true;
      _errorMessage = null;
    });

    try {
      final orgs = await context.read<AuthProvider>().getPublicOrganizations();
      if (!mounted) return;
      setState(() {
        _organizations = orgs;
        _isLoadingOrgs = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingOrgs = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingOrgs = false;
        _errorMessage =
            'Unable to load organizations. Please check your connection.';
      });
    }
  }

  Future<void> _loadAcademicDepartments(int organizationId) async {
    setState(() {
      _isLoadingDepts = true;
      _errorMessage = null;
    });

    try {
      final depts = await context
          .read<AuthProvider>()
          .getAcademicDepartments(organizationId);
      if (!mounted) return;
      setState(() {
        _departments = depts;
        _isLoadingDepts = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDepts = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingDepts = false;
        _errorMessage =
            'Unable to load departments. Please check your connection.';
      });
    }
  }

  void _onOrganizationChanged(Organization? org) {
    if (org == _selectedOrganization) return;
    setState(() {
      _selectedOrganization = org;
      _selectedDepartment = null;
      _departments = [];
      _errorMessage = null;
    });

    if (org != null) {
      _loadAcademicDepartments(org.organizationId);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrganization == null || _selectedDepartment == null) {
      setState(
        () => _errorMessage = 'Select an organization and academic department.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final identifier = _identifierController.text.trim();
      final orgId = _selectedOrganization!.organizationId;
      final deptId = _selectedDepartment!.academicDepartmentId;

      final sendResult = await context.read<AuthProvider>().sendRegistrationOtp(
        email: email,
        organizationId: orgId,
        academicDepartmentId: deptId,
        identifier: identifier,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final registrationData = RegistrationData(
        email: email,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        identifier: identifier,
        phone: _phoneController.text.trim(),
        organizationId: orgId,
        academicDepartmentId: deptId,
        initialCooldownSeconds: sendResult.resendCooldownSeconds,
      );

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => OtpVerificationScreen(
            registrationData: registrationData,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to send verification code. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainHint = _selectedOrganization?.emailDomain;

    return AuthShell(
      title: 'Create your student account',
      subtitle:
          'Join your campus community with your official student details.',
      child: Form(
        key: _formKey,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StudentRoleNote(),
              const SizedBox(height: AppDimensions.spacingLarge),
              AppTextField(
                controller: _nameController,
                label: 'Full name',
                hint: 'Enter your full name',
                prefixIcon: Icons.person_outline,
                validator: (value) => _required(value, 'Full name'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              _buildOrganizationDropdown(),
              const SizedBox(height: AppDimensions.spacingMedium),
              _buildDepartmentDropdown(),
              const SizedBox(height: AppDimensions.spacingMedium),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: domainHint != null ? 'you@$domainHint' : 'you@campus.edu',
                helperText: domainHint != null
                    ? 'Must be your official @$domainHint email'
                    : null,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: _requiredEmail,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              AppTextField(
                controller: _phoneController,
                label: 'Phone',
                hint: 'Enter your phone number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: _phoneValidator,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              AppTextField(
                controller: _identifierController,
                label: 'USN / Student ID',
                hint: 'Enter your student identifier',
                prefixIcon: Icons.badge_outlined,
                validator: (value) => _required(value, 'USN or Student ID'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: _visibilityButton(
                  _obscurePassword,
                  () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: _passwordValidator,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              AppTextField(
                controller: _confirmPasswordController,
                label: 'Confirm password',
                hint: 'Re-enter your password',
                prefixIcon: Icons.lock_reset_outlined,
                obscureText: _obscureConfirmation,
                suffixIcon: _visibilityButton(
                  _obscureConfirmation,
                  () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation,
                  ),
                ),
                validator: (value) {
                  final required = _required(value, 'Password confirmation');
                  if (required != null) return required;
                  return value != _passwordController.text
                      ? 'Passwords do not match'
                      : null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppDimensions.spacingMedium),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.spacingLarge),
              AppButton(
                label: 'Create student account',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
                expand: true,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Center(
                child: AuthLink(
                  text: 'Already have an account? Log in',
                  onPressed: () => context.go(AppRoutes.login),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationDropdown() {
    return DropdownButtonFormField<Organization>(
      initialValue: _selectedOrganization,
      isExpanded: true,
      icon: _isLoadingOrgs
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more_rounded),
      decoration: const InputDecoration(
        labelText: 'Organization',
        hintText: 'Select your organization',
        prefixIcon: Icon(Icons.account_balance_outlined),
      ),
      items: _organizations.map((org) {
        return DropdownMenuItem<Organization>(
          value: org,
          child: Text(
            org.organizationName,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _isLoading ? null : _onOrganizationChanged,
      validator: (selected) =>
          selected == null ? 'Organization is required' : null,
    );
  }

  Widget _buildDepartmentDropdown() {
    final hint = _selectedOrganization == null
        ? 'Select organization first'
        : (_isLoadingDepts
            ? 'Loading departments...'
            : (_departments.isEmpty
                ? 'No departments available'
                : 'Select your department'));

    return DropdownButtonFormField<AcademicDepartment>(
      key: ValueKey('${_selectedOrganization?.organizationId}_${_departments.length}'),
      initialValue: _selectedDepartment,
      isExpanded: true,
      icon: _isLoadingDepts
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more_rounded),
      decoration: InputDecoration(
        labelText: 'Academic department',
        hintText: hint,
        prefixIcon: const Icon(Icons.school_outlined),
      ),
      items: _departments.map((dept) {
        return DropdownMenuItem<AcademicDepartment>(
          value: dept,
          child: Text(
            '${dept.departmentName} (${dept.departmentCode})',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (_isLoading || _departments.isEmpty)
          ? null
          : (value) => setState(() => _selectedDepartment = value),
      validator: (selected) =>
          selected == null ? 'Academic department is required' : null,
    );
  }

  Widget _visibilityButton(bool isObscured, VoidCallback onPressed) {
    return IconButton(
      tooltip: isObscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: Icon(
        isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }

  String? _requiredEmail(String? value) {
    final required = _required(value, 'Email');
    if (required != null) return required;
    final email = value!.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    if (_selectedOrganization?.emailDomain != null) {
      final domain = _selectedOrganization!.emailDomain!.toLowerCase();
      if (!email.toLowerCase().endsWith('@$domain')) {
        return 'Email must belong to @$domain';
      }
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final required = _required(value, 'Phone');
    if (required != null) return required;
    final digits = value!.replaceAll(RegExp(r'\D'), '');
    return digits.length < 7 ? 'Enter a valid phone number' : null;
  }

  String? _passwordValidator(String? value) {
    final required = _required(value, 'Password');
    if (required != null) return required;
    return value!.length < 8 ? 'Use at least 8 characters' : null;
  }

  String? _required(String? value, String label) {
    return value == null || value.trim().isEmpty ? '$label is required' : null;
  }
}

class _StudentRoleNote extends StatelessWidget {
  const _StudentRoleNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.standardCardPadding),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_outlined, color: AppColors.primary),
          SizedBox(width: AppDimensions.spacingSmall),
          Expanded(
            child: Text(
              'Student registration only. Staff and administrator accounts are provisioned separately.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
