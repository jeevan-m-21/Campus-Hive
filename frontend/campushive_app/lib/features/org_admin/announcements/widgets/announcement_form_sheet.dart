import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_url_resolver.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../models/announcement.dart';
import '../../../../providers/announcement_provider.dart';
import '../../../../services/announcement_service.dart';

class AnnouncementFormSheet extends StatefulWidget {
  const AnnouncementFormSheet({this.announcement, super.key});

  final Announcement? announcement;

  bool get isEditing => announcement != null;

  @override
  State<AnnouncementFormSheet> createState() => _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends State<AnnouncementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late bool _isImportant;
  final List<_AttachmentDraft> _attachments = [];
  bool _isSubmitting = false;
  String? _uploadStatusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final item = widget.announcement;
    _titleController = TextEditingController(text: item?.title ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _isImportant = item?.isImportant ?? false;

    if (item != null) {
      if (item.attachments.isNotEmpty) {
        for (final att in item.attachments) {
          _attachments.add(
            _AttachmentDraft(
              attachmentId: att.attachmentId,
              attachmentType: att.attachmentType,
              attachmentUrl: att.attachmentUrl,
              displayName: att.originalFilename ?? att.attachmentUrl,
              mimeType: att.mimeType,
              fileSize: att.fileSize,
            ),
          );
        }
      } else if (item.attachmentType != 'NONE' &&
          item.attachmentUrl != null &&
          item.attachmentUrl!.trim().isNotEmpty) {
        _attachments.add(
          _AttachmentDraft(
            attachmentType: item.attachmentType,
            attachmentUrl: item.attachmentUrl!.trim(),
            displayName: item.attachmentUrl!.trim(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      final newDrafts = <_AttachmentDraft>[];
      for (final file in pickedFiles) {
        final length = await file.length();
        if (length > 15 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${file.name} exceeds 15MB limit.')),
            );
          }
          continue;
        }
        final ext = file.name.split('.').last.toLowerCase();
        final mimeType = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
        newDrafts.add(
          _AttachmentDraft(
            attachmentType: 'IMAGE',
            localFilePath: file.path,
            displayName: file.name,
            mimeType: mimeType,
            fileSize: length,
          ),
        );
      }

      if (mounted && newDrafts.isNotEmpty) {
        setState(() => _attachments.addAll(newDrafts));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isEmpty) return;

      final newDrafts = <_AttachmentDraft>[];
      for (final file in files) {
        final filePath = file.path;
        if (filePath == null) continue;
        final fileSize = file.lengthSync() ?? await file.length() ?? 0;
        if (fileSize > 15 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${file.name} exceeds 15MB limit.')),
            );
          }
          continue;
        }
        final ext = file.extension?.toLowerCase() ?? '';
        final isPdf = ext == 'pdf';
        final attachmentType = isPdf ? 'PDF' : 'IMAGE';
        final mimeType = isPdf ? 'application/pdf' : 'image/$ext';
        newDrafts.add(
          _AttachmentDraft(
            attachmentType: attachmentType,
            localFilePath: filePath,
            displayName: file.name,
            mimeType: mimeType,
            fileSize: fileSize,
          ),
        );
      }

      if (mounted && newDrafts.isNotEmpty) {
        setState(() => _attachments.addAll(newDrafts));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick files: $e')));
      }
    }
  }

