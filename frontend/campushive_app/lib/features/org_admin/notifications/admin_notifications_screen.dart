import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/notification.dart';
import '../../../providers/notification_provider.dart';
import 'widgets/admin_notification_card.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().load(refresh: true);
      }
    });
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    final provider = context.read<NotificationProvider>();
    if (!notification.isRead) {
      try {
        await provider.markAsRead(notification.notificationId);
      } catch (_) {}
    }

    if (!mounted) return;

    final type = notification.notificationType.toUpperCase();
    if (type == 'COMPLAINT' && notification.referenceId != null) {
      context.push(AppRoutes.adminComplaintDetail(notification.referenceId!));
    } else if (type == 'ANNOUNCEMENT') {
      context.go(AppRoutes.adminAnnouncements);
    }
  }

  Future<void> _markSingleAsRead(AppNotification notification) async {
    try {
      await context.read<NotificationProvider>().markAsRead(
        notification.notificationId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark as read: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final count = await context.read<NotificationProvider>().markAllAsRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '$count notification${count == 1 ? "" : "s"} marked as read.'
                : 'All notifications marked as read.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark all as read: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(AppNotification notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text(
          'Are you sure you want to delete this notification?\n\n"${notification.title}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<NotificationProvider>().deleteNotification(
        notification.notificationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete notification: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.adminDashboard);
            }
          },
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(
                Icons.done_all,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
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
          color: AppColors.primary,
          onRefresh: () => provider.load(refresh: true),
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                        provider.isLoading && provider.isEmpty
                            ? 'All'
                            : 'All (${provider.total})',
                        style: TextStyle(
                          color: !provider.unreadOnly
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: !provider.unreadOnly
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                      selected: !provider.unreadOnly,
                      selectedColor: AppColors.primary,
                      onSelected: (selected) {
                        if (selected) provider.setUnreadOnly(false);
                      },
                    ),
                    const SizedBox(width: AppDimensions.spacingSmall),
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mark_email_unread_outlined,
                            size: 14,
                            color: provider.unreadOnly
                                ? Colors.white
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Unread (${provider.unreadCount})',
                            style: TextStyle(
                              color: provider.unreadOnly
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: provider.unreadOnly
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      selected: provider.unreadOnly,
                      selectedColor: AppColors.primary,
                      onSelected: (selected) {
                        if (selected) provider.setUnreadOnly(true);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(child: _buildBody(context, provider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationProvider provider) {
    if (provider.isLoading && provider.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (provider.errorMessage != null && provider.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyState(
            title: 'Could not load notifications',
            message: provider.errorMessage,
            actionLabel: 'Retry',
            onAction: () => provider.load(refresh: true),
          ),
        ),
      );
    }

    if (provider.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenHorizontalPadding,
            ),
            child: EmptyState(
              title: provider.unreadOnly
                  ? 'No unread notifications'
                  : 'No notifications',
              message: provider.unreadOnly
                  ? 'You have caught up with all campus alerts and notices.'
                  : 'Official broadcasts, alerts, and system notifications will appear here.',
              icon: provider.unreadOnly
                  ? Icons.done_all_outlined
                  : Icons.notifications_off_outlined,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
      itemCount: provider.notifications.length + (provider.hasNext ? 1 : 0),
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppDimensions.spacingSmall),
      itemBuilder: (context, index) {
        if (index == provider.notifications.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingMedium,
            ),
            child: AppButton(
              label: provider.isLoadingPage ? 'Loading...' : 'Load more',
              isLoading: provider.isLoadingPage,
              onPressed: provider.loadNextPage,
              expand: true,
            ),
          );
        }

        final notif = provider.notifications[index];
        return AdminNotificationCard(
          notification: notif,
          onTap: () => _handleNotificationTap(notif),
          onMarkAsRead: () => _markSingleAsRead(notif),
          onDelete: () => _confirmDelete(notif),
        );
      },
    );
  }
}
