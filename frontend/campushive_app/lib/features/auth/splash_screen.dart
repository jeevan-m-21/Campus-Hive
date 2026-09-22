import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 220,
                    width: 220,
                    child: Image.asset(
                      'assets/logos/campus_hive_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  const Text(
                    'The heart of your digital campus life',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  const _BootStatus(),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  AppButton(
                    label: 'Enter CampusHive',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => context.go(AppRoutes.landing),
                    expand: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootStatus extends StatelessWidget {
  const _BootStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.standardCardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.success),
          SizedBox(width: AppDimensions.spacingSmall),
          Expanded(
            child: Text(
              'Ready to connect your campus community',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
