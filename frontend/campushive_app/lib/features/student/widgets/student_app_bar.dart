import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/notification_provider.dart';

class StudentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StudentAppBar({
    this.title,
    this.actions,
    this.showBack = false,
    this.showNotification = true,
    this.onBack,
    super.key,
  });

  final String? title;
  final List<Widget>? actions;
  final bool showBack;
  final bool showNotification;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    int unreadCount = 0;
    try {
      unreadCount = context.watch<NotificationProvider>().unreadCount;
    } catch (_) {
      unreadCount = 0;
    }

    final notificationAction = Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push(AppRoutes.studentNotifications),
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

    final effectiveActions = <Widget>[
      if (showNotification) notificationAction,
      if (actions != null) ...actions!,
    ];

    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                if (onBack != null) {
                  onBack!();
                } else if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.studentDashboard);
                }
              },
            )
          : null,
      title: title != null
          ? Text(title!)
          : Image.asset(
              'assets/logos/campus_hive_header_logo.png',
              height: 36,
              fit: BoxFit.contain,
            ),
      actions: effectiveActions.isNotEmpty ? effectiveActions : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

