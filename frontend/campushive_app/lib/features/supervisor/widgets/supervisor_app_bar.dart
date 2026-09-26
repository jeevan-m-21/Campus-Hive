import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notification_provider.dart';

class SupervisorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SupervisorAppBar({
    this.title,
    this.showBack = false,
    this.onBack,
    super.key,
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;

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
                  context.go(AppRoutes.supervisorDashboard);
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
      actions: [
        // Notification Icon (immediately to the LEFT of Logout icon)
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push(AppRoutes.supervisorNotifications),
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
        ),
        // Logout Icon
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_outlined),
          onPressed: () async {
            await context.read<AuthProvider>().signOut();
            if (context.mounted) context.go(AppRoutes.login);
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
