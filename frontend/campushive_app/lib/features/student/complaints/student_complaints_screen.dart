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
import '../../../models/complaint.dart';
import '../../../providers/complaint_provider.dart';
import '../widgets/student_app_bar.dart';

class StudentComplaintsScreen extends StatefulWidget {
  const StudentComplaintsScreen({super.key});

  @override
  State<StudentComplaintsScreen> createState() =>
      _StudentComplaintsScreenState();
}

class _StudentComplaintsScreenState extends State<StudentComplaintsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _statuses = <String?>[
    null,
    'PENDING',
    'ASSIGNED',
    'IN_PROGRESS',
    'RESOLVED',
    'REOPENED',
    'ESCALATED',
    'CLOSED',
  ];
  static const _priorities = <String?>[null, 'LOW', 'MEDIUM', 'HIGH'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ComplaintProvider>();
    final complaints = provider.complaints.where(_matchesSearch).toList();

    return Scaffold(
      appBar: const StudentAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.studentReportIssue),
        tooltip: 'Report issue',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadComplaints(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          children: [
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
                          'All Complaints',
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
                          'My Complaints',
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
              controller: _searchController,
              label: 'Search complaints',
              hint: 'Search title, description, or location',
              prefixIcon: Icons.search_outlined,
              onChanged: (value) => setState(() => _searchQuery = value),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            _FilterGroup(
              label: 'Status',
              values: _statuses,
              selected: provider.statusFilter,
              onSelected: (value) => provider.setFilters(
                status: value,
                priority: provider.priorityFilter,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            _FilterGroup(
              label: 'Priority',
              values: _priorities,
              selected: provider.priorityFilter,
              onSelected: (value) => provider.setFilters(
                status: provider.statusFilter,
                priority: value,
              ),
              humanize: _priorityLabel,
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            if (provider.isLoading && provider.complaints.isEmpty)
              const SizedBox(height: 220, child: AppLoader())
            else if (provider.errorMessage != null &&
                provider.complaints.isEmpty)
              EmptyState(
                title: 'Could not load complaints',
                message: provider.errorMessage,
                actionLabel: 'Retry',
                onAction: () => provider.loadComplaints(refresh: true),
              )
            else if (complaints.isEmpty)
              EmptyState(
                title:
                    _searchQuery.isNotEmpty ||
                        provider.statusFilter != null ||
                        provider.priorityFilter != null
                    ? 'No matching complaints'
                    : 'No complaints yet',
                message:
                    _searchQuery.isNotEmpty ||
                        provider.statusFilter != null ||
                        provider.priorityFilter != null
                    ? 'Try changing your search or filters.'
                    : 'Campus complaints will appear here.',
                icon: Icons.assignment_outlined,
              )
            else ...[
              Text(
                '${provider.total} complaint${provider.total == 1 ? '' : 's'}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              ...complaints.map(
                (complaint) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingSmall,
                  ),
                  child: _ComplaintCard(complaint: complaint),
                ),
              ),
              if (provider.hasNext)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppDimensions.spacingSmall,
                  ),
                  child: AppButton(
                    label: provider.isLoadingPage ? 'Loading...' : 'Load more',
                    icon: Icons.expand_more,
                    isLoading: provider.isLoadingPage,
                    onPressed: provider.loadNextPage,
                    expand: true,
                  ),
                ),
              if (provider.pages > 1)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppDimensions.spacingSmall,
                  ),
                  child: Center(
                    child: Text(
                      'Page ${provider.page} of ${provider.pages}',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _matchesSearch(Complaint complaint) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return complaint.title.toLowerCase().contains(query) ||
        complaint.description.toLowerCase().contains(query) ||
        (complaint.location?.toLowerCase().contains(query) ?? false);
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.humanize = _statusLabel,
  });

  final String label;
  final List<String?> values;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String Function(String) humanize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: values
                .map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value == null ? 'All' : humanize(value)),
                      selected: selected == value,
                      onSelected: (_) => onSelected(value),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ComplaintProvider>();
    return AppCard(
      onTap: () =>
          context.push(AppRoutes.studentComplaintDetail(complaint.complaintId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${complaint.complaintId}', style: AppTextStyles.caption),
              const Spacer(),
              _Badge(
                label: _statusLabel(complaint.status),
                color: _statusColor(complaint.status),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Text(complaint.title, style: AppTextStyles.headingSmall),
          const SizedBox(height: 4),
          Text(
            complaint.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Wrap(
            spacing: AppDimensions.spacingMedium,
            runSpacing: 4,
            children: [
              if (complaint.location != null)
                _Metadata(Icons.location_on_outlined, complaint.location!),
              if (complaint.departmentName != null)
                _Metadata(Icons.apartment_outlined, complaint.departmentName!),
              if (complaint.createdAt != null)
                _Metadata(Icons.schedule_outlined, _date(complaint.createdAt!)),
              if (complaint.deadline != null)
                _Metadata(
                  Icons.event_outlined,
                  'Due ${_date(complaint.deadline!)}',
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              if (complaint.finalPriority != null)
                _Badge(
                  label: _priorityLabel(complaint.finalPriority!),
                  color: AppColors.warning,
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Support complaint',
                onPressed: provider.isSupporting
                    ? null
                    : () async {
                        final supported = await provider.supportComplaint(
                          complaint.complaintId,
                        );
                        if (!context.mounted || supported) return;
                        final message = provider.supportErrorMessage;
                        if (message != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                      },
                icon: const Icon(Icons.favorite_border),
              ),
              Text('${complaint.supportCount}', style: AppTextStyles.caption),
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
  const _Metadata(this.icon, this.text);

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

String _statusLabel(String value) => _humanize(value);
String _priorityLabel(String value) => _humanize(value);

String _humanize(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

Color _statusColor(String status) {
  switch (status) {
    case 'RESOLVED':
    case 'CLOSED':
      return AppColors.success;
    case 'ESCALATED':
      return AppColors.error;
    case 'IN_PROGRESS':
      return AppColors.primary;
    default:
      return AppColors.warning;
  }
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
