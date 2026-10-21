import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import 'splash_canvas_painter.dart';

/// Presentation widget that coordinates the rich cinematic splash animation
/// for CampusHive, followed by an unchanged clean logo hold.
class CampusHiveSplashAnimator extends StatelessWidget {
  CampusHiveSplashAnimator({
    required this.controller,
    this.statusWidget,
    this.isError = false,
    this.activeFraction = 0.50, // 3500ms active animation / 7000ms total
    super.key,
  })  : ribbonDrawAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.000, 0.230, curve: Curves.easeOutCubic), // 0.0s – 1.6s
        ),
        ribbonFadeAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.286, 0.400, curve: Curves.easeOutQuad), // 2.0s – 2.8s (gone by 2.8s!)
        ),
        particleClockAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.000, 0.414, curve: Curves.linear), // 0.0s – 2.9s
        ),
        particleFadeAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.286, 0.414, curve: Curves.easeOutQuad), // 2.0s – 2.9s (gone by 2.9s!)
        ),
        burstAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.240, 0.429, curve: Curves.easeOutQuad), // 1.7s – 3.0s
        ),
        hexagonAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.200, 0.371, curve: Curves.linear), // 1.4s – 2.6s
        ),
        emblemAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.257, 0.386, curve: Curves.linear), // 1.8s – 2.7s
        ),
        logoCrossfadeAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.343, 0.457, curve: Curves.easeOutQuad), // 2.4s – 3.2s
        ),
        textRevealAnimation = CurvedAnimation(
          parent: controller,
          curve: const Interval(0.400, 0.486, curve: Curves.easeOut), // 2.8s – 3.4s
        );

  final AnimationController controller;
  final Widget? statusWidget;
  final bool isError;
  final double activeFraction;

  final Animation<double> ribbonDrawAnimation;
  final Animation<double> ribbonFadeAnimation;
  final Animation<double> particleClockAnimation;
  final Animation<double> particleFadeAnimation;
  final Animation<double> burstAnimation;
  final Animation<double> hexagonAnimation;
  final Animation<double> emblemAnimation;
  final Animation<double> logoCrossfadeAnimation;
  final Animation<double> textRevealAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            // Enlarged logo size (~17.4% larger than previous 230px, capped proportionally)
            final maxLogo = isError ? 240.0 : 270.0;
            final logoSize = math.min(w * 0.70, math.min(h * (isError ? 0.30 : 0.36), maxLogo));

            // Unified vertical center (balanced across screen aspect ratios)
            final centerRatio = isError ? (h > 700 ? 0.36 : 0.30) : (h > 700 ? 0.44 : 0.42);
            final logoCenter = Offset(w / 2, h * centerRatio);

            // Crossfade into high-resolution final brand logo
            final logoFadeProgress = logoCrossfadeAnimation.value;
            final logoScale = 0.98 + 0.02 * logoFadeProgress;
            final logoSlideY = (1.0 - logoFadeProgress) * 5.0;

            // Subtitle fade
            final textFadeProgress = textRevealAnimation.value;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1: Procedural dynamic canvas.
                // Ribbons fade out starting at 2.0s and reach exact 0 opacity at 2.8s.
                // Particles fade out by 2.9s. Bursts fade out by 3.0s.
                // During the 3.5s–7.0s hold, canvas is completely clean warm ivory background.
                Positioned.fill(
                  child: CustomPaint(
                    painter: SplashCanvasPainter(
                      ribbonDrawProgress: ribbonDrawAnimation.value,
                      ribbonFadeProgress: ribbonFadeAnimation.value,
                      particleProgress: particleClockAnimation.value,
                      particleFadeProgress: particleFadeAnimation.value,
                      burstProgress: burstAnimation.value,
                      hexagonProgress: hexagonAnimation.value,
                      emblemProgress: emblemAnimation.value,
                      crossfadeProgress: logoFadeProgress,
                      logoCenter: logoCenter,
                      logoSize: logoSize,
                    ),
                  ),
                ),

                // Layer 2: Official enlarged logo asset crossfade.
                // Anchored to the identical physical bounding box with exact 1:1 proportionality.
                Positioned(
                  left: logoCenter.dx - logoSize / 2,
                  top: logoCenter.dy - logoSize / 2,
                  width: logoSize,
                  height: logoSize,
                  child: Transform.translate(
                    offset: Offset(0, logoSlideY),
                    child: Transform.scale(
                      scale: logoScale,
                      child: Opacity(
                        opacity: logoFadeProgress,
                        child: Image.asset(
                          'assets/logos/campus_hive_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Layer 3: Subtitle & status controls unified below the enlarged logo.
                Positioned.fill(
                  child: SafeArea(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: logoCenter.dy + logoSize / 2 + 16.0,
                        left: AppDimensions.screenHorizontalPadding,
                        right: AppDimensions.screenHorizontalPadding,
                        bottom: 16.0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Slogan
                              Opacity(
                                opacity: isError ? 1.0 : textFadeProgress,
                                child: const Text(
                                  'The heart of your digital campus life',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),

                              const SizedBox(height: AppDimensions.spacingLarge),

                              // Status / loader / retry button
                              if (statusWidget != null)
                                Opacity(
                                  opacity: isError ? 1.0 : textFadeProgress,
                                  child: statusWidget!,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
