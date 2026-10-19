import 'package:flutter/material.dart';

import '../../../features/lessons/widgets/calendar_lesson_block.dart';
import 'mobile_baseline_hang.dart';

// Ascent of Plus Jakarta Sans, in font sizes.
const double _ascent = 1.038;

// Glyphs land on the baseline rounded to a whole pixel from the line's top.
double _drawnDrift(double em) => (_ascent * em).roundToDouble() - _ascent * em;

// "Apertura" beside each mode's hours; hours that wrap stay in their column, under the first.
class MobileOpeningHours extends StatelessWidget
{
  // Mode and hours, in order.
  final List<(String, String)> openings;

  final TextStyle labelStyle;
  final TextStyle hoursStyle;
  final double iconSize;
  final Color iconColor;

  // Set, each mode's icon takes its own colour instead.
  final Color Function(String mode)? iconColorOf;
  final double iconGap;
  final double gap;

  const MobileOpeningHours({
    super.key,
    required this.openings,
    required this.labelStyle,
    required this.hoursStyle,
    required this.iconSize,
    required this.iconColor,
    this.iconColorOf,
    required this.iconGap,
    required this.gap,
  });

  @override
  Widget build(BuildContext context)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double em = scaler.scale(hoursStyle.fontSize ?? 14);
    final double labelEm = scaler.scale(labelStyle.fontSize ?? 14);

    // The smaller label is lifted so its capitals centre on the hours', as the icons do.
    final double shift = _drawnDrift(em) - _drawnDrift(labelEm) - kCapitalsMiddle * (em - labelEm);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Transform.translate(
          offset: Offset(0, shift),
          child: Text('Apertura'.toUpperCase(), style: labelStyle),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Wrap(
            spacing: gap,
            runSpacing: 4,
            children: [
              for (final (mode, hours) in openings)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    MobileBaselineHang(
                      above: kCapitalsMiddle * em,
                      child: Icon(lessonModeIcon(mode), size: iconSize, color: iconColorOf?.call(mode) ?? iconColor),
                    ),
                    SizedBox(width: iconGap),
                    Text(hours, style: hoursStyle),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
