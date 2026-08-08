import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

// Dark label that follows the hovered element on a chart. It is always built,
// even when nothing is hovered: keeping it mounted and only animating opacity is
// what lets it fade out in place instead of vanishing.
class ChartValuePopup extends StatelessWidget
{
  final Offset target;
  final String text;
  final bool isVisible;
  final double verticalOffset;

  const ChartValuePopup({
    super.key,
    required this.target,
    required this.text,
    required this.isVisible,
    this.verticalOffset = 10,
  });

  @override
  Widget build(BuildContext context)
  {
    return Positioned(
      left: target.dx,
      top: target.dy - verticalOffset,
      child: IgnorePointer(
        // Anchors the balloon by its bottom centre, so it sits above the point
        // regardless of how wide the text is.
        child: FractionalTranslation(
          translation: const Offset(-0.5, -1.0),
          child: AnimatedScale(
            scale: isVisible ? 1.0 : 0.6,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    // The app's one dark surface, read from the theme rather
                    // than dressed here: this is a tooltip, and a tooltip on a
                    // chart has no reason to be a different object from the one
                    // on a button.
                    decoration: AppTheme.tooltipDecoration,
                    child: Text(text, style: AppTheme.tooltipTextStyle),
                  ),
                  CustomPaint(
                    size: const Size(10, 5),
                    painter: _TriangleArrowPainter(),
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

class _TriangleArrowPainter extends CustomPainter
{
  @override
  void paint(Canvas canvas, Size size)
  {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()
        // The same surface as the balloon above it, alpha included, or the two
        // read as two objects.
        ..color = AppTheme.trialOcean.withValues(alpha: 0.97)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}