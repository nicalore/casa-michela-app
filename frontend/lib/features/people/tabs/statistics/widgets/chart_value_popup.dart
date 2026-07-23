import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';

const Color _popupShadow = Color(0x1F000000);

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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.slate800,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: _popupShadow, offset: Offset(0, 3), blurRadius: 6),
                      ],
                    ),
                    child: Text(
                      text,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
        ..color = AppTheme.slate800
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}