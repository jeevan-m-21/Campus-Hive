import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/announcement.dart';
import '../../../../providers/announcement_provider.dart';
import '../../../student/home/widgets/feed_card_shell.dart';

class AdminAnnouncementCard extends StatelessWidget {
  const AdminAnnouncementCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final Announcement item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        item.attachmentType == 'IMAGE' &&
        item.attachmentUrl != null &&
        item.attachmentUrl!.isNotEmpty;

    final hasDocumentOrLink =
        (item.attachmentType == 'PDF' || item.attachmentType == 'LINK') &&
        item.attachmentUrl != null &&
        item.attachmentUrl!.isNotEmpty;

    return FeedCardShell(
      authorName: 'Administration',
      typeLabel: 'Announcement',
      typeColor: item.isImportant ? AppColors.error : AppColors.primary,
      createdAt: item.createdAt,
      fallbackIcon: Icons.campaign_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.headingSmall,
                          ),
                        ),
                        if (item.isImportant) ...[
                          const SizedBox(width: AppDimensions.spacingSmall),
                          const FeedBadge(
                            label: 'IMPORTANT',
                            color: AppColors.error,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Notice Actions',
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text('Edit Notice', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete Notice',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.description,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (hasImage) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            FeedCardImage(imageUrl: item.attachmentUrl!),
          ],
          if (hasDocumentOrLink) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    item.attachmentType == 'PDF'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.link_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.attachmentUrl!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.spacingMedium),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  context.read<AnnouncementProvider>().toggleLike(
                    item.announcementId,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: item.isLiked
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.likeCount}',
                        style: AppTextStyles.label.copyWith(
                          fontWeight: item.isLiked
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: item.isLiked
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (item.attachmentType != 'NONE') ...[
                const SizedBox(width: 8),
                FeedChip(
                  label: item.attachmentType,
                  icon: item.attachmentType == 'PDF'
                      ? Icons.picture_as_pdf_outlined
                      : item.attachmentType == 'IMAGE'
                      ? Icons.image_outlined
                      : Icons.link_outlined,
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Edit Announcement',
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.error,
                ),
                tooltip: 'Delete Announcement',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
