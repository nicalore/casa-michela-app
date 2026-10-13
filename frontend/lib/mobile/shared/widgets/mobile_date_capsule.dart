import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/utils/day_marks.dart';
import '../mobile_palette.dart';

// Measured: the widest day label of a year in Plus Jakarta Sans.
const String kWidestDayLabel = 'Domenica 20 settembre';

const double _sidePadding = 10;
const double _iconSize = 20;
const double _iconGap = 8;

class MobileDateCapsule extends StatelessWidget
{
  final String label;

  // The widest label the capsule may show, so every label keeps one size.
  final String? widestLabel;
  final bool current;
  final bool tablet;

  // Null where there is nothing that way.
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  final VoidCallback onPick;

  const MobileDateCapsule({
    super.key,
    required this.label,
    this.widestLabel,
    required this.current,
    required this.tablet,
    required this.onBack,
    required this.onForward,
    required this.onPick,
  });

  static final Color _divider = Colors.white.withValues(alpha: 0.18);

  TextStyle _labelStyle(double fontSize)
  {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.1,
      color: Colors.white,
    );
  }

  // Shrinks the type where the widest label would not fit beside the icon.
  double _fontSize(BuildContext context, double room)
  {
    final double base = tablet ? 18 : 16;
    final TextStyle style = DefaultTextStyle.of(context).style.merge(_labelStyle(base));
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    double widthOf(String text)
    {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();

      final double width = painter.width;
      painter.dispose();

      return width;
    }

    final String? widestLabel = this.widestLabel;
    final double widest = math.max(widthOf(label), widestLabel == null ? 0 : widthOf(widestLabel));
    final double textRoom = room - _iconSize - _iconGap;

    return widest <= textRoom ? base : (base * textRoom / widest * 10).floorToDouble() / 10;
  }

  Widget _buildArrow(IconData icon, VoidCallback? onTap, {required bool leading})
  {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: tablet ? 54 : 48,
          decoration: BoxDecoration(
            border: leading ? Border(right: BorderSide(color: _divider)) : Border(left: BorderSide(color: _divider)),
          ),
          child: Icon(icon, size: 26, color: Colors.white.withValues(alpha: onTap != null ? 0.92 : 0.26)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double height = tablet ? 50 : 46;
    final BorderRadius radius = BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      foregroundDecoration: current
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: MobilePalette.currentRim,
                width: MobilePalette.currentRimWidth,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildArrow(Icons.chevron_left_rounded, onBack, leading: true),
          Expanded(
            child: Semantics(
              button: true,
              label: kPickDayLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: _iconSize,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        const SizedBox(width: _iconGap),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _labelStyle(_fontSize(context, constraints.maxWidth)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildArrow(Icons.chevron_right_rounded, onForward, leading: false),
        ],
      ),
    );
  }
}
