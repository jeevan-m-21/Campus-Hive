import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/admin_complaint_provider.dart';
import '../providers/announcement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/supervisor_complaint_provider.dart';
import '../services/fcm_service.dart';
import 'routes.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  void _setupFcm() {
    FcmService.instance.initialize(
      onForegroundMessage: (message) {
        final ctx = AppRoutes.rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          try {
            Provider.of<NotificationProvider>(ctx, listen: false)
                .loadUnreadCount();
          } catch (_) {}
        }
      },
      onNotificationTapped: (data) {
        final ctx = AppRoutes.rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          try {
            Provider.of<NotificationProvider>(ctx, listen: false)
                .loadUnreadCount();
          } catch (_) {}
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SupervisorComplaintProvider()),
        ChangeNotifierProvider(create: (_) => AdminComplaintProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: AppRoutes.router(),
      ),
    );
  }
}
