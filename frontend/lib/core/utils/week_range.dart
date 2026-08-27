// Week math and labels for the Orari weekly-hours table. Day stepping uses the
// DateTime constructor (y, m, d + n), not Duration add(), which skews across DST.

import 'package:flutter/material.dart';

// The step every hour moves by, and the one the backend stores.
const int kQuarterHour = 15;

// The shortest stretch a pupil can give; the database refuses less.
const int kMinimumBandMinutes = 30;

// The association's day in minutes from midnight: 06:00 to 23:00.
const int kDayStartMinutes = 6 * 60;
const int kDayEndMinutes = 23 * 60;

const List<String> _weekdayNamesShort = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

const List<String> _weekdayNamesFull = [
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
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
String weekdayShortName(int weekday) => _weekdayNamesShort[weekday - 1];

// "Lunedì".."Domenica" for ISO weekday 1-7.
String weekdayFullName(int weekday) => _weekdayNamesFull[weekday - 1];

// "Lunedì 27 dicembre".
String formatWeekdayColumnLabel(DateTime date)
{
  return '${_weekdayNamesFull[date.weekday - 1]} ${date.day} ${_monthNamesFull[date.month - 1]}';
}

// "27 lug".
String formatDayMonthShort(DateTime date)
{
  return '${date.day} ${_monthNamesShort[date.month - 1]}';
}

// "27 dicembre".
String formatDayMonthFull(DateTime date)
{
  return '${date.day} ${_monthNamesFull[date.month - 1]}';
}

// "Dal 20 al 22 agosto", collapsing the repeated month.
String formatDateSpan(DateTime start, DateTime end)
{
  if (start.month == end.month && start.year == end.year)
  {
    return 'Dal ${start.day} al ${formatDayMonthFull(end)}';
  }

  return 'Dal ${formatDayMonthFull(start)} al ${formatDayMonthFull(end)}';
}

// "09:00" — display-only; json_parsing's formatTimeOfDay makes "09:00:00"
// for the backend.
String formatTimeOfDayShort(TimeOfDay time)
{
  return '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

// "09:00–13:00"
String formatTimeRange(TimeOfDay start, TimeOfDay end)
{
  return '${formatTimeOfDayShort(start)}–${formatTimeOfDayShort(end)}';
}

// "09:00–13:00", from minutes from midnight.
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
