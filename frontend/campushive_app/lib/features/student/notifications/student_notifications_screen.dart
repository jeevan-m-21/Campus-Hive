import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../shared/notifications/unified_notifications_view.dart';

/// Student notification screen using the standardized [UnifiedNotificationsView].
class StudentNotificationsScreen extends StatelessWidget {
  const StudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedNotificationsView(
      role: 'STUDENT',
      fallbackHomeRoute: AppRoutes.studentDashboard,
    );
  }
}
