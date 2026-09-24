import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/complaint_provider.dart';

class StudentActivityMetrics extends StatelessWidget {
  const StudentActivityMetrics({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ComplaintProvider>();
    final metrics = [
      _MetricData(
        'Total',
        provider.totalCount,
        Icons.inbox_outlined,
        AppColors.info,
      ),
      _MetricData(
        'Active',
        provider.activeCount,
        Icons.pending_actions_outlined,
        AppColors.warning,
      ),
      _MetricData(
        'In progress',
        provider.inProgressCount,
        Icons.sync_outlined,
        AppColors.primary,
      ),
      _MetricData(
        'Resolved',
        provider.resolvedCount,
        Icons.check_circle_outline,
        AppColors.success,
      ),
      _MetricData(
        'Support',
        provider.supportCount,
        Icons.favorite_border,
        AppColors.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620
            ? 5
            : constraints.maxWidth >= 360
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppDimensions.spacingSmall,
            mainAxisSpacing: AppDimensions.spacingSmall,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) => _MetricCard(data: metrics[index]),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.spacingSmall),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, color: data.color, size: AppDimensions.iconMedium),
          const SizedBox(height: 4),
          Text('${data.value}', style: AppTextStyles.headingSmall),
          Text(
            data.label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
