import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

enum _PopupPart { balloon, arrow }

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
    final Offset tip = Offset(target.dx, target.dy - verticalOffset);

    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints)
          {
            final Size area = constraints.biggest;

            if (area.isEmpty)
            {
              return const SizedBox.shrink();
            }

            return AnimatedScale(
              scale: isVisible ? 1.0 : 0.6,
              // Grows out of the arrow's tip, wherever the balloon is pushed.
              alignment: Alignment(tip.dx / area.width * 2 - 1, tip.dy / area.height * 2 - 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: CustomMultiChildLayout(
                  delegate: _PopupLayout(tip),
                  children: [
                    LayoutId(
                      id: _PopupPart.balloon,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: AppTheme.tooltipDecoration,
                        child: Text(text, style: AppTheme.tooltipTextStyle),
                      ),
                    ),
                    LayoutId(
                      id: _PopupPart.arrow,
                      child: CustomPaint(
                        size: const Size(10, 5),
                        painter: _TriangleArrowPainter(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// The arrow stays on the point; the balloon slides sideways to stay inside the
// chart, which would otherwise clip it at either end.
class _PopupLayout extends MultiChildLayoutDelegate
{
  final Offset tip;

  _PopupLayout(this.tip);

  @override
  void performLayout(Size size)
  {
    final Size arrow = layoutChild(_PopupPart.arrow, BoxConstraints.loose(size));
    final Size balloon = layoutChild(_PopupPart.balloon, BoxConstraints.loose(size));

    final double arrowTop = tip.dy - arrow.height;
    final double left = (tip.dx - balloon.width / 2).clamp(0.0, math.max(0.0, size.width - balloon.width));

    positionChild(_PopupPart.arrow, Offset(tip.dx - arrow.width / 2, arrowTop));
    positionChild(_PopupPart.balloon, Offset(left, arrowTop - balloon.height));
  }

  @override
  bool shouldRelayout(_PopupLayout oldDelegate) => oldDelegate.tip != tip;
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
