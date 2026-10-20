import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/complaint.dart';
import '../../../providers/admin_complaint_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../student/home/widgets/feed_card_shell.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_complaint_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminComplaintProvider>().loadDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthProvider>().session?.user ??
        const <String, dynamic>{};
    final name = user['full_name']?.toString().trim() ?? 'Admin';
    final employeeId = user['usn_or_employee_id']?.toString().trim() ?? '';
    final imageUrl = user['profile_image']?.toString().trim() ?? '';

    final provider = context.watch<AdminComplaintProvider>();
    final stats = provider.dashboardStats;
    final isLoading = provider.isLoadingDashboard;
    final error = provider.dashboardErrorMessage;

    return Scaffold(
      appBar: const AdminAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              provider.loadDashboardStats(refresh: true),
              provider.loadComplaints(refresh: true),
              provider.loadDepartments(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            children: [
              _AdminGreetingCard(
                name: name,
                employeeId: employeeId,
                imageUrl: imageUrl,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              const _QuickActionsSection(),
              const SizedBox(height: AppDimensions.spacingLarge),

              if (isLoading && stats == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: AppLoader(),
                  ),
                )
              else if (error != null && stats == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: EmptyState(
                    title: 'Unable to load statistics',
                    message: error,
                    actionLabel: 'Retry',
                    onAction: () => provider.loadDashboardStats(refresh: true),
                  ),
                )
              else if (stats != null) ...[
                if (stats.activeHighPriorityComplaints.isNotEmpty) ...[
                  _HighPriorityAlertCard(
                    activeCount: stats.activeHighPriorityComplaints.length,
                    totalHighPriority: stats.highPriority,
                    onTap: () {
                      provider.setPriorityFilter('HIGH');
                      context.go(AppRoutes.adminComplaints);
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                ],
                _ComplaintStatsOverview(
                  stats: stats,
                  onSelectStatus: (status) {
                    provider.setStatusFilter(status);
                    context.go(AppRoutes.adminComplaints);
                  },
                  onSelectPriority: (priority) {
                    provider.setPriorityFilter(priority);
                    context.go(AppRoutes.adminComplaints);
                  },
                  onSelectAll: () {
                    provider.clearFilters();
                    context.go(AppRoutes.adminComplaints);
                  },
                ),
                const SizedBox(height: AppDimensions.spacingLarge),
                _RecentComplaintsSection(
                  complaints: stats.recentComplaints,
                  totalCount: stats.total,
                  onViewAll: () {
                    provider.clearFilters();
                    context.go(AppRoutes.adminComplaints);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminGreetingCard extends StatelessWidget {
  const _AdminGreetingCard({
    required this.name,
    required this.employeeId,
    required this.imageUrl,
  });

  final String name;
  final String employeeId;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final greetingName = name.isEmpty ? 'Admin' : name;
    return AppCard(
      child: Row(
        children: [
          imageUrl.isEmpty
              ? const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.divider,
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.textSecondary,
                    size: 28,
                  ),
                )
              : CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.divider,
                  backgroundImage: NetworkImage(resolveImageUrl(imageUrl)),
                ),
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_timeOfDay()}, $greetingName',
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: 2),
                if (employeeId.isNotEmpty)
                  Text(
                    'Admin ID: $employeeId',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Organization Administration & Control Center',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _HighPriorityAlertCard extends StatelessWidget {
  const _HighPriorityAlertCard({
    required this.activeCount,
    required this.totalHighPriority,
    required this.onTap,
  });

  final int activeCount;
  final int totalHighPriority;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.standardCardPadding),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$activeCount Active High-Priority Ticket${activeCount == 1 ? "" : "s"}',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalHighPriority Total High',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Requires prompt administrative review or supervisor coordination.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintStatsOverview extends StatelessWidget {
  const _ComplaintStatsOverview({
    required this.stats,
    required this.onSelectStatus,
    required this.onSelectPriority,
    required this.onSelectAll,
  });

  final AdminDashboardStats stats;
  final ValueChanged<String> onSelectStatus;
  final ValueChanged<String> onSelectPriority;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Complaint Analytics',
              style: AppTextStyles.headingSmall,
            ),
            Text(
              '${stats.activeTickets} Active / ${stats.total} Total',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),

        // Primary summary row: Total, Pending, In Progress, Resolved
        Row(
          children: [
            Expanded(
              child: _StatMetricCard(
                label: 'Total Tickets',
                count: stats.total,
                icon: Icons.assignment_outlined,
                accentColor: AppColors.primary,
                onTap: onSelectAll,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _StatMetricCard(
                label: 'Pending',
                count: stats.pending,
                icon: Icons.hourglass_top_outlined,
                accentColor: AppColors.warning,
                onTap: () => onSelectStatus('PENDING'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _StatMetricCard(
                label: 'In Progress',
                count: stats.inProgress,
                icon: Icons.play_circle_outline,
                accentColor: AppColors.info,
                onTap: () => onSelectStatus('IN_PROGRESS'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),

        // Secondary row: Resolved, Assigned, High Priority
        Row(
          children: [
            Expanded(
              child: _StatMetricCard(
                label: 'Resolved',
                count: stats.resolved,
                icon: Icons.check_circle_outline,
                accentColor: AppColors.success,
                onTap: () => onSelectStatus('RESOLVED'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _StatMetricCard(
                label: 'Assigned',
                count: stats.assigned,
                icon: Icons.manage_accounts_outlined,
                accentColor: AppColors.primaryDark,
                onTap: () => onSelectStatus('ASSIGNED'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _StatMetricCard(
                label: 'High Priority',
                count: stats.highPriority,
                icon: Icons.flag_outlined,
                accentColor: AppColors.error,
                onTap: () => onSelectPriority('HIGH'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),

        // Tertiary row: Escalated, Reopened, Closed
        Row(
          children: [
            Expanded(
              child: _StatMetricCard(
                label: 'Escalated',
                count: stats.escalated,
                icon: Icons.priority_high,
                accentColor: AppColors.error,
                onTap: () => onSelectStatus('ESCALATED'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _StatMetricCard(
                label: 'Reopened',
                count: stats.reopened,
                icon: Icons.restart_alt,
                accentColor: Colors.deepOrange,
                onTap: () => onSelectStatus('REOPENED'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _StatMetricCard(
                label: 'Closed',
                count: stats.closed,
                icon: Icons.lock_outline,
                accentColor: AppColors.textSecondary,
                onTap: () => onSelectStatus('CLOSED'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatMetricCard extends StatelessWidget {
  const _StatMetricCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 16, color: accentColor),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: count > 0 ? accentColor : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: AppTextStyles.headingMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Access', style: AppTextStyles.headingSmall),
        const SizedBox(height: AppDimensions.spacingSmall),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.assignment_outlined,
                title: 'Complaints',
                subtitle: 'Manage all tickets',
                onTap: () => context.go(AppRoutes.adminComplaints),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.campaign_outlined,
                title: 'Announcements',
                subtitle: 'Campus broadcasts',
                onTap: () => context.go(AppRoutes.adminAnnouncements),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        _QuickActionCard(
          icon: Icons.badge_outlined,
          title: 'Supervisor Management',
          subtitle: 'Create & manage department staff',
          onTap: () => context.push(AppRoutes.adminSupervisors),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.standardCardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentComplaintsSection extends StatelessWidget {
  const _RecentComplaintsSection({
    required this.complaints,
    required this.totalCount,
    required this.onViewAll,
  });

  final List<Complaint> complaints;
  final int totalCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Complaints', style: AppTextStyles.headingSmall),
            InkWell(
              onTap: onViewAll,
              child: Text(
                'View All ($totalCount)',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        if (complaints.isEmpty)
          const AppCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 40,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No complaints submitted yet',
                      style: AppTextStyles.headingSmall,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complaints submitted by students will appear here in real time.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: complaints.map((complaint) {
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.spacingMedium,
                ),
                child: AdminComplaintCard(complaint: complaint),
              );
            }).toList(),
          ),
      ],
    );
  }
}
