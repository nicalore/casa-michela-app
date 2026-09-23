import 'package:flutter/material.dart';

enum GlowCorner
{
  topRight,
  bottomLeft,
}

// Static on purpose: on web every animated frame rasterises the whole window.
class CornerGlow extends StatelessWidget
{
  static const double _diameter = 1600;

  static const double _widthFactor = 1.15;
  static const double _minDiameter = 520;

  static double _diameterFor(BuildContext context)
  {
    final width = MediaQuery.sizeOf(context).width * _widthFactor;

    return width.clamp(_minDiameter, _diameter);
  }

  static const Color _defaultTint = Color(0xFF003C82);

  static const double _innerOpacity = 0.30;
  static const double _midOpacity = 0.13;

  final GlowCorner corner;

  final Color tint;

  final Color? edgeTint;

  final double intensity;

  const CornerGlow({
    super.key,
    required this.corner,
    this.tint = _defaultTint,
    this.edgeTint,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context)
  {
    final isTopRight = corner == GlowCorner.topRight;
    final outerTint = edgeTint ?? tint;

    // Clamped: intensity is a free-form knob and alpha outside 0..1 throws.
    final innerAlpha = (_innerOpacity * intensity).clamp(0.0, 1.0);
    final midAlpha = (_midOpacity * intensity).clamp(0.0, 1.0);

    final diameter = _diameterFor(context);
    final offset = -diameter / 2;

    return Positioned(
      top: isTopRight ? offset : null,
      right: isTopRight ? offset : null,
      bottom: isTopRight ? null : offset,
      left: isTopRight ? null : offset,
      child: IgnorePointer(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  tint.withValues(alpha: innerAlpha),
                  outerTint.withValues(alpha: midAlpha),
                  outerTint.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
