import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/opening_day_item.dart';

// Mode values as the backend stores them.
const String kPresenceMode = 'presence';
const String kOnlineMode = 'online';

String modeLabel(String mode) => mode == kOnlineMode ? 'Online' : tr('In presenza', 'In person');

// When the association is open on one day, in one band, in one mode.
class OpeningWindow
{
  final int startMinutes;
  final int endMinutes;

  const OpeningWindow({required this.startMinutes, required this.endMinutes});

  TimeOfDay get start => timeOfDayFromMinutes(startMinutes);

  TimeOfDay get end => timeOfDayFromMinutes(endMinutes);

  int get minutes => endMinutes - startMinutes;

  bool contains(TimeOfDay time)
  {
    final minutes = minutesOfTimeOfDay(time);

    return minutes >= startMinutes && minutes <= endMinutes;
  }
}

// Null where shut; rows with no hours are closures, and a row belongs to the band its start is in.
// [from]: only hours not yet begun, as nothing begun may be written (calendar_freeze.has_begun).
OpeningWindow? openingWindowFor(
  List<OpeningDayItem> openingDays,
  DateTime day,
  String mode,
  TimeBucket bucket, {
  DateTime? from,
})
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

  return _notBegun(OpeningWindow(startMinutes: start, endMinutes: end), day, from);
}

// Nothing on days gone; today from the first quarter hour after [now].
OpeningWindow? _notBegun(OpeningWindow window, DateTime day, DateTime? now)
{
  if (now == null)
  {
    return window;
  }

  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime date = DateTime(day.year, day.month, day.day);

  if (date.isAfter(today))
  {
    return window;
  }

  if (date.isBefore(today))
  {
    return null;
  }

  final int next = ((now.hour * 60 + now.minute) ~/ kQuarterHour + 1) * kQuarterHour;
  final int start = max(window.startMinutes, next);

  if (window.endMinutes - start < kMinimumBandMinutes)
  {
    return null;
  }

  return OpeningWindow(startMinutes: start, endMinutes: window.endMinutes);
}

// Intersection across days; null if any day is shut or the openings do not overlap.
OpeningWindow? sharedOpeningWindow(
  List<OpeningDayItem> openingDays,
  Iterable<DateTime> days,
  String mode,
  TimeBucket bucket, {
  DateTime? from,
})
{
  int? start;
  int? end;

  for (final day in days)
  {
    final window = openingWindowFor(openingDays, day, mode, bucket, from: from);

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

// Union of the two modes: an intersection would hide hours bookable in only one mode.
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

String get kInBuilding => tr('in presenza', 'in person');
const String kOnScreen = 'online';
String get kBothWays => tr('in presenza e online', 'in person and online');

class BandOpening
{
  final int startMinutes;
  final int endMinutes;
  final String mode;

  const BandOpening({
    required this.startMinutes,
    required this.endMinutes,
    required this.mode,
  });

  String get hours => formatMinutesRange(startMinutes, endMinutes);
}

List<BandOpening> bandOpeningsFor(
  List<OpeningDayItem> openingDays,
  DateTime day,
  TimeBucket bucket,
)
{
  final presence = openingWindowFor(openingDays, day, kPresenceMode, bucket);
  final online = openingWindowFor(openingDays, day, kOnlineMode, bucket);

  // Same hours both ways: merged into one opening.
  if (presence != null &&
      online != null &&
      presence.startMinutes == online.startMinutes &&
      presence.endMinutes == online.endMinutes)
  {
    return [
      BandOpening(
        startMinutes: presence.startMinutes,
        endMinutes: presence.endMinutes,
        mode: kBothWays,
      ),
    ];
  }

  return [
    if (presence != null)
      BandOpening(
        startMinutes: presence.startMinutes,
        endMinutes: presence.endMinutes,
        mode: kInBuilding,
      ),
    if (online != null)
      BandOpening(
        startMinutes: online.startMinutes,
        endMinutes: online.endMinutes,
        mode: kOnScreen,
      ),
  ];
}
