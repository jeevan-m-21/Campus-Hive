import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'auth_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session = await context.read<AuthProvider>().login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        identifier: _identifierController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (session.role.toUpperCase() == 'STUDENT') {
        context.go(AppRoutes.studentDashboard);
      } else {
        setState(
          () => _errorMessage =
              'Signed in as ${session.role}. This dashboard is not available yet.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _firebaseErrorMessage(error.code);
      });
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
        _errorMessage = 'Unable to sign in. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to continue to your campus community.',
      child: Form(
        key: _formKey,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                controller: _identifierController,
                label: 'USN / Employee ID',
                hint: 'Enter your campus identifier',
                prefixIcon: Icons.badge_outlined,
                validator: (value) => _required(value, 'USN or Employee ID'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) => _required(value, 'Password'),
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
                label: 'Log in',
                onPressed: _submit,
                isLoading: _isLoading,
                expand: true,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Center(
                child: AuthLink(
                  text: 'Create a student account',
                  onPressed: () => context.go(AppRoutes.register),
                ),
              ),
            ],
          ),
        ),
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
    return null;
  }

  String? _required(String? value, String label) {
    return value == null || value.trim().isEmpty ? '$label is required' : null;
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Unable to sign in. Please check your connection.';
      default:
        return 'Unable to sign in. Please try again.';
    }
  }
}
