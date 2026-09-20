export '../../../core/utils/week_range.dart' show isSameDate;

// Weekly unlock window for availabilities and presences: every Friday at
// 20:00 the entire following week (Monday-Sunday) opens up, on top of
// whatever remains of the already unlocked current week. Mirrors
// backend/app/core/booking_window.py — keep both in sync if the rule changes.
//
// Every day-stepping computation here goes through the DateTime constructor
// (year, month, day + n) rather than Duration-based add()/subtract(): Duration
// arithmetic on local DateTimes can skew across Italy's DST transitions,
// while constructor field arithmetic is plain calendar math with no such risk.

const List<String> _weekdayNames = [
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

const List<String> _monthNames = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

const int _unlockHour = 20;

DateTime _dateOnly(DateTime value)
{
  return DateTime(value.year, value.month, value.day);
}

DateTime _addDays(DateTime date, int days)
{
  return DateTime(date.year, date.month, date.day + days);
}

DateTime _mondayOf(DateTime day)
{
  return _addDays(day, -(day.weekday - DateTime.monday));
}

// Whether the week after [now]'s has opened: from Friday 20:00 to Sunday night.
bool isNextWeekUnlocked(DateTime now)
{
  final currentWeekMonday = _mondayOf(_dateOnly(now));
  final fridayThisWeek20 = DateTime(
    currentWeekMonday.year,
    currentWeekMonday.month,
    currentWeekMonday.day + (DateTime.friday - DateTime.monday),
    _unlockHour,
  );

  return !now.isBefore(fridayThisWeek20);
}

// The last unlocked day: this week's Sunday, or next week's once it opens.
DateTime lastUnlockedDay(DateTime now)
{
  final currentWeekMonday = _mondayOf(_dateOnly(now));

  return _addDays(currentWeekMonday, isNextWeekUnlocked(now) ? 13 : 6);
}

// Today through the furthest unlocked day, inclusive; never empty (3 to 10 days).
List<DateTime> computeAvailableDays(DateTime now)
{
  final today = _dateOnly(now);
  final maxUnlocked = lastUnlockedDay(now);

  final days = <DateTime>[];
  var cursor = today;

  while (!cursor.isAfter(maxUnlocked))
  {
    days.add(cursor);
    cursor = _addDays(cursor, 1);
  }

  return days;
}

// E.g. "Sabato 25 luglio". No locale data is initialized in this app, so
// DateFormat with a locale would throw at runtime; manual lookup instead.
String formatAvailableDayLabel(DateTime date)
{
  final weekday = _weekdayNames[date.weekday - 1];
  final month = _monthNames[date.month - 1];

  return '$weekday ${date.day} $month';
}

// E.g. "Lun 3 ago".
String formatAvailableDayShortLabel(DateTime date)
{
  final weekday = _weekdayNames[date.weekday - 1].substring(0, 3);
  final month = _monthNames[date.month - 1].substring(0, 3);

  return '$weekday ${date.day} $month';
}
