import 'package:flutter/material.dart';

import '../../../../core/utils/week_range.dart';
import '../../../lessons/utils/opening_window.dart';
import '../../models/opening_day_item.dart';
import 'current_schedule.dart';

const List<String> kHoursModes = [kPresenceMode, kOnlineMode];

// Lookback covers a holiday weekday's past hours; the fetch overshoots so runs keep their real end.
const int kScheduleLookbackDays = 27;
const int kVariationsWindowDays = 60;
const int kVariationsFetchDays = kVariationsWindowDays + 90;

// Mode to weekday (1-7) to the bands in force on the next occurrence of that day.
typedef StandardSchedule = Map<String, Map<int, List<OpeningDayItem>>>;

List<OpeningDayItem> upcomingVariationsOf(List<OpeningDayItem> days, DateTime today)
{
  final day = DateTime(today.year, today.month, today.day);

  return days.where((d) => d.isOverride && !d.date.isBefore(day)).toList();
}

StandardSchedule standardScheduleOf(List<OpeningDayItem> days, DateTime today)
{
  return {
    for (final mode in kHoursModes)
      mode: currentScheduleByWeekday(days.where((d) => d.mode == mode).toList(), today),
  };
}

List<OpeningDayItem> standardBands(StandardSchedule schedule, String mode, int weekday)
{
  final rows = schedule[mode]?[weekday] ?? const <OpeningDayItem>[];

  return sortedByStart(rows.where((band) => band.startTime != null && band.endTime != null));
}

bool hasStandardHours(StandardSchedule schedule)
{
  for (var weekday = 1; weekday <= 7; weekday++)
  {
    if (kHoursModes.any((mode) => standardBands(schedule, mode, weekday).isNotEmpty))
    {
      return true;
    }
  }

  return false;
}

// Closures (no hours) sort before any timed band.
List<OpeningDayItem> sortedByStart(Iterable<OpeningDayItem> rows)
{
  int minutesOf(TimeOfDay? time) => time == null ? -1 : time.hour * 60 + time.minute;

  return rows.toList()..sort((a, b) => minutesOf(a.startTime).compareTo(minutesOf(b.startTime)));
}

String? joinedNote(Iterable<OpeningDayItem> rows)
{
  final notes = <String>[];

  for (final row in sortedByMode(rows))
  {
    final note = row.note?.trim();

    if (note != null && note.isNotEmpty && !notes.contains(note))
    {
      notes.add(note);
    }
  }

  return notes.isEmpty ? null : notes.join(' · ');
}

List<OpeningDayItem> sortedByMode(Iterable<OpeningDayItem> rows)
{
  return [
    for (final mode in kHoursModes) ...rows.where((row) => row.mode == mode),
  ];
}

String _hoursOf(OpeningDayItem row)
{
  return row.startTime == null ? 'chiuso' : formatTimeRange(row.startTime!, row.endTime!);
}

class ModeDayHours
{
  final List<OpeningDayItem> bands;

  // A row with no hours: a decided closure.
  final bool isOverrideClosure;

  // No rows: the template never opens that day in this mode.
  final bool isOrdinaryClosure;

  final String? note;

  const ModeDayHours({
    required this.bands,
    required this.isOverrideClosure,
    required this.isOrdinaryClosure,
    this.note,
  });

  bool get isClosed => isOverrideClosure || isOrdinaryClosure;
}

class CombinedDay
{
  final DateTime date;
  final Map<String, ModeDayHours> byMode;

  const CombinedDay({required this.date, required this.byMode});

  // [isLoading] keeps a day from reading closed while the rows are still the previous week's.
  factory CombinedDay.read(List<OpeningDayItem> rows, DateTime day, {required bool isLoading})
  {
    final forDay = rows.where((row) => isSameDate(row.date, day)).toList();

    return CombinedDay(
      date: day,
      byMode: {
        for (final mode in kHoursModes) mode: _readMode(forDay.where((row) => row.mode == mode).toList(), isLoading),
      },
    );
  }

  static ModeDayHours _readMode(List<OpeningDayItem> rows, bool isLoading)
  {
    final isOverrideClosure = rows.any((row) => row.startTime == null);

    return ModeDayHours(
      bands: isOverrideClosure ? const [] : sortedByStart(rows),
      isOverrideClosure: isOverrideClosure,
      isOrdinaryClosure: !isLoading && rows.isEmpty,
      note: joinedNote(rows.where((row) => row.isOverride)),
    );
  }

  ModeDayHours of(String mode) => byMode[mode]!;

  bool get isClosedAllDay => isOverrideClosedAllDay || byMode.values.every((hours) => hours.isOrdinaryClosure);

  bool get isOverrideClosedAllDay => byMode.values.every((hours) => hours.isOverrideClosure);
}

// A mode missing from [bandsByMode] keeps its standard hours.
class CombinedVariation
{
  final DateTime start;
  final DateTime end;

  // A closure is a single band with no hours.
  final Map<String, List<OpeningDayItem>> bandsByMode;

  final String? note;

  const CombinedVariation({
    required this.start,
    required this.end,
    required this.bandsByMode,
    this.note,
  });

  bool get isSingleDay => isSameDate(start, end);

  String get dateLabel => isSingleDay ? formatWeekdayColumnLabel(start) : formatDateSpan(start, end);

  // Holidays are seeded by calendar generation: never edited or deleted by hand.
  bool get isHoliday => bandsByMode.values.any((bands) => bands.any((band) => band.isHoliday));

  bool isClosed(String mode)
  {
    final bands = bandsByMode[mode];

    return bands != null && bands.first.startTime == null;
  }

  // [startsOnOrBefore] filters whole runs, not input rows, so a run keeps its real end date.
  static List<CombinedVariation> from(List<OpeningDayItem> variations, {DateTime? startsOnOrBefore})
  {
    final byDate = <DateTime, List<OpeningDayItem>>{};

    for (final variation in variations)
    {
      final day = DateTime(variation.date.year, variation.date.month, variation.date.day);
      byDate.putIfAbsent(day, () => []).add(variation);
    }

    final dates = byDate.keys.toList()..sort();
    final runs = <CombinedVariation>[];

    var runStart = 0;

    for (var i = 0; i < dates.length; i++)
    {
      final breaksRun = i == dates.length - 1 ||
          !isSameDate(dates[i + 1], addDays(dates[i], 1)) ||
          _signature(byDate[dates[i + 1]]!) != _signature(byDate[dates[i]]!);

      if (!breaksRun)
      {
        continue;
      }

      if (startsOnOrBefore == null || !dates[runStart].isAfter(startsOnOrBefore))
      {
        final rows = byDate[dates[runStart]]!;

        runs.add(CombinedVariation(
          start: dates[runStart],
          end: dates[i],
          bandsByMode: _byMode(rows),
          note: joinedNote(rows),
        ));
      }

      runStart = i + 1;
    }

    return runs;
  }

  static Map<String, List<OpeningDayItem>> _byMode(List<OpeningDayItem> rows)
  {
    return {
      for (final mode in kHoursModes)
        if (rows.any((row) => row.mode == mode)) mode: sortedByStart(rows.where((row) => row.mode == mode)),
    };
  }

  static String _signature(List<OpeningDayItem> rows)
  {
    final byMode = _byMode(rows);
    final hours = [
      for (final mode in kHoursModes) '$mode:${(byMode[mode] ?? const []).map(_hoursOf).join('|')}',
    ].join(';');

    return '$hours||${joinedNote(rows) ?? ''}';
  }
}
