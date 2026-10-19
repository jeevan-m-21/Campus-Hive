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
import '../../../models/department.dart';
import '../../../models/supervisor.dart';
import '../../../providers/admin_complaint_provider.dart';
import '../../student/home/widgets/feed_card_shell.dart';
import '../widgets/admin_app_bar.dart';

class AdminComplaintDetailScreen extends StatefulWidget {
  const AdminComplaintDetailScreen({required this.complaintId, super.key});

  final int complaintId;

  @override
  State<AdminComplaintDetailScreen> createState() =>
      _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState
    extends State<AdminComplaintDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSendingComment = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminComplaintProvider>();
      provider.getOrFetchComplaint(widget.complaintId);
      provider.loadComments(widget.complaintId, refresh: true);
      provider.loadDepartments();
      provider.loadSupervisors();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminComplaintProvider>();
    final complaint = provider.complaints
        .where((c) => c.complaintId == widget.complaintId)
        .firstOrNull;

    return Scaffold(
      appBar: AdminAppBar(
        title: 'Complaint #${widget.complaintId}',
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
                    const Text('Complaint not found or unavailable'),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Retry',
                      onPressed: () {
                        provider.getOrFetchComplaint(
                          widget.complaintId,
                          force: true,
                        );
                        provider.loadComments(
                          widget.complaintId,
                          refresh: true,
                        );
                        provider.loadDepartments();
                        provider.loadSupervisors();
                      },
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    provider.getOrFetchComplaint(
                      widget.complaintId,
                      force: true,
                    ),
                    provider.loadComments(widget.complaintId, refresh: true),
                    provider.loadDepartments(),
                    provider.loadSupervisors(),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.all(
                    AppDimensions.screenHorizontalPadding,
                  ),
                  children: [
                    _ComplaintHeaderCard(
                      complaint: complaint,
                      onUpdateStatus: () => _showStatusUpdateDialog(complaint),
                      onUpdatePriority: () => _showPriorityDialog(complaint),
                      onUpdateDepartment: () =>
                          _showDepartmentDialog(complaint),
                      onUpdateDeadline: () => _pickDeadline(complaint),
                      onManageSupervisor: () =>
                          _showSupervisorDialog(complaint),
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    _AdminActionsSection(
                      complaint: complaint,
                      isUpdating: _isUpdating,
                      onQuickStatus: (status) =>
                          _quickUpdateStatus(complaint, status),
                      onFullStatusUpdate: () =>
                          _showStatusUpdateDialog(complaint),
                      onUpdatePriority: () => _showPriorityDialog(complaint),
                      onReassignDepartment: () =>
                          _showDepartmentDialog(complaint),
                      onUpdateDeadline: () => _pickDeadline(complaint),
                      onManageSupervisor: () =>
                          _showSupervisorDialog(complaint),
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
    final provider = context.read<AdminComplaintProvider>();

    setState(() => _isSendingComment = true);
    try {
      await provider.addComment(complaintId, text);
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to post message: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _quickUpdateStatus(Complaint complaint, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AdminComplaintProvider>();

    setState(() => _isUpdating = true);
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
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _pickDeadline(Complaint complaint) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AdminComplaintProvider>();

    if (complaint.deadline != null) {
      final shouldClear = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Deadline',
                    style: AppTextStyles.headingSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current deadline: ${_formatDate(complaint.deadline!)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.edit_calendar,
                      color: AppColors.primary,
                    ),
                    title: const Text('Change Deadline Date'),
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                  ListTile(
                    leading: const Icon(Icons.clear, color: AppColors.error),
                    title: const Text('Clear Deadline'),
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (shouldClear == true) {
        setState(() => _isUpdating = true);
        try {
          await provider.updateComplaint(
            complaint.complaintId,
            clearDeadline: true,
          );
          messenger.showSnackBar(
            const SnackBar(content: Text('Deadline removed successfully')),
          );
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Failed to clear deadline: $e')),
          );
        } finally {
          if (mounted) setState(() => _isUpdating = false);
        }
        return;
      } else if (shouldClear == null) {
        return;
      }
    }

    if (!mounted) return;
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
      setState(() => _isUpdating = true);
      try {
        await provider.updateComplaint(complaint.complaintId, deadline: picked);
        messenger.showSnackBar(
          const SnackBar(content: Text('Deadline updated successfully')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update deadline: $e')),
        );
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showSupervisorDialog(Complaint complaint) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AdminComplaintProvider>();

    if (provider.supervisors.isEmpty) {
      await provider.loadSupervisors();
      if (!mounted) return;
    }
    final supervisors = provider.supervisors;

    if (supervisors.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No active supervisors found for your organization.'),
        ),
      );
      return;
    }

    int? selectedSupervisorId = complaint.supervisorId;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Supervisor Assignment',
                          style: AppTextStyles.headingSmall,
                        ),
                        if (complaint.supervisorId != null)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmUnassignSupervisor(complaint);
                            },
                            child: const Text(
                              'Unassign',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      complaint.departmentName != null
                          ? 'Operational Department: ${complaint.departmentName}'
                          : 'Select an active supervisor to assign this complaint.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: supervisors.length,
                        itemBuilder: (ctx, idx) {
                          final Supervisor supervisor = supervisors[idx];
                          final isSelected =
                              selectedSupervisorId == supervisor.userId;
                          final isDeptMatch =
                              supervisor.departmentId == complaint.departmentId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : AppColors.background,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isDeptMatch
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : AppColors.divider,
                                child: Icon(
                                  Icons.person_outline,
                                  color: isDeptMatch
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      supervisor.fullName,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (isDeptMatch)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Dept Match',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.success,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '${supervisor.departmentName ?? "Unassigned Dept"} • ${supervisor.email}',
                                style: AppTextStyles.caption,
                              ),
                              trailing: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              onTap: () => setModalState(
                                () => selectedSupervisorId = supervisor.userId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Assign to This Complaint',
                      expand: true,
                      onPressed: selectedSupervisorId == null
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              if (selectedSupervisorId ==
                                  complaint.supervisorId) {
                                return;
                              }
                              setState(() => _isUpdating = true);
                              try {
                                await provider.updateComplaint(
                                  complaint.complaintId,
                                  supervisorId: selectedSupervisorId,
                                );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Supervisor assigned successfully.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to assign supervisor: $e',
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isUpdating = false);
                                }
                              }
                            },
                    ),
                    if (selectedSupervisorId != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() => _isUpdating = true);
                          try {
                            final res = await provider
                                .designateDepartmentSupervisor(
                              complaint.departmentId,
                              selectedSupervisorId!,
                            );
                            final assignedCount =
                                res['assigned_complaints_count'] ?? 0;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Designated department supervisor. Assigned to $assignedCount pending complaints.',
                                ),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to designate supervisor: $e',
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isUpdating = false);
                            }
                          }
                        },
                        child: const Text(
                          'Designate as Dept Supervisor & Assign Queue',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmUnassignSupervisor(Complaint complaint) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AdminComplaintProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unassign Supervisor'),
        content: Text(
          'Are you sure you want to unassign Supervisor #${complaint.supervisorId} from this complaint?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Unassign',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await provider.updateComplaint(
        complaint.complaintId,
        clearSupervisor: true,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Supervisor unassigned successfully')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to unassign supervisor: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _showPriorityDialog(Complaint complaint) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AdminComplaintProvider>();
    const priorities = ['LOW', 'MEDIUM', 'HIGH'];
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
                      'Update Final Priority',
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
                        setState(() => _isUpdating = true);
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
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
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

  Future<void> _showDepartmentDialog(Complaint complaint) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AdminComplaintProvider>();

    if (provider.departments.isEmpty) {
      await provider.loadDepartments();
      if (!mounted) return;
    }
    final departments = provider.departments;

    if (departments.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No departments available to assign.')),
      );
      return;
    }

    int selectedDeptId = complaint.departmentId;

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
                      'Reassign Department',
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Reassigning the department will route the ticket to that service department and recalculate priority automatically.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: departments.length,
                        itemBuilder: (ctx, idx) {
                          final Department dept = departments[idx];
                          final isSelected =
                              selectedDeptId == dept.departmentId;
                          final hasDescription =
                              dept.description?.isNotEmpty == true;
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
                              dept.departmentName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: hasDescription
                                ? Text(
                                    dept.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption,
                                  )
                                : null,
                            onTap: () => setModalState(
                              () => selectedDeptId = dept.departmentId,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Save Department',
                      expand: true,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (selectedDeptId == complaint.departmentId) return;

                        setState(() => _isUpdating = true);
                        try {
                          final updated = await provider.updateComplaint(
                            complaint.complaintId,
                            departmentId: selectedDeptId,
                          );
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Department reassigned to ${updated.departmentName ?? "selected department"}',
                              ),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to reassign department: $e',
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
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

  Future<void> _showStatusUpdateDialog(Complaint complaint) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AdminComplaintProvider>();

    const statuses = [
      'PENDING',
      'ASSIGNED',
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
                      'Update Complaint Status',
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
                        labelText: 'Remarks / Resolution Notes',
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
                        setState(() => _isUpdating = true);
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
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
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

  static String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _ComplaintHeaderCard extends StatelessWidget {
  const _ComplaintHeaderCard({
    required this.complaint,
    required this.onUpdateStatus,
    required this.onUpdatePriority,
    required this.onUpdateDepartment,
    required this.onUpdateDeadline,
    required this.onManageSupervisor,
  });

  final Complaint complaint;
  final VoidCallback onUpdateStatus;
  final VoidCallback onUpdatePriority;
  final VoidCallback onUpdateDepartment;
  final VoidCallback onUpdateDeadline;
  final VoidCallback onManageSupervisor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author & Status Header
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
                borderRadius: BorderRadius.circular(12),
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

          // Metadata wrap
          Wrap(
            spacing: AppDimensions.spacingSmall,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Department Chip
              InkWell(
                onTap: onUpdateDepartment,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.apartment_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        complaint.departmentName ?? 'Assign Dept',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // Location Chip
              if (complaint.location != null && complaint.location!.isNotEmpty)
                FeedChip(
                  label: complaint.location!,
                  icon: Icons.location_on_outlined,
                ),

              // Support Count Chip
              if (complaint.supportCount > 0)
                FeedChip(
                  label:
                      '${complaint.supportCount} ${complaint.supportCount == 1 ? "support" : "supports"}',
                  icon: Icons.thumb_up_alt_outlined,
                ),

              // ML Priority Badge (if present)
              if (complaint.mlPriority != null &&
                  complaint.mlPriority!.isNotEmpty)
                FeedBadge(
                  label: 'ML: ${complaint.mlPriority}',
                  color: _priorityColor(complaint.mlPriority!),
                ),

              // Final Priority Badge (clickable to edit)
              InkWell(
                onTap: onUpdatePriority,
                borderRadius: BorderRadius.circular(12),
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

              // Deadline Chip (clickable to set/edit/clear)
              InkWell(
                onTap: onUpdateDeadline,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: complaint.deadline != null
                        ? AppColors.warning.withValues(alpha: 0.1)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: complaint.deadline != null
                          ? AppColors.warning
                          : AppColors.border,
                    ),
                  ),
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
              ),

              // Supervisor Assignment Chip
              if (complaint.supervisorId != null)
                InkWell(
                  onTap: onManageSupervisor,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.manage_accounts_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          complaint.supervisorName != null
                              ? 'Supervisor: ${complaint.supervisorName}'
                              : 'Supervisor #${complaint.supervisorId}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: onManageSupervisor,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Unassigned (Tap to assign)',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
      case 'ASSIGNED':
        return AppColors.info;
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

class _AdminActionsSection extends StatelessWidget {
  const _AdminActionsSection({
    required this.complaint,
    required this.isUpdating,
    required this.onQuickStatus,
    required this.onFullStatusUpdate,
    required this.onUpdatePriority,
    required this.onReassignDepartment,
    required this.onUpdateDeadline,
    required this.onManageSupervisor,
  });

  final Complaint complaint;
  final bool isUpdating;
  final ValueChanged<String> onQuickStatus;
  final VoidCallback onFullStatusUpdate;
  final VoidCallback onUpdatePriority;
  final VoidCallback onReassignDepartment;
  final VoidCallback onUpdateDeadline;
  final VoidCallback onManageSupervisor;

  @override
  Widget build(BuildContext context) {
    final status = complaint.status.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organization Admin Controls',
          style: AppTextStyles.headingSmall,
        ),
        const SizedBox(height: AppDimensions.spacingSmall),

        // Quick status actions row
        Row(
          children: [
            if (status != 'IN_PROGRESS' && status != 'RESOLVED')
              Expanded(
                child: AppButton(
                  label: 'Mark In Progress',
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
                  onPressed: onFullStatusUpdate,
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
                  onPressed: onFullStatusUpdate,
                ),
              ),
            ],
            if (status == 'RESOLVED' || status == 'CLOSED')
              Expanded(
                child: AppButton(
                  label: 'Reopen Ticket',
                  icon: Icons.restart_alt,
                  variant: AppButtonVariant.outlined,
                  isLoading: isUpdating,
                  onPressed: () => onQuickStatus('REOPENED'),
                ),
              ),
            const SizedBox(width: AppDimensions.spacingSmall),
            IconButton.outlined(
              tooltip: 'All Status Options',
              icon: const Icon(Icons.more_horiz),
              onPressed: onFullStatusUpdate,
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.spacingSmall),

        // Secondary controls row 1: Department & Supervisor
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.apartment_outlined, size: 16),
                label: const Text('Department'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onReassignDepartment,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                label: Text(
                  complaint.supervisorId != null
                      ? 'Supervisor'
                      : 'Assign Superv.',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onManageSupervisor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),

        // Secondary controls row 2: Priority & Deadline
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Priority'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onUpdatePriority,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('Deadline'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onUpdateDeadline,
              ),
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
    final provider = context.watch<AdminComplaintProvider>();
    final comments = provider.getComments(complaintId);
    final isLoading = provider.isLoadingComments(complaintId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Timeline & Official Updates',
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
                      'Broadcast an administrative message, update, or note...',
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
                'No official updates yet. Send an update to keep everyone informed.',
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
                    : 'Staff / Admin',
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
