import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/campus_hive_app_bar.dart';

/// Supervisor role-specific application header delegating to [CampusHiveAppBar].
class SupervisorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SupervisorAppBar({
    this.title,
    this.showBack = false,
    this.showNotification = true,
    this.showLogout = true,
    this.onBack,
    this.actions,
    super.key,
  });

  final String? title;
  final bool showBack;
  final bool showNotification;
  final bool showLogout;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return CampusHiveAppBar(
      title: title,
      showBack: showBack,
      showNotification: showNotification,
      showLogout: showLogout,
      notificationRoute: AppRoutes.supervisorNotifications,
      fallbackHomeRoute: AppRoutes.supervisorDashboard,
      onBack: onBack,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
