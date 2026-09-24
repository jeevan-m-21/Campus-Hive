import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/complaint.dart';
import '../../../models/complaint_comment.dart';
import '../../../services/complaint_service.dart';
import '../widgets/student_app_bar.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({required this.complaintId, super.key});

  final int complaintId;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _service = ComplaintService();
  final _commentController = TextEditingController();
  Complaint? _complaint;
  List<ComplaintComment> _comments = const [];
  String? _errorMessage;
  String? _commentError;
  bool _isLoading = true;
  bool _isCommentsLoading = true;
  bool _isSubmitting = false;
  bool _isSupporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final complaint = await _service.fetchComplaint(widget.complaintId);
      if (mounted) setState(() => _complaint = complaint);
      await _loadComments();
    } on ComplaintException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to load this complaint.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _isCommentsLoading = true;
      _commentError = null;
    });
    try {
      final comments = await _service.fetchComments(widget.complaintId);
      if (mounted) setState(() => _comments = comments);
    } on ComplaintException catch (error) {
      if (mounted) setState(() => _commentError = error.message);
    } catch (_) {
      if (mounted) setState(() => _commentError = 'Unable to load comments.');
    } finally {
      if (mounted) setState(() => _isCommentsLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final message = _commentController.text.trim();
    if (message.isEmpty || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _commentError = null;
    });
    try {
      await _service.addComment(widget.complaintId, message);
      _commentController.clear();
      await _loadComments();
    } on ComplaintException catch (error) {
      if (mounted) setState(() => _commentError = error.message);
    } catch (_) {
      if (mounted) setState(() => _commentError = 'Unable to add comment.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _supportComplaint() async {
    if (_isSupporting || _complaint == null) return;
    setState(() => _isSupporting = true);
    try {
      final count = await _service.supportComplaint(widget.complaintId);
      if (mounted && _complaint != null) {
        setState(() {
          _complaint = Complaint(
            complaintId: _complaint!.complaintId,
            organizationId: _complaint!.organizationId,
            studentId: _complaint!.studentId,
            departmentId: _complaint!.departmentId,
            supervisorId: _complaint!.supervisorId,
            title: _complaint!.title,
            description: _complaint!.description,
            location: _complaint!.location,
            imageUrl: _complaint!.imageUrl,
            mlPriority: _complaint!.mlPriority,
            finalPriority: _complaint!.finalPriority,
            status: _complaint!.status,
            supportCount: count,
            deadline: _complaint!.deadline,
            resolvedAt: _complaint!.resolvedAt,
            studentFeedback: _complaint!.studentFeedback,
            createdAt: _complaint!.createdAt,
            updatedAt: _complaint!.updatedAt,
            studentName: _complaint!.studentName,
            departmentName: _complaint!.departmentName,
          );
        });
      }
    } on ComplaintException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to support complaint.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSupporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StudentAppBar(showBack: true),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: AppLoader())
            : _errorMessage != null
            ? EmptyState(
                title: 'Could not load complaint',
                message: _errorMessage,
                actionLabel: 'Retry',
                onAction: _loadData,
              )
            : _complaint == null
            ? const SizedBox.shrink()
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                  vertical: AppDimensions.spacingMedium,
                ),
                children: [
                  _PostHeader(complaint: _complaint!),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  Text(_complaint!.title, style: AppTextStyles.headingMedium),
                  const SizedBox(height: AppDimensions.spacingSmall),
                  Text(
                    _complaint!.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  if (_complaint!.imageUrl != null &&
                      _complaint!.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingMedium),
                    _PostImage(imageUrl: _complaint!.imageUrl!),
                  ],
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _PostMetadataChips(complaint: _complaint!),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _ActionBar(
                    supportCount: _complaint!.supportCount,
                    isSupporting: _isSupporting,
                    onSupport: _supportComplaint,
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Discussion (${_comments.length})',
                        style: AppTextStyles.headingSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _CommentsList(
                    comments: _comments,
                    isLoading: _isCommentsLoading,
                    errorMessage: _commentError,
                    onRetry: _loadComments,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _CommentInput(
                    controller: _commentController,
                    isSubmitting: _isSubmitting,
                    onSubmit: _submitComment,
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                ],
              ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final name = complaint.studentName ?? 'Student';
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'S',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTextStyles.label),
              const SizedBox(height: 2),
              Text(
                '#${complaint.complaintId} • ${complaint.createdAt != null ? _formatDate(complaint.createdAt!) : ''}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        _Badge(
          label: _humanize(complaint.status),
          color: _statusColor(complaint.status),
        ),
        if (complaint.finalPriority != null) ...[
          const SizedBox(width: 6),
          _Badge(
            label: _humanize(complaint.finalPriority!),
            color: AppColors.warning,
          ),
        ],
      ],
    );
  }
}

class _PostImage extends StatelessWidget {
  const _PostImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${AppConstants.apiBaseUrl.replaceAll('/api/v1', '')}$imageUrl';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        fullUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 160,
          width: double.infinity,
          color: AppColors.divider,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PostMetadataChips extends StatelessWidget {
  const _PostMetadataChips({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacingSmall,
      runSpacing: 6,
      children: [
        if (complaint.departmentName != null)
          _InfoChip(
            icon: Icons.apartment_outlined,
            text: complaint.departmentName!,
          ),
        if (complaint.location != null && complaint.location!.isNotEmpty)
          _InfoChip(
            icon: Icons.location_on_outlined,
            text: complaint.location!,
          ),
        if (complaint.deadline != null)
          _InfoChip(
            icon: Icons.event_outlined,
            text: 'Due ${_formatDate(complaint.deadline!)}',
          ),
        if (complaint.resolvedAt != null)
          _InfoChip(
            icon: Icons.check_circle_outline,
            text: 'Resolved ${_formatDate(complaint.resolvedAt!)}',
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.supportCount,
    required this.isSupporting,
    required this.onSupport,
  });

  final int supportCount;
  final bool isSupporting;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: isSupporting ? null : onSupport,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite_outline,
                    color: supportCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$supportCount Support${supportCount == 1 ? '' : 's'}',
                    style: AppTextStyles.label.copyWith(
                      color: supportCount > 0
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: isSupporting ? null : onSupport,
            icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
            label: const Text('Support'),
          ),
        ],
      ),
    );
  }
}

class _CommentsList extends StatelessWidget {
  const _CommentsList({
    required this.comments,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final List<ComplaintComment> comments;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: AppLoader()),
      );
    }
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No comments yet. Share an update or support note.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return Column(
      children: comments
          .map((comment) => _CommentTile(comment: comment))
          .toList(),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final ComplaintComment comment;

  @override
  Widget build(BuildContext context) {
    final senderName = comment.senderName ?? 'User';
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.divider,
                child: Text(
                  senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(senderName, style: AppTextStyles.label),
              const Spacer(),
              if (comment.sentAt != null)
                Text(
                  _formatDateTime(comment.sentAt!),
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.message,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: controller,
          label: 'Add a comment',
          hint: 'Please support this complaint...',
          maxLines: 3,
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        AppButton(
          label: 'Post comment',
          icon: Icons.send_outlined,
          isLoading: isSubmitting,
          onPressed: onSubmit,
          expand: true,
        ),
      ],
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

String _formatDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