  Future<void> _addLinkDialog() async {
    final linkController = TextEditingController();
    final linkFormKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Web Link'),
        content: Form(
          key: linkFormKey,
          child: TextFormField(
            controller: linkController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL *',
              hintText: 'https://example.com/circular',
              prefixIcon: Icon(Icons.link_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a URL';
              }
              final trimmed = value.trim();
              if (!trimmed.startsWith('http://') &&
                  !trimmed.startsWith('https://') &&
                  !trimmed.startsWith('/')) {
                return 'URL must start with http://, https://, or /';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (linkFormKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Add Link'),
          ),
        ],
      ),
    );

    if (added == true && mounted) {
      final url = linkController.text.trim();
      setState(() {
        _attachments.add(
          _AttachmentDraft(
            attachmentType: 'LINK',
            attachmentUrl: url,
            displayName: url,
          ),
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _uploadStatusMessage = null;
    });

    final provider = context.read<AnnouncementProvider>();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    try {
      // 1. Upload newly selected local files
      final localFilesToUpload = _attachments.where((a) => a.isLocal).toList();
      int uploadedCount = 0;
      for (final draft in localFilesToUpload) {
        uploadedCount++;
        setState(() {
          _uploadStatusMessage =
              'Uploading attachment ($uploadedCount/${localFilesToUpload.length})...';
        });

        final uploaded = await provider.uploadAttachment(draft.localFilePath!);
        draft.attachmentUrl = uploaded.attachmentUrl;
        draft.mimeType ??= uploaded.mimeType;
        draft.fileSize ??= uploaded.fileSize;
      }

      setState(() {
        _uploadStatusMessage = widget.isEditing
            ? 'Updating announcement...'
            : 'Publishing announcement...';
      });

      // 2. Prepare payload
      final attachmentsPayload = _attachments.map((a) => a.toMap()).toList();
      final primaryType = _attachments.isNotEmpty
          ? _attachments.first.attachmentType
          : 'NONE';
      final primaryUrl = _attachments.isNotEmpty
          ? _attachments.first.attachmentUrl
          : null;

      // 3. Save announcement
      if (widget.isEditing) {
        await provider.updateAnnouncement(
          widget.announcement!.announcementId,
          title: title,
          description: description,
          isImportant: _isImportant,
          attachmentType: primaryType,
          attachmentUrl: primaryUrl,
          attachments: attachmentsPayload,
        );
      } else {
        await provider.createAnnouncement(
          title: title,
          description: description,
          isImportant: _isImportant,
          attachmentType: primaryType,
          attachmentUrl: primaryUrl,
          attachments: attachmentsPayload,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AnnouncementException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _uploadStatusMessage = null;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _uploadStatusMessage = null;
        _errorMessage = widget.isEditing
            ? 'Failed to update announcement. Please check your connection.'
            : 'Failed to create announcement. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.cardRadius),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenHorizontalPadding,
            vertical: AppDimensions.spacingMedium,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.isEditing
                            ? Icons.edit_note_outlined
                            : Icons.campaign_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEditing
                                ? 'Edit Announcement'
                                : 'Create Announcement',
                            style: AppTextStyles.headingSmall,
                          ),
                          Text(
                            widget.isEditing
                                ? 'Update notice details broadcasted to users'
                                : 'Broadcast notice to campus students & staff',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppDimensions.spacingMedium),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_uploadStatusMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _uploadStatusMessage!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text('Title *', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Campus Maintenance Notice',
                    prefixIcon: Icon(Icons.title, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an announcement title';
                    }
                    if (value.trim().length < 3) {
                      return 'Title must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSmall),
                Text('Content / Description *', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter complete announcement details...',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter announcement description';
                    }
                    if (value.trim().length < 5) {
                      return 'Description must be at least 5 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        const Icon(
                          Icons.priority_high,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mark as Important',
                          style: AppTextStyles.label.copyWith(
                            color: _isImportant
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    subtitle: const Text(
                      'Presents notice with urgent badge at the top of feeds',
                      style: AppTextStyles.bodySmall,
                    ),
                    value: _isImportant,
                    activeThumbColor: AppColors.error,
                    onChanged: (val) => setState(() => _isImportant = val),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attachments (${_attachments.length})',
                      style: AppTextStyles.label,
                    ),
                    Text(
                      'Max 15MB each',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Add Images'),
                      onPressed: _isSubmitting ? null : _pickImages,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Add PDF / Files'),
                      onPressed: _isSubmitting ? null : _pickFiles,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.link_outlined, size: 18),
                      label: const Text('Add Link'),
                      onPressed: _isSubmitting ? null : _addLinkDialog,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attachments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _attachments[index];
                      return _AttachmentDraftCard(
                        draft: item,
                        onDelete: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _attachments.removeAt(index);
                                });
                              },
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppDimensions.spacingLarge),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.outlined,
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: widget.isEditing
                            ? 'Save Changes'
                            : 'Publish Notice',
                        icon: widget.isEditing
                            ? Icons.save_outlined
                            : Icons.send_outlined,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentDraft {
  _AttachmentDraft({
    this.attachmentId,
    required this.attachmentType,
    this.attachmentUrl,
    this.localFilePath,
    required this.displayName,
    this.mimeType,
    this.fileSize,
  });

  final int? attachmentId;
  final String attachmentType;
  String? attachmentUrl;
  final String? localFilePath;
  final String displayName;
  String? mimeType;
  int? fileSize;

  bool get isLocal =>
      localFilePath != null &&
      (attachmentUrl == null || attachmentUrl!.isEmpty);
  bool get isUploaded => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isLink => attachmentType == 'LINK';

  Map<String, dynamic> toMap() {
    return {
      if (attachmentId != null) 'attachment_id': attachmentId,
      'attachment_type': attachmentType,
      'attachment_url': attachmentUrl,
      'original_filename': displayName,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileSize != null) 'file_size': fileSize,
    };
  }
}

class _AttachmentDraftCard extends StatelessWidget {
  const _AttachmentDraftCard({required this.draft, required this.onDelete});

  final _AttachmentDraft draft;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget thumbnail;
    if (draft.attachmentType == 'IMAGE') {
      if (draft.localFilePath != null &&
          File(draft.localFilePath!).existsSync()) {
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(draft.localFilePath!),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        );
      } else if (draft.attachmentUrl != null &&
          draft.attachmentUrl!.isNotEmpty) {
        final url = resolveImageUrl(draft.attachmentUrl!);
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            url,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image_outlined,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
        );
      } else {
        thumbnail = const Icon(Icons.image_outlined, color: AppColors.primary);
      }
    } else if (draft.attachmentType == 'PDF') {
      thumbnail = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.picture_as_pdf_outlined,
          color: AppColors.error,
          size: 24,
        ),
      );
    } else {
      thumbnail = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.link_outlined, color: AppColors.info, size: 24),
      );
    }

    String statusLabel;
    Color statusColor;
    if (draft.isLocal) {
      statusLabel = 'Local file (Ready to upload)';
      statusColor = AppColors.success;
    } else if (draft.isLink) {
      statusLabel = 'Web link';
      statusColor = AppColors.info;
    } else {
      statusLabel = 'Uploaded';
      statusColor = AppColors.textSecondary;
    }

    String sizeInfo = '';
    if (draft.fileSize != null && draft.fileSize! > 0) {
      final sizeMb = draft.fileSize! / (1024 * 1024);
      if (sizeMb >= 1.0) {
        sizeInfo = ' • ${sizeMb.toStringAsFixed(1)} MB';
      } else {
        final sizeKb = draft.fileSize! / 1024;
        sizeInfo = ' • ${sizeKb.toStringAsFixed(0)} KB';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          thumbnail,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '$statusLabel$sizeInfo',
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.error,
            ),
            tooltip: 'Remove',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
