import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/announcement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/supervisor_complaint_provider.dart';
import 'routes.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SupervisorComplaintProvider()),
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
