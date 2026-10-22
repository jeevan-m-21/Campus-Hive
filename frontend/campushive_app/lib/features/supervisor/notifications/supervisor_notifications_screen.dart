import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../shared/notifications/unified_notifications_view.dart';

/// Supervisor notification screen using the standardized [UnifiedNotificationsView].
class SupervisorNotificationsScreen extends StatelessWidget {
  const SupervisorNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedNotificationsView(
      role: 'SUPERVISOR',
      fallbackHomeRoute: AppRoutes.supervisorDashboard,
    );
  }
}
