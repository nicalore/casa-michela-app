import 'package:flutter/material.dart';

import '../../../../core/utils/week_range.dart';
import '../../models/opening_day_item.dart';

/// One variation as the Orari tab presents it: a run of consecutive days that
/// all carry the same bands and the same note.
///
/// Grouped by day rather than by band — three "14:00–17:00" rows for the 20th,
/// 21st and 22nd say far less than a single "Dal 20 al 22 agosto" — and by the
/// whole day rather than one band of it, so a row maps to exactly one thing the
/// admin can edit or undo. Splitting a day across two rows would mean editing
/// one of them silently rewrote the other, since a variation is applied to
/// whole days.
class VariationGroup
{
  final DateTime start;
  final DateTime end;

  /// The bands of one day of the run; every day in it carries the same ones.
  /// A closure is the single band with no hours on it.
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

  /// Public holidays are seeded by the calendar generation, not by an admin:
  /// they carry no edit or delete action, since the next run would put them
  /// back anyway.
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

  /// The variations of a mode, collapsed into the rows the card shows.
  ///
  /// Two passes: first every date is reduced to the signature of what happens
  /// on it, then runs of consecutive dates sharing a signature are folded into
  /// one group.
  ///
  /// [startsOnOrBefore] bounds the result to the runs that begin within it, and
  /// is applied to whole groups rather than to the rows going in: a variation
  /// that starts inside the window and carries on past it belongs here, and
  /// keeps its real end date instead of being cut short at the boundary.
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

  /// What has to match for two days to belong to the same run: the same bands
  /// and the same note.
  static String _signature(List<OpeningDayItem> bands)
  {
    final hours = bands
        .map((band) => band.startTime == null
            ? 'chiuso'
            : formatTimeRange(band.startTime!, band.endTime!))
        .join('|');

    return '$hours||${bands.first.note ?? ''}';
  }

  /// Closures sort before any timed band, so a day's rows always start with it.
  static int _minutesOf(TimeOfDay? time) => time == null ? -1 : time.hour * 60 + time.minute;
}
