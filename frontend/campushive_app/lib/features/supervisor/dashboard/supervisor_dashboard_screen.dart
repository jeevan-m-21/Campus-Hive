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
import '../../../providers/announcement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/supervisor_complaint_provider.dart';
import '../../student/home/widgets/announcement_feed_card.dart';
import '../../student/home/widgets/feed_card_shell.dart';
import '../widgets/supervisor_app_bar.dart';
import '../widgets/supervisor_complaint_card.dart';

class SupervisorDashboardScreen extends StatelessWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SupervisorDashboardView();
  }
}

class _SupervisorDashboardView extends StatelessWidget {
  const _SupervisorDashboardView();

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthProvider>().session?.user ??
        const <String, dynamic>{};
    final name = user['full_name']?.toString().trim() ?? 'Supervisor';
    final employeeId = user['usn_or_employee_id']?.toString().trim() ?? '';
    final imageUrl = user['profile_image']?.toString().trim() ?? '';

    return Scaffold(
      appBar: const SupervisorAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              context.read<SupervisorComplaintProvider>().loadComplaints(
                refresh: true,
              ),
              context.read<AnnouncementProvider>().load(refresh: true),
              context.read<NotificationProvider>().loadUnreadCount(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            children: [
              _SupervisorGreetingCard(
                name: name,
                employeeId: employeeId,
                imageUrl: imageUrl,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              const _WorkStatsSection(),
              const SizedBox(height: AppDimensions.spacingLarge),
              _SectionHeader(
                title: 'Assigned Complaints',
                actionLabel: 'View Task Queue',
                onAction: () => context.go(AppRoutes.supervisorQueue),
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              const _AssignedComplaintsFeed(),
              const SizedBox(height: AppDimensions.spacingLarge),
              _SectionHeader(
                title: 'Campus Announcements',
                actionLabel: 'View All',
                onAction: () => context.go(AppRoutes.supervisorAnnouncements),
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              const _DashboardAnnouncementsFeed(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupervisorGreetingCard extends StatelessWidget {
  const _SupervisorGreetingCard({
    required this.name,
    required this.employeeId,
    required this.imageUrl,
  });

  final String name;
  final String employeeId;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final greetingName = name.isEmpty ? 'Supervisor' : name;
    return AppCard(
      child: Row(
        children: [
          imageUrl.isEmpty
              ? const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.divider,
                  child: Icon(
                    Icons.badge_outlined,
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
                    'Employee ID: $employeeId',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Here are your assigned tasks and latest announcements.',
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

class _WorkStatsSection extends StatelessWidget {
  const _WorkStatsSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupervisorComplaintProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Activity & Workload', style: AppTextStyles.headingSmall),
        const SizedBox(height: AppDimensions.spacingSmall),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Assigned',
                count: provider.totalAssigned,
                icon: Icons.assignment_outlined,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _StatCard(
                label: 'Pending',
                count: provider.pendingCount,
                icon: Icons.pending_actions_outlined,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'In Progress',
                count: provider.inProgressCount,
                icon: Icons.sync_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: _StatCard(
                label: 'Resolved',
                count: provider.resolvedCount,
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        if (provider.escalatedCount > 0 ||
            provider.reopenedCount > 0 ||
            provider.closedCount > 0) ...[
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              if (provider.escalatedCount > 0)
                Expanded(
                  child: _StatCard(
                    label: 'Escalated',
                    count: provider.escalatedCount,
                    icon: Icons.priority_high_outlined,
                    color: AppColors.error,
                  ),
                ),
              if (provider.escalatedCount > 0 && provider.reopenedCount > 0)
                const SizedBox(width: AppDimensions.spacingSmall),
              if (provider.reopenedCount > 0)
                Expanded(
                  child: _StatCard(
                    label: 'Reopened',
                    count: provider.reopenedCount,
                    icon: Icons.replay_outlined,
                    color: AppColors.warning,
                  ),
                ),
              if (provider.closedCount > 0) ...[
                const SizedBox(width: AppDimensions.spacingSmall),
                Expanded(
                  child: _StatCard(
                    label: 'Closed',
                    count: provider.closedCount,
                    icon: Icons.lock_outline,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.headingSmall),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            children: [
              Text(
                actionLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssignedComplaintsFeed extends StatelessWidget {
  const _AssignedComplaintsFeed();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupervisorComplaintProvider>();

    if (provider.isLoading && provider.complaints.isEmpty) {
      return const SizedBox(height: 160, child: AppLoader());
    }

    if (provider.errorMessage != null && provider.complaints.isEmpty) {
      return EmptyState(
        title: 'Could not load tasks',
        message: provider.errorMessage,
        actionLabel: 'Retry',
        onAction: () => provider.loadComplaints(refresh: true),
      );
    }

    if (provider.complaints.isEmpty) {
      return const EmptyState(
        title: 'No assigned complaints',
        message: 'You have no complaints assigned at the moment.',
        icon: Icons.check_circle_outline,
      );
    }

    // Take top 4 recent assigned complaints
    final recent = provider.complaints.take(4).toList();

    return Column(
      children: recent.map((complaint) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          child: SupervisorComplaintCard(complaint: complaint),
        );
      }).toList(),
    );
  }
}

class _DashboardAnnouncementsFeed extends StatelessWidget {
  const _DashboardAnnouncementsFeed();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnnouncementProvider>();

    if (provider.isLoading && provider.items.isEmpty) {
      return const SizedBox(height: 120, child: AppLoader());
    }

    if (provider.items.isEmpty) {
      return const EmptyState(
        title: 'No announcements',
        message: 'Campus announcements published by Admin will appear here.',
        icon: Icons.campaign_outlined,
      );
    }

    final recent = provider.items.take(3).toList();

    return Column(
      children: recent.map((announcement) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          child: AnnouncementFeedCard(item: announcement),
        );
      }).toList(),
    );
  }
}
