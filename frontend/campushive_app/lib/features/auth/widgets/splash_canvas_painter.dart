import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Data model representing a single ambient floating particle.
class SplashParticle {
  const SplashParticle({
    required this.normalizedX,
    required this.normalizedY,
    required this.radius,
    required this.color,
    required this.phase,
    required this.speed,
    this.isVortex = false,
    this.vortexRadius = 0.0,
    this.vortexAngle = 0.0,
  });

  final double normalizedX;
  final double normalizedY;
  final double radius;
  final Color color;
  final double phase;
  final double speed;
  final bool isVortex;
  final double vortexRadius;
  final double vortexAngle;
}

/// Model representing one honeycomb hexagon outline.
class HoneycombHexCell {
  const HoneycombHexCell({
    required this.offsetFrom500Center,
    required this.radius500,
    required this.color,
    required this.strokeWidth500,
    required this.delayFraction,
    required this.initialAngleOffset,
    required this.flightOffset,
  });

  // Center offset relative to (250, 250) in 500x500 reference logo
  final Offset offsetFrom500Center;
  final double radius500;
  final Color color;
  final double strokeWidth500;
  final double delayFraction; // 0.0 to 1.0 within assembly interval
  final double initialAngleOffset; // slight rotation on entry
  final Offset flightOffset; // slight displacement converging to center
}

/// High-performance CustomPainter rendering the cinematic splash visuals.
/// All procedural geometry (hexagons, emblem, radial burst) is mathematically
/// aligned to the exact physical coordinates of assets/logos/campus_hive_logo.png.
/// When ribbonFadeProgress reaches 1.0 (at 2.8s), all ribbons are completely invisible.
/// During the final logo hold (3.5s–7.0s), all decorative elements have zero opacity.
class SplashCanvasPainter extends CustomPainter {
  SplashCanvasPainter({
    required this.ribbonDrawProgress,
    required this.ribbonFadeProgress,
    required this.particleProgress,
    required this.particleFadeProgress,
    required this.burstProgress,
    required this.hexagonProgress,
    required this.emblemProgress,
    required this.crossfadeProgress,
    this.logoCenter,
    this.logoSize,
  });

  final double ribbonDrawProgress;
  final double ribbonFadeProgress;
  final double particleProgress;
  final double particleFadeProgress;
  final double burstProgress;
  final double hexagonProgress;
  final double emblemProgress;
  final double crossfadeProgress;
  final Offset? logoCenter;
  final double? logoSize;

  // Brand Palette
  static const Color navyColor = Color(0xFF163B65);
  static const Color navyDarkColor = Color(0xFF0F2B4D);
  static const Color goldColor = Color(0xFFFDBE11);
  static const Color goldAccentColor = Color(0xFFF5A623);
  static const Color warmBgCenter = Color(0xFFFCFBF9);
  static const Color warmBgEdge = Color(0xFFF3F1EC);

  // 28 deterministic particles: 16 rising ambient motes + 12 inward swirling vortex particles
  static final List<SplashParticle> _particles = _createParticles();

  static List<SplashParticle> _createParticles() {
    final list = <SplashParticle>[];
    final random = math.Random(42);

    // 16 rising motes
    for (int i = 0; i < 16; i++) {
      final isGold = random.nextBool();
      list.add(
        SplashParticle(
          normalizedX: random.nextDouble(),
          normalizedY: random.nextDouble(),
          radius: 1.4 + random.nextDouble() * 2.0,
          color: isGold ? goldColor : navyColor,
          phase: random.nextDouble() * 2 * math.pi,
          speed: 0.20 + random.nextDouble() * 0.30,
          isVortex: false,
        ),
      );
    }

    // 12 inward swirling vortex particles that converge toward the center emblem
    for (int i = 0; i < 12; i++) {
      final isGold = i % 2 == 0;
      final angle = (i * 2 * math.pi / 12) + random.nextDouble() * 0.5;
      final dist = 0.25 + random.nextDouble() * 0.25;
      list.add(
        SplashParticle(
          normalizedX: 0.5 + math.cos(angle) * dist,
          normalizedY: 0.44 + math.sin(angle) * dist,
          radius: 1.8 + random.nextDouble() * 1.8,
          color: isGold ? goldAccentColor : goldColor,
          phase: random.nextDouble() * 2 * math.pi,
          speed: 0.35 + random.nextDouble() * 0.25,
          isVortex: true,
          vortexRadius: dist,
          vortexAngle: angle,
        ),
      );
    }

    return list;
  }

