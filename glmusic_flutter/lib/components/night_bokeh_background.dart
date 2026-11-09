import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

enum BokehStyle {
  diffuseCloud,
  softOrb,
  crispDisc,
  sparklingPin,
}

class BokehSpot {
  final int id;
  final double xRatio;
  final double yRatio;
  final double diameter;
  final double blurRadius;
  final double baseOpacity;
  final int colorType; // 0: primary, 1: secondary, 2: highlight
  final BokehStyle style;
  final Offset driftRange;

  const BokehSpot({
    required this.id,
    required this.xRatio,
    required this.yRatio,
    required this.diameter,
    required this.blurRadius,
    required this.baseOpacity,
    required this.colorType,
    required this.style,
    required this.driftRange,
  });
}

class NightBokehBackground extends StatefulWidget {
  const NightBokehBackground({super.key});

  @override
  State<NightBokehBackground> createState() => _NightBokehBackgroundState();
}

class _NightBokehBackgroundState extends State<NightBokehBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  static const List<BokehSpot> _spots = [
    // 1. 远景大光晕
    BokehSpot(id: 1, xRatio: 0.82, yRatio: 0.15, diameter: 290, blurRadius: 50, baseOpacity: 0.12, colorType: 0, style: BokehStyle.diffuseCloud, driftRange: Offset(14, -12)),
    BokehSpot(id: 2, xRatio: 0.15, yRatio: 0.20, diameter: 230, blurRadius: 44, baseOpacity: 0.10, colorType: 1, style: BokehStyle.diffuseCloud, driftRange: Offset(-10, 12)),
    BokehSpot(id: 3, xRatio: 0.50, yRatio: 0.70, diameter: 260, blurRadius: 52, baseOpacity: 0.09, colorType: 0, style: BokehStyle.diffuseCloud, driftRange: Offset(12, 14)),
    BokehSpot(id: 4, xRatio: 0.88, yRatio: 0.82, diameter: 250, blurRadius: 46, baseOpacity: 0.11, colorType: 1, style: BokehStyle.diffuseCloud, driftRange: Offset(-12, -10)),

    // 2. 中景经典焦外柔光球
    BokehSpot(id: 5, xRatio: 0.70, yRatio: 0.28, diameter: 130, blurRadius: 22, baseOpacity: 0.15, colorType: 1, style: BokehStyle.softOrb, driftRange: Offset(-14, 10)),
    BokehSpot(id: 6, xRatio: 0.08, yRatio: 0.48, diameter: 110, blurRadius: 18, baseOpacity: 0.14, colorType: 0, style: BokehStyle.softOrb, driftRange: Offset(12, -8)),
    BokehSpot(id: 7, xRatio: 0.32, yRatio: 0.62, diameter: 120, blurRadius: 20, baseOpacity: 0.13, colorType: 1, style: BokehStyle.softOrb, driftRange: Offset(-10, 12)),
    BokehSpot(id: 8, xRatio: 0.78, yRatio: 0.75, diameter: 135, blurRadius: 22, baseOpacity: 0.14, colorType: 0, style: BokehStyle.softOrb, driftRange: Offset(12, -12)),

    // 3. 具象清晰光斑
    BokehSpot(id: 9, xRatio: 0.78, yRatio: 0.18, diameter: 74, blurRadius: 2.0, baseOpacity: 0.17, colorType: 0, style: BokehStyle.crispDisc, driftRange: Offset(-10, 8)),
    BokehSpot(id: 10, xRatio: 0.86, yRatio: 0.32, diameter: 54, blurRadius: 1.5, baseOpacity: 0.21, colorType: 1, style: BokehStyle.crispDisc, driftRange: Offset(8, -10)),
    BokehSpot(id: 11, xRatio: 0.68, yRatio: 0.40, diameter: 88, blurRadius: 2.2, baseOpacity: 0.15, colorType: 2, style: BokehStyle.crispDisc, driftRange: Offset(-8, -8)),
    BokehSpot(id: 12, xRatio: 0.18, yRatio: 0.35, diameter: 62, blurRadius: 1.8, baseOpacity: 0.18, colorType: 0, style: BokehStyle.crispDisc, driftRange: Offset(10, 8)),
    BokehSpot(id: 13, xRatio: 0.25, yRatio: 0.72, diameter: 68, blurRadius: 2.0, baseOpacity: 0.16, colorType: 2, style: BokehStyle.crispDisc, driftRange: Offset(-8, 10)),
    BokehSpot(id: 14, xRatio: 0.62, yRatio: 0.82, diameter: 80, blurRadius: 2.2, baseOpacity: 0.15, colorType: 1, style: BokehStyle.crispDisc, driftRange: Offset(8, -10)),
    BokehSpot(id: 15, xRatio: 0.92, yRatio: 0.58, diameter: 48, blurRadius: 1.5, baseOpacity: 0.22, colorType: 0, style: BokehStyle.crispDisc, driftRange: Offset(-6, 6)),

    // 4. 近景晶莹微光点
    BokehSpot(id: 16, xRatio: 0.94, yRatio: 0.18, diameter: 30, blurRadius: 2.5, baseOpacity: 0.34, colorType: 2, style: BokehStyle.crispDisc, driftRange: Offset(6, -6)),
    BokehSpot(id: 17, xRatio: 0.64, yRatio: 0.20, diameter: 36, blurRadius: 3.0, baseOpacity: 0.30, colorType: 2, style: BokehStyle.softOrb, driftRange: Offset(-8, 8)),
    BokehSpot(id: 18, xRatio: 0.20, yRatio: 0.82, diameter: 26, blurRadius: 2.0, baseOpacity: 0.36, colorType: 2, style: BokehStyle.crispDisc, driftRange: Offset(6, 8)),
    BokehSpot(id: 19, xRatio: 0.45, yRatio: 0.88, diameter: 34, blurRadius: 2.8, baseOpacity: 0.28, colorType: 0, style: BokehStyle.softOrb, driftRange: Offset(-6, -8)),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _resolveColor(int type, ThemeProvider theme) {
    switch (type) {
      case 0:
        return theme.primaryColor;
      case 1:
        return theme.secondaryColor;
      case 2:
        return theme.highlightColor;
      default:
        return theme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final t = _animation.value; // 0.0 to 1.0
          return CustomPaint(
            size: Size.infinite,
            painter: _BokehPainter(
              theme: theme,
              progress: t,
              spots: _spots,
              resolveColor: (type) => _resolveColor(type, theme),
            ),
          );
        },
      ),
    );
  }
}

