import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../models/department.dart';
import '../../../services/complaint_service.dart';
import '../widgets/student_app_bar.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _service = ComplaintService();

  List<Department> _departments = [];
  int? _selectedDepartmentId;
  bool _isLoadingDepartments = true;
  String? _departmentLoadError;

  XFile? _selectedImage;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoadingDepartments = true;
      _departmentLoadError = null;
    });

    try {
      final depts = await _service.fetchDepartments();
      if (!mounted) return;
      setState(() {
        _departments = depts;
        _isLoadingDepartments = false;
      });
    } on ComplaintException catch (error) {
      if (!mounted) return;
      setState(() {
        _departmentLoadError = error.message;
        _isLoadingDepartments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _departmentLoadError = 'Unable to load service departments.';
        _isLoadingDepartments = false;
      });
    }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartmentId == null) {
      setState(() {
        _errorMessage = 'Please select a department.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await _service.uploadImage(_selectedImage!.path);
      }

      final complaint = await _service.createComplaint(
        departmentId: _selectedDepartmentId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        imageUrl: uploadedImageUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint submitted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pushReplacement(
        AppRoutes.studentComplaintDetail(complaint.complaintId),
      );
    } on ComplaintException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to submit complaint.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildDepartmentSelector() {
    if (_isLoadingDepartments) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Department',
          prefixIcon: Icon(Icons.apartment_outlined),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppDimensions.spacingSmall),
            Text('Loading departments...', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    if (_departmentLoadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Department',
              prefixIcon: Icon(Icons.apartment_outlined),
              errorText: 'Failed to load departments',
            ),
            child: Text(
              _departmentLoadError!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadDepartments,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _selectedDepartmentId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Department',
        hintText: 'Select a department',
        prefixIcon: Icon(Icons.apartment_outlined),
      ),
      items: _departments.map((department) {
        return DropdownMenuItem<int>(
          value: department.departmentId,
          child: Text(
            department.departmentName,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDepartmentId = value;
        });
      },
      validator: (value) => value == null ? 'Please select a department' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const Text('Report an issue', style: AppTextStyles.headingLarge),
              const SizedBox(height: AppDimensions.spacingSmall),
              const Text(
                'Tell the relevant department what needs attention on campus.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDepartmentSelector(),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    AppTextField(
                      controller: _titleController,
                      label: 'Issue title',
                      hint: 'Briefly describe the issue',
                      prefixIcon: Icons.title_outlined,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    AppTextField(
                      controller: _locationController,
                      label: 'Location (optional)',
                      hint: 'Where is the issue?',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    AppTextField(
                      controller: _descriptionController,
                      label: 'Detailed description',
                      hint: 'Describe the issue clearly',
                      maxLines: 5,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Description is required'
                          : null,
                    ),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    const Text(
                      'Attachment (optional)',
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
                        label: const Text('Add Photo / Screenshot'),
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
                      label: 'Submit complaint',
                      icon: Icons.send_outlined,
                      isLoading: _isSubmitting,
                      onPressed: _isLoadingDepartments ? null : _submit,
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
