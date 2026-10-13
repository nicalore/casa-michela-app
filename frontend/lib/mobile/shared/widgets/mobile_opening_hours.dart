import 'package:flutter/material.dart';

import '../../../features/lessons/widgets/calendar_lesson_block.dart';
import 'mobile_baseline_hang.dart';

// «Apertura» beside each mode's hours; hours that wrap stay in their column, under the first.
class MobileOpeningHours extends StatelessWidget
{
  // Mode and hours, in order.
  final List<(String, String)> openings;

  final TextStyle labelStyle;
  final TextStyle hoursStyle;
  final double iconSize;
  final Color iconColor;
  final double iconGap;
  final double gap;

  const MobileOpeningHours({
    super.key,
    required this.openings,
    required this.labelStyle,
    required this.hoursStyle,
    required this.iconSize,
    required this.iconColor,
    required this.iconGap,
    required this.gap,
  });

  @override
  Widget build(BuildContext context)
  {
    final double em = MediaQuery.textScalerOf(context).scale(hoursStyle.fontSize ?? 14);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Apertura'.toUpperCase(), style: labelStyle),
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
                      child: Icon(lessonModeIcon(mode), size: iconSize, color: iconColor),
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
