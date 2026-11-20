import '../../../core/language/app_language.dart';

export '../../../core/utils/week_range.dart' show isSameDate;

// Every Friday 20:00 the next Mon-Sun week unlocks. Mirrors backend/app/core/booking_window.py.
// Days step via DateTime(y, m, d + n), never Duration: Duration math skews across DST.

List<String> get _weekdayNames => [
  tr('Lunedì', 'Monday'),
  tr('Martedì', 'Tuesday'),
  tr('Mercoledì', 'Wednesday'),
  tr('Giovedì', 'Thursday'),
  tr('Venerdì', 'Friday'),
  tr('Sabato', 'Saturday'),
  tr('Domenica', 'Sunday'),
];

List<String> get _monthNames => [
  tr('gennaio', 'January'),
  tr('febbraio', 'February'),
  tr('marzo', 'March'),
  tr('aprile', 'April'),
  tr('maggio', 'May'),
  tr('giugno', 'June'),
  tr('luglio', 'July'),
  tr('agosto', 'August'),
  tr('settembre', 'September'),
  tr('ottobre', 'October'),
  tr('novembre', 'November'),
  tr('dicembre', 'December'),
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

// "Sabato 25 luglio"; no locale data is initialized, so a localized DateFormat would throw.
String formatAvailableDayLabel(DateTime date)
{
  final weekday = _weekdayNames[date.weekday - 1];
  final month = _monthNames[date.month - 1];

  return '$weekday ${date.day} $month';
}

// Inside a sentence: "sabato 25 luglio", but "Saturday 25 July" in English.
String formatAvailableDayInSentence(DateTime date)
{
  final String label = formatAvailableDayLabel(date);

  return isEnglish ? label : label.toLowerCase();
}

// E.g. "Lun 3 ago".
String formatAvailableDayShortLabel(DateTime date)
{
  final weekday = _weekdayNames[date.weekday - 1].substring(0, 3);
  final month = _monthNames[date.month - 1].substring(0, 3);

  return '$weekday ${date.day} $month';
}
