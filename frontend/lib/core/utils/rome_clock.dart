// Rome's wall time whatever the device zone, as the server reckons deadlines (booking_close.py).
DateTime romeNow() => romeWallTime(DateTime.now());

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
