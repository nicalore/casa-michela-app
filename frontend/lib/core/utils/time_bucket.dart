import 'package:flutter/material.dart';

import 'week_range.dart';

export 'week_range.dart' show kMinimumBandMinutes, kQuarterHour, minutesOfTimeOfDay, timeOfDayFromMinutes;

enum TimeBucket { morning, afternoon, evening }

// Mirrors app/core/time_band.py. Half-open, except evening's close, which is
// a real closing time and stays selectable.
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

int bandStartMinutes(TimeBucket bucket) => _bandStartHour(bucket) * 60;

int bandEndMinutes(TimeBucket bucket) => _bandEndHour(bucket) * 60;

// Bookings close: mirrors app/core/booking_close.py.
const Map<TimeBucket, (int daysBefore, int hour)> _closingTimes = {
  TimeBucket.morning: (1, 20),
  TimeBucket.afternoon: (0, 11),
  TimeBucket.evening: (0, 18),
};

DateTime bookingsCloseAt(DateTime day, TimeBucket band)
{
  final handover = _closingTimes[band]!;

  return DateTime(day.year, day.month, day.day - handover.$1, handover.$2);
}

bool haveBookingsClosed(DateTime day, TimeBucket band, DateTime now)
{
  return !now.isBefore(bookingsCloseAt(day, band));
}

String bookingsCloseLabel(DateTime day, TimeBucket band)
{
  final at = bookingsCloseAt(day, band);
  final hour = at.hour.toString().padLeft(2, '0');

  if (_closingTimes[band]!.$1 == 0)
  {
    return '$hour:00';
  }

  return '$hour:00 di ${formatDayMonthShort(at)}';
}
