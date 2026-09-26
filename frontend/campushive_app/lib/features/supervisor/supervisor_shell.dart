import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/supervisor_complaint_provider.dart';
import 'announcements/supervisor_announcements_screen.dart';
import 'complaints/supervisor_task_queue_screen.dart';
import 'dashboard/supervisor_dashboard_screen.dart';
import 'profile/supervisor_profile_screen.dart';

class SupervisorShellScreen extends StatefulWidget {
  const SupervisorShellScreen({required this.selectedIndex, super.key});

  final int selectedIndex;

  @override
  State<SupervisorShellScreen> createState() => _SupervisorShellScreenState();
}

class _SupervisorShellScreenState extends State<SupervisorShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SupervisorComplaintProvider>().loadComplaints();
      context.read<NotificationProvider>().loadUnreadCount();
      context.read<AnnouncementProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: widget.selectedIndex,
        children: const [
          SupervisorDashboardScreen(),
          SupervisorTaskQueueScreen(),
          SupervisorAnnouncementsScreen(),
          SupervisorProfileScreen(),
        ],
      ),
      bottomNavigationBar: _SupervisorBottomNavigationBar(
        selectedIndex: widget.selectedIndex,
      ),
    );
  }
}

class _SupervisorBottomNavigationBar extends StatelessWidget {
  const _SupervisorBottomNavigationBar({required this.selectedIndex});

  final int selectedIndex;

  static const _destinations = [
    _SupervisorDestination(
      'Dashboard',
      Icons.dashboard_outlined,
      Icons.dashboard,
    ),
    _SupervisorDestination(
      'Task Queue',
      Icons.assignment_outlined,
      Icons.assignment,
    ),
    _SupervisorDestination(
      'Announcements',
      Icons.campaign_outlined,
      Icons.campaign,
    ),
    _SupervisorDestination('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => context.go(_routeFor(index)),
          items: [
            for (final destination in _destinations)
              BottomNavigationBarItem(
                icon: Icon(destination.icon),
                activeIcon: Icon(destination.activeIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }

  String _routeFor(int index) {
    switch (index) {
      case 1:
        return AppRoutes.supervisorQueue;
      case 2:
        return AppRoutes.supervisorAnnouncements;
      case 3:
        return AppRoutes.supervisorProfile;
      default:
        return AppRoutes.supervisorDashboard;
    }
  }
}

class _SupervisorDestination {
  const _SupervisorDestination(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
