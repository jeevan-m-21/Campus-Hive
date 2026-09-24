import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/lost_found.dart';
import '../../../services/lost_found_service.dart';
import '../widgets/student_app_bar.dart';

class MyLostFoundActivityScreen extends StatefulWidget {
  const MyLostFoundActivityScreen({super.key});

  @override
  State<MyLostFoundActivityScreen> createState() =>
      _MyLostFoundActivityScreenState();
}

class _MyLostFoundActivityScreenState extends State<MyLostFoundActivityScreen> {
  final _service = LostFoundService();
  List<LostFound> _items = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final page = await _service.fetchItems(page: 1, perPage: 100, mine: true);
      if (mounted) {
        setState(() {
          _items = page.items;
          _isLoading = false;
        });
      }
    } on LostFoundException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load your lost and found posts.';
          _isLoading = false;
        });
      }
    }
  }

  int _countType(String type) =>
      _items.where((item) => item.itemType.toUpperCase() == type).length;

  int _countStatus(String status) =>
      _items.where((item) => item.status.toUpperCase() == status).length;

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final lost = _countType('LOST');
    final found = _countType('FOUND');
    final open = _countStatus('OPEN');
    final closed = _countStatus('CLOSED');

    final stats = [
      _StatItem('Total', total, AppColors.info, Icons.inventory_2_outlined),
      _StatItem('Lost', lost, AppColors.error, Icons.search_off_outlined),
      _StatItem('Found', found, AppColors.success, Icons.check_box_outlined),
      _StatItem('Open', open, AppColors.primary, Icons.lock_open_outlined),
      _StatItem('Closed', closed, AppColors.textSecondary, Icons.lock_outline),
    ];

    return Scaffold(
      appBar: const StudentAppBar(showBack: true),
      body: RefreshIndicator(
        onRefresh: _loadItems,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          children: [
            const Text(
              'Personal Lost & Found Statistics',
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            const Text(
              'Real-time overview of your lost and found listings.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 500 ? 5 : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, index) {
                    final item = stats[index];
                    return AppCard(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, color: item.color, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            '${item.value}',
                            style: AppTextStyles.headingSmall,
                          ),
                          Text(
                            item.label,
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            const Text('My Lost & Found', style: AppTextStyles.headingMedium),
            const SizedBox(height: AppDimensions.spacingSmall),
            if (_isLoading)
              const SizedBox(height: 180, child: Center(child: AppLoader()))
            else if (_errorMessage != null)
              EmptyState(
                title: 'Could not load posts',
                message: _errorMessage,
                actionLabel: 'Retry',
                onAction: _loadItems,
              )
            else if (_items.isEmpty)
              const EmptyState(
                title: 'No items posted',
                message: 'You have not posted any lost or found items yet.',
                icon: Icons.search_off_outlined,
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingSmall,
                  ),
                  child: _LostFoundItemCard(item: item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.color, this.icon);

  final String label;
  final int value;
  final Color color;
  final IconData icon;
}

class _LostFoundItemCard extends StatelessWidget {
  const _LostFoundItemCard({required this.item});

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
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
          ],
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
                _Metadata(icon: Icons.category_outlined, text: item.category!),
              if (item.location != null)
                _Metadata(
                  icon: Icons.location_on_outlined,
                  text: item.location!,
                ),
              if (item.createdAt != null)
                _Metadata(
                  icon: Icons.schedule_outlined,
                  text:
                      '${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year}',
                ),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSmall,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.caption),
      ],
    );
  }
}
