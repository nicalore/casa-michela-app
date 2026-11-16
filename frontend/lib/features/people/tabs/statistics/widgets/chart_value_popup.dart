import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

enum _PopupPart { balloon, arrow }

// Past the chart's sides, into the card's padding, the balloon may reach this far.
const double _overhang = 12;

// The balloon's corner, as AppTheme.tooltipDecoration rounds it: the arrow stays off it.
const double _balloonRadius = 12;

// Where the arrow's tip sits from the middle of its base: set by the layout, read by the painter.
class _ArrowLean
{
  double dx = 0;
}

// Always built, even with nothing hovered: animating only opacity lets it fade out in place.
class ChartValuePopup extends StatelessWidget
{
  final Offset target;
  final String? text;

  // Several lines instead of [text].
  final Widget? content;

  final bool isVisible;
  final double verticalOffset;

  const ChartValuePopup({
    super.key,
    required this.target,
    this.text,
    this.content,
    required this.isVisible,
    this.verticalOffset = 10,
  }) : assert((text == null) != (content == null));

  @override
  Widget build(BuildContext context)
  {
    final Offset tip = Offset(target.dx, target.dy - verticalOffset);
    final _ArrowLean lean = _ArrowLean();

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
                  delegate: _PopupLayout(tip, lean),
                  children: [
                    LayoutId(
                      id: _PopupPart.balloon,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: AppTheme.tooltipDecoration,
                        child: content ?? Text(text!, style: AppTheme.tooltipTextStyle),
                      ),
                    ),
                    LayoutId(
                      id: _PopupPart.arrow,
                      child: CustomPaint(
                        size: const Size(10, 5),
                        painter: _TriangleArrowPainter(lean),
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

// The balloon slides sideways to stay inside the chart, a little past its sides at most; the
// arrow's base stays on the balloon's straight edge and its tip on the point.
class _PopupLayout extends MultiChildLayoutDelegate
{
  final Offset tip;
  final _ArrowLean lean;

  _PopupLayout(this.tip, this.lean);

  @override
  void performLayout(Size size)
  {
    final Size arrow = layoutChild(_PopupPart.arrow, BoxConstraints.loose(size));
    final Size balloon = layoutChild(
      _PopupPart.balloon,
      BoxConstraints.loose(Size(size.width + 2 * _overhang, size.height)),
    );

    final double arrowTop = tip.dy - arrow.height;
    final double left = (tip.dx - balloon.width / 2).clamp(
      -_overhang,
      math.max(-_overhang, size.width + _overhang - balloon.width),
    );
    final double inset = _balloonRadius + arrow.width / 2;
    final double base = tip.dx.clamp(left + inset, math.max(left + inset, left + balloon.width - inset));

    lean.dx = tip.dx - base;

    positionChild(_PopupPart.arrow, Offset(base - arrow.width / 2, arrowTop));
    positionChild(_PopupPart.balloon, Offset(left, arrowTop - balloon.height));
  }

  @override
  bool shouldRelayout(_PopupLayout oldDelegate) => oldDelegate.tip != tip || oldDelegate.lean != lean;
}

class _TriangleArrowPainter extends CustomPainter
{
  final _ArrowLean lean;

  _TriangleArrowPainter(this.lean);

  @override
  void paint(Canvas canvas, Size size)
  {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2 + lean.dx, size.height)
        ..close(),
      Paint()
        // Must match the balloon's surface, alpha included.
        ..color = AppTheme.trialOcean.withValues(alpha: 0.97)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TriangleArrowPainter oldDelegate) => oldDelegate.lean != lean;
}
