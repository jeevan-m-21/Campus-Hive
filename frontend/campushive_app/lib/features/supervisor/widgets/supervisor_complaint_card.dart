import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/complaint.dart';
import '../../student/home/widgets/feed_card_shell.dart';

class SupervisorComplaintCard extends StatelessWidget {
  const SupervisorComplaintCard({
    required this.complaint,
    this.compact = false,
    super.key,
  });

  final Complaint complaint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FeedCardShell(
      authorName: complaint.studentName?.isNotEmpty == true
          ? complaint.studentName
          : 'Student',
      typeLabel: 'Assigned Task',
      typeColor: AppColors.primary,
      createdAt: complaint.createdAt,
      fallbackIcon: Icons.person_outline,
      onTap: () => context.push(
        AppRoutes.supervisorComplaintDetail(complaint.complaintId),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(complaint.title, style: AppTextStyles.headingSmall),
              ),
              const SizedBox(width: 8),
              Text(
                '#${complaint.complaintId}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (complaint.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              complaint.description,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (!compact &&
              complaint.imageUrl != null &&
              complaint.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            FeedCardImage(imageUrl: complaint.imageUrl!),
          ],
          const SizedBox(height: AppDimensions.spacingMedium),
          Wrap(
            spacing: AppDimensions.spacingSmall,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (complaint.departmentName != null &&
                  complaint.departmentName!.isNotEmpty)
                FeedChip(
                  label: complaint.departmentName!,
                  icon: Icons.apartment_outlined,
                ),
              if (complaint.location != null && complaint.location!.isNotEmpty)
                FeedChip(
                  label: complaint.location!,
                  icon: Icons.location_on_outlined,
                ),
              if (complaint.finalPriority != null &&
                  complaint.finalPriority!.isNotEmpty)
                FeedBadge(
                  label: _humanize(complaint.finalPriority!),
                  color: _priorityColor(complaint.finalPriority!),
                ),
              FeedBadge(
                label: _humanize(complaint.status),
                color: _statusColor(complaint.status),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Workspace',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (complaint.deadline != null) ...[
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due ${_formatDate(complaint.deadline!)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _humanize(String value) => value
      .toLowerCase()
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
      case 'CLOSED':
        return AppColors.success;
      case 'ESCALATED':
        return AppColors.error;
      case 'IN_PROGRESS':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  static Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return AppColors.error;
      case 'MEDIUM':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  static String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
