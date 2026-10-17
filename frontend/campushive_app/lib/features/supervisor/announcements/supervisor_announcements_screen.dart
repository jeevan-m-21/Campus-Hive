import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../providers/announcement_provider.dart';
import '../../student/home/widgets/announcement_feed_card.dart';
import '../widgets/supervisor_app_bar.dart';

class SupervisorAnnouncementsScreen extends StatelessWidget {
  const SupervisorAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SupervisorAnnouncementsView();
  }
}

class _SupervisorAnnouncementsView extends StatelessWidget {
  const _SupervisorAnnouncementsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnnouncementProvider>();

    return Scaffold(
      appBar: const SupervisorAppBar(title: 'Announcements'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.load(refresh: true),
          child: _buildBody(context, provider),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AnnouncementProvider provider) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (provider.errorMessage != null && provider.items.isEmpty) {
      return EmptyState(
        title: 'Could not load announcements',
        message: provider.errorMessage,
        actionLabel: 'Retry',
        onAction: () => provider.load(refresh: true),
      );
    }

    if (provider.items.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: EmptyState(
            title: 'No announcements yet',
            message:
                'Campus broadcasts and notices from Administration will appear here.',
            icon: Icons.campaign_outlined,
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
      itemCount: provider.items.length,
      itemBuilder: (context, index) {
        final announcement = provider.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          child: AnnouncementFeedCard(item: announcement),
        );
      },
    );
  }
}
