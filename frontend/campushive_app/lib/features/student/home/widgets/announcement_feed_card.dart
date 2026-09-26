import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/announcement.dart';
import '../../../../providers/announcement_provider.dart';
import '../../../../providers/home_feed_provider.dart';
import 'feed_card_shell.dart';

class AnnouncementFeedCard extends StatelessWidget {
  const AnnouncementFeedCard({required this.item, super.key});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    HomeFeedProvider? homeFeedProvider;
    AnnouncementProvider? announcementProvider;
    try {
      homeFeedProvider = context.watch<HomeFeedProvider>();
    } catch (_) {}
    try {
      announcementProvider = context.watch<AnnouncementProvider>();
    } catch (_) {}

    final isLiked = homeFeedProvider?.isAnnouncementLiked(item) ?? item.isLiked;
    final likeCount =
        homeFeedProvider?.getAnnouncementLikeCount(item) ?? item.likeCount;

    final hasImage =
        item.attachmentType == 'IMAGE' &&
        item.attachmentUrl != null &&
        item.attachmentUrl!.isNotEmpty;

    return FeedCardShell(
      authorName: null,
      typeLabel: 'Announcement',
      typeColor: item.isImportant ? AppColors.error : AppColors.info,
      createdAt: item.createdAt,
      fallbackIcon: Icons.campaign_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.title, style: AppTextStyles.headingSmall),
              ),
              if (item.isImportant) ...[
                const SizedBox(width: AppDimensions.spacingSmall),
                const FeedBadge(label: 'IMPORTANT', color: AppColors.error),
              ],
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (hasImage) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            FeedCardImage(imageUrl: item.attachmentUrl!),
          ],
          const SizedBox(height: AppDimensions.spacingMedium),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (homeFeedProvider != null) {
                    homeFeedProvider.toggleAnnouncementLike(
                      item.announcementId,
                    );
                  } else if (announcementProvider != null) {
                    announcementProvider.toggleLike(item.announcementId);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$likeCount',
                        style: AppTextStyles.label.copyWith(
                          fontWeight: isLiked
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isLiked
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (item.attachmentType != 'NONE') ...[
                const Spacer(),
                FeedChip(
                  label: item.attachmentType,
                  icon: item.attachmentType == 'PDF'
                      ? Icons.picture_as_pdf_outlined
                      : item.attachmentType == 'IMAGE'
                      ? Icons.image_outlined
                      : Icons.link_outlined,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
