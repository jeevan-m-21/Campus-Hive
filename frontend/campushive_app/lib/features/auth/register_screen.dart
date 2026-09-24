import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import 'auth_shell.dart';

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
  String? _organization;
  String? _department;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _organizations = const [
    'Select organization',
    'Organization will be loaded from CampusHive',
  ];
  final _departments = const [
    'Select academic department',
    'Academic department will be loaded from CampusHive',
  ];

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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_organization == null || _department == null) {
      setState(
        () => _errorMessage = 'Select an organization and academic department.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = 'Registration will be connected in a later step.';
    });
  }

  @override
  Widget build(BuildContext context) {
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
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'you@campus.edu',
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
              _SelectionField(
                label: 'Organization',
                hint: 'Select your organization',
                icon: Icons.account_balance_outlined,
                value: _organization,
                options: _organizations,
                onChanged: (value) => setState(() => _organization = value),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              _SelectionField(
                label: 'Academic department',
                hint: 'Select your department',
                icon: Icons.school_outlined,
                value: _department,
                options: _departments,
                onChanged: (value) => setState(() => _department = value),
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
                  style: const TextStyle(color: AppColors.info, fontSize: 12),
                ),
              ],
              const SizedBox(height: AppDimensions.spacingLarge),
              AppButton(
                label: 'Create student account',
                onPressed: _submit,
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
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())
        ? null
        : 'Enter a valid email address';
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

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      items: options
          .map(
            (option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(),
      onChanged: onChanged,
      validator: (selected) => selected == null ? '$label is required' : null,
    );
  }
}
