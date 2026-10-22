import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/admin_complaint_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/notification_provider.dart';
import 'announcements/admin_announcements_screen.dart';
import 'complaints/admin_complaints_screen.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'profile/admin_profile_screen.dart';
import 'widgets/admin_app_bar.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({required this.selectedIndex, super.key});

  final int selectedIndex;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminComplaintProvider>().loadComplaints();
      context.read<AdminComplaintProvider>().loadDepartments();
      context.read<AdminComplaintProvider>().loadDashboardStats();
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
          AdminDashboardScreen(),
          AdminComplaintsScreen(),
          AdminAnnouncementsScreen(),
          AdminProfileScreen(),
        ],
      ),
      bottomNavigationBar: _AdminBottomNavigationBar(
        selectedIndex: widget.selectedIndex,
      ),
    );
  }
}

class _AdminBottomNavigationBar extends StatelessWidget {
  const _AdminBottomNavigationBar({required this.selectedIndex});

  final int selectedIndex;

  static const _destinations = [
    _AdminDestination('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _AdminDestination(
      'Complaints',
      Icons.assignment_outlined,
      Icons.assignment,
    ),
    _AdminDestination('Announcements', Icons.campaign_outlined, Icons.campaign),
    _AdminDestination('Profile', Icons.person_outline, Icons.person),
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
        return AppRoutes.adminComplaints;
      case 2:
        return AppRoutes.adminAnnouncements;
      case 3:
        return AppRoutes.adminProfile;
      default:
        return AppRoutes.adminDashboard;
    }
  }
}

class _AdminDestination {
  const _AdminDestination(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({
    required this.title,
    required this.icon,
    required this.description,
    super.key,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdminAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: AppColors.primary),
                const SizedBox(height: AppDimensions.spacingMedium),
                Text(title, style: AppTextStyles.headingMedium),
                const SizedBox(height: AppDimensions.spacingSmall),
                Text(
                  description,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
