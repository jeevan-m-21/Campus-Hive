import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/complaint.dart';
import '../../../providers/complaint_provider.dart';
import '../home/widgets/feed_card_shell.dart';
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
              label: 'Search complaints',
              hint: 'Search title, description, or location',
              prefixIcon: Icons.search_outlined,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            _FilterRow(
              title: 'Status',
              values: _statuses,
              selected: provider.statusFilter,
              humanize: _statusLabel,
              onSelected: (value) => provider.setFilters(status: value),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            _FilterRow(
              title: 'Priority',
              values: _priorities,
              selected: provider.priorityFilter,
              humanize: _priorityLabel,
              onSelected: (value) => provider.setFilters(priority: value),
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
                title: provider.isMineOnly
                    ? 'No complaints found'
                    : 'No complaints reported',
                message: provider.isMineOnly
                    ? 'Complaints you submit will appear here.'
                    : 'Campus complaints will appear here.',
                icon: Icons.assignment_outlined,
              )
            else ...[
              ...complaints.map(
                (complaint) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingMedium,
                  ),
                  child: _ComplaintCard(complaint: complaint),
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

  bool _matchesSearch(Complaint complaint) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    final title = complaint.title.toLowerCase();
    final description = complaint.description.toLowerCase();
    final location = (complaint.location ?? '').toLowerCase();
    return title.contains(query) ||
        description.contains(query) ||
        location.contains(query);
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.title,
    required this.values,
    required this.selected,
    required this.humanize,
    required this.onSelected,
  });

  final String title;
  final List<String?> values;
  final String? selected;
  final String Function(String) humanize;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.label),
        const SizedBox(height: 6),
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
    final isSupported = provider.isComplaintSupported(complaint);

    return FeedCardShell(
      authorName: complaint.studentName?.isNotEmpty == true
          ? complaint.studentName
          : 'Student',
      typeLabel: 'Complaint',
      typeColor: AppColors.primary,
      createdAt: complaint.createdAt,
      fallbackIcon: Icons.person_outline,
      onTap: () =>
          context.push(AppRoutes.studentComplaintDetail(complaint.complaintId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(complaint.title, style: AppTextStyles.headingSmall),
          if (complaint.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              complaint.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (complaint.imageUrl != null && complaint.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            FeedCardImage(imageUrl: complaint.imageUrl!),
          ],
          const SizedBox(height: AppDimensions.spacingMedium),
          Wrap(
            spacing: AppDimensions.spacingMedium,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (complaint.departmentName != null &&
                  complaint.departmentName!.isNotEmpty)
                FeedChip(
                  label: complaint.departmentName!,
                  icon: Icons.apartment_outlined,
                ),
              if (complaint.location != null && complaint.location!.isNotEmpty)
                FeedChip(
                  label: complaint.location!,
                  icon: Icons.location_on_outlined,
                ),
              if (complaint.deadline != null)
                FeedChip(
                  label: 'Due ${_date(complaint.deadline!)}',
                  icon: Icons.event_outlined,
                ),
              if (complaint.finalPriority != null &&
                  complaint.finalPriority!.isNotEmpty)
                FeedBadge(
                  label: _priorityLabel(complaint.finalPriority!),
                  color: _priorityColor(complaint.finalPriority!),
                ),
              FeedBadge(
                label: _statusLabel(complaint.status),
                color: _statusColor(complaint.status),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: provider.isSupporting
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      if (provider.isSupporting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        Icon(
                          isSupported
                              ? Icons.thumb_up_alt
                              : Icons.thumb_up_alt_outlined,
                          size: 19,
                          color: isSupported
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '${complaint.supportCount}',
                        style: AppTextStyles.label.copyWith(
                          fontWeight: isSupported
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSupported
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMedium),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push(
                  AppRoutes.studentComplaintDetail(complaint.complaintId),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 19,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Text('Comment', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '#${complaint.complaintId}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
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
  switch (status.toUpperCase()) {
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

Color _priorityColor(String priority) {
  switch (priority.toUpperCase()) {
    case 'HIGH':
      return AppColors.error;
    case 'MEDIUM':
      return AppColors.warning;
    default:
      return AppColors.textSecondary;
  }
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
