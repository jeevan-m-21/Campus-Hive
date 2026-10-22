import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// A reusable confirmation dialog shown before logging out of CampusHive.
class LogoutConfirmationDialog extends StatelessWidget {
  const LogoutConfirmationDialog({super.key});

  static bool _isDialogShowing = false;

  /// Whether a logout confirmation dialog is currently active on screen.
  static bool get isDialogShowing => _isDialogShowing;

  @visibleForTesting
  static void resetDialogStateForTesting() {
    _isDialogShowing = false;
  }

  /// Shows the logout confirmation dialog and executes the logout flow if confirmed.
  ///
  /// Prevents multiple dialogs from opening simultaneously.
  /// Returns `true` if logout was confirmed and performed, or `false` if cancelled.
  static Future<bool> show(
    BuildContext context, {
    Future<void> Function()? onConfirm,
  }) async {
    if (_isDialogShowing) return false;
    _isDialogShowing = true;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => const LogoutConfirmationDialog(),
      );

      if (confirmed == true && context.mounted) {
        if (onConfirm != null) {
          await onConfirm();
        } else {
          try {
            await context.read<AuthProvider>().signOut();
            if (context.mounted) {
              context.go(AppRoutes.login);
            }
          } catch (error) {
            if (context.mounted) {
              final message = switch (error) {
                AuthException(:final message) => message,
                AuthNetworkException(:final message) => message,
                _ => error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
              };
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to log out: $message'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
        return true;
      }
      return false;
    } finally {
      _isDialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLarge,
        AppDimensions.spacingLarge,
        AppDimensions.spacingLarge,
        AppDimensions.spacingSmall,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLarge,
        0,
        AppDimensions.spacingLarge,
        AppDimensions.spacingLarge,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLarge,
        0,
        AppDimensions.spacingLarge,
        AppDimensions.spacingLarge,
      ),
      title: const Text(
        'Log out?',
        style: AppTextStyles.headingMedium,
      ),
      content: const Text(
        'Are you sure you want to log out of your CampusHive account?',
        style: AppTextStyles.bodyMedium,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                key: const Key('logout_stay_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingSmall,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Stay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: ElevatedButton(
                key: const Key('logout_confirm_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingSmall,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Log Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Convenience function to show the logout confirmation dialog.
Future<bool> showLogoutConfirmationDialog(
  BuildContext context, {
  Future<void> Function()? onConfirm,
}) =>
    LogoutConfirmationDialog.show(context, onConfirm: onConfirm);
