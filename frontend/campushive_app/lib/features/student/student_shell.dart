import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/complaint_provider.dart';
import 'complaints/student_complaints_screen.dart';
import 'home/student_dashboard_screen.dart';
import 'lost_found/lost_found_screen.dart';
import 'announcements/announcements_screen.dart';
import 'profile/student_profile_screen.dart';
import 'widgets/student_app_bar.dart';

class StudentShellScreen extends StatelessWidget {
  const StudentShellScreen({required this.selectedIndex, super.key});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ComplaintProvider()..loadComplaints(),
      child: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: const [
            StudentDashboardScreen(),
            StudentComplaintsScreen(),
            LostFoundScreen(),
            AnnouncementsScreen(),
            StudentProfileScreen(),
          ],
        ),
        bottomNavigationBar: _StudentBottomNavigationBar(
          selectedIndex: selectedIndex,
        ),
      ),
    );
  }
}

class _StudentBottomNavigationBar extends StatelessWidget {
  const _StudentBottomNavigationBar({required this.selectedIndex});

  final int selectedIndex;

  static const _destinations = [
    _StudentDestination('Home', Icons.home_outlined, Icons.home),
    _StudentDestination(
      'Complaints',
      Icons.assignment_outlined,
      Icons.assignment,
    ),
    _StudentDestination('Lost & Found', Icons.search_outlined, Icons.search),
    _StudentDestination(
      'Announcements',
      Icons.campaign_outlined,
      Icons.campaign,
    ),
    _StudentDestination('Profile', Icons.person_outline, Icons.person),
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
        return AppRoutes.studentComplaints;
      case 2:
        return AppRoutes.studentLostFound;
      case 3:
        return AppRoutes.studentAnnouncements;
      case 4:
        return AppRoutes.studentProfile;
      default:
        return AppRoutes.studentDashboard;
    }
  }
}

class _StudentDestination {
  const _StudentDestination(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class StudentPlaceholderScreen extends StatelessWidget {
  const StudentPlaceholderScreen({
    required this.title,
    required this.icon,
    super.key,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StudentAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: AppColors.primary),
                const SizedBox(height: AppDimensions.spacingMedium),
                Text(title, style: AppTextStyles.headingMedium),
                const SizedBox(height: AppDimensions.spacingSmall),
                const Text(
                  'This section is coming next.',
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
