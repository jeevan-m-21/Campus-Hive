import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../services/lost_found_service.dart';
import '../widgets/student_app_bar.dart';

class ReportLostFoundScreen extends StatefulWidget {
  const ReportLostFoundScreen({super.key});

  @override
  State<ReportLostFoundScreen> createState() => _ReportLostFoundScreenState();
}

class _ReportLostFoundScreenState extends State<ReportLostFoundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _service = LostFoundService();

  String _itemType = 'LOST';
  String? _selectedCategory;
  DateTime? _selectedDate = DateTime.now();

  XFile? _selectedImage;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _categories = [
    'Electronics',
    'Documents & Cards',
    'Clothing & Accessories',
    'Keys',
    'Books & Stationery',
    'Water Bottles & Flasks',
    'Personal Belongings',
    'Others',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _selectedImage = image);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick image.')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await _service.uploadImage(_selectedImage!.path);
      }

      final dateStr = _selectedDate != null
          ? "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
          : null;

      await _service.createItem(
        itemType: _itemType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        location: _locationController.text.trim(),
        dateOfIncident: dateStr,
        imageUrl: uploadedImageUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _itemType == 'LOST'
                ? 'Lost report submitted successfully.'
                : 'Found report submitted successfully.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop(true);
    } on LostFoundException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to create post.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _itemType = 'LOST'),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _itemType == 'LOST'
                      ? AppColors.error
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Lost Item',
                  style: AppTextStyles.label.copyWith(
                    color: _itemType == 'LOST'
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _itemType = 'FOUND'),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _itemType == 'FOUND'
                      ? AppColors.success
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Found Item',
                  style: AppTextStyles.label.copyWith(
                    color: _itemType == 'FOUND'
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _selectedDate != null
        ? "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
        : 'Select date';

    return Scaffold(
      appBar: const StudentAppBar(showBack: true),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            children: [
              Text(
                _itemType == 'LOST'
                    ? 'Report a lost item'
                    : 'Report a found item',
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Text(
                _itemType == 'LOST'
                    ? 'Provide details to help others identify and return your lost item.'
                    : 'Provide details to help the rightful owner find their lost item.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTypeToggle(),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    AppTextField(
                      controller: _titleController,
                      label: 'Item title',
                      hint: 'e.g. Blue Dell Laptop Bag, Black Wallet',
                      prefixIcon: Icons.title_outlined,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        hintText: 'Select item category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    AppTextField(
                      controller: _locationController,
                      label: 'Location (optional)',
                      hint: 'Where was it lost/found? (e.g. Library 2nd Floor)',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of incident',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          formattedDate,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    AppTextField(
                      controller: _descriptionController,
                      label: 'Detailed description',
                      hint:
                          'Describe item features, color, brand, distinct marks, etc.',
                      maxLines: 4,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Description is required'
                          : null,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    const Text(
                      'Photo attachment (optional)',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: AppDimensions.spacingSmall),
                    if (_selectedImage != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_selectedImage!.path),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    setState(() => _selectedImage = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Add Photo'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppDimensions.spacingMedium),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.spacingLarge),
                    AppButton(
                      label: _itemType == 'LOST'
                          ? 'Submit Lost Report'
                          : 'Submit Found Report',
                      icon: Icons.send_outlined,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                      expand: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
