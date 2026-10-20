import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({this.autoRestore = true, super.key});

  final bool autoRestore;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isChecking = true;
  String? _networkError;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoRestore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkSession();
      });
    } else {
      _isChecking = false;
    }
  }

  Future<void> _checkSession() async {
    if (!mounted) return;
    setState(() {
      _isChecking = true;
      _networkError = null;
    });

    try {
      final session = await context.read<AuthProvider>().restoreSession();
      if (!mounted) return;

      if (session != null) {
        final pendingData =
            FcmService.instance.consumePendingNotificationData();
        if (pendingData != null) {
          final targetRoute = FcmService.resolveRouteForNotification(
            pendingData,
            role: session.role,
          );
          final dashboardRoute = _dashboardForRole(session.role);
          if (_hasNavigated || !mounted) return;
          _hasNavigated = true;
          final router = GoRouter.of(context);
          router.go(dashboardRoute);
          if (targetRoute != dashboardRoute) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              router.push(targetRoute);
            });
          }
          return;
        }
        _navigateForRole(session.role);
      } else {
        _safeNavigate(AppRoutes.landing);
      }
    } on AuthNetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _networkError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      _safeNavigate(AppRoutes.landing);
    }
  }

  String _dashboardForRole(String role) {
    final normalized = role.trim().toUpperCase();
    if (normalized == 'STUDENT') {
      return AppRoutes.studentDashboard;
    } else if (normalized == 'SUPERVISOR') {
      return AppRoutes.supervisorDashboard;
    } else if (normalized == 'ORG_ADMIN' || normalized == 'SUPER_ADMIN') {
      return AppRoutes.adminDashboard;
    } else {
      return AppRoutes.landing;
    }
  }

  void _navigateForRole(String role) {
    _safeNavigate(_dashboardForRole(role));
  }

  void _safeNavigate(String route) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 220,
                    width: 220,
                    child: Image.asset(
                      'assets/logos/campus_hive_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  const Text(
                    'The heart of your digital campus life',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  if (_isChecking) ...[
                    const SizedBox(height: 12),
                    const AppLoader(),
                    const SizedBox(height: 16),
                    Text(
                      'Restoring campus session...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else if (_networkError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.cardRadius,
                        ),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.wifi_off_outlined,
                            color: AppColors.error,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connection Issue',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _networkError!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    AppButton(
                      label: 'Retry Connection',
                      icon: Icons.refresh,
                      onPressed: _checkSession,
                      expand: true,
                    ),
                    const SizedBox(height: AppDimensions.spacingSmall),
                    AppButton(
                      label: 'Continue to Sign In',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => _safeNavigate(AppRoutes.landing),
                      expand: true,
                    ),
                  ] else ...[
                    const _BootStatus(),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    AppButton(
                      label: 'Enter CampusHive',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => _safeNavigate(AppRoutes.landing),
                      expand: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootStatus extends StatelessWidget {
  const _BootStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.standardCardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.success),
          SizedBox(width: AppDimensions.spacingSmall),
          Expanded(
            child: Text(
              'Ready to connect your campus community',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
