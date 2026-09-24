import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.child,
    this.title,
    this.subtitle,
    this.showBrand = true,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenHorizontalPadding,
            AppDimensions.spacingLarge,
            AppDimensions.screenHorizontalPadding,
            AppDimensions.spacingExtraLarge,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBrand) const _BrandMark(),
                  if (showBrand && (title != null || subtitle != null))
                    const SizedBox(height: AppDimensions.spacingExtraLarge),
                  if (title != null)
                    Text(title!, style: AppTextStyles.headingLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppDimensions.spacingSmall),
                    Text(subtitle!, style: AppTextStyles.bodyMedium),
                  ],
                  if (title != null || subtitle != null)
                    const SizedBox(height: AppDimensions.spacingLarge),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      width: double.infinity,
      child: Image.asset(
        'assets/logos/campus_hive_logo.png',
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class AuthLink extends StatelessWidget {
  const AuthLink({required this.text, required this.onPressed, super.key});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: Text(text));
  }
}
