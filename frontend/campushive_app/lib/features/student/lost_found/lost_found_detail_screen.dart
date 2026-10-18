import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/image_url_resolver.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/lost_found.dart';
import '../../../models/lost_found_comment.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/lost_found_service.dart';
import '../widgets/student_app_bar.dart';

class LostFoundDetailScreen extends StatefulWidget {
  const LostFoundDetailScreen({required this.itemId, super.key});

  final int itemId;

  @override
  State<LostFoundDetailScreen> createState() => _LostFoundDetailScreenState();
}

class _LostFoundDetailScreenState extends State<LostFoundDetailScreen> {
  final _service = LostFoundService();
  final _commentController = TextEditingController();

  LostFound? _item;
  List<LostFoundComment> _comments = const [];
  String? _errorMessage;
  String? _commentError;
  bool _isLoading = true;
  bool _isCommentsLoading = true;
  bool _isSubmitting = false;
  bool _isClosing = false;

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
      final item = await _service.fetchItem(widget.itemId);
      if (mounted) setState(() => _item = item);
      await _loadComments();
    } on LostFoundException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Unable to load this lost & found item.',
        );
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
      final comments = await _service.fetchComments(widget.itemId);
      if (mounted) setState(() => _comments = comments);
    } on LostFoundException catch (error) {
      if (mounted) setState(() => _commentError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _commentError = 'Unable to load comments.');
      }
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
      await _service.addComment(widget.itemId, message);
      _commentController.clear();
      await _loadComments();
    } on LostFoundException catch (error) {
      if (mounted) setState(() => _commentError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _commentError = 'Unable to post comment.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmClosePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Listing'),
        content: const Text(
          'Are you sure you want to mark this item as closed? This indicates the item has been returned or found and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Post'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isClosing = true);
    try {
      final updated = await _service.closeItem(widget.itemId);
      if (mounted) {
        setState(() => _item = updated);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item marked as closed.')));
      }
    } on LostFoundException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to close post.')));
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  void _openImagePreview(String imageUrl) {
    final resolved = resolveImageUrl(imageUrl);
    if (resolved.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(
                resolved,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final currentUserId = session?.user['user_id'];
    final isCreator =
        currentUserId != null &&
        _item != null &&
        (currentUserId == _item!.postedBy ||
            currentUserId.toString() == _item!.postedBy.toString());
    final canClose =
        isCreator && _item != null && _item!.status.toUpperCase() == 'OPEN';

    return Scaffold(
      appBar: const StudentAppBar(showBack: true),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: AppLoader())
            : _errorMessage != null
            ? EmptyState(
                title: 'Could not load item',
                message: _errorMessage,
                actionLabel: 'Retry',
                onAction: _loadData,
              )
            : _item == null
            ? const EmptyState(
                title: 'Item not found',
                message: 'This lost and found post does not exist.',
                icon: Icons.search_off_outlined,
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                  vertical: AppDimensions.spacingMedium,
                ),
                children: [
                  _PostHeader(
                    item: _item!,
                    canClose: canClose,
                    isClosing: _isClosing,
                    onClosePost: _confirmClosePost,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  Text(_item!.title, style: AppTextStyles.headingMedium),
                  const SizedBox(height: AppDimensions.spacingSmall),
                  Text(
                    _item!.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  if (_item!.images.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingMedium),
                    _ImagesGallery(
                      images: _item!.images,
                      onImageTap: _openImagePreview,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _MetadataSection(item: _item!),
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
                  if (_item!.status.toUpperCase() == 'CLOSED')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.divider.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This post is closed. New comments are disabled.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
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
  const _PostHeader({
    required this.item,
    required this.canClose,
    required this.isClosing,
    required this.onClosePost,
  });

  final LostFound item;
  final bool canClose;
  final bool isClosing;
  final VoidCallback onClosePost;

  @override
  Widget build(BuildContext context) {
    final posterName = item.posterName ?? 'Anonymous';
    final typeColor = item.itemType.toUpperCase() == 'LOST'
        ? AppColors.error
        : AppColors.success;
    final statusColor = item.status.toUpperCase() == 'OPEN'
        ? AppColors.primary
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                posterName.isNotEmpty ? posterName[0].toUpperCase() : 'U',
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
                  Text(posterName, style: AppTextStyles.label),
                  if (item.createdAt != null)
                    Text(
                      _formatDateTime(item.createdAt!),
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
            ),
            _Badge(label: item.itemType, color: typeColor),
            const SizedBox(width: 6),
            _Badge(label: item.status, color: statusColor),
          ],
        ),
        if (canClose) ...[
          const SizedBox(height: AppDimensions.spacingSmall),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Close Listing',
              icon: Icons.check_circle_outline,
              variant: AppButtonVariant.outlined,
              isLoading: isClosing,
              onPressed: onClosePost,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImagesGallery extends StatelessWidget {
  const _ImagesGallery({required this.images, required this.onImageTap});

  final List<LostFoundImage> images;
  final ValueChanged<String> onImageTap;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      final img = images.first;
      final fullUrl = resolveImageUrl(img.imageUrl);

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onImageTap(img.imageUrl),
          child: _ImageFrame(
            imageUrl: fullUrl,
            height: 220,
            width: double.infinity,
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final img = images[index];
          final fullUrl = resolveImageUrl(img.imageUrl);

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onImageTap(img.imageUrl),
              child: _ImageFrame(imageUrl: fullUrl, height: 180, width: 240),
            ),
          );
        },
      ),
    );
  }
}

class _ImageFrame extends StatelessWidget {
  const _ImageFrame({
    required this.imageUrl,
    required this.height,
    required this.width,
  });

  final String imageUrl;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: AppColors.divider,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 36,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Image.network(
      imageUrl,
      height: height,
      width: width,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: height,
          width: width,
          color: AppColors.divider.withValues(alpha: 0.3),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        height: height,
        width: width,
        color: AppColors.divider,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 36,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.item});

  final LostFound item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacingMedium,
      runSpacing: 8,
      children: [
        if (item.category != null && item.category!.isNotEmpty)
          _Chip(icon: Icons.category_outlined, text: item.category!),
        if (item.location != null && item.location!.isNotEmpty)
          _Chip(icon: Icons.location_on_outlined, text: item.location!),
        if (item.dateOfIncident != null)
          _Chip(
            icon: Icons.event_outlined,
            text: 'Incident: ${_formatDate(item.dateOfIncident!)}',
          ),
        if (item.resolvedAt != null)
          _Chip(
            icon: Icons.check_circle_outline,
            text: 'Resolved: ${_formatDate(item.resolvedAt!)}',
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: AppTextStyles.bodySmall),
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

  final List<LostFoundComment> comments;
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
            'No comments yet. Have you seen this item or have an inquiry?',
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

  final LostFoundComment comment;

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
          hint: 'Leave information or inquiry regarding this item...',
          maxLines: 3,
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        AppButton(
          label: 'Post comment',
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : onSubmit,
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

String _formatDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
