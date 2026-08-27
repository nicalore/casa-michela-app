import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/opening_day_item.dart';

// Mode values as the backend stores them.
const String kPresenceMode = 'presence';
const String kOnlineMode = 'online';

String modeLabel(String mode) => mode == kOnlineMode ? 'Online' : 'In presenza';

// When the association is open on one day, in one band, in one mode.
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

// Null where shut; rows with no hours are closures. A row belongs to the band
// its start falls in.
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

    // Multiple rows in one band should not happen but can; take the widest.
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

// Intersection across days; null if any day is shut or the openings do not overlap.
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

// Union of the two modes' openings: an intersection would hide hours bookable
// in only one mode.
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

bool isOpenOn(List<OpeningDayItem> openingDays, DateTime day, String mode)
{
  return TimeBucket.values.any((bucket) => openingWindowFor(openingDays, day, mode, bucket) != null);
}
