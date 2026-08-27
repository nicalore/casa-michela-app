import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

// Always built, even when nothing is hovered: keeping it mounted and animating
// only opacity is what lets it fade out in place.
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
        // Anchored by its bottom centre, so it sits above the point whatever
        // the text width.
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
        // Must match the balloon's surface, alpha included.
        ..color = AppTheme.trialOcean.withValues(alpha: 0.97)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}