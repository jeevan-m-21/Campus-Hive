import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/feed_item.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/home_feed_provider.dart';
import '../widgets/student_app_bar.dart';
import 'widgets/announcement_feed_card.dart';
import 'widgets/complaint_feed_card.dart';
import 'widgets/feed_card_shell.dart';
import 'widgets/lost_found_feed_card.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const _StudentDashboardView();
}

class _StudentDashboardView extends StatelessWidget {
  const _StudentDashboardView();

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthProvider>().session?.user ??
        const <String, dynamic>{};
    final name = _displayValue(user['full_name']);
    final identifier = _displayValue(user['usn_or_employee_id']);
    final imageUrl = _displayValue(user['profile_image']);

    return Scaffold(
      appBar: StudentAppBar(
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              context.read<HomeFeedProvider>().loadFeed(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            children: [
              _GreetingCard(
                name: name,
                identifier: identifier,
                imageUrl: imageUrl,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              _PrimaryActions(
                onReportIssue: () => context.push(AppRoutes.studentReportIssue),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Campus Feed', style: AppTextStyles.headingSmall),
                  Text(
                    'Last 7 days',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              const _HomeFeedSection(),
            ],
          ),
        ),
      ),
    );
  }

  static String _displayValue(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? '' : text;
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.name,
    required this.identifier,
    required this.imageUrl,
  });

  final String name;
  final String identifier;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final greetingName = name.isEmpty ? 'there' : name;
    return AppCard(
      child: Row(
        children: [
          imageUrl.isEmpty
              ? const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.divider,
                  child: Icon(
                    Icons.person_outline,
                    color: AppColors.textSecondary,
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
                const SizedBox(height: AppDimensions.spacingSmall),
                if (identifier.isNotEmpty)
                  Text(identifier, style: AppTextStyles.label),
                const SizedBox(height: AppDimensions.spacingSmall),
                const Text(
                  'Keep up with recent activity across your campus.',
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

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.onReportIssue});

  final VoidCallback onReportIssue;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData('Report New Issue', Icons.add_task_outlined, onReportIssue),
      _ActionData(
        'Lost & Found',
        Icons.search_outlined,
        () => context.go(AppRoutes.studentLostFound),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = actions
            .map((action) => _ActionButton(data: action))
            .toList();
        if (constraints.maxWidth < 520) {
          return Column(
            children: buttons
                .map(
                  (button) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimensions.spacingSmall,
                    ),
                    child: button,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: buttons
              .map(
                (button) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: AppDimensions.spacingSmall,
                    ),
                    child: button,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ActionData {
  const _ActionData(this.label, this.icon, this.onPressed);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.data});

  final _ActionData data;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: data.label,
      icon: data.icon,
      onPressed: data.onPressed,
      expand: true,
    );
  }
}

class _HomeFeedSection extends StatelessWidget {
  const _HomeFeedSection();

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<HomeFeedProvider>();

    if (feedProvider.isLoading && feedProvider.isEmpty) {
      return const SizedBox(height: 220, child: AppLoader());
    }

    if (feedProvider.errorMessage != null && feedProvider.isEmpty) {
      return EmptyState(
        title: 'Could not load campus feed',
        message: feedProvider.errorMessage,
        actionLabel: 'Retry',
        onAction: () => feedProvider.loadFeed(refresh: true),
      );
    }

    if (feedProvider.isEmpty) {
      return const EmptyState(
        title: 'No recent activity',
        message:
            'New complaints, lost & found posts, and announcements will appear here.',
        icon: Icons.inbox_outlined,
      );
    }

    return Column(
      children: feedProvider.items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          child: switch (item) {
            ComplaintFeedItem(:final complaint) => ComplaintFeedCard(
              complaint: complaint,
            ),
            LostFoundFeedItem(:final item) => LostFoundFeedCard(item: item),
            AnnouncementFeedItem(:final announcement) => AnnouncementFeedCard(
              item: announcement,
            ),
          },
        );
      }).toList(),
    );
  }
}
