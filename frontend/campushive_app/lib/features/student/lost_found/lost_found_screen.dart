import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/lost_found.dart';
import '../../../providers/lost_found_provider.dart';
import '../widgets/student_app_bar.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LostFoundProvider()..load(),
      child: const _LostFoundView(),
    );
  }
}

class _LostFoundView extends StatelessWidget {
  const _LostFoundView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LostFoundProvider>();
    return Scaffold(
      appBar: const StudentAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.push<bool>(
            AppRoutes.studentReportLostFound,
          );
          if (created == true && context.mounted) {
            context.read<LostFoundProvider>().load(refresh: true);
          }
        },
        tooltip: 'Report Lost & Found',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          children: [
            const Text('Lost & Found', style: AppTextStyles.headingLarge),
            const SizedBox(height: AppDimensions.spacingSmall),
            const Text(
              'Browse recent lost and found items on campus.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => provider.setMineOnly(false),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !provider.isMineOnly
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'All Items',
                          style: AppTextStyles.label.copyWith(
                            color: !provider.isMineOnly
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => provider.setMineOnly(true),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: provider.isMineOnly
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'My Lost & Found',
                          style: AppTextStyles.label.copyWith(
                            color: provider.isMineOnly
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            AppTextField(
              label: 'Search items',
              hint: 'Search title, description, or location',
              prefixIcon: Icons.search_outlined,
              onChanged: (value) => provider.setFilters(search: value),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            _TypeFilters(provider: provider),
            const SizedBox(height: AppDimensions.spacingLarge),
            if (provider.isLoading && provider.items.isEmpty)
              const SizedBox(height: 220, child: AppLoader())
            else if (provider.errorMessage != null && provider.items.isEmpty)
              EmptyState(
                title: 'Could not load items',
                message: provider.errorMessage,
                actionLabel: 'Retry',
                onAction: () => provider.load(refresh: true),
              )
            else if (provider.items.isEmpty)
              const EmptyState(
                title: 'No items found',
                message: 'Lost and found posts will appear here.',
                icon: Icons.search_off_outlined,
              )
            else ...[
              ...provider.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingSmall,
                  ),
                  child: _LostFoundCard(item: item),
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

class _TypeFilters extends StatelessWidget {
  const _TypeFilters({required this.provider});
  final LostFoundProvider provider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in const [
            (null, 'All'),
            ('LOST', 'Lost'),
            ('FOUND', 'Found'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.$2),
                selected: provider.itemTypeFilter == entry.$1,
                onSelected: (_) => provider.setFilters(itemType: entry.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _LostFoundCard extends StatelessWidget {
  const _LostFoundCard({required this.item});
  final LostFound item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.images.isNotEmpty ? item.images.first.imageUrl : null;
    final typeColor = item.itemType == 'LOST'
        ? AppColors.error
        : AppColors.success;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (imageUrl != null && imageUrl.isNotEmpty)
            const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              _Badge(label: item.itemType, color: typeColor),
              const Spacer(),
              _Badge(
                label: item.status,
                color: item.status == 'OPEN'
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Text(item.title, style: AppTextStyles.headingSmall),
          const SizedBox(height: 4),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Wrap(
            spacing: AppDimensions.spacingMedium,
            runSpacing: 4,
            children: [
              if (item.category != null)
                _Meta(Icons.category_outlined, item.category!),
              if (item.location != null)
                _Meta(Icons.location_on_outlined, item.location!),
              if (item.dateOfIncident != null)
                _Meta(Icons.event_outlined, _date(item.dateOfIncident!)),
            ],
          ),
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

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: AppDimensions.iconSmall, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: AppTextStyles.caption),
    ],
  );
}

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
