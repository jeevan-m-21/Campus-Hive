import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/image_url_resolver.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

/// Interactive profile avatar widget allowing users to change their profile picture.
///
/// Features:
/// - Camera and Gallery image selection via bottom sheet
/// - Loading overlay spinner during upload
/// - Duplicate request prevention while uploading
/// - Graceful error handling with SnackBar feedback
/// - Cache eviction on successful update
/// - Fallback icon when no profile image exists
class EditableProfileAvatar extends StatefulWidget {
  const EditableProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 38.0,
    this.fallbackIcon = Icons.person_outline,
    this.fallbackIconColor = AppColors.textSecondary,
    this.imagePicker,
    this.onUploadSuccess,
  });

  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final Color fallbackIconColor;
  final ImagePicker? imagePicker;
  final VoidCallback? onUploadSuccess;

  @override
  State<EditableProfileAvatar> createState() => _EditableProfileAvatarState();
}

class _EditableProfileAvatarState extends State<EditableProfileAvatar> {
  bool _isUploading = false;

  Future<void> _showImageSourcePicker(BuildContext context) async {
    if (_isUploading) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Change Profile Picture',
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(modalContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(modalContext).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;
    await _pickAndUploadImage(source);
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    if (_isUploading) return;

    final picker = widget.imagePicker ?? ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Permission denied or media unavailable.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select image.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (pickedFile == null || !mounted) return; // User cancelled

    setState(() => _isUploading = true);

    try {
      final oldRawUrl = widget.imageUrl;
      await context.read<AuthProvider>().uploadProfileImage(pickedFile.path);

      // Evict old image from cache if applicable to prevent stale display
      if (oldRawUrl != null && oldRawUrl.isNotEmpty) {
        final oldResolved = resolveImageUrl(oldRawUrl);
        if (oldResolved.isNotEmpty) {
          PaintingBinding.instance.imageCache.evict(NetworkImage(oldResolved));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onUploadSuccess?.call();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to upload profile picture. Please check your connection.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = (widget.imageUrl ?? '').trim();
    final resolvedUrl = resolveImageUrl(rawUrl);
    final size = widget.radius * 2;

    return Semantics(
      label: 'Change profile picture',
      button: true,
      child: InkWell(
        onTap: _isUploading ? null : () => _showImageSourcePicker(context),
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              resolvedUrl.isEmpty
                  ? CircleAvatar(
                      radius: widget.radius,
                      backgroundColor: AppColors.divider,
                      child: Icon(
                        widget.fallbackIcon,
                        size: widget.radius * 0.9,
                        color: widget.fallbackIconColor,
                      ),
                    )
                  : CircleAvatar(
                      radius: widget.radius,
                      backgroundColor: AppColors.divider,
                      backgroundImage: NetworkImage(resolvedUrl),
                      onBackgroundImageError: (exception, stackTrace) {},
                    ),
              if (_isUploading)
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              if (!_isUploading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
