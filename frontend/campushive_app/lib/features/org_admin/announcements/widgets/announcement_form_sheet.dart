import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
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
  late final TextEditingController _attachmentUrlController;

  late bool _isImportant;
  late String _attachmentType;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _attachmentOptions = [
    ('NONE', 'None', Icons.block),
    ('IMAGE', 'Image', Icons.image_outlined),
    ('PDF', 'PDF Document', Icons.picture_as_pdf_outlined),
    ('LINK', 'Web Link', Icons.link_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.announcement;
    _titleController = TextEditingController(text: item?.title ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _attachmentUrlController = TextEditingController(
      text: item?.attachmentUrl ?? '',
    );
    _isImportant = item?.isImportant ?? false;
    _attachmentType = item?.attachmentType ?? 'NONE';
    if (!_attachmentOptions.any((opt) => opt.$1 == _attachmentType)) {
      _attachmentType = 'NONE';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _attachmentUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final provider = context.read<AnnouncementProvider>();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final attachmentUrl = _attachmentType == 'NONE'
        ? null
        : _attachmentUrlController.text.trim();

    try {
      if (widget.isEditing) {
        await provider.updateAnnouncement(
          widget.announcement!.announcementId,
          title: title,
          description: description,
          isImportant: _isImportant,
          attachmentType: _attachmentType,
          attachmentUrl: attachmentUrl,
        );
      } else {
        await provider.createAnnouncement(
          title: title,
          description: description,
          isImportant: _isImportant,
          attachmentType: _attachmentType,
          attachmentUrl: attachmentUrl,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AnnouncementException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
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
                Text('Attachment Type', style: AppTextStyles.label),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _attachmentType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.attach_file, size: 20),
                  ),
                  items: _attachmentOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt.$1,
                      child: Row(
                        children: [
                          Icon(
                            opt.$3,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(opt.$2),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _attachmentType = val;
                      });
                    }
                  },
                ),
                if (_attachmentType != 'NONE') ...[
                  const SizedBox(height: AppDimensions.spacingMedium),
                  Text(
                    _attachmentType == 'IMAGE'
                        ? 'Image Resource URL *'
                        : _attachmentType == 'PDF'
                        ? 'PDF Document URL *'
                        : 'Web Link URL *',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _attachmentUrlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: _attachmentType == 'IMAGE'
                          ? 'https://example.com/banner.png'
                          : _attachmentType == 'PDF'
                          ? 'https://example.com/circular.pdf'
                          : 'https://example.com/announcement',
                      prefixIcon: Icon(
                        _attachmentType == 'IMAGE'
                            ? Icons.image_outlined
                            : _attachmentType == 'PDF'
                            ? Icons.picture_as_pdf_outlined
                            : Icons.link_outlined,
                        size: 20,
                      ),
                      helperText:
                          'Campus announcements link directly to online documents and media resources.',
                      helperMaxLines: 2,
                    ),
                    validator: (value) {
                      if (_attachmentType == 'NONE') return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'URL is required when attachment type is selected';
                      }
                      final trimmed = value.trim();
                      if (!trimmed.startsWith('http://') &&
                          !trimmed.startsWith('https://') &&
                          !trimmed.startsWith('/')) {
                        return 'Please provide a valid URL starting with http://, https://, or /';
                      }
                      return null;
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
