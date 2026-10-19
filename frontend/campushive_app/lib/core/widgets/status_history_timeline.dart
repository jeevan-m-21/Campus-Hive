import 'package:flutter/material.dart';

import '../../models/complaint_status_history.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'app_loader.dart';

class StatusHistoryTimeline extends StatelessWidget {
  const StatusHistoryTimeline({
    required this.history,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final List<ComplaintStatusHistory> history;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.timeline_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Status History (${history.length})',
                style: AppTextStyles.headingSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading && history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: AppLoader()),
      );
    }

    if (errorMessage != null && history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No status updates recorded yet.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++)
            _TimelineItem(
              entry: history[i],
              isFirst: i == 0,
              isLast: i == history.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final ComplaintStatusHistory entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(entry.newStatus);

    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 13,
            top: 24,
            bottom: 0,
            child: Container(
              width: 2,
              color: AppColors.border,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicator icon
            SizedBox(
              width: 28,
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      _statusIcon(entry.newStatus),
                      size: 12,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content block
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status transition chips / text
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (entry.oldStatus != null &&
                          entry.oldStatus!.isNotEmpty) ...[
                        _StatusPill(
                          label: _humanize(entry.oldStatus!),
                          color: AppColors.textSecondary,
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ],
                      _StatusPill(
                        label: _humanize(entry.newStatus),
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Actor and Timestamp row
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (entry.updaterName != null &&
                          entry.updaterName!.isNotEmpty)
                        Text(
                          'by ${entry.updaterName}',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      if (entry.updaterName != null && entry.updatedAt != null)
                        Text('•', style: AppTextStyles.caption),
                      if (entry.updatedAt != null)
                        Text(
                          _formatDateTime(entry.updatedAt!),
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                  // Remarks (if available)
                  if (entry.remarks != null && entry.remarks!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.divider.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        entry.remarks!.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.warning;
      case 'ASSIGNED':
        return Colors.indigo;
      case 'IN_PROGRESS':
        return AppColors.primary;
      case 'RESOLVED':
        return AppColors.success;
      case 'REOPENED':
        return Colors.deepOrange;
      case 'ESCALATED':
        return AppColors.error;
      case 'CLOSED':
        return Colors.grey.shade700;
      default:
        return AppColors.textSecondary;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.hourglass_top_outlined;
      case 'ASSIGNED':
        return Icons.person_outline;
      case 'IN_PROGRESS':
        return Icons.construction_outlined;
      case 'RESOLVED':
        return Icons.check_circle_outline;
      case 'REOPENED':
        return Icons.replay_outlined;
      case 'ESCALATED':
        return Icons.warning_amber_rounded;
      case 'CLOSED':
        return Icons.done_all;
      default:
        return Icons.circle;
    }
  }

  static String _humanize(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    final day = local.day;
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $ampm';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
