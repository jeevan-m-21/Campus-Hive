import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import 'logout_confirmation_dialog.dart';

/// Reusable standardized header for CampusHive root and top-level screens.
///
/// Features:
/// - CampusHive logo aligned to the left (or title if specified)
/// - Notification bell aligned to the right with unread count badge
/// - Logout icon at the far right invoking [LogoutConfirmationDialog]
/// - Clean light background with consistent height and safe area handling
class CampusHiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CampusHiveAppBar({
    this.title,
    this.showBack = false,
    this.showNotification = true,
    this.showLogout = true,
    this.notificationRoute,
    this.fallbackHomeRoute,
    this.onBack,
    this.actions,
    super.key,
  });

  final String? title;
  final bool showBack;
  final bool showNotification;
  final bool showLogout;
  final String? notificationRoute;
  final String? fallbackHomeRoute;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    int unreadCount = 0;
    try {
      unreadCount = context.watch<NotificationProvider>().unreadCount;
    } catch (_) {
      unreadCount = 0;
    }

    String? role;
    try {
      role = context.watch<AuthProvider>().session?.role.toUpperCase();
    } catch (_) {
      role = null;
    }
    final effectiveNotificationRoute = notificationRoute ??
        _resolveNotificationRoute(role);
    final effectiveHomeRoute = fallbackHomeRoute ?? _resolveHomeRoute(role);

    final notificationAction = Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined, size: 24),
          color: AppColors.textPrimary,
          onPressed: () => context.push(effectiveNotificationRoute),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );

    final logoutAction = IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout_outlined, size: 24),
      color: AppColors.textPrimary,
      onPressed: () => LogoutConfirmationDialog.show(context),
    );

    final effectiveActions = <Widget>[
      if (actions != null) ...actions!,
      if (showNotification) notificationAction,
      if (showLogout) logoutAction,
    ];

    final logoWidget = Image.asset(
      'assets/logos/campus_hive_header_logo.png',
      height: 36,
      fit: BoxFit.contain,
    );

    // If showBack is true (nested detail screen), display the contextual title.
    // If showBack is false (root screen header), ONLY display the CampusHive logo on the left.
    // Never show the screen title beside the logo or divider in the global root header.
    final Widget titleWidget;
    if (showBack) {
      if (title != null && title!.trim().isNotEmpty) {
        titleWidget = Text(
          title!,
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        );
      } else {
        titleWidget = logoWidget;
      }
    } else {
      titleWidget = logoWidget;
    }

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: showBack ? 0 : AppDimensions.screenHorizontalPadding,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              color: AppColors.textPrimary,
              onPressed: () {
                if (onBack != null) {
                  onBack!();
                } else if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go(effectiveHomeRoute);
                }
              },
            )
          : null,
      title: titleWidget,
      actions: effectiveActions.isNotEmpty ? effectiveActions : null,
    );
  }

  static String _resolveNotificationRoute(String? role) {
    switch (role) {
      case 'SUPERVISOR':
        return AppRoutes.supervisorNotifications;
      case 'ORG_ADMIN':
      case 'SUPER_ADMIN':
        return AppRoutes.adminNotifications;
      default:
        return AppRoutes.studentNotifications;
    }
  }

  static String _resolveHomeRoute(String? role) {
    switch (role) {
      case 'SUPERVISOR':
        return AppRoutes.supervisorDashboard;
      case 'ORG_ADMIN':
      case 'SUPER_ADMIN':
        return AppRoutes.adminDashboard;
      default:
        return AppRoutes.studentDashboard;
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