class _BokehPainter extends CustomPainter {
  final ThemeProvider theme;
  final double progress;
  final List<BokehSpot> spots;
  final Color Function(int type) resolveColor;

  _BokehPainter({
    required this.theme,
    required this.progress,
    required this.spots,
    required this.resolveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base dark background with slight tint
    final basePaint = Paint()
      ..color = const Color(0xFF0F1115);
    canvas.drawRect(Offset.zero & size, basePaint);

    final tintPaint = Paint()
      ..color = theme.primaryColor.withValues(alpha: 0.04);
    canvas.drawRect(Offset.zero & size, tintPaint);

    // 2. Top subtle gradient
    final Rect topRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.55);
    final topGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        theme.primaryColor.withValues(alpha: 0.08),
        theme.secondaryColor.withValues(alpha: 0.03),
        Colors.transparent,
      ],
    );
    final topPaint = Paint()..shader = topGradient.createShader(topRect);
    canvas.drawRect(topRect, topPaint);

    // 3. Render 19 bokeh spots
    for (final spot in spots) {
      final color = resolveColor(spot.colorType);
      final baseX = size.width * spot.xRatio;
      final baseY = size.height * spot.yRatio;

      // Drift calculation
      final driftX = (progress * 2 - 1) * spot.driftRange.dx;
      final driftY = (progress * 2 - 1) * spot.driftRange.dy;
      final center = Offset(baseX + driftX, baseY + driftY);

      // Subtle scale pulsation (0.95 to 1.05)
      final scale = 0.95 + 0.10 * progress;
      final radius = (spot.diameter / 2) * scale;

      switch (spot.style) {
        case BokehStyle.diffuseCloud:
        case BokehStyle.softOrb:
          final radialShader = RadialGradient(
            colors: [
              color.withValues(alpha: spot.baseOpacity),
              color.withValues(alpha: spot.baseOpacity * 0.65),
              color.withValues(alpha: spot.baseOpacity * 0.15),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 0.8, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius));

          final spotPaint = Paint()
            ..shader = radialShader
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, spot.blurRadius);
          canvas.drawCircle(center, radius, spotPaint);
          break;

        case BokehStyle.crispDisc:
          // Disc fill with brighter rim
          final discShader = RadialGradient(
            colors: [
              color.withValues(alpha: spot.baseOpacity * 0.50),
              color.withValues(alpha: spot.baseOpacity * 0.70),
              color.withValues(alpha: spot.baseOpacity * 0.90),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius));

          final discPaint = Paint()
            ..shader = discShader
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, spot.blurRadius);
          canvas.drawCircle(center, radius, discPaint);

          // Clear rim outline like camera lens aperture ring
          final strokePaint = Paint()
            ..color = color.withValues(alpha: (spot.baseOpacity * 1.55).clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, spot.blurRadius);
          canvas.drawCircle(center, radius, strokePaint);
          break;

        case BokehStyle.sparklingPin:
          // Outer halo
          final haloPaint = Paint()
            ..color = color.withValues(alpha: spot.baseOpacity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, spot.blurRadius);
          canvas.drawCircle(center, radius, haloPaint);

          // Bright inner core
          final corePaint = Paint()
            ..color = Colors.white.withValues(alpha: (spot.baseOpacity * 0.85).clamp(0.0, 1.0))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
          canvas.drawCircle(center, radius * 0.38, corePaint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BokehPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.theme != theme;
  }
}
