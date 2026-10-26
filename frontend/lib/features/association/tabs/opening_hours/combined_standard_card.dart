import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/page_density.dart';
import '../../models/opening_day_item.dart';
import 'combined_hours.dart';
import 'hours_strings.dart';
import 'hours_grid.dart';
import 'mode_hours_parts.dart';

class CombinedStandardCard extends StatelessWidget
{
  static const double _bandsFontSize = 15;
  static const double _denseBandsFontSize = 13.5;

  static TextStyle _closedStyle({required bool dense}) => GoogleFonts.plusJakartaSans(
        fontSize: dense ? 13.5 : 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
      );

  final StandardSchedule scheduleByMode;

  final bool isLoading;

  const CombinedStandardCard({super.key, required this.scheduleByMode, required this.isLoading});

  @override
  Widget build(BuildContext context)
  {
    // Below the wide window the card takes the page's sizes, as the other cards there.
    final bool dense = AppPageDensity.of(context);

    return AppCard(
      title: kStandardHoursTitle,
      compact: !dense,
      selectable: false,
      leading: AppCardBadge(icon: Icons.schedule_rounded, compact: !dense),
      child: _buildBody(context, dense: dense),
    );
  }

  Widget _buildBody(BuildContext context, {required bool dense})
  {
    if (isLoading)
    {
      return const SizedBox.shrink();
    }

    if (!hasStandardHours(scheduleByMode))
    {
      return Center(
        child: Text(
          kNoStandardHours,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: dense ? 14 : 16, color: AppTheme.trialMutedText),
        ),
      );
    }

    return HoursGrid(
      days: [
        for (var weekday = 1; weekday <= 7; weekday++)
          HoursGridDay(
            title: weekdayFullName(weekday),
            shortTitle: weekdayShortName(weekday),
            modes: {for (final mode in kHoursModes) mode: _modeHours(mode, weekday, dense: dense)},
          ),
      ],
      entryWidth: _entryWidth(context, dense: dense),
      dayWidths: [for (var weekday = 1; weekday <= 7; weekday++) _dayWidth(context, weekday, dense: dense)],
    );
  }

  Widget _modeHours(String mode, int weekday, {required bool dense})
  {
    final bands = _bandsFor(mode, weekday);

    if (bands.isEmpty)
    {
      return Text(kClosedLabel, style: _closedStyle(dense: dense));
    }

    return BandTimes(
      bands: bands,
      fontSize: dense ? _denseBandsFontSize : _bandsFontSize,
      fontWeight: FontWeight.w700,
      stacked: true,
    );
  }

  double _entryWidth(BuildContext context, {required bool dense})
  {
    return [for (var weekday = 1; weekday <= 7; weekday++) _dayWidth(context, weekday, dense: dense)].reduce(math.max);
  }

  // The widest of the day's name and hours, "Chiuso" included.
  double _dayWidth(BuildContext context, int weekday, {required bool dense})
  {
    return [
      measureText(context, kClosedLabel, _closedStyle(dense: dense)),
      measureText(context, weekdayFullName(weekday), HoursGrid.titleStyleOf(dense: dense)),
      for (final mode in kHoursModes)
        BandTimes.widthOf(
          context,
          _bandsFor(mode, weekday),
          fontSize: dense ? _denseBandsFontSize : _bandsFontSize,
          fontWeight: FontWeight.w700,
          stacked: true,
        ),
    ].reduce(math.max);
  }

  List<OpeningDayItem> _bandsFor(String mode, int weekday) => standardBands(scheduleByMode, mode, weekday);
}
