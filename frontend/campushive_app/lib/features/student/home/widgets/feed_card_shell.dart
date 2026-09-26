import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

String resolveImageUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  final base = AppConstants.apiBaseUrl.replaceAll('/api/v1', '');
  return '$base$url';
}

String formatRelativeTime(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.isNegative || diff.inSeconds < 60) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h';
  }
  if (diff.inDays == 1) {
    return 'Yesterday';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d';
  }
  return '${date.day}/${date.month}/${date.year}';
}

class FeedCardShell extends StatelessWidget {
  const FeedCardShell({
    required this.authorName,
    required this.typeLabel,
    required this.typeColor,
    required this.createdAt,
    required this.child,
    this.avatarUrl,
    this.fallbackIcon = Icons.person_outline,
    this.onTap,
    super.key,
  });

  final String? authorName;
  final String typeLabel;
  final Color typeColor;
  final DateTime? createdAt;
  final String? avatarUrl;
  final IconData fallbackIcon;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final timeStr = formatRelativeTime(createdAt);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _UserAvatar(avatarUrl: avatarUrl, fallbackIcon: fallbackIcon),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (authorName != null && authorName!.isNotEmpty)
                      Text(
                        authorName!,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                            typeLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '•  $timeStr',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          child,
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.avatarUrl, required this.fallbackIcon});

  final String? avatarUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.divider,
        backgroundImage: NetworkImage(resolveImageUrl(avatarUrl!)),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.divider,
      child: Icon(fallbackIcon, size: 20, color: AppColors.textSecondary),
    );
  }
}

class FeedCardImage extends StatelessWidget {
  const FeedCardImage({required this.imageUrl, this.height = 180, super.key});

  final String imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fullUrl = resolveImageUrl(imageUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        fullUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          width: double.infinity,
          color: AppColors.divider,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class FeedChip extends StatelessWidget {
  const FeedChip({required this.label, required this.icon, super.key});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class FeedBadge extends StatelessWidget {
  const FeedBadge({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
