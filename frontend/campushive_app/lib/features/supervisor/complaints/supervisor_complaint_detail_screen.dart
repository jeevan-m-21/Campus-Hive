import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../models/complaint.dart';
import '../../../models/complaint_comment.dart';
import '../../../providers/supervisor_complaint_provider.dart';
import '../../student/home/widgets/feed_card_shell.dart';
import '../widgets/supervisor_app_bar.dart';

class SupervisorComplaintDetailScreen extends StatefulWidget {
  const SupervisorComplaintDetailScreen({required this.complaintId, super.key});

  final int complaintId;

  @override
  State<SupervisorComplaintDetailScreen> createState() =>
      _SupervisorComplaintDetailScreenState();
}

class _SupervisorComplaintDetailScreenState
    extends State<SupervisorComplaintDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSendingComment = false;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SupervisorComplaintProvider>();
      provider.getOrFetchComplaint(widget.complaintId);
      provider.loadComments(widget.complaintId, refresh: true);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupervisorComplaintProvider>();
    final complaint = provider.complaints
        .where((c) => c.complaintId == widget.complaintId)
        .firstOrNull;

    return Scaffold(
      appBar: SupervisorAppBar(
        title: 'Task #${widget.complaintId}',
        showBack: true,
      ),
      body: SafeArea(
        child: complaint == null && provider.isLoading
            ? const Center(child: AppLoader())
            : complaint == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Complaint not found'),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Retry',
                      onPressed: () =>
                          provider.getOrFetchComplaint(widget.complaintId),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    provider.getOrFetchComplaint(widget.complaintId),
                    provider.loadComments(widget.complaintId, refresh: true),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.all(
                    AppDimensions.screenHorizontalPadding,
                  ),
                  children: [
                    _ComplaintHeaderCard(
                      complaint: complaint,
                      onUpdateStatus: () =>
                          _showStatusUpdateDialog(context, complaint),
                      onUpdatePriority: () =>
                          _showPriorityDialog(context, complaint),
                      onUpdateDeadline: () => _pickDeadline(context, complaint),
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    _ActionButtonsRow(
                      complaint: complaint,
                      isUpdating: _isUpdatingStatus,
                      onQuickStatus: (status) =>
                          _quickUpdateStatus(complaint, status),
                      onFullUpdate: () =>
                          _showStatusUpdateDialog(context, complaint),
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    _CommentsSection(
                      complaintId: widget.complaintId,
                      controller: _commentController,
                      isSending: _isSendingComment,
                      onSend: () => _sendComment(widget.complaintId),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _sendComment(int complaintId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<SupervisorComplaintProvider>();

    setState(() => _isSendingComment = true);
    try {
      await provider.addComment(complaintId, text);
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to post update: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _quickUpdateStatus(Complaint complaint, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<SupervisorComplaintProvider>();

    setState(() => _isUpdatingStatus = true);
    try {
      await provider.updateComplaint(complaint.complaintId, status: newStatus);
      messenger.showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _pickDeadline(BuildContext context, Complaint complaint) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<SupervisorComplaintProvider>();

    final initialDate =
        complaint.deadline ?? DateTime.now().add(const Duration(days: 2));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(DateTime.now())
          ? DateTime.now()
          : initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      try {
        await provider.updateComplaint(complaint.complaintId, deadline: picked);
        messenger.showSnackBar(
          const SnackBar(content: Text('Deadline updated successfully')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update deadline: $e')),
        );
      }
    }
  }

  Future<void> _showPriorityDialog(
    BuildContext context,
    Complaint complaint,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<SupervisorComplaintProvider>();
    final priorities = ['LOW', 'MEDIUM', 'HIGH'];
    String selected = complaint.finalPriority?.toUpperCase() ?? 'MEDIUM';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Change Priority',
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: 12),
                    ...priorities.map((p) {
                      final isSelected = selected == p;
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          '$p Priority',
                          style: AppTextStyles.bodyMedium,
                        ),
                        onTap: () => setModalState(() => selected = p),
                      );
                    }),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Save Priority',
                      expand: true,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await provider.updateComplaint(
                            complaint.complaintId,
                            finalPriority: selected,
                          );
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Priority updated to $selected'),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to update priority: $e'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showStatusUpdateDialog(
    BuildContext context,
    Complaint complaint,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<SupervisorComplaintProvider>();

    final statuses = [
      'PENDING',
      'IN_PROGRESS',
      'RESOLVED',
      'REOPENED',
      'ESCALATED',
      'CLOSED',
    ];
    String selectedStatus = complaint.status.toUpperCase();
    final remarksController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Task Status',
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Select New Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: statuses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedStatus = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Resolution Notes / Remarks',
                        hintText:
                            'Add notes about actions taken or reason for update...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Save Status Update',
                      expand: true,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await provider.updateComplaint(
                            complaint.complaintId,
                            status: selectedStatus,
                            remarks: remarksController.text.trim(),
                          );
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Status updated to $selectedStatus',
                              ),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to update: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ComplaintHeaderCard extends StatelessWidget {
  const _ComplaintHeaderCard({
    required this.complaint,
    required this.onUpdateStatus,
    required this.onUpdatePriority,
    required this.onUpdateDeadline,
  });

  final Complaint complaint;
  final VoidCallback onUpdateStatus;
  final VoidCallback onUpdatePriority;
  final VoidCallback onUpdateDeadline;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.divider,
                child: Icon(
                  Icons.person_outline,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.studentName?.isNotEmpty == true
                          ? complaint.studentName!
                          : 'Student',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      formatRelativeTime(complaint.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onUpdateStatus,
                child: FeedBadge(
                  label: complaint.status,
                  color: _statusColor(complaint.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Text(complaint.title, style: AppTextStyles.headingMedium),
          const SizedBox(height: AppDimensions.spacingSmall),
          Text(
            complaint.description,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
          ),
          if (complaint.imageUrl != null && complaint.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            FeedCardImage(imageUrl: complaint.imageUrl!, height: 220),
          ],
          const SizedBox(height: AppDimensions.spacingMedium),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppDimensions.spacingMedium),
          // Metadata grid
          Wrap(
            spacing: AppDimensions.spacingMedium,
            runSpacing: 8,
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
              InkWell(
                onTap: onUpdatePriority,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FeedBadge(
                      label: '${complaint.finalPriority ?? "MEDIUM"} Priority',
                      color: _priorityColor(
                        complaint.finalPriority ?? 'MEDIUM',
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.edit_outlined,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onUpdateDeadline,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: complaint.deadline != null
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      complaint.deadline != null
                          ? 'Due: ${_formatDate(complaint.deadline!)}'
                          : 'Set Deadline',
                      style: AppTextStyles.caption.copyWith(
                        color: complaint.deadline != null
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static Color _statusColor(String status) {
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

  static Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return AppColors.error;
      case 'MEDIUM':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({
    required this.complaint,
    required this.isUpdating,
    required this.onQuickStatus,
    required this.onFullUpdate,
  });

  final Complaint complaint;
  final bool isUpdating;
  final ValueChanged<String> onQuickStatus;
  final VoidCallback onFullUpdate;

  @override
  Widget build(BuildContext context) {
    final status = complaint.status.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: AppTextStyles.headingSmall),
        const SizedBox(height: AppDimensions.spacingSmall),
        Row(
          children: [
            if (status != 'IN_PROGRESS' && status != 'RESOLVED')
              Expanded(
                child: AppButton(
                  label: 'Start Work',
                  icon: Icons.play_arrow_outlined,
                  isLoading: isUpdating,
                  onPressed: () => onQuickStatus('IN_PROGRESS'),
                ),
              ),
            if (status == 'IN_PROGRESS') ...[
              Expanded(
                flex: 5,
                child: AppButton(
                  label: 'Mark Resolved',
                  icon: Icons.check_circle_outline,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  isLoading: isUpdating,
                  onPressed: onFullUpdate,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                flex: 4,
                child: AppButton(
                  label: 'Escalate',
                  icon: Icons.priority_high,
                  variant: AppButtonVariant.outlined,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  isLoading: isUpdating,
                  onPressed: onFullUpdate,
                ),
              ),
            ],
            if (status == 'RESOLVED' || status == 'CLOSED')
              Expanded(
                child: AppButton(
                  label: 'Update Resolution',
                  icon: Icons.edit_note,
                  variant: AppButtonVariant.outlined,
                  onPressed: onFullUpdate,
                ),
              ),
            const SizedBox(width: AppDimensions.spacingSmall),
            IconButton.outlined(
              tooltip: 'More Status Options',
              icon: const Icon(Icons.more_horiz),
              onPressed: onFullUpdate,
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.complaintId,
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final int complaintId;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupervisorComplaintProvider>();
    final comments = provider.getComments(complaintId);
    final isLoading = provider.isLoadingComments(complaintId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Timeline & Messages',
              style: AppTextStyles.headingSmall,
            ),
            Text(
              '${comments.length} updates',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        // Comment composer
        AppCard(
          child: Column(
            children: [
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'Post an official update or reply to the student...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Send Update',
                    icon: Icons.send_rounded,
                    isLoading: isSending,
                    onPressed: onSend,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        // Comments list
        if (isLoading && comments.isEmpty)
          const Center(
            child: Padding(padding: EdgeInsets.all(20), child: AppLoader()),
          )
        else if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No messages yet. Send an update to keep the student informed.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          )
        else
          Column(
            children: comments.map((comment) {
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.spacingSmall,
                ),
                child: _CommentTile(comment: comment),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final ComplaintComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment.senderName?.isNotEmpty == true
                    ? comment.senderName!
                    : 'User',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                formatRelativeTime(comment.sentAt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
