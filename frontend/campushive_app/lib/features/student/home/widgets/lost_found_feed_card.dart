import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/lost_found.dart';
import 'feed_card_shell.dart';

class LostFoundFeedCard extends StatelessWidget {
  const LostFoundFeedCard({required this.item, super.key});

  final LostFound item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.images.isNotEmpty ? item.images.first.imageUrl : null;
    final isLost = item.itemType.toUpperCase() == 'LOST';
    final typeColor = isLost ? AppColors.error : AppColors.success;
    final typeLabel = isLost ? 'Lost Item' : 'Found Item';

    return FeedCardShell(
      authorName: item.posterName?.isNotEmpty == true
          ? item.posterName
          : 'Campus Member',
      typeLabel: typeLabel,
      typeColor: typeColor,
      createdAt: item.createdAt,
      fallbackIcon: Icons.search_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: AppTextStyles.headingSmall),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            FeedCardImage(imageUrl: imageUrl),
          ],
          const SizedBox(height: AppDimensions.spacingMedium),
          Wrap(
            spacing: AppDimensions.spacingMedium,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.category != null && item.category!.isNotEmpty)
                FeedChip(label: item.category!, icon: Icons.category_outlined),
              if (item.location != null && item.location!.isNotEmpty)
                FeedChip(
                  label: item.location!,
                  icon: Icons.location_on_outlined,
                ),
              if (item.dateOfIncident != null)
                FeedChip(
                  label: _dateLabel(item.dateOfIncident!),
                  icon: Icons.event_outlined,
                ),
              FeedBadge(
                label: item.status.toUpperCase(),
                color: item.status.toUpperCase() == 'OPEN'
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
