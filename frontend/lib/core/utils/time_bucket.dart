import 'package:flutter/material.dart';

import 'week_range.dart';

// The band bounds are this module's own; the quarter-hour step and the two
// conversions used to live here and are now general enough to be read off
// week_range, which is where every other hour of the app is formatted.
export 'week_range.dart' show kMinimumBandMinutes, kQuarterHour, minutesOfTimeOfDay, timeOfDayFromMinutes;

enum TimeBucket { morning, afternoon, evening }

// The three bands the association's day is divided into. They belong to the
// whole app and not to the page that draws them: the opening hours are written
// in them, and a teacher's availability is offered in them. Half-open by
// convention — a band owns its start and hands its end to the next one, so
// 13:00 is the first afternoon slot rather than the last morning one — except
// evening's 23:00, which is a real closing time and stays selectable.
const int _morningStartHour = kDayStartMinutes ~/ 60;
const int _afternoonStartHour = 13;
const int _eveningStartHour = 19;
const int _eveningEndHour = kDayEndMinutes ~/ 60;

int _bandStartHour(TimeBucket bucket)
{
  switch (bucket)
  {
    case TimeBucket.morning:
      return _morningStartHour;
    case TimeBucket.afternoon:
      return _afternoonStartHour;
    case TimeBucket.evening:
      return _eveningStartHour;
  }
}

int _bandEndHour(TimeBucket bucket)
{
  switch (bucket)
  {
    case TimeBucket.morning:
      return _afternoonStartHour;
    case TimeBucket.afternoon:
      return _eveningStartHour;
    case TimeBucket.evening:
      return _eveningEndHour;
  }
}

// Bucketing is a start_time-only heuristic, not a strict boundary on the
// displayed range: a slot starting at 14:00 and ending at 19:00 still lands
// in Pomeriggio and shows its full range there. Assumes at most one row per
// bucket per day, matching the current weekly_templates shape — a same-bucket
// collision is an accepted, undefended degradation (last one wins).
//
// Returns null outside 06:00-23:00, so pre-existing rows from before these
// bounds existed are simply not shown in any band rather than being forced
// into the nearest one.
TimeBucket? bucketFor(TimeOfDay? start)
{
  if (start == null)
  {
    return null;
  }

  final minutes = start.hour * 60 + start.minute;

  if (minutes < _morningStartHour * 60 || minutes >= _eveningEndHour * 60)
  {
    return null;
  }

  if (minutes < _afternoonStartHour * 60)
  {
    return TimeBucket.morning;
  }

  if (minutes < _eveningStartHour * 60)
  {
    return TimeBucket.afternoon;
  }

  return TimeBucket.evening;
}

String bandLabel(TimeBucket bucket)
{
  switch (bucket)
  {
    case TimeBucket.morning:
      return 'Mattina';
    case TimeBucket.afternoon:
      return 'Pomeriggio';
    case TimeBucket.evening:
      return 'Sera';
  }
}

// The window a band owns, in minutes from midnight. Public because the slider
// is that window: its track runs from one to the other.
int bandStartMinutes(TimeBucket bucket) => _bandStartHour(bucket) * 60;

int bandEndMinutes(TimeBucket bucket) => _bandEndHour(bucket) * 60;
