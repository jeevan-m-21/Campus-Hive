import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/announcement.dart';
import '../../../providers/announcement_provider.dart';
import '../widgets/admin_app_bar.dart';
import 'widgets/admin_announcement_card.dart';
import 'widgets/announcement_form_sheet.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AnnouncementProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFormSheet([Announcement? announcement]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: AnnouncementFormSheet(announcement: announcement),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            announcement != null
                ? 'Announcement updated successfully.'
                : 'Announcement published successfully.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Announcement announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text(
          'Are you sure you want to delete "${announcement.title}"?\n\nThis will remove the announcement from student, supervisor, and administrative feeds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AnnouncementProvider>().deleteAnnouncement(
        announcement.announcementId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement deleted successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete announcement: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnnouncementProvider>();

    final filteredItems = _searchQuery.isEmpty
        ? provider.items
        : provider.items.where((item) {
            final query = _searchQuery.toLowerCase();
            return item.title.toLowerCase().contains(query) ||
                item.description.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      appBar: const AdminAppBar(title: 'Announcements'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text(
          'New Announcement',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () => _openFormSheet(),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => provider.load(refresh: true),
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenHorizontalPadding,
                  12,
                  AppDimensions.screenHorizontalPadding,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search announcements...',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        isDense: true,
                        fillColor: AppColors.background,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(
                            provider.isLoading && provider.items.isEmpty
                                ? 'All'
                                : 'All (${provider.total})',
                            style: TextStyle(
                              color: !provider.importantOnly
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: !provider.importantOnly
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                          selected: !provider.importantOnly,
                          selectedColor: AppColors.primary,
                          onSelected: (selected) {
                            if (selected) {
                              provider.setImportantOnly(false);
                            }
                          },
                        ),
                        const SizedBox(width: AppDimensions.spacingSmall),
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.priority_high,
                                size: 14,
                                color: provider.importantOnly
                                    ? Colors.white
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Important Only',
                                style: TextStyle(
                                  color: provider.importantOnly
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: provider.importantOnly
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          selected: provider.importantOnly,
                          selectedColor: AppColors.primary,
                          onSelected: (selected) {
                            if (selected) {
                              provider.setImportantOnly(true);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(child: _buildContent(context, provider, filteredItems)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AnnouncementProvider provider,
    List<Announcement> items,
  ) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (provider.errorMessage != null && provider.items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EmptyState(
            title: 'Could not load announcements',
            message: provider.errorMessage,
            actionLabel: 'Retry',
            onAction: () => provider.load(refresh: true),
          ),
        ),
      );
    }

    if (provider.items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenHorizontalPadding,
            ),
            child: EmptyState(
              title: provider.importantOnly
                  ? 'No important announcements'
                  : 'No announcements yet',
              message: provider.importantOnly
                  ? 'No urgent notices flagged at this time.'
                  : 'Publish official organization notices and broadcasts for campus members.',
              icon: Icons.campaign_outlined,
              actionLabel: 'Create Announcement',
              onAction: () => _openFormSheet(),
            ),
          ),
        ),
      );
    }

    if (items.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenHorizontalPadding,
            ),
            child: EmptyState(
              title: 'No matching notices',
              message: 'No announcements matched "$_searchQuery".',
              icon: Icons.search_off,
              actionLabel: 'Clear Search',
              onAction: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenHorizontalPadding,
        AppDimensions.spacingMedium,
        AppDimensions.screenHorizontalPadding,
        80, // extra clearance for FloatingActionButton
      ),
      itemCount: items.length + (provider.hasNext ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingMedium,
            ),
            child: AppButton(
              label: provider.isLoadingPage ? 'Loading...' : 'Load more',
              isLoading: provider.isLoadingPage,
              onPressed: provider.loadNextPage,
              expand: true,
            ),
          );
        }

        final announcement = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          child: AdminAnnouncementCard(
            item: announcement,
            onEdit: () => _openFormSheet(announcement),
            onDelete: () => _confirmDelete(announcement),
          ),
        );
      },
    );
  }
}
