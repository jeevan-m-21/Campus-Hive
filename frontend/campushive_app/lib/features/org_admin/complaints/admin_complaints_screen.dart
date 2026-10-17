import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/complaint.dart';
import '../../../providers/admin_complaint_provider.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_complaint_card.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final _searchController = TextEditingController();

  static const _statusOptions = [
    'ALL',
    'PENDING',
    'ASSIGNED',
    'IN_PROGRESS',
    'REOPENED',
    'ESCALATED',
    'RESOLVED',
    'CLOSED',
  ];

  static const _priorityOptions = ['ALL', 'HIGH', 'MEDIUM', 'LOW'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminComplaintProvider>();
      provider.loadComplaints();
      provider.loadDepartments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminComplaintProvider>();
    final items = provider.filteredComplaints;

    return Scaffold(
      appBar: const AdminAppBar(title: 'Complaint Management'),
      body: SafeArea(
        child: Column(
          children: [
            // Filter and Search Header
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
                      hintText:
                          'Search tickets by title, student, department...',
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

                  // Priority and Department Filters Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Priority Chips
                        ..._priorityOptions.map((priority) {
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                          );
                        }),

                        // Department Filter Chips
                        if (provider.departments.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          const VerticalDivider(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: const Text('All Depts'),
                              selected: provider.departmentFilter == null,
                              onSelected: (_) =>
                                  provider.setDepartmentFilter(null),
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: provider.departmentFilter == null
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: provider.departmentFilter == null
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              backgroundColor: AppColors.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: provider.departmentFilter == null
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                          ),
                          ...provider.departments.map((dept) {
                            final isSelected =
                                provider.departmentFilter == dept.departmentId;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(dept.departmentName),
                                selected: isSelected,
                                onSelected: (_) => provider.setDepartmentFilter(
                                  dept.departmentId,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Results count and Reset Filters
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
                    '${provider.total} total complaints (Showing ${items.length})',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (provider.statusFilter != 'ALL' ||
                      provider.priorityFilter != 'ALL' ||
                      provider.departmentFilter != null ||
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

            // Complaints List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.loadComplaints(refresh: true),
                child: _buildComplaintList(provider, items),
              ),
            ),

            // Pagination Controls (when total pages > 1)
            if (provider.pages > 1)
              _PaginationBar(
                currentPage: provider.page,
                totalPages: provider.pages,
                hasNext: provider.hasNext,
                hasPrev: provider.hasPrevious,
                isLoading: provider.isLoading,
                onNext: provider.nextPage,
                onPrev: provider.previousPage,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintList(
    AdminComplaintProvider provider,
    List<Complaint> items,
  ) {
    if (provider.isLoading && provider.complaints.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (provider.errorMessage != null && provider.complaints.isEmpty) {
      return EmptyState(
        title: 'Could not load complaints',
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
            title: 'No complaints found',
            message:
                'No complaints match your selected filters or search query.',
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
          child: AdminComplaintCard(complaint: complaint),
        );
      },
    );
  }

  static String _humanize(String value) {
    if (value == 'ALL') return 'All Statuses';
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

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
    required this.isLoading,
    required this.onNext,
    required this.onPrev,
  });

  final int currentPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;
  final bool isLoading;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
            onPressed: hasPrev && !isLoading ? onPrev : null,
          ),
          Text(
            'Page $currentPage of $totalPages',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
            onPressed: hasNext && !isLoading ? onNext : null,
          ),
        ],
      ),
    );
  }
}
