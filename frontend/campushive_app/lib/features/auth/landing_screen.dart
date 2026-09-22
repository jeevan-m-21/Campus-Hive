import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'auth_shell.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Your campus, in one place.',
      subtitle:
          'Stay connected to campus updates, report issues, and find what matters to you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
                SizedBox(height: AppDimensions.spacingMedium),
                Text(
                  'A clearer campus experience',
                  style: AppTextStyles.headingSmall,
                ),
                SizedBox(height: AppDimensions.spacingSmall),
                Text(
                  'Bring announcements, complaints, events, and community conversations into one calm, useful space.',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          AppButton(
            label: 'Log in',
            icon: Icons.login_rounded,
            onPressed: () => context.go(AppRoutes.login),
            expand: true,
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          AppButton(
            label: 'Create student account',
            variant: AppButtonVariant.outlined,
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => context.go(AppRoutes.register),
            expand: true,
          ),
        ],
      ),
    );
  }
}
