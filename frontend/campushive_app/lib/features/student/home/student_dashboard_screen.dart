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
import '../../../core/widgets/empty_state.dart';
import '../../../models/complaint.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/complaint_provider.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const _StudentDashboardView();
}

class _StudentDashboardView extends StatelessWidget {
  const _StudentDashboardView();

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthProvider>().session?.user ??
        const <String, dynamic>{};
    final name = _displayValue(user['full_name']);
    final identifier = _displayValue(user['usn_or_employee_id']);
    final imageUrl = _displayValue(user['profile_image']);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/logos/campus_hive_header_logo.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              context.read<ComplaintProvider>().loadComplaints(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            children: [
              _GreetingCard(
                name: name,
                identifier: identifier,
                imageUrl: imageUrl,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              _PrimaryActions(onUnavailable: () => _showUnavailable(context)),
              const SizedBox(height: AppDimensions.spacingLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent complaints',
                    style: AppTextStyles.headingSmall,
                  ),
                  TextButton(
                    onPressed: () => _showUnavailable(context),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              const _ComplaintsSection(),
            ],
          ),
        ),
      ),
    );
  }

  static String _displayValue(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? '' : text;
  }

  static void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This destination is not available yet.')),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.name,
    required this.identifier,
    required this.imageUrl,
  });

  final String name;
  final String identifier;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final greetingName = name.isEmpty ? 'there' : name;
    return AppCard(
      child: Row(
        children: [
          imageUrl.isEmpty
              ? const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.divider,
                  child: Icon(
                    Icons.person_outline,
                    color: AppColors.textSecondary,
                  ),
                )
              : CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.divider,
                  backgroundImage: NetworkImage(imageUrl),
                ),
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_timeOfDay()}, $greetingName',
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: AppDimensions.spacingSmall),
                if (identifier.isNotEmpty)
                  Text(identifier, style: AppTextStyles.label),
                const SizedBox(height: AppDimensions.spacingSmall),
                const Text(
                  'Keep up with your campus activity and support requests.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.onUnavailable});

  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData('Report New Issue', Icons.add_task_outlined),
      _ActionData('Lost & Found', Icons.search_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = actions
            .map(
              (action) => _ActionButton(data: action, onPressed: onUnavailable),
            )
            .toList();
        if (constraints.maxWidth < 520) {
          return Column(
            children: buttons
                .map(
                  (button) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimensions.spacingSmall,
                    ),
                    child: button,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: buttons
              .map(
                (button) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: AppDimensions.spacingSmall,
                    ),
                    child: button,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ActionData {
  const _ActionData(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.data, required this.onPressed});

  final _ActionData data;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: data.label,
      icon: data.icon,
      onPressed: onPressed,
      expand: true,
    );
  }
}

class _ComplaintsSection extends StatelessWidget {
  const _ComplaintsSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ComplaintProvider>();
    if (provider.isLoading && provider.complaints.isEmpty) {
      return const SizedBox(height: 180, child: AppLoader());
    }
    if (provider.errorMessage != null && provider.complaints.isEmpty) {
      return EmptyState(
        title: 'Could not load complaints',
        message: provider.errorMessage,
        actionLabel: 'Retry',
        onAction: () => provider.loadComplaints(refresh: true),
      );
    }
    if (provider.complaints.isEmpty) {
      return const EmptyState(
        title: 'No complaints yet',
        message: 'Your submitted complaints will appear here.',
        icon: Icons.assignment_outlined,
      );
    }
    return Column(
      children: provider.complaints
          .take(5)
          .map(
            (complaint) => Padding(
              padding: const EdgeInsets.only(
                bottom: AppDimensions.spacingSmall,
              ),
              child: _ComplaintCard(complaint: complaint),
            ),
          )
          .toList(),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
