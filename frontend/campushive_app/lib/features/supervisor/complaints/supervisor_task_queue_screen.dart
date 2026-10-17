import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../providers/supervisor_complaint_provider.dart';
import '../widgets/supervisor_app_bar.dart';
import '../widgets/supervisor_complaint_card.dart';

class SupervisorTaskQueueScreen extends StatefulWidget {
  const SupervisorTaskQueueScreen({super.key});

  @override
  State<SupervisorTaskQueueScreen> createState() =>
      _SupervisorTaskQueueScreenState();
}

class _SupervisorTaskQueueScreenState extends State<SupervisorTaskQueueScreen> {
  final _searchController = TextEditingController();

  static const _statusOptions = [
    'ALL',
    'PENDING',
    'IN_PROGRESS',
    'REOPENED',
    'ESCALATED',
    'RESOLVED',
    'CLOSED',
  ];

  static const _priorityOptions = ['ALL', 'HIGH', 'MEDIUM', 'LOW'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupervisorComplaintProvider>();
    final items = provider.filteredComplaints;

    return Scaffold(
      appBar: const SupervisorAppBar(title: 'Task Queue'),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Filter Header
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenHorizontalPadding,
                AppDimensions.spacingSmall,
                AppDimensions.screenHorizontalPadding,
                AppDimensions.spacingSmall,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search TextField
                  TextField(
                    controller: _searchController,
                    onChanged: provider.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Search tasks, student, department...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                provider.setSearchQuery('');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSmall),
                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusOptions.map((status) {
                        final isSelected =
                            provider.statusFilter.toUpperCase() == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(_humanize(status)),
                            selected: isSelected,
                            onSelected: (_) => provider.setStatusFilter(status),
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            backgroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Priority Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _priorityOptions.map((priority) {
                        final isSelected =
                            provider.priorityFilter.toUpperCase() == priority;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(
                              priority == 'ALL'
                                  ? 'All Priorities'
                                  : '$priority Priority',
                            ),
                            selected: isSelected,
                            onSelected: (_) =>
                                provider.setPriorityFilter(priority),
                            selectedColor: _priorityColor(
                              priority,
                            ).withValues(alpha: 0.15),
                            checkmarkColor: _priorityColor(priority),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? _priorityColor(priority)
                                  : AppColors.textSecondary,
                            ),
                            backgroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected
                                    ? _priorityColor(priority)
                                    : AppColors.border,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Queue Count & Results
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenHorizontalPadding,
                AppDimensions.spacingSmall,
                AppDimensions.screenHorizontalPadding,
                4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${items.length} ${items.length == 1 ? 'task' : 'tasks'} found',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (provider.statusFilter != 'ALL' ||
                      provider.priorityFilter != 'ALL' ||
                      provider.searchQuery.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        provider.clearFilters();
                      },
                      child: Text(
                        'Reset Filters',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // List View
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.loadComplaints(refresh: true),
                child: _buildQueueContent(provider, items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueContent(
    SupervisorComplaintProvider provider,
    List<dynamic> items,
  ) {
    if (provider.isLoading && provider.complaints.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (provider.errorMessage != null && provider.complaints.isEmpty) {
      return EmptyState(
        title: 'Could not load queue',
        message: provider.errorMessage,
        actionLabel: 'Retry',
        onAction: () => provider.loadComplaints(refresh: true),
      );
    }

    if (items.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: EmptyState(
            title: 'No tasks match your filters',
            message:
                'Try selecting a different status or clearing your search.',
            icon: Icons.filter_alt_off_outlined,
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final complaint = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          child: SupervisorComplaintCard(complaint: complaint),
        );
      },
    );
  }

  static String _humanize(String value) {
    if (value == 'ALL') return 'All Tasks';
    return value
        .toLowerCase()
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  static Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return AppColors.error;
      case 'MEDIUM':
        return AppColors.warning;
      case 'LOW':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }
}