  // Exact hexagon offsets measured directly from assets/logos/campus_hive_logo.png (500x500)
  // Image center is (250, 250). Hexagons have radius ~33.5px and stroke ~3.4px.
  // Each hexagon now includes a dynamic flightOffset and initialAngleOffset for rich entry.
  static const List<HoneycombHexCell> _hexCells = [
    // Top center (Gold)
    HoneycombHexCell(
      offsetFrom500Center: Offset(-3.5, -90.5),
      radius500: 33.5,
      color: goldColor,
      strokeWidth500: 3.4,
      delayFraction: 0.0,
      initialAngleOffset: -0.25,
      flightOffset: Offset(0, -28),
    ),
    // Top left (Navy)
    HoneycombHexCell(
      offsetFrom500Center: Offset(-58.5, -90.5),
      radius500: 33.5,
      color: navyColor,
      strokeWidth500: 3.4,
      delayFraction: 0.12,
      initialAngleOffset: 0.20,
      flightOffset: Offset(-24, -20),
    ),
    // Top right (Navy)
    HoneycombHexCell(
      offsetFrom500Center: Offset(56.0, -90.5),
      radius500: 33.5,
      color: navyColor,
      strokeWidth500: 3.4,
      delayFraction: 0.20,
      initialAngleOffset: -0.20,
      flightOffset: Offset(24, -20),
    ),
    // Middle-left (Navy)
    HoneycombHexCell(
      offsetFrom500Center: Offset(-42.5, -40.5),
      radius500: 33.5,
      color: navyColor,
      strokeWidth500: 3.4,
      delayFraction: 0.32,
      initialAngleOffset: 0.18,
      flightOffset: Offset(-20, 10),
    ),
    // Far left (Gold)
    HoneycombHexCell(
      offsetFrom500Center: Offset(-90.0, -40.0),
      radius500: 33.5,
      color: goldColor,
      strokeWidth500: 3.4,
      delayFraction: 0.44,
      initialAngleOffset: -0.22,
      flightOffset: Offset(-30, 0),
    ),
    // Middle-right (Gold)
    HoneycombHexCell(
      offsetFrom500Center: Offset(42.5, -42.0),
      radius500: 33.5,
      color: goldColor,
      strokeWidth500: 3.4,
      delayFraction: 0.54,
      initialAngleOffset: -0.18,
      flightOffset: Offset(20, 10),
    ),
    // Far right (Gold)
    HoneycombHexCell(
      offsetFrom500Center: Offset(85.5, -40.0),
      radius500: 33.5,
      color: goldColor,
      strokeWidth500: 3.4,
      delayFraction: 0.65,
      initialAngleOffset: 0.22,
      flightOffset: Offset(30, 0),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveLogoSize = logoSize ?? (math.min(size.width * 0.70, 270.0));
    final effectiveLogoCenter = logoCenter ?? Offset(size.width / 2, size.height * 0.44);
    final scale = effectiveLogoSize / 500.0;

    _paintWarmBackground(canvas, size, effectiveLogoCenter);
    _paintFloatingParticles(canvas, size, effectiveLogoCenter);
    _paintCurvedRibbons(canvas, size, effectiveLogoCenter);
    _paintRadialBurst(canvas, size, effectiveLogoCenter, scale);
    _paintHoneycombHexagons(canvas, effectiveLogoCenter, scale);
    _paintEducationalEmblem(canvas, effectiveLogoCenter, scale);
  }

  /// 1. Warm off-white background with subtle radial warmth centered on logo
  void _paintWarmBackground(Canvas canvas, Size size, Offset center) {
    final maxRadius = math.max(size.width, size.height) * 0.9;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (center.dx / size.width) * 2 - 1,
          (center.dy / size.height) * 2 - 1,
        ),
        radius: 1.1,
        colors: const [
          warmBgCenter,
          warmBgCenter,
          warmBgEdge,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawRect(Offset.zero & size, bgPaint);
  }

  /// 2. Floating particles: rising motes + converging vortex particles
  /// Fades completely to 0 opacity as particleFadeProgress reaches 1.0 (by 2.9s).
  void _paintFloatingParticles(Canvas canvas, Size size, Offset center) {
    if (particleProgress <= 0.0) return;

    final fadeOut = (1.0 - particleFadeProgress).clamp(0.0, 1.0);
    if (fadeOut <= 0.001) return; // Completely invisible during hold!

    for (final p in _particles) {
      double x;
      double y;

      if (p.isVortex) {
        // Swirl inward toward the center emblem as animation advances
        final inwardFraction = (1.0 - particleProgress * 0.65).clamp(0.2, 1.0);
        final currentRadius = p.vortexRadius * math.min(size.width, size.height) * inwardFraction;
        final currentAngle = p.vortexAngle + particleProgress * 2.5 * math.pi;

        x = center.dx + math.cos(currentAngle) * currentRadius;
        y = center.dy + math.sin(currentAngle) * currentRadius * 0.75;
      } else {
        // Gentle upward drift with horizontal sine sway
        final driftY = (p.normalizedY - particleProgress * p.speed) % 1.0;
        y = driftY * size.height;

        final sway = math.sin(particleProgress * 3 * math.pi + p.phase) * 16.0;
        x = (p.normalizedX * size.width + sway) % size.width;
      }

      final alphaPulse = (0.35 + 0.65 * math.sin(particleProgress * 4 * math.pi + p.phase)).clamp(0.0, 1.0);
      final alpha = (alphaPulse * fadeOut * 0.75).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  /// 3. Flowing dynamic navy-blue and golden-yellow curved ribbons (Bezier curves)
  /// Disappears completely as ribbonFadeProgress reaches 1.0 (2.0s–2.8s).
  /// Strictly zero opacity from 2.8s onward!
  void _paintCurvedRibbons(Canvas canvas, Size size, Offset center) {
    if (ribbonDrawProgress <= 0.0) return;

    final ribbonOpacity = (1.0 - ribbonFadeProgress).clamp(0.0, 1.0);
    if (ribbonOpacity <= 0.001) return; // Fully invisible by 2.8s!

    final w = size.width;
    final h = size.height;
    final cx = center.dx;
    final cy = center.dy;

    // Ribbon 1: Primary Golden Ribbon (sweeps from top-left, loops under emblem, flows to bottom-right)
    final goldPath = Path()
      ..moveTo(-w * 0.18, cy - h * 0.26)
      ..cubicTo(
        w * 0.28,
        cy - h * 0.38,
        w * 0.15,
        cy + h * 0.14,
        cx + w * 0.06,
        cy + h * 0.02,
      )
      ..cubicTo(
        cx + w * 0.28,
        cy - h * 0.10,
        w * 0.88,
        cy + h * 0.24,
        w * 1.18,
        cy + h * 0.38,
      );

    _drawFlowingRibbon(
      canvas: canvas,
      path: goldPath,
      drawProgress: ribbonDrawProgress,
      strokeWidth: 4.2,
      opacity: ribbonOpacity * 0.90,
      primaryColor: goldColor,
      secondaryColor: goldAccentColor,
      rect: Rect.fromLTWH(0, 0, w, h),
    );

    // Ribbon 2: Primary Navy Ribbon (sweeps from bottom-left, curls around honeycomb, soars to top-right)
    final navyPath = Path()
      ..moveTo(-w * 0.14, cy + h * 0.36)
      ..cubicTo(
        w * 0.22,
        cy + h * 0.42,
        w * 0.42,
        cy - h * 0.16,
        cx - w * 0.04,
        cy - h * 0.10,
      )
      ..cubicTo(
        cx + w * 0.18,
        cy - h * 0.06,
        w * 0.82,
        cy - h * 0.34,
        w * 1.14,
        cy - h * 0.28,
      );

    _drawFlowingRibbon(
      canvas: canvas,
      path: navyPath,
      drawProgress: (ribbonDrawProgress * 1.08 - 0.04).clamp(0.0, 1.0),
      strokeWidth: 4.8,
      opacity: ribbonOpacity * 0.95,
      primaryColor: navyColor,
      secondaryColor: navyDarkColor,
      rect: Rect.fromLTWH(0, 0, w, h),
    );

    // Ribbon 3: Amber Spiral Accent Ribbon (dynamic spiraling counter-thread)
    final accentGoldPath = Path()
      ..moveTo(w * 0.05, cy - h * 0.34)
      ..cubicTo(
        w * 0.65,
        cy - h * 0.26,
        w * 0.25,
        cy + h * 0.28,
        w * 0.92,
        cy + h * 0.42,
      );

    _drawFlowingRibbon(
      canvas: canvas,
      path: accentGoldPath,
      drawProgress: (ribbonDrawProgress * 0.95).clamp(0.0, 1.0),
      strokeWidth: 2.2,
      opacity: ribbonOpacity * 0.65,
      primaryColor: goldAccentColor,
      secondaryColor: goldColor,
      rect: Rect.fromLTWH(0, 0, w, h),
    );

    // Ribbon 4: Navy Secondary Counter-Wave (provides layered depth in opposite motion)
    final accentNavyPath = Path()
      ..moveTo(w * 0.95, cy - h * 0.20)
      ..cubicTo(
        w * 0.60,
        cy + h * 0.18,
        w * 0.40,
        cy - h * 0.28,
        -w * 0.10,
        cy + h * 0.15,
      );

    _drawFlowingRibbon(
      canvas: canvas,
      path: accentNavyPath,
      drawProgress: (ribbonDrawProgress * 0.90).clamp(0.0, 1.0),
      strokeWidth: 2.4,
      opacity: ribbonOpacity * 0.50,
      primaryColor: navyColor,
      secondaryColor: navyDarkColor,
      rect: Rect.fromLTWH(0, 0, w, h),
    );
  }

  void _drawFlowingRibbon({
    required Canvas canvas,
    required Path path,
    required double drawProgress,
    required double strokeWidth,
    required double opacity,
    required Color primaryColor,
    required Color secondaryColor,
    required Rect rect,
  }) {
    if (drawProgress <= 0.0 || opacity <= 0.001) return;

    for (final metric in path.computeMetrics()) {
      final totalLen = metric.length;
      final head = (drawProgress * totalLen).clamp(0.0, totalLen);
      final extracted = metric.extractPath(0.0, head);

      // Main dynamic stroke
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            secondaryColor.withValues(alpha: opacity * 0.25),
            primaryColor.withValues(alpha: opacity),
            secondaryColor.withValues(alpha: opacity * 0.35),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect);

      canvas.drawPath(extracted, strokePaint);
    }
  }

  /// 4. Cinematic radial light burst behind the emblem
  /// Blooms to peak when cap reveals, then fades out completely by 3.0s.
  void _paintRadialBurst(Canvas canvas, Size size, Offset logoCenter, double scale) {
    if (burstProgress <= 0.0) return;

    // Fades out completely as official logo takes over
    final fadeOut = (1.0 - crossfadeProgress).clamp(0.0, 1.0);
    if (fadeOut <= 0.001) return;

    final burstCenter = logoCenter + Offset(0, -45.5 * scale);
    final maxRadius = size.width * 0.52;
    final currentRadius = maxRadius * (0.25 + 0.75 * burstProgress);

    // Dynamic bloom curve: rises quickly to intense peak, then recedes
    final bloomCurve = (burstProgress < 0.50
            ? (burstProgress / 0.50)
            : (1.0 - (burstProgress - 0.50) / 0.50))
        .clamp(0.0, 1.0);

    final burstAlpha = (bloomCurve * 0.85 * fadeOut).clamp(0.0, 1.0);
    if (burstAlpha <= 0.001) return;

    // Multi-stop warm radial glow halo
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          goldColor.withValues(alpha: 0.65 * burstAlpha),
          goldAccentColor.withValues(alpha: 0.30 * burstAlpha),
          goldAccentColor.withValues(alpha: 0.08 * burstAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: burstCenter, radius: currentRadius));

    canvas.drawCircle(burstCenter, currentRadius, glowPaint);

    // 16 dynamic rotating light rays
    final rayPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.22 * burstAlpha)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rayRotation = burstProgress * 0.35 * math.pi;
    for (int i = 0; i < 16; i++) {
      final angle = (i * 2 * math.pi / 16) + rayRotation;
      final start = burstCenter + Offset(math.cos(angle) * 24, math.sin(angle) * 24);
      final rayLen = currentRadius * (0.65 + 0.35 * (i % 2 == 0 ? 1.0 : 0.60));
      final end = burstCenter + Offset(math.cos(angle) * rayLen, math.sin(angle) * rayLen);
      canvas.drawLine(start, end, rayPaint);
    }
  }

