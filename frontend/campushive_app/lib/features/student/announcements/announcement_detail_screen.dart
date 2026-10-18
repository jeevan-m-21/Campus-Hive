import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/image_url_resolver.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/announcement.dart';
import '../../../models/announcement_attachment.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/announcement_service.dart';
import '../../org_admin/announcements/widgets/announcement_form_sheet.dart';
import '../widgets/student_app_bar.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({
    required this.announcementId,
    this.initialAnnouncement,
    this.service,
    super.key,
  });

  final int announcementId;
  final Announcement? initialAnnouncement;
  final AnnouncementService? service;

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  late final AnnouncementService _service;

  Announcement? _announcement;
  String? _errorMessage;
  late bool _isLoading;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AnnouncementService();
    _announcement = widget.initialAnnouncement;
    _isLoading = widget.initialAnnouncement == null;
    if (_announcement == null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final announcement = await _service.fetchAnnouncement(
        widget.announcementId,
      );
      if (mounted) setState(() => _announcement = announcement);
    } on AnnouncementException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to load announcement.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking || _announcement == null) return;
    setState(() => _isLiking = true);
    try {
      final result = await _service.toggleLike(widget.announcementId);
      if (mounted) {
        setState(() {
          _announcement = _announcement!.copyWith(
            likeCount: result.likeCount,
            isLiked: result.isLiked,
          );
        });
      }
    } on AnnouncementException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like status.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _openEditSheet() async {
    if (_announcement == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: AnnouncementFormSheet(announcement: _announcement),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement updated successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
    }
  }

  void _copyAttachmentUrl(String url, String typeLabel) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$typeLabel copied to clipboard.')));
  }

  Future<void> _launchExternalUrl(String url) async {
    final resolved = resolveImageUrl(url);
    final uri = Uri.tryParse(resolved.isNotEmpty ? resolved : url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid link address.')));
      }
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open link: $url')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open link: $e')));
      }
    }
  }

  void _openImagePreview(String imageUrl) {
    final resolved = resolveImageUrl(imageUrl);
    if (resolved.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Unable to load image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
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
    String? role;
    try {
      role = context.watch<AuthProvider>().session?.role;
    } catch (_) {}
    final isOrgAdmin = role == 'ORG_ADMIN';

    final effectiveAttachments = <AnnouncementAttachment>[];
    if (_announcement != null) {
      if (_announcement!.attachments.isNotEmpty) {
        effectiveAttachments.addAll(_announcement!.attachments);
      } else if (_announcement!.attachmentType != 'NONE' &&
          _announcement!.attachmentUrl != null &&
          _announcement!.attachmentUrl!.trim().isNotEmpty) {
        effectiveAttachments.add(
          AnnouncementAttachment(
            attachmentType: _announcement!.attachmentType,
            attachmentUrl: _announcement!.attachmentUrl!.trim(),
          ),
        );
      }
    }

    return Scaffold(
      appBar: StudentAppBar(
        showBack: true,
        actions: [
          if (isOrgAdmin && _announcement != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Notice',
              onPressed: _openEditSheet,
            ),
        ],
        onBack: () {
          if (Navigator.of(context).canPop()) {
            context.pop();
          } else {
            if (role == 'ORG_ADMIN') {
              context.go(AppRoutes.adminAnnouncements);
            } else if (role == 'SUPERVISOR') {
              context.go(AppRoutes.supervisorAnnouncements);
            } else {
              context.go(AppRoutes.studentAnnouncements);
            }
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: AppLoader())
            : _errorMessage != null
            ? EmptyState(
                title: 'Could not load announcement',
                message: _errorMessage,
                actionLabel: 'Retry',
                onAction: _loadData,
              )
            : _announcement == null
            ? const EmptyState(
                title: 'Announcement not found',
                message:
                    'This announcement does not exist or has been removed.',
                icon: Icons.campaign_outlined,
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                  vertical: AppDimensions.spacingMedium,
                ),
                children: [
                  _HeaderSection(announcement: _announcement!),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  Text(
                    _announcement!.title,
                    style: AppTextStyles.headingMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingSmall),
                  Text(
                    _announcement!.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  if (effectiveAttachments.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingLarge),
                    _MultiAttachmentSection(
                      attachments: effectiveAttachments,
                      onImageTap: _openImagePreview,
                      onCopyUrl: _copyAttachmentUrl,
                      onOpenUrl: _launchExternalUrl,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacingLarge),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _ActionBar(
                    announcement: _announcement!,
                    isLiking: _isLiking,
                    onToggleLike: _toggleLike,
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                ],
              ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(
            Icons.campaign_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Administration', style: AppTextStyles.label),
              if (announcement.createdAt != null)
                Text(
                  _formatDateTime(announcement.createdAt!),
                  style: AppTextStyles.caption,
                ),
            ],
          ),
        ),
        if (announcement.isImportant) ...[
          const _Badge(label: 'IMPORTANT', color: AppColors.error),
          const SizedBox(width: 6),
        ],
        const _Badge(label: 'OFFICIAL', color: AppColors.info),
      ],
    );
  }
}

class _MultiAttachmentSection extends StatelessWidget {
  const _MultiAttachmentSection({
    required this.attachments,
    required this.onImageTap,
    required this.onCopyUrl,
    required this.onOpenUrl,
  });

  final List<AnnouncementAttachment> attachments;
  final ValueChanged<String> onImageTap;
  final void Function(String url, String typeLabel) onCopyUrl;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final images = attachments
        .where((a) => a.attachmentType == 'IMAGE')
        .toList();
    final documents = attachments
        .where((a) => a.attachmentType == 'PDF')
        .toList();
    final links = attachments.where((a) => a.attachmentType == 'LINK').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                images.length == 1
                    ? 'Attachment Image'
                    : 'Attachment Images (${images.length})',
                style: AppTextStyles.label,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (images.length == 1)
            _ImageCard(
              imageUrl: images.first.attachmentUrl,
              onTap: () => onImageTap(images.first.attachmentUrl),
              height: 240,
            )
          else
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final img = images[index];
                  return SizedBox(
                    width: 260,
                    child: _ImageCard(
                      imageUrl: img.attachmentUrl,
                      onTap: () => onImageTap(img.attachmentUrl),
                      height: 200,
                      badge: '${index + 1}/${images.length}',
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppDimensions.spacingMedium),
        ],
        if (documents.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                documents.length == 1
                    ? 'Attached Document'
                    : 'Attached Documents (${documents.length})',
                style: AppTextStyles.label,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: documents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = documents[index];
              return _DocumentCard(
                attachment: doc,
                onOpen: () => onOpenUrl(doc.attachmentUrl),
                onCopy: () => onCopyUrl(doc.attachmentUrl, 'PDF link'),
              );
            },
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
        ],
        if (links.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.link_outlined, size: 18, color: AppColors.info),
              const SizedBox(width: 6),
              Text(
                links.length == 1
                    ? 'Related Link'
                    : 'Related Links (${links.length})',
                style: AppTextStyles.label,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: links.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final link = links[index];
              return _LinkCard(
                attachment: link,
                onOpen: () => onOpenUrl(link.attachmentUrl),
                onCopy: () => onCopyUrl(link.attachmentUrl, 'Link'),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.imageUrl,
    required this.onTap,
    required this.height,
    this.badge,
  });

  final String imageUrl;
  final VoidCallback onTap;
  final double height;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final fullUrl = resolveImageUrl(imageUrl);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            InkWell(
              onTap: onTap,
              child: Image.network(
                fullUrl,
                height: height,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: height,
                    width: double.infinity,
                    color: AppColors.divider.withValues(alpha: 0.3),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
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
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    if (badge != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.attachment,
    required this.onOpen,
    required this.onCopy,
  });

  final AnnouncementAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final name =
        attachment.originalFilename != null &&
            attachment.originalFilename!.isNotEmpty
        ? attachment.originalFilename!
        : (attachment.attachmentUrl.split('/').last.isNotEmpty
              ? attachment.attachmentUrl.split('/').last
              : 'PDF Document');

    final sizeText = _formatFileSize(attachment.fileSize);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.label.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sizeText.isNotEmpty
                      ? 'PDF Document • $sizeText'
                      : 'PDF Document',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open PDF',
            icon: const Icon(
              Icons.open_in_new,
              size: 20,
              color: AppColors.primary,
            ),
            onPressed: onOpen,
          ),
          IconButton(
            tooltip: 'Copy link',
            icon: const Icon(
              Icons.copy_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.attachment,
    required this.onOpen,
    required this.onCopy,
  });

  final AnnouncementAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final title =
        attachment.originalFilename != null &&
            attachment.originalFilename!.isNotEmpty
        ? attachment.originalFilename!
        : attachment.attachmentUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.link_outlined,
              color: AppColors.info,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Web Link',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Visit link',
            icon: const Icon(
              Icons.open_in_browser,
              size: 20,
              color: AppColors.primary,
            ),
            onPressed: onOpen,
          ),
          IconButton(
            tooltip: 'Copy link',
            icon: const Icon(
              Icons.copy_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.announcement,
    required this.isLiking,
    required this.onToggleLike,
  });

  final Announcement announcement;
  final bool isLiking;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isLiking ? null : onToggleLike,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (isLiking)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  else
                    Icon(
                      announcement.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 22,
                      color: announcement.isLiked
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '${announcement.likeCount} ${announcement.likeCount == 1 ? 'Like' : 'Likes'}',
                    style: AppTextStyles.label.copyWith(
                      color: announcement.isLiked
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (announcement.updatedAt != null)
            Text(
              'Updated ${_formatDate(announcement.updatedAt!)}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
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

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1.0) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  final kb = bytes / 1024;
  return '${kb.toStringAsFixed(0)} KB';
}

String _formatDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
