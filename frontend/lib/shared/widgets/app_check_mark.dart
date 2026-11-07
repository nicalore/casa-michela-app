import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const Color kPickedSurface = Color(0xFFE8F7F5);

class AppCheckMark extends StatelessWidget
{
  static const double size = 22;

  static const double _markSize = 15;

  static const Duration _fade = Duration(milliseconds: 180);

  static final BorderRadius _radius = BorderRadius.circular(7);

  final bool selected;
  final bool partial;
  final VoidCallback? onTap;

  // Grey instead of the brand gradient: a choice kept but not counting.
  final bool muted;

  const AppCheckMark({
    super.key,
    required this.selected,
    this.partial = false,
    this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool filled = selected || partial;

    final Widget mark = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _radius,
              border: Border.all(color: AppTheme.trialLine, width: 2),
            ),
          ),
          AnimatedOpacity(
            opacity: filled ? 1 : 0,
            duration: _fade,
            curve: Curves.easeOutCubic,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: muted ? null : AppTheme.brandGradient,
                color: muted ? AppTheme.trialMutedText.withValues(alpha: 0.45) : null,
                borderRadius: _radius,
              ),
              child: Center(
                child: AnimatedScale(
                  scale: filled ? 1 : 0.7,
                  duration: _fade,
                  curve: Curves.easeOutCubic,
                  child: CustomPaint(
                    size: const Size.square(_markSize),
                    painter: _MarkPainter(tick: selected || !partial),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null)
    {
      return mark;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: mark),
    );
  }
}

// Drawn, not a glyph: a text baseline snaps to whole pixels, so the tick jumped as its scale ended.
class _MarkPainter extends CustomPainter
{
  static const double _grid = 24;

  // The Material icons' centre lines; the stroke is a shade over theirs to weigh as the glyph did.
  static final Path _tick = Path()
    ..moveTo(4.825, 13.405)
    ..lineTo(9, 17.59)
    ..lineTo(19.585, 7.005);

  static final Path _dash = Path()
    ..moveTo(6, 12)
    ..lineTo(18, 12);

  static final Paint _pen = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final bool tick;

  const _MarkPainter({required this.tick});

  @override
  void paint(Canvas canvas, Size size)
  {
    canvas.scale(size.width / _grid);
    canvas.drawPath(tick ? _tick : _dash, _pen);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.tick != tick;
}
