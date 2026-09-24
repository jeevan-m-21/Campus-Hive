import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/announcement.dart';
import '../../../providers/announcement_provider.dart';
import '../widgets/student_app_bar.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AnnouncementProvider()..load(),
      child: const _AnnouncementsView(),
    );
  }
}

class _AnnouncementsView extends StatelessWidget {
  const _AnnouncementsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnnouncementProvider>();
    return Scaffold(
      appBar: const StudentAppBar(),
      body: RefreshIndicator(
        onRefresh: () => provider.load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          children: [
            const Text('Announcements', style: AppTextStyles.headingLarge),
            const SizedBox(height: AppDimensions.spacingSmall),
            const Text(
              'Stay up to date with official campus news.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            ChoiceChip(
              label: const Text('Important only'),
              selected: provider.importantOnly,
              onSelected: provider.setImportantOnly,
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            if (provider.isLoading && provider.items.isEmpty)
              const SizedBox(height: 220, child: AppLoader())
            else if (provider.errorMessage != null && provider.items.isEmpty)
              EmptyState(
                title: 'Could not load announcements',
                message: provider.errorMessage,
                actionLabel: 'Retry',
                onAction: () => provider.load(refresh: true),
              )
            else if (provider.items.isEmpty)
              const EmptyState(
                title: 'No announcements yet',
                message: 'Official campus updates will appear here.',
                icon: Icons.campaign_outlined,
              )
            else ...[
              ...provider.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingSmall,
                  ),
                  child: _AnnouncementCard(item: item),
                ),
              ),
              if (provider.hasNext)
                AppButton(
                  label: provider.isLoadingPage ? 'Loading...' : 'Load more',
                  isLoading: provider.isLoadingPage,
                  onPressed: provider.loadNextPage,
                  expand: true,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});
  final Announcement item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.isImportant)
                const _Badge(label: 'IMPORTANT', color: AppColors.error),
              const Spacer(),
              if (item.createdAt != null)
                Text(_date(item.createdAt!), style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Text(item.title, style: AppTextStyles.headingSmall),
          const SizedBox(height: 4),
          Text(
            item.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
          if (item.attachmentType != 'NONE') ...[
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              'Attachment: ${item.attachmentType}',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
  );
}

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
