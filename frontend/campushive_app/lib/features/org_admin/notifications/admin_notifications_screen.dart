import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../shared/notifications/unified_notifications_view.dart';

/// Organization Admin notification screen using the standardized [UnifiedNotificationsView].
class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedNotificationsView(
      role: 'ORG_ADMIN',
      fallbackHomeRoute: AppRoutes.adminDashboard,
    );
  }
}
