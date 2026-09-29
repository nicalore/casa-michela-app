import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/opening_day_item.dart';
import '../../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../../features/association/tabs/opening_hours/hours_strings.dart';
import '../../../../features/association/tabs/opening_hours/mode_hours_parts.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import 'mobile_hours_parts.dart';

const double _radius = 22;
const double _columnGap = 14;

class MobileStandardHoursCard extends StatelessWidget
{
  final StandardSchedule schedule;
  final bool tablet;

  const MobileStandardHoursCard({super.key, required this.schedule, required this.tablet});

  TextStyle get _dayStyle => GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 15.5 : 14.5,
        fontWeight: FontWeight.w700,
        height: 1.45,
        color: AppTheme.trialInk,
      );

  TextStyle get _closedStyle => GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 15 : 14,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: MobilePalette.mutedText,
      );

  TextStyle _hoursStyle(String mode) => GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 15 : 14,
        fontWeight: FontWeight.w800,
        height: 1.45,
        color: hoursInk(mode),
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // As wide as the longest weekday, so every row's hours start level.
  double _dayWidth(BuildContext context)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle style = DefaultTextStyle.of(context).style.merge(_dayStyle);

    double widest = 0;

    for (var weekday = 1; weekday <= 7; weekday++)
    {
      final painter = TextPainter(
        text: TextSpan(text: weekdayFullName(weekday), style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();

      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    return widest.ceilToDouble();
  }

  Widget _buildHead(double dayWidth)
  {
    Widget heading(String mode)
    {
      return Expanded(
        child: Row(
          children: [
            Icon(lessonModeIcon(mode), size: tablet ? 16 : 15, color: hoursInk(mode)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                modeLabel(mode).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: tablet ? 10.5 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: hoursInk(mode),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Row(
        children: [
          SizedBox(width: dayWidth),
          const SizedBox(width: _columnGap),
          heading(kHoursModes.first),
          const SizedBox(width: _columnGap),
          heading(kHoursModes.last),
        ],
      ),
    );
  }

  Widget _buildCell(String mode, List<OpeningDayItem> bands)
  {
    if (bands.isEmpty)
    {
      return Text(kClosedLabel, style: _closedStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final band in bands)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(bandHours(band), maxLines: 1, style: _hoursStyle(mode)),
          ),
      ],
    );
  }

  Widget _buildDay(int weekday, double dayWidth)
  {
    final List<OpeningDayItem> presence = standardBands(schedule, kHoursModes.first, weekday);
    final List<OpeningDayItem> online = standardBands(schedule, kHoursModes.last, weekday);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tablet ? 11 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: dayWidth, child: Text(weekdayFullName(weekday), maxLines: 1, style: _dayStyle)),
          const SizedBox(width: _columnGap),
          if (presence.isEmpty && online.isEmpty)
            Expanded(child: Text(kClosedLabel, style: _closedStyle))
          else ...[
            Expanded(child: _buildCell(kHoursModes.first, presence)),
            const SizedBox(width: _columnGap),
            Expanded(child: _buildCell(kHoursModes.last, online)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final EdgeInsets padding = tablet ? const EdgeInsets.fromLTRB(20, 16, 20, 8) : const EdgeInsets.fromLTRB(18, 14, 18, 6);

    if (!hasStandardHours(schedule))
    {
      return MobileGlassPanel(
        padding: tablet ? const EdgeInsets.all(20) : const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(_radius),
        child: Text(kNoStandardHours, style: _closedStyle.copyWith(fontWeight: FontWeight.w500)),
      );
    }

    final double dayWidth = _dayWidth(context);
    final Color rule = AppTheme.trialInk.withValues(alpha: 0.08);

    return MobileGlassPanel(
      padding: padding,
      borderRadius: BorderRadius.circular(_radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHead(dayWidth),
          Container(height: 1, color: AppTheme.trialInk.withValues(alpha: 0.1)),
          for (var weekday = 1; weekday <= 7; weekday++) ...[
            if (weekday > 1) Container(height: 1, color: rule),
            _buildDay(weekday, dayWidth),
          ],
        ],
      ),
    );
  }
}
