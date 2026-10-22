import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_permission_banner.dart';
import '../../../models/notification.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../student/home/widgets/feed_card_shell.dart';

/// Unified notification view component shared across Student, Supervisor, and Admin roles.
class UnifiedNotificationsView extends StatefulWidget {
  const UnifiedNotificationsView({
    this.role,
    this.onBack,
    this.fallbackHomeRoute,
    this.onNotificationTap,
    super.key,
  });

  final String? role;
  final VoidCallback? onBack;
  final String? fallbackHomeRoute;
  final void Function(AppNotification notification)? onNotificationTap;

  @override
  State<UnifiedNotificationsView> createState() =>
      _UnifiedNotificationsViewState();
}

class _UnifiedNotificationsViewState extends State<UnifiedNotificationsView> {
  bool _isMarkingAllRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().load(refresh: true);
      }
    });
  }

  String _getEffectiveRole() {
    if (widget.role != null && widget.role!.isNotEmpty) {
      return widget.role!.toUpperCase();
    }
    try {
      final authRole = context.read<AuthProvider>().session?.role.toUpperCase();
      if (authRole != null && authRole.isNotEmpty) {
        return authRole;
      }
    } catch (_) {}
    return 'STUDENT';
  }

  String _defaultHomeRoute(String role) {
    switch (role) {
      case 'SUPERVISOR':
        return AppRoutes.supervisorDashboard;
      case 'ORG_ADMIN':
      case 'SUPER_ADMIN':
        return AppRoutes.adminDashboard;
      default:
        return AppRoutes.studentDashboard;
    }
  }

  Future<void> _handleNotificationTap(
    AppNotification notification,
    String role,
  ) async {
    final provider = context.read<NotificationProvider>();
    if (!notification.isRead) {
      try {
        await provider.markAsRead(notification.notificationId);
      } catch (_) {}
    }

    if (!mounted) return;

    if (widget.onNotificationTap != null) {
      widget.onNotificationTap!(notification);
      return;
    }

    final type = notification.notificationType.toUpperCase();
    final normalizedRole = role.toUpperCase();

    if (type == 'COMPLAINT' && notification.referenceId != null) {
      if (normalizedRole == 'SUPERVISOR') {
        context.push(
          AppRoutes.supervisorComplaintDetail(notification.referenceId!),
        );
      } else if (normalizedRole == 'ORG_ADMIN' ||
          normalizedRole == 'SUPER_ADMIN') {
        context.push(
          AppRoutes.adminComplaintDetail(notification.referenceId!),
        );
      } else {
        context.push(
          AppRoutes.studentComplaintDetail(notification.referenceId!),
        );
      }
    } else if (type == 'ANNOUNCEMENT') {
      if (normalizedRole == 'STUDENT') {
        if (notification.referenceId != null) {
          context.push(
            AppRoutes.studentAnnouncementDetail(notification.referenceId!),
          );
        } else {
          context.go(AppRoutes.studentAnnouncements);
        }
      } else if (normalizedRole == 'SUPERVISOR') {
        context.go(AppRoutes.supervisorAnnouncements);
      } else {
        context.go(AppRoutes.adminAnnouncements);
      }
    } else if (type == 'LOST_FOUND' && notification.referenceId != null) {
      context.push(
        AppRoutes.studentLostFoundDetail(notification.referenceId!),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllRead) return;
    setState(() => _isMarkingAllRead = true);

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
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final role = _getEffectiveRole();
    final homeRoute = widget.fallbackHomeRoute ?? _defaultHomeRoute(role);
    final unreadCount = provider.unreadCount;
    final allCount = provider.allTotal;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          color: AppColors.textPrimary,
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go(homeRoute);
            }
          },
        ),
        title: const Text(
          'Notifications',
          style: AppTextStyles.headingMedium,
        ),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                key: const Key('mark_all_as_read_button'),
                onPressed: _isMarkingAllRead ? null : _markAllAsRead,
                icon: _isMarkingAllRead
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.done_all,
                        size: 16,
                        color: AppColors.primary,
                      ),
                label: Text(
                  _isMarkingAllRead ? 'Marking...' : 'Mark all read',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const NotificationPermissionBanner(
              margin: EdgeInsets.fromLTRB(
                AppDimensions.screenHorizontalPadding,
                AppDimensions.spacingSmall,
                AppDimensions.screenHorizontalPadding,
                AppDimensions.spacingSmall,
              ),
            ),
            // Filter Controls: All (count) and Unread (count)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenHorizontalPadding,
                vertical: 10,
              ),
              child: Row(
                children: [
                  ChoiceChip(
                    key: const Key('filter_tab_all'),
                    label: Text(
                      'All ($allCount)',
                      style: TextStyle(
                        color: !provider.unreadOnly
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: !provider.unreadOnly
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    selected: !provider.unreadOnly,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: !provider.unreadOnly
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    onSelected: (selected) {
                      if (selected) provider.setUnreadOnly(false);
                    },
                  ),
                  const SizedBox(width: AppDimensions.spacingSmall),
                  ChoiceChip(
                    key: const Key('filter_tab_unread'),
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
                          'Unread ($unreadCount)',
                          style: TextStyle(
                            color: provider.unreadOnly
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: provider.unreadOnly
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    selected: provider.unreadOnly,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: provider.unreadOnly
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    onSelected: (selected) {
                      if (selected) provider.setUnreadOnly(true);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => provider.load(refresh: true),
                child: _buildBody(context, provider, role),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationProvider provider,
    String role,
  ) {
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
                  : 'Updates on your complaints, task assignments, and campus notices will appear here.',
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
          onDismissed: (_) {
            provider.deleteNotification(notif.notificationId).catchError((e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete notification: $e'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
          },
          child: StandardNotificationCard(
            notification: notif,
            onTap: () => _handleNotificationTap(notif, role),
          ),
        );
      },
    );
  }
}

/// Standardized notification card component matching CampusHive visual language.
class StandardNotificationCard extends StatelessWidget {
  const StandardNotificationCard({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final typeColor = _getTypeColor(notification.notificationType);
    final typeIcon = _getTypeIcon(notification.notificationType);

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
                ? AppColors.primary.withValues(alpha: 0.28)
                : AppColors.border,
            width: isUnread ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, color: typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notification.notificationType.toUpperCase(),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (notification.createdAt != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '•  ${formatRelativeTime(notification.createdAt)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.title,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'COMPLAINT':
        return Icons.assignment_outlined;
      case 'ANNOUNCEMENT':
        return Icons.campaign_outlined;
      case 'CHAT':
        return Icons.chat_bubble_outline;
      case 'LOST_FOUND':
        return Icons.search_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'COMPLAINT':
        return AppColors.primary;
      case 'ANNOUNCEMENT':
        return AppColors.warning;
      case 'CHAT':
        return AppColors.info;
      case 'LOST_FOUND':
        return Colors.teal;
      default:
        return AppColors.primary;
    }
  }
}
