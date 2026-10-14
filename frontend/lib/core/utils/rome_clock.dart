import 'package:flutter/foundation.dart';

// Stands in for the clock in tests.
@visibleForTesting
DateTime Function()? debugRomeNow;

// --dart-define=FAKE_TODAY=2026-10-30 sets the day, keeping the real hour; ignored in release.
const String _fakeToday = String.fromEnvironment('FAKE_TODAY');

final DateTime? _fakeDay = !kReleaseMode && _fakeToday.isNotEmpty ? DateTime.parse(_fakeToday) : null;

// Rome's wall time whatever the device zone, as the server reckons deadlines (booking_close.py).
DateTime romeNow()
{
  final DateTime Function()? stand = debugRomeNow;

  if (stand != null)
  {
    return stand();
  }

  final DateTime now = romeWallTime(DateTime.now());
  final DateTime? day = _fakeDay;

  if (day == null)
  {
    return now;
  }

  return DateTime(day.year, day.month, day.day, now.hour, now.minute, now.second, now.millisecond, now.microsecond);
}

// Rome's date and time at [instant], as a plain local DateTime.
DateTime romeWallTime(DateTime instant)
{
  final DateTime utc = instant.toUtc();
  final DateTime shifted = utc.add(Duration(hours: _isSummerTime(utc) ? 2 : 1));

  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
    shifted.microsecond,
  );
}

// EU rule: from the last Sunday of March to the last Sunday of October, at 01:00 UTC.
bool _isSummerTime(DateTime utc)
{
  return !utc.isBefore(_lastSundayAtOne(utc.year, 3)) && utc.isBefore(_lastSundayAtOne(utc.year, 10));
}

DateTime _lastSundayAtOne(int year, int month)
{
  final DateTime lastDay = DateTime.utc(year, month + 1, 0, 1);

  return lastDay.subtract(Duration(days: lastDay.weekday % DateTime.daysPerWeek));
}
