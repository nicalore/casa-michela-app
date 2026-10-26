import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/rome_clock.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/desktop_tour.dart';
import '../../../../shared/widgets/page_density.dart';
import '../../association_tour.dart';
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
  static const double _denseBandsFontSize = 13.5;

  final DateTime weekStart;

  final List<OpeningDayItem> openingDays;

  final bool isLoading;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onPickDay;

  const CombinedWeekCard({
    super.key,
    required this.weekStart,
    required this.openingDays,
    required this.isLoading,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickDay,
  });

  Widget _weekNav({required bool stacked})
  {
    return DesktopTourTarget(
      id: kTourAssociationWeek,
      child: HoursWeekNav(
        weekStart: weekStart,
        stacked: stacked,
        onPreviousWeek: onPreviousWeek,
        onNextWeek: onNextWeek,
        onPickDay: onPickDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final days = [
      for (final day in daysOfWeek(weekStart)) CombinedDay.read(openingDays, day, isLoading: isLoading),
    ];

    // The week's first variation symbol is the one a tour lights.
    final (CombinedDay, String)? lit = [
      for (final day in days)
        for (final mode in kHoursModes)
          if (!day.of(mode).isClosed && day.of(mode).bands.any((band) => band.isOverride)) (day, mode),
    ].firstOrNull;

    // Below the wide window the card takes the page's sizes, as the other cards there.
    final bool dense = AppPageDensity.of(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final navBeside = constraints.maxWidth >= kHoursTableNavBreakpoint;

        return AppCard(
          title: kWeeklyHoursTitle,
          compact: !dense,
          selectable: false,
          leading: AppCardBadge(icon: Icons.calendar_month_rounded, compact: !dense),
          trailing: navBeside ? _weekNav(stacked: false) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!navBeside) ...[
                _weekNav(stacked: true),
                SizedBox(height: dense ? 10 : 20),
              ],
              AnimatedOpacity(
                opacity: isLoading ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: DesktopTourTarget(
                  id: kTourAssociationDays,
                  child: HoursGrid(
                    days: [
                      for (final day in days)
                        _gridDay(day, lit: identical(day, lit?.$1) ? lit?.$2 : null, dense: dense),
                    ],
                    entryWidth: _entryWidth(context, days, dense: dense),
                    dayWidths: [for (final day in days) _dayWidth(context, day, dense: dense)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // [lit]: the mode whose variation symbol a tour lights.
  HoursGridDay _gridDay(CombinedDay day, {String? lit, required bool dense})
  {
    return HoursGridDay(
      title: weekdayFullName(day.date.weekday),
      subtitle: formatDayMonthFull(day.date),
      shortTitle: '${weekdayShortName(day.date.weekday)} ${day.date.day}',
      isToday: isSameDate(day.date, romeNow()),
      modes: {for (final mode in kHoursModes) mode: _modeHours(day.of(mode), lit: mode == lit, dense: dense)},
    );
  }

  static Widget _modeHours(ModeDayHours hours, {bool lit = false, required bool dense})
  {
    if (hours.isClosed)
    {
      return ClosedPill(isOverride: hours.isOverrideClosure, note: hours.note, dense: dense);
    }

    return BandTimes(
      bands: hours.bands,
      fontSize: dense ? _denseBandsFontSize : _bandsFontSize,
      stacked: true,
      variationNote: hours.note,
      variationTour: lit ? kTourAssociationVariation : null,
    );
  }

  static double _entryWidth(BuildContext context, List<CombinedDay> days, {required bool dense})
  {
    return days.map((day) => _dayWidth(context, day, dense: dense)).reduce(math.max);
  }

  // The widest of the day's name, date and hours.
  static double _dayWidth(BuildContext context, CombinedDay day, {required bool dense})
  {
    double hoursWidth(ModeDayHours hours)
    {
      if (hours.isClosed)
      {
        return ClosedPill.widthOf(context, isOverride: hours.isOverrideClosure, dense: dense);
      }

      return BandTimes.widthOf(
        context,
        hours.bands,
        fontSize: dense ? _denseBandsFontSize : _bandsFontSize,
        stacked: true,
      );
    }

    return [
      measureText(context, weekdayFullName(day.date.weekday), HoursGrid.titleStyleOf(dense: dense)),
      measureText(context, formatDayMonthFull(day.date), HoursGrid.subtitleStyleOf(dense: dense)),
      for (final mode in kHoursModes) hoursWidth(day.of(mode)),
    ].reduce(math.max);
  }
}