  /// 5. Honeycomb hexagons assembling around the center
  /// Hexagons now have dynamic inward flight + rotational snap for rich assembly!
  /// Procedural hexagons dissolve completely to zero opacity as official logo fades in.
  void _paintHoneycombHexagons(Canvas canvas, Offset logoCenter, double scale) {
    if (hexagonProgress <= 0.0) return;

    final crossfadeAlpha = (1.0 - crossfadeProgress).clamp(0.0, 1.0);
    if (crossfadeAlpha <= 0.001) return;

    for (final hex in _hexCells) {
      final start = hex.delayFraction * 0.42;
      final end = (start + 0.58).clamp(0.0, 1.0);
      if (hexagonProgress < start) continue;

      final localT = ((hexagonProgress - start) / (end - start)).clamp(0.0, 1.0);
      final curvedT = Curves.easeOutBack.transform(localT);

      // Dynamic inward flight: cells converge from outside into exact lattice positions
      final flightRemaining = (1.0 - curvedT);
      final currentFlight = Offset(
        hex.flightOffset.dx * scale * flightRemaining,
        hex.flightOffset.dy * scale * flightRemaining,
      );

      final hexCenter = logoCenter + Offset(
        hex.offsetFrom500Center.dx * scale,
        hex.offsetFrom500Center.dy * scale,
      ) + currentFlight;

      final hexRadius = hex.radius500 * scale * curvedT;
      if (hexRadius <= 0.1) continue;

      // Rotational snap into place
      final currentRotation = hex.initialAngleOffset * flightRemaining;
      final hexPath = _createPointyHexagonPath(hexCenter, hexRadius, rotation: currentRotation);

      // Activation spark fill (brief flash as cell locks into position)
      if (localT > 0.4 && localT < 0.95) {
        final sparkAlpha = (math.sin((localT - 0.4) / 0.55 * math.pi) * 0.12 * crossfadeAlpha).clamp(0.0, 1.0);
        final fillPaint = Paint()
          ..color = hex.color.withValues(alpha: sparkAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawPath(hexPath, fillPaint);
      }

      // Perimeter stroke trim
      for (final metric in hexPath.computeMetrics()) {
        final perimeter = metric.length;
        final extractLen = perimeter * localT;
        final drawnPath = metric.extractPath(0.0, extractLen);

        final opacity = (localT * crossfadeAlpha).clamp(0.0, 1.0);

        final strokePaint = Paint()
          ..color = hex.color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = hex.strokeWidth500 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        canvas.drawPath(drawnPath, strokePaint);
      }
    }
  }

  Path _createPointyHexagonPath(Offset c, double r, {double rotation = 0.0}) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) - (math.pi / 2) + rotation;
      final x = c.dx + r * math.cos(angle);
      final y = c.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// 6. Educational graduation-cap emblem at center
  /// Features prominent spring entrance + realistic double-pendulum damped tassel sway!
  /// Procedural emblem aligns to exact pixel location and dissolves completely into logo.
  void _paintEducationalEmblem(Canvas canvas, Offset logoCenter, double scale) {
    if (emblemProgress <= 0.0) return;

    final emblemAlpha = (1.0 - crossfadeProgress).clamp(0.0, 1.0);
    if (emblemAlpha <= 0.001) return;

    // Center cap offset from (250, 250) is (0.0, -45.5)
    final center = logoCenter + Offset(0.0, -45.5 * scale);

    final elasticScale = Curves.easeOutBack.transform(emblemProgress.clamp(0.0, 1.0));
    final capWidth = 100.0 * scale * elasticScale;
    final capHeight = 44.0 * scale * elasticScale;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Diamond cap top (mortarboard rhombus)
    final capTopPath = Path()
      ..moveTo(0, -capHeight * 0.48)
      ..lineTo(capWidth * 0.5, 0)
      ..lineTo(0, capHeight * 0.48)
      ..lineTo(-capWidth * 0.5, 0)
      ..close();

    final capPaint = Paint()
      ..color = navyColor.withValues(alpha: emblemAlpha)
      ..style = PaintingStyle.fill;

    canvas.drawShadow(
      capTopPath,
      navyDarkColor.withValues(alpha: 0.40 * emblemAlpha),
      5.0 * scale,
      false,
    );
    canvas.drawPath(capTopPath, capPaint);

    // Cap base / skull cap
    final capBasePath = Path()
      ..moveTo(-capWidth * 0.24, capHeight * 0.18)
      ..cubicTo(
        -capWidth * 0.20,
        capHeight * 0.65,
        capWidth * 0.20,
        capHeight * 0.65,
        capWidth * 0.24,
        capHeight * 0.18,
      )
      ..close();

    final capBasePaint = Paint()
      ..color = navyDarkColor.withValues(alpha: emblemAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(capBasePath, capBasePaint);

    // Center button with highlight
    final buttonPaint = Paint()
      ..color = goldColor.withValues(alpha: emblemAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 3.2 * scale, buttonPaint);

    // Realistic damped pendulum tassel sway: swings right, rebounds, and settles naturally
    final swayTime = emblemProgress.clamp(0.0, 1.0);
    final tasselSway = math.sin(swayTime * 3.5 * math.pi) * math.exp(-1.8 * swayTime) * 6.5 * scale;

    final tasselPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        capWidth * 0.22,
        -capHeight * 0.08,
        capWidth * 0.42,
        capHeight * 0.08,
        capWidth * 0.38 + tasselSway,
        capHeight * 0.55,
      );

    final tasselLinePaint = Paint()
      ..color = goldColor.withValues(alpha: emblemAlpha)
      ..strokeWidth = 2.2 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(tasselPath, tasselLinePaint);

    // Tassel fringe / tip
    canvas.drawCircle(
      Offset(capWidth * 0.38 + tasselSway, capHeight * 0.60),
      3.4 * scale,
      buttonPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SplashCanvasPainter oldDelegate) {
    return oldDelegate.ribbonDrawProgress != ribbonDrawProgress ||
        oldDelegate.ribbonFadeProgress != ribbonFadeProgress ||
        oldDelegate.particleProgress != particleProgress ||
        oldDelegate.particleFadeProgress != particleFadeProgress ||
        oldDelegate.burstProgress != burstProgress ||
        oldDelegate.hexagonProgress != hexagonProgress ||
        oldDelegate.emblemProgress != emblemProgress ||
        oldDelegate.crossfadeProgress != crossfadeProgress ||
        oldDelegate.logoCenter != logoCenter ||
        oldDelegate.logoSize != logoSize;
  }
}
