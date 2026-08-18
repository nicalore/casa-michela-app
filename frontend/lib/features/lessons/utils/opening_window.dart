import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/opening_day_item.dart';

// The two ways the association is open, written the way the backend keeps them.
const String kPresenceMode = 'presence';
const String kOnlineMode = 'online';

String modeLabel(String mode) => mode == kOnlineMode ? 'Online' : 'In presenza';

// When the association is open on one day, in one band, in one mode.
//
// The opening hours are rows on the association's own calendar: one per band it
// opens, and a row with no hours at all where the day is shut. A teacher can
// only be available inside one of these, so this is what the wizard reads to
// know what it may offer — and, where nothing comes back, what it must refuse.
class OpeningWindow
{
  final int startMinutes;
  final int endMinutes;

  const OpeningWindow({required this.startMinutes, required this.endMinutes});

  TimeOfDay get start => timeOfDayFromMinutes(startMinutes);

  TimeOfDay get end => timeOfDayFromMinutes(endMinutes);

  bool contains(TimeOfDay time)
  {
    final minutes = minutesOfTimeOfDay(time);

    return minutes >= startMinutes && minutes <= endMinutes;
  }
}

// The association's opening on that day, in that band, in that mode, or null
// where it is shut. Rows with no hours are closures and never produce one.
//
// A row is taken as belonging to the band its start falls in, which is how the
// association's own table reads them.
OpeningWindow? openingWindowFor(
  List<OpeningDayItem> openingDays,
  DateTime day,
  String mode,
  TimeBucket bucket,
)
{
  int? start;
  int? end;

  for (final row in openingDays)
  {
    if (row.mode != mode || !isSameDate(row.date, day))
    {
      continue;
    }

    final rowStart = row.startTime;
    final rowEnd = row.endTime;

    if (rowStart == null || rowEnd == null || bucketFor(rowStart) != bucket)
    {
      continue;
    }

    // More than one row in a band is not what the association's editor writes,
    // but nothing stops the calendar from holding it: the widest of them is the
    // honest answer to "when could a teacher be here".
    final rowStartMinutes = minutesOfTimeOfDay(rowStart);
    final rowEndMinutes = minutesOfTimeOfDay(rowEnd);

    start = start == null ? rowStartMinutes : min(start, rowStartMinutes);
    end = end == null ? rowEndMinutes : max(end, rowEndMinutes);
  }

  if (start == null || end == null)
  {
    return null;
  }

  return OpeningWindow(startMinutes: start, endMinutes: end);
}

// The opening shared by every one of those days: a teacher offering the same
// hours on three days can only offer what all three have open. Null as soon as
// one of them is shut in that band, or where the openings do not overlap.
OpeningWindow? sharedOpeningWindow(
  List<OpeningDayItem> openingDays,
  Iterable<DateTime> days,
  String mode,
  TimeBucket bucket,
)
{
  int? start;
  int? end;

  for (final day in days)
  {
    final window = openingWindowFor(openingDays, day, mode, bucket);

    if (window == null)
    {
      return null;
    }

    start = start == null ? window.startMinutes : max(start, window.startMinutes);
    end = end == null ? window.endMinutes : min(end, window.endMinutes);
  }

  if (start == null || end == null || end - start < kQuarterHour)
  {
    return null;
  }

  return OpeningWindow(startMinutes: start, endMinutes: end);
}

// The opening of that band whichever way the association is open.
//
// Union and not intersection, and it is the calendar that needs it: the two
// modes have opening rows of their own — the building from two, the screens
// from three — and a timeline drawn on what they have in common would leave
// out the hour a teacher can legitimately be booked in one of them.
OpeningWindow? unionOpeningWindow(
  List<OpeningDayItem> openingDays,
  DateTime day,
  TimeBucket bucket,
)
{
  final windows = [
    openingWindowFor(openingDays, day, kPresenceMode, bucket),
    openingWindowFor(openingDays, day, kOnlineMode, bucket),
  ].nonNulls.toList();

  if (windows.isEmpty)
  {
    return null;
  }

  return OpeningWindow(
    startMinutes: windows.map((window) => window.startMinutes).reduce(min),
    endMinutes: windows.map((window) => window.endMinutes).reduce(max),
  );
}

// Whether the association opens at all on that day in that mode.
bool isOpenOn(List<OpeningDayItem> openingDays, DateTime day, String mode)
{
  return TimeBucket.values.any((bucket) => openingWindowFor(openingDays, day, mode, bucket) != null);
}
