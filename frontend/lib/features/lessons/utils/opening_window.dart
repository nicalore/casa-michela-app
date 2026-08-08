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

/// The association's opening on that day, in that band, in that mode, or null
/// where it is shut. Rows with no hours are closures and never produce one.
///
/// A row is taken as belonging to the band its start falls in, which is how the
/// association's own table reads them.
OpeningWindow? openingWindowFor(
  List<OpeningDayItem> openingDays,
  DateTime day,
  String mode,
  TimeBucket bucket,
)
{
  var start = -1;
  var end = -1;

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
    final startMinutes = minutesOfTimeOfDay(rowStart);
    final endMinutes = minutesOfTimeOfDay(rowEnd);

    if (start < 0 || startMinutes < start)
    {
      start = startMinutes;
    }

    if (endMinutes > end)
    {
      end = endMinutes;
    }
  }

  if (start < 0)
  {
    return null;
  }

  return OpeningWindow(startMinutes: start, endMinutes: end);
}

/// The opening shared by every one of those days: a teacher offering the same
/// hours on three days can only offer what all three have open. Null as soon as
/// one of them is shut in that band, or where the openings do not overlap.
OpeningWindow? sharedOpeningWindow(
  List<OpeningDayItem> openingDays,
  Iterable<DateTime> days,
  String mode,
  TimeBucket bucket,
)
{
  var start = -1;
  var end = -1;

  for (final day in days)
  {
    final window = openingWindowFor(openingDays, day, mode, bucket);

    if (window == null)
    {
      return null;
    }

    start = start < 0 ? window.startMinutes : (window.startMinutes > start ? window.startMinutes : start);
    end = end < 0 ? window.endMinutes : (window.endMinutes < end ? window.endMinutes : end);
  }

  if (start < 0 || end - start < kQuarterHour)
  {
    return null;
  }

  return OpeningWindow(startMinutes: start, endMinutes: end);
}

/// Whether the association opens at all on that day in that mode.
bool isOpenOn(List<OpeningDayItem> openingDays, DateTime day, String mode)
{
  return TimeBucket.values.any((bucket) => openingWindowFor(openingDays, day, mode, bucket) != null);
}
