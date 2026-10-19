import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/notification.dart';
import '../../../providers/notification_provider.dart';

class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() =>
      _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState
    extends State<StudentNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => provider.markAllAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.load(refresh: true),
          child: _buildBody(context, provider),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationProvider provider) {
    if (provider.isLoading && provider.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (provider.errorMessage != null && provider.isEmpty) {
      return EmptyState(
        title: 'Could not load notifications',
        message: provider.errorMessage,
        actionLabel: 'Retry',
        onAction: () => provider.load(refresh: true),
      );
    }

    if (provider.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: EmptyState(
            title: 'No notifications',
            message:
                'Updates on your complaints, task assignments, and campus notices will appear here.',
            icon: Icons.notifications_off_outlined,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
      itemCount: provider.notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notif = provider.notifications[index];
        return Dismissible(
          key: ValueKey(notif.notificationId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => provider.deleteNotification(notif.notificationId),
          child: _NotificationCard(
            notification: notif,
            onTap: () {
              if (!notif.isRead) {
                provider.markAsRead(notif.notificationId);
              }
              final type = notif.notificationType.toUpperCase();
              if (type == 'COMPLAINT' && notif.referenceId != null) {
                context.push(
                  AppRoutes.studentComplaintDetail(notif.referenceId!),
                );
              } else if (type == 'ANNOUNCEMENT') {
                if (notif.referenceId != null) {
                  context.push(
                    AppRoutes.studentAnnouncementDetail(notif.referenceId!),
                  );
                } else {
                  context.go(AppRoutes.studentAnnouncements);
                }
              } else if (type == 'LOST_FOUND' && notif.referenceId != null) {
                context.push(
                  AppRoutes.studentLostFoundDetail(notif.referenceId!),
                );
              }
            },
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _typeColor(
                  notification.notificationType,
                ).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _typeIcon(notification.notificationType),
                color: _typeColor(notification.notificationType),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: isUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (notification.createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatRelativeTime(notification.createdAt!),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: isUnread
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'COMPLAINT':
        return AppColors.primary;
      case 'ANNOUNCEMENT':
        return Colors.orange;
      case 'LOST_FOUND':
        return Colors.teal;
      case 'CHAT':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  static IconData _typeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'COMPLAINT':
        return Icons.assignment_outlined;
      case 'ANNOUNCEMENT':
        return Icons.campaign_outlined;
      case 'LOST_FOUND':
        return Icons.search_outlined;
      case 'CHAT':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  static String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
