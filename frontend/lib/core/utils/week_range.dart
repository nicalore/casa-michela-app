// Day stepping uses DateTime(y, m, d + n), not Duration add(), which skews across DST.

import 'package:flutter/material.dart';

import '../language/app_language.dart';

// The step every hour moves by, and the one the backend stores.
const int kQuarterHour = 15;

// The shortest stretch a pupil can give; the database refuses less.
const int kMinimumBandMinutes = 30;

// A lesson lasts half an hour at least; a quarter of an hour only when that is its whole booking.
const int kMinimumLessonMinutes = kMinimumBandMinutes;
const int kQuarterLessonMinutes = kQuarterHour;

int minimumLessonMinutes(int bookingMinutes) => bookingMinutes < kMinimumLessonMinutes ? bookingMinutes : kMinimumLessonMinutes;

// The association's day in minutes from midnight: 06:00 to 23:00.
const int kDayStartMinutes = 6 * 60;
const int kDayEndMinutes = 23 * 60;

const List<String> _weekdayNamesShort = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
const List<String> _weekdayNamesShortEnglish = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const List<String> _weekdayNamesFull = [
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

const List<String> _weekdayNamesFullEnglish = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthNamesShort = [
  'gen',
  'feb',
  'mar',
  'apr',
  'mag',
  'giu',
  'lug',
  'ago',
  'set',
  'ott',
  'nov',
  'dic',
];

const List<String> _monthNamesShortEnglish = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthNamesFull = [
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

const List<String> _monthNamesFullEnglish = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

List<String> get _weekdaysShort => isEnglish ? _weekdayNamesShortEnglish : _weekdayNamesShort;
List<String> get _weekdaysFull => isEnglish ? _weekdayNamesFullEnglish : _weekdayNamesFull;
List<String> get _monthsShort => isEnglish ? _monthNamesShortEnglish : _monthNamesShort;
List<String> get _monthsFull => isEnglish ? _monthNamesFullEnglish : _monthNamesFull;

DateTime _dateOnly(DateTime value)
{
  return DateTime(value.year, value.month, value.day);
}

DateTime addDays(DateTime date, int days)
{
  return DateTime(date.year, date.month, date.day + days);
}

// The Monday of the week containing [date], time-of-day stripped.
DateTime startOfWeek(DateTime date)
{
  final day = _dateOnly(date);
  return addDays(day, -(day.weekday - DateTime.monday));
}

// The 7 dates from [weekStart] (a Monday) through Sunday.
List<DateTime> daysOfWeek(DateTime weekStart)
{
  return List.generate(7, (i) => addDays(weekStart, i));
}

bool isSameDate(DateTime a, DateTime b)
{
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

TimeOfDay timeOfDayFromMinutes(int minutes)
{
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

int minutesOfTimeOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

// "Lun".."Dom" for ISO weekday 1-7.
String weekdayShortName(int weekday) => _weekdaysShort[weekday - 1];

// "Lunedì".."Domenica" for ISO weekday 1-7.
String weekdayFullName(int weekday) => _weekdaysFull[weekday - 1];

// "Lunedì 27 dicembre".
String formatWeekdayColumnLabel(DateTime date)
{
  return '${_weekdaysFull[date.weekday - 1]} ${date.day} ${_monthsFull[date.month - 1]}';
}

// "27 lug".
String formatDayMonthShort(DateTime date)
{
  return '${date.day} ${_monthsShort[date.month - 1]}';
}

// "27 dicembre".
String formatDayMonthFull(DateTime date)
{
  return '${date.day} ${_monthsFull[date.month - 1]}';
}

// "settembre".
String formatMonthName(DateTime month) => _monthsFull[month.month - 1];

// "Settembre 2026".
String formatMonthYear(DateTime month)
{
  final name = _monthsFull[month.month - 1];

  return '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
}

List<String> get kWeekdayInitials => isEnglish
    ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
    : const ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

// Six weeks from the Monday on or before the 1st, null outside the month: same height every month.
List<DateTime?> monthGridDays(DateTime month)
{
  final lead = DateTime(month.year, month.month, 1).weekday - 1;
  final count = DateTime(month.year, month.month + 1, 0).day;

  return [
    for (var i = 0; i < 42; i++)
      if (i < lead || i >= lead + count) null else DateTime(month.year, month.month, i - lead + 1),
  ];
}

// Days read with a leading vowel in Italian (1, 8, 11) take the elided article.
bool _elides(int day) => day == 1 || day == 8 || day == 11;

// "dal 20 agosto", "dall'1 agosto", inside a sentence; "from 20 August".
String fromDayInSentence(DateTime day)
{
  return isEnglish ? 'from ${formatDayMonthFull(day)}' : '${_elides(day.day) ? "dall'" : 'dal '}${formatDayMonthFull(day)}';
}

// "al 20 agosto", "all'8 agosto"; "to 20 August".
String toDayInSentence(DateTime day)
{
  return isEnglish ? 'to ${formatDayMonthFull(day)}' : '${_elides(day.day) ? "all'" : 'al '}${formatDayMonthFull(day)}';
}

// "dal 12", "dall'11": a day of a month already named.
String fromDayNumberInSentence(int day) => isEnglish ? 'from $day' : '${_elides(day) ? "dall'" : 'dal '}$day';

// "al 18", "all'11".
String toDayNumberInSentence(int day) => isEnglish ? 'to $day' : '${_elides(day) ? "all'" : 'al '}$day';

// "Dal 20 al 22 agosto", "Dall'1 all'8 agosto", collapsing the repeated month; "From 20 to 22 August".
String formatDateSpan(DateTime start, DateTime end)
{
  final from = isEnglish ? 'From ' : (_elides(start.day) ? "Dall'" : 'Dal ');
  final to = isEnglish ? 'to ' : (_elides(end.day) ? "all'" : 'al ');

  if (start.month == end.month && start.year == end.year)
  {
    return '$from${start.day} $to${formatDayMonthFull(end)}';
  }

  return '$from${formatDayMonthFull(start)} $to${formatDayMonthFull(end)}';
}

// "09:00", display-only; json_parsing's formatTimeOfDay makes "09:00:00" for the backend.
String formatTimeOfDayShort(TimeOfDay time)
{
  return '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

// "09:00-13:00" (en dash).
String formatTimeRange(TimeOfDay start, TimeOfDay end)
{
  return '${formatTimeOfDayShort(start)}–${formatTimeOfDayShort(end)}';
}

// Same, from minutes from midnight.
String formatMinutesRange(int startMinutes, int endMinutes)
{
  return formatTimeRange(timeOfDayFromMinutes(startMinutes), timeOfDayFromMinutes(endMinutes));
}

// "2h", "2h 30m", "45m".
String formatMinutes(int minutes)
{
  final hours = minutes ~/ 60;
  final rest = minutes % 60;

  if (hours == 0)
  {
    return '${rest}m';
  }

  if (rest == 0)
  {
    return '${hours}h';
  }

  return '${hours}h ${rest}m';
}
