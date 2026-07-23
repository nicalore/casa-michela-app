import 'package:flutter/material.dart';

enum GlowCorner
{
  topRight,
  bottomLeft,
}

// Decorative radial glow bleeding in from a corner of the page. It is far
// larger than the viewport and deliberately positioned off screen, so only the
// faded tail of the gradient is visible.
class CornerGlow extends StatelessWidget
{
  static const double _diameter = 1600;
  static const double _offset = -800;

  final GlowCorner corner;

  const CornerGlow({super.key, required this.corner});

  @override
  Widget build(BuildContext context)
  {
    final isTopRight = corner == GlowCorner.topRight;

    return Positioned(
      top: isTopRight ? _offset : null,
      right: isTopRight ? _offset : null,
      bottom: isTopRight ? null : _offset,
      left: isTopRight ? null : _offset,
      child: const IgnorePointer(
        child: SizedBox(
          width: _diameter,
          height: _diameter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x4D003C82),
                  Color(0x22003C82),
                  Color(0x00003C82),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}