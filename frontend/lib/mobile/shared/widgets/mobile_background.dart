import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class MobileBackground extends StatelessWidget
{
  final Widget? child;

  const MobileBackground({super.key, this.child});

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  Widget build(BuildContext context)
  {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(painter: _BackdropPainter()),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter
{
  const _BackdropPainter();

  // CSS angle: 0 points up, growing clockwise.
  static const double _angleDegrees = 160;

  static const List<Color> _seaColors = [
    AppTheme.trialDeepWater,
    AppTheme.trialTealDeep,
    AppTheme.trialSeaGreen,
    AppTheme.trialLagoon,
  ];

  static const List<double> _seaStops = [0.0, 0.45, 0.75, 1.0];

  @override
  void paint(Canvas canvas, Size size)
  {
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..shader = _sea(size).createShader(rect));

    _paintGlow(
      canvas,
      center: Offset(size.width * 0.85, -size.height * 0.10),
      radiusX: 1200,
      radiusY: 800,
      color: AppTheme.trialGold.withValues(alpha: 0.25),
      fadeAt: 0.60,
    );

    _paintGlow(
      canvas,
      center: Offset(-size.width * 0.10, size.height * 1.10),
      radiusX: 1000,
      radiusY: 700,
      color: AppTheme.trialViolet.withValues(alpha: 0.18),
      fadeAt: 0.55,
    );
  }

  // Ends land on the corners as in CSS linear-gradient, so the tilt holds on any aspect ratio.
  LinearGradient _sea(Size size)
  {
    final radians = _angleDegrees * math.pi / 180;
    final dx = math.sin(radians);
    final dy = -math.cos(radians);
    final length = (size.width * dx).abs() + (size.height * dy).abs();

    final end = Alignment(dx * length / size.width, dy * length / size.height);

    return LinearGradient(begin: -end, end: end, colors: _seaColors, stops: _seaStops);
  }

  // Fading to the tint at zero alpha, not to black, keeps the mid-tones from greying.
  void _paintGlow(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    required double fadeAt,
  })
  {
    final shader = ui.Gradient.radial(
      Offset.zero,
      radiusX,
      [color, color.withValues(alpha: 0)],
      [0.0, fadeAt],
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, radiusY / radiusX);
    canvas.drawCircle(Offset.zero, radiusX, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}
