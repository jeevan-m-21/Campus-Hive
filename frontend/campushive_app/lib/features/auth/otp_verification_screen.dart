import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../models/email_verification.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'auth_shell.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    required this.registrationData,
    super.key,
  });

  final RegistrationData registrationData;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  late int _cooldownSeconds;
  Timer? _cooldownTimer;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isRegistering = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _cooldownSeconds = widget.registrationData.initialCooldownSeconds >= 0
        ? widget.registrationData.initialCooldownSeconds
        : 60;
    if (_cooldownSeconds > 0) {
      _startCooldownTimer();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_cooldownSeconds > 0 || _isResending || _isVerifying || _isRegistering) {
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await context.read<AuthProvider>().sendRegistrationOtp(
        email: widget.registrationData.email,
        organizationId: widget.registrationData.organizationId,
        academicDepartmentId: widget.registrationData.academicDepartmentId,
        identifier: widget.registrationData.identifier,
      );

      if (!mounted) return;
      setState(() {
        _isResending = false;
        _cooldownSeconds = result.resendCooldownSeconds > 0
            ? result.resendCooldownSeconds
            : 60;
        _successMessage = 'A new verification code has been sent to your email.';
        _otpController.clear();
      });
      _startCooldownTimer();
      _focusNode.requestFocus();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorMessage =
            'Unable to resend verification code. Please check your connection.';
      });
    }
  }

  Future<void> _verifyAndRegister() async {
    _focusNode.unfocus();
    final otp = _otpController.text.trim();

    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit verification code.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // 1. Verify OTP with backend
      final verifyResult =
          await context.read<AuthProvider>().verifyRegistrationOtp(
        email: widget.registrationData.email,
        otp: otp,
      );

      final verificationToken = verifyResult.verificationToken;
      if (verificationToken.isEmpty) {
        throw const AuthException(
          'Verification failed: No verification token returned.',
        );
      }

      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isRegistering = true;
      });

      // 2. Complete registration: creates Firebase account + backend user record
      final session = await context.read<AuthProvider>().register(
        email: widget.registrationData.email,
        password: widget.registrationData.password,
        fullName: widget.registrationData.fullName,
        identifier: widget.registrationData.identifier,
        phone: widget.registrationData.phone,
        organizationId: widget.registrationData.organizationId,
        academicDepartmentId: widget.registrationData.academicDepartmentId,
        verificationToken: verificationToken,
      );

      if (!mounted) return;
      setState(() => _isRegistering = false);

      // 3. Navigate on success
      if (session.role.toUpperCase() == 'STUDENT') {
        context.go(AppRoutes.studentDashboard);
      } else {
        context.go(AppRoutes.login);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isRegistering = false;
        _errorMessage = _firebaseErrorMessage(error.code);
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isRegistering = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isRegistering = false;
        _errorMessage =
            'An unexpected error occurred during registration. Please try again.';
      });
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 8 characters.';
      case 'operation-not-allowed':
        return 'Registration is temporarily unavailable. Please contact support.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection.';
      default:
        return 'Registration failed ($code). Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isVerifying || _isRegistering;

    return AuthShell(
      title: 'Verify your email',
      subtitle: 'Enter the six-digit code sent to complete your registration.',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEmailBanner(),
            const SizedBox(height: AppDimensions.spacingLarge),
            _buildOtpInputSection(),
            const SizedBox(height: AppDimensions.spacingMedium),
            _buildExpiryNotice(),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              _buildMessageBanner(
                message: _errorMessage!,
                isError: true,
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              _buildMessageBanner(
                message: _successMessage!,
                isError: false,
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLarge),
            AppButton(
              label: _isRegistering
                  ? 'Completing registration...'
                  : (_isVerifying ? 'Verifying code...' : 'Verify & Register'),
              onPressed: isBusy ? null : _verifyAndRegister,
              isLoading: isBusy,
              expand: true,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            _buildResendSection(),
            const SizedBox(height: AppDimensions.spacingSmall),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to registration details'),
                onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMedium,
        vertical: AppDimensions.spacingSmall + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: AppDimensions.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verification code sent to',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.registrationData.email,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change email',
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
            onPressed: (_isVerifying || _isRegistering)
                ? null
                : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter 6-digit OTP',
          style: AppTextStyles.label,
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        Stack(
          alignment: Alignment.center,
          children: [
            // Visual digit cells
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _otpController,
              builder: (context, value, _) {
                final text = value.text;
                return Row(
                  children: List.generate(6, (index) {
                    final char = index < text.length ? text[index] : '';
                    final isFocused = _focusNode.hasFocus &&
                        (index == text.length || (index == 5 && text.length == 6));

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _focusNode.requestFocus(),
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: index == 0 || index == 5 ? 2.0 : 3.5,
                          ),
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFocused
                                  ? AppColors.primary
                                  : (char.isNotEmpty
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : AppColors.border),
                              width: isFocused ? 2.0 : 1.2,
                            ),
                            boxShadow: isFocused
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            char,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            // Transparent full-width text field for keyboard interaction
            Opacity(
              opacity: 0.0,
              child: TextField(
                key: const Key('otp_text_field'),
                controller: _otpController,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (val) {
                  if (val.length == 6) {
                    _verifyAndRegister();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpiryNotice() {
    return const Row(
      children: [
        Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            'Code expires in 5 minutes',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBanner({
    required String message,
    required bool isError,
  }) {
    final color = isError ? AppColors.error : AppColors.success;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingSmall + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppDimensions.spacingSmall),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendSection() {
    if (_cooldownSeconds > 0) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Resend code in ${_cooldownSeconds}s',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: TextButton.icon(
        key: const Key('resend_otp_button'),
        icon: _isResending
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded, size: 16),
        label: Text(_isResending ? 'Sending...' : 'Resend code'),
        onPressed: (_isResending || _isVerifying || _isRegistering)
            ? null
            : _resendOtp,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
