import 'package:flutter/material.dart';

import '../../../../core/utils/week_range.dart';
import '../../models/opening_day_item.dart';

// A run of consecutive days carrying the same bands and note. Grouped by whole
// day: variations apply to whole days, so a row maps to one editable thing.
class VariationGroup
{
  final DateTime start;
  final DateTime end;

  // Bands of one day of the run (every day carries the same ones); a closure
  // is a single band with no hours.
  final List<OpeningDayItem> bands;

  final String? note;

  const VariationGroup({
    required this.start,
    required this.end,
    required this.bands,
    this.note,
  });

  bool get isSingleDay => isSameDate(start, end);

  bool get isClosed => bands.first.startTime == null;

  // Holidays are seeded by calendar generation; they carry no edit/delete.
  bool get isHoliday => bands.any((band) => band.isHoliday);

  String get dateLabel => isSingleDay ? formatWeekdayColumnLabel(start) : formatDateSpan(start, end);

  String get hoursLabel
  {
    if (isClosed)
    {
      return 'Chiuso';
    }

    return bands.map((band) => formatTimeRange(band.startTime!, band.endTime!)).join(', ');
  }

  // [startsOnOrBefore] filters whole groups, not the rows going in: a run
  // starting inside the window keeps its real end date.
  static List<VariationGroup> from(List<OpeningDayItem> variations, {DateTime? startsOnOrBefore})
  {
    final byDate = <DateTime, List<OpeningDayItem>>{};

    for (final variation in variations)
    {
      final day = DateTime(variation.date.year, variation.date.month, variation.date.day);
      byDate.putIfAbsent(day, () => []).add(variation);
    }

    for (final bands in byDate.values)
    {
      bands.sort((a, b) => _minutesOf(a.startTime).compareTo(_minutesOf(b.startTime)));
    }

    final dates = byDate.keys.toList()..sort();
    final groups = <VariationGroup>[];

    var runStart = 0;

    for (var i = 0; i < dates.length; i++)
    {
      final isLast = i == dates.length - 1;
      final breaksRun = isLast ||
          !isSameDate(dates[i + 1], addDays(dates[i], 1)) ||
          _signature(byDate[dates[i + 1]]!) != _signature(byDate[dates[i]]!);

      if (!breaksRun)
      {
        continue;
      }

      final bands = byDate[dates[runStart]]!;

      if (startsOnOrBefore == null || !dates[runStart].isAfter(startsOnOrBefore))
      {
        groups.add(VariationGroup(
          start: dates[runStart],
          end: dates[i],
          bands: bands,
          note: bands.map((band) => band.note).firstWhere((note) => note != null && note.isNotEmpty, orElse: () => null),
        ));
      }

      runStart = i + 1;
    }

    return groups;
  }

  // Two days join a run only when bands and note match.
  static String _signature(List<OpeningDayItem> bands)
  {
    final hours = bands
        .map((band) => band.startTime == null
            ? 'chiuso'
            : formatTimeRange(band.startTime!, band.endTime!))
        .join('|');

    return '$hours||${bands.first.note ?? ''}';
  }

  // Closures sort before any timed band, so a day's rows always start with it.
  static int _minutesOf(TimeOfDay? time) => time == null ? -1 : time.hour * 60 + time.minute;
}
