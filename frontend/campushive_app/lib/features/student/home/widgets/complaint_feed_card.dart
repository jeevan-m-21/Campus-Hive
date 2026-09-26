import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/complaint.dart';
import '../../../../providers/home_feed_provider.dart';
import 'feed_card_shell.dart';

class ComplaintFeedCard extends StatelessWidget {
  const ComplaintFeedCard({required this.complaint, super.key});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<HomeFeedProvider>();
    final isSupporting = feedProvider.isSupportingComplaint(
      complaint.complaintId,
    );
    final isSupported = feedProvider.isComplaintSupported(complaint);
    final supportCount = feedProvider.getSupportCount(complaint);

    return FeedCardShell(
      authorName: complaint.studentName?.isNotEmpty == true
          ? complaint.studentName
          : 'Student',
      typeLabel: 'Complaint',
      typeColor: AppColors.primary,
      createdAt: complaint.createdAt,
      fallbackIcon: Icons.person_outline,
      onTap: () =>
          context.push(AppRoutes.studentComplaintDetail(complaint.complaintId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(complaint.title, style: AppTextStyles.headingSmall),
          if (complaint.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              complaint.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (complaint.imageUrl != null && complaint.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            FeedCardImage(imageUrl: complaint.imageUrl!),
          ],
          const SizedBox(height: AppDimensions.spacingMedium),
          Wrap(
            spacing: AppDimensions.spacingMedium,
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
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: isSupporting
                    ? null
                    : () async {
                        final error = await feedProvider.supportComplaint(
                          complaint.complaintId,
                        );
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      if (isSupporting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        Icon(
                          isSupported
                              ? Icons.thumb_up_alt
                              : Icons.thumb_up_alt_outlined,
                          size: 20,
                          color: isSupported
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '$supportCount',
                        style: AppTextStyles.label.copyWith(
                          fontWeight: isSupported
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSupported
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMedium),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push(
                  AppRoutes.studentComplaintDetail(complaint.complaintId),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 19,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Text('Comment', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '#${complaint.complaintId}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
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
}
