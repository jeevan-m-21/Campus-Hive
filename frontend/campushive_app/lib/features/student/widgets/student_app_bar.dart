import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/campus_hive_app_bar.dart';

/// Student role-specific application header delegating to [CampusHiveAppBar].
class StudentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StudentAppBar({
    this.title,
    this.actions,
    this.showBack = false,
    this.showNotification = true,
    this.showLogout = true,
    this.onBack,
    super.key,
  });

  final String? title;
  final List<Widget>? actions;
  final bool showBack;
  final bool showNotification;
  final bool showLogout;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return CampusHiveAppBar(
      title: title,
      showBack: showBack,
      showNotification: showNotification,
      showLogout: showLogout,
      notificationRoute: AppRoutes.studentNotifications,
      fallbackHomeRoute: AppRoutes.studentDashboard,
      onBack: onBack,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
