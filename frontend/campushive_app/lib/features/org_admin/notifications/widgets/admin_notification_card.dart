import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/notification.dart';
import '../../../student/home/widgets/feed_card_shell.dart';

class AdminNotificationCard extends StatelessWidget {
  const AdminNotificationCard({
    required this.notification,
    required this.onTap,
    required this.onMarkAsRead,
    required this.onDelete,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;

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
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
            width: isUnread ? 1.5 : 1.0,
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
                          margin: const EdgeInsets.only(right: 4),
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
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isUnread) ...[
                        TextButton.icon(
                          onPressed: onMarkAsRead,
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Mark read'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: AppColors.primary,
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.error,
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }
}
