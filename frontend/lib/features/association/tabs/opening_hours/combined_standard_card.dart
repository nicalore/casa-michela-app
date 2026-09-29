import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../models/opening_day_item.dart';
import 'combined_hours.dart';
import 'hours_strings.dart';
import 'hours_grid.dart';
import 'mode_hours_parts.dart';

class CombinedStandardCard extends StatelessWidget
{
  static const double _bandsFontSize = 15;

  static final TextStyle _closedStyle = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppTheme.trialMutedText,
  );

  final StandardSchedule scheduleByMode;

  final bool isLoading;

  const CombinedStandardCard({super.key, required this.scheduleByMode, required this.isLoading});

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: kStandardHoursTitle,
      compact: true,
      selectable: false,
      leading: const AppCardBadge(icon: Icons.schedule_rounded, compact: true),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context)
  {
    if (isLoading)
    {
      return const SizedBox.shrink();
    }

    if (!hasStandardHours(scheduleByMode))
    {
      return Text(
        kNoStandardHours,
        style: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppTheme.trialMutedText),
      );
    }

    return HoursGrid(
      days: [
        for (var weekday = 1; weekday <= 7; weekday++)
          HoursGridDay(
            title: weekdayFullName(weekday),
            modes: {for (final mode in kHoursModes) mode: _modeHours(mode, weekday)},
          ),
      ],
      entryWidth: _entryWidth(context),
    );
  }

  Widget _modeHours(String mode, int weekday)
  {
    final bands = _bandsFor(mode, weekday);

    if (bands.isEmpty)
    {
      return Text(kClosedLabel, style: _closedStyle);
    }

    return BandTimes(bands: bands, fontSize: _bandsFontSize, fontWeight: FontWeight.w700, stacked: true);
  }

  double _entryWidth(BuildContext context)
  {
    return [
      measureText(context, kClosedLabel, _closedStyle),
      for (var weekday = 1; weekday <= 7; weekday++) ...[
        measureText(context, weekdayFullName(weekday), HoursGrid.titleStyle),
        for (final mode in kHoursModes)
          BandTimes.widthOf(
            context,
            _bandsFor(mode, weekday),
            fontSize: _bandsFontSize,
            fontWeight: FontWeight.w700,
            stacked: true,
          ),
      ],
    ].reduce(math.max);
  }

  List<OpeningDayItem> _bandsFor(String mode, int weekday) => standardBands(scheduleByMode, mode, weekday);
}
