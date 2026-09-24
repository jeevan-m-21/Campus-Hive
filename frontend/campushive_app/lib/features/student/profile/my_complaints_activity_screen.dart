import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/complaint.dart';
import '../../../services/complaint_service.dart';
import '../widgets/student_app_bar.dart';

class MyComplaintsActivityScreen extends StatefulWidget {
  const MyComplaintsActivityScreen({super.key});

  @override
  State<MyComplaintsActivityScreen> createState() =>
      _MyComplaintsActivityScreenState();
}

class _MyComplaintsActivityScreenState
    extends State<MyComplaintsActivityScreen> {
  final _service = ComplaintService();
  List<Complaint> _complaints = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final page = await _service.fetchComplaints(
        page: 1,
        perPage: 100,
        mine: true,
      );
      if (mounted) {
        setState(() {
          _complaints = page.complaints;
          _isLoading = false;
        });
      }
    } on ComplaintException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load your complaints.';
          _isLoading = false;
        });
      }
    }
  }

  int _countStatus(String status) =>
      _complaints.where((c) => c.status.toUpperCase() == status).length;

  @override
  Widget build(BuildContext context) {
    final total = _complaints.length;
    final pending = _countStatus('PENDING');
    final assigned = _countStatus('ASSIGNED');
    final inProgress = _countStatus('IN_PROGRESS');
    final resolved = _countStatus('RESOLVED');
    final reopened = _countStatus('REOPENED');
    final escalated = _countStatus('ESCALATED');
    final closed = _countStatus('CLOSED');

    final stats = [
      _StatItem('Total', total, AppColors.info, Icons.inbox_outlined),
      _StatItem(
        'Pending',
        pending,
        AppColors.warning,
        Icons.hourglass_top_outlined,
      ),
      _StatItem(
        'Assigned',
        assigned,
        AppColors.primary,
        Icons.assignment_ind_outlined,
      ),
      _StatItem(
        'In Progress',
        inProgress,
        AppColors.primaryDark,
        Icons.sync_outlined,
      ),
      _StatItem(
        'Resolved',
        resolved,
        AppColors.success,
        Icons.check_circle_outline,
      ),
      _StatItem('Reopened', reopened, AppColors.warning, Icons.replay_outlined),
      _StatItem(
        'Escalated',
        escalated,
        AppColors.error,
        Icons.warning_amber_outlined,
      ),
      _StatItem(
        'Closed',
        closed,
        AppColors.textSecondary,
        Icons.archive_outlined,
      ),
    ];

    return Scaffold(
      appBar: const StudentAppBar(showBack: true),
      body: RefreshIndicator(
        onRefresh: _loadComplaints,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          children: [
            const Text(
              'Personal Complaint Statistics',
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            const Text(
              'Real-time overview of your submitted issues.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
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
                      Text('${item.value}', style: AppTextStyles.headingSmall),
                      Text(
                        item.label,
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            const Text('My Complaints', style: AppTextStyles.headingMedium),
            const SizedBox(height: AppDimensions.spacingSmall),
            if (_isLoading)
              const SizedBox(height: 180, child: Center(child: AppLoader()))
            else if (_errorMessage != null)
              EmptyState(
                title: 'Could not load complaints',
                message: _errorMessage,
                actionLabel: 'Retry',
                onAction: _loadComplaints,
              )
            else if (_complaints.isEmpty)
              const EmptyState(
                title: 'No complaints reported',
                message: 'You have not submitted any complaints yet.',
                icon: Icons.assignment_outlined,
              )
            else
              ..._complaints.map(
                (complaint) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingSmall,
                  ),
                  child: _ComplaintItemCard(complaint: complaint),
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

class _ComplaintItemCard extends StatelessWidget {
  const _ComplaintItemCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
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
                label: _humanize(complaint.status),
                color: _statusColor(complaint.status),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Text(complaint.title, style: AppTextStyles.headingSmall),
          const SizedBox(height: 4),
          Text(
            complaint.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Wrap(
            spacing: AppDimensions.spacingMedium,
            runSpacing: 4,
            children: [
              if (complaint.departmentName != null)
                _Metadata(
                  icon: Icons.apartment_outlined,
                  text: complaint.departmentName!,
                ),
              if (complaint.location != null)
                _Metadata(
                  icon: Icons.location_on_outlined,
                  text: complaint.location!,
                ),
              if (complaint.createdAt != null)
                _Metadata(
                  icon: Icons.schedule_outlined,
                  text: _dateLabel(complaint.createdAt!),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Row(
            children: [
              if (complaint.finalPriority != null)
                _Badge(
                  label: _humanize(complaint.finalPriority!),
                  color: AppColors.warning,
                ),
              const Spacer(),
              const Icon(
                Icons.favorite_border,
                size: AppDimensions.iconSmall,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text('${complaint.supportCount}', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }

  static String _humanize(String value) => value
      .toLowerCase()
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  static Color _statusColor(String status) {
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

  static String _dateLabel(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
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
