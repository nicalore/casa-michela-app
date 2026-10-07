import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/rome_clock.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../models/opening_day_item.dart';
import 'combined_hours.dart';
import 'hours_strings.dart';
import 'hours_grid.dart';
import 'hours_week_nav.dart';
import 'mode_hours_parts.dart';
import 'opening_hours_layout.dart';

class CombinedWeekCard extends StatelessWidget
{
  static const double _bandsFontSize = 15;

  final DateTime weekStart;

  final List<OpeningDayItem> openingDays;

  final bool isLoading;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onPickDay;

  final ValueChanged<DateTime>? onDayTap;

  const CombinedWeekCard({
    super.key,
    required this.weekStart,
    required this.openingDays,
    required this.isLoading,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickDay,
    this.onDayTap,
  });

  HoursWeekNav _weekNav({required bool stacked})
  {
    return HoursWeekNav(
      weekStart: weekStart,
      stacked: stacked,
      onPreviousWeek: onPreviousWeek,
      onNextWeek: onNextWeek,
      onPickDay: onPickDay,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final days = [
      for (final day in daysOfWeek(weekStart)) CombinedDay.read(openingDays, day, isLoading: isLoading),
    ];

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final navBeside = constraints.maxWidth >= kHoursTableNavBreakpoint;

        return AppCard(
          title: kWeeklyHoursTitle,
          compact: true,
          selectable: false,
          leading: const AppCardBadge(icon: Icons.calendar_month_rounded, compact: true),
          trailing: navBeside ? _weekNav(stacked: false) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!navBeside) ...[
                _weekNav(stacked: true),
                const SizedBox(height: 20),
              ],
              AnimatedOpacity(
                opacity: isLoading ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: HoursGrid(
                  days: [for (final day in days) _gridDay(day)],
                  entryWidth: _entryWidth(context, days),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  HoursGridDay _gridDay(CombinedDay day)
  {
    final onDayTap = this.onDayTap;

    return HoursGridDay(
      title: weekdayFullName(day.date.weekday),
      subtitle: formatDayMonthFull(day.date),
      isToday: isSameDate(day.date, romeNow()),
      modes: {for (final mode in kHoursModes) mode: _modeHours(day.of(mode))},
      onTap: onDayTap == null ? null : () => onDayTap(day.date),
    );
  }

  static Widget _modeHours(ModeDayHours hours)
  {
    if (hours.isClosed)
    {
      return ClosedPill(isOverride: hours.isOverrideClosure, note: hours.note);
    }

    return BandTimes(bands: hours.bands, fontSize: _bandsFontSize, stacked: true, variationNote: hours.note);
  }

  static double _entryWidth(BuildContext context, List<CombinedDay> days)
  {
    double hoursWidth(ModeDayHours hours)
    {
      if (hours.isClosed)
      {
        return ClosedPill.widthOf(context, isOverride: hours.isOverrideClosure);
      }

      return BandTimes.widthOf(context, hours.bands, fontSize: _bandsFontSize, stacked: true);
    }

    return [
      for (final day in days) ...[
        measureText(context, weekdayFullName(day.date.weekday), HoursGrid.titleStyle),
        measureText(context, formatDayMonthFull(day.date), HoursGrid.subtitleStyle),
        for (final mode in kHoursModes) hoursWidth(day.of(mode)),
      ],
    ].reduce(math.max);
  }
}
