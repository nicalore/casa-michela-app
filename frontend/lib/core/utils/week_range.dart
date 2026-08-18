// Week math and compact date/time labels for the Orari weekly-hours table
// (Associazione > Orari > In presenza/Online). Shared by both sub-tabs, hence
// living under core/utils rather than a single feature folder.
//
// Every day-stepping computation here goes through the DateTime constructor
// (year, month, day + n) rather than Duration-based add()/subtract(), mirroring
// features/lessons/utils/booking_window.dart: Duration arithmetic on local
// DateTimes can skew across Italy's DST transitions, while constructor field
// arithmetic is plain calendar math with no such risk.

import 'package:flutter/material.dart';

// The step every hour in this app moves by, and the one the backend stores.
const int kQuarterHour = 15;

// The shortest stretch a pupil can give, in the building or online. Anything
// under it is a pupil arriving and leaving, and the database refuses it anyway.
const int kMinimumBandMinutes = 30;

// The association's day, in minutes from midnight: the morning band opens at
// six and the evening one shuts at eleven. Anything that asks for an hour —
// the bands of the weekly hours, a teacher's availability, a pupil's presence
// — is a stretch of this day, so the two ends live here rather than in the
// module that happened to need them first.
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

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

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

// The 7 dates from [weekStart] (expected to already be a Monday) through the
// following Sunday, inclusive.
List<DateTime> daysOfWeek(DateTime weekStart)
{
  return List.generate(7, (i) => addDays(weekStart, i));
}

bool isSameDate(DateTime a, DateTime b)
{
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Minutes from midnight
// ---------------------------------------------------------------------------

TimeOfDay timeOfDayFromMinutes(int minutes)
{
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

int minutesOfTimeOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

// ---------------------------------------------------------------------------
// Labels
// ---------------------------------------------------------------------------

String _twoDigits(int value) => value.toString().padLeft(2, '0');

// "Lun".."Dom" for ISO weekday 1-7.
String weekdayShortName(int weekday) => _weekdayNamesShort[weekday - 1];

// "Lunedì".."Domenica" for ISO weekday 1-7 — the un-dated counterpart of
// weekdayShortName, used where a full day name is needed without an actual
// date (e.g. one wizard step per weekday).
String weekdayFullName(int weekday) => _weekdayNamesFull[weekday - 1];

// "Lunedì 27 dicembre" — the day-column label for the opening-hours table,
// written out in full (not abbreviated, unlike the week-range caption below).
String formatWeekdayColumnLabel(DateTime date)
{
  return '${_weekdayNamesFull[date.weekday - 1]} ${date.day} ${_monthNamesFull[date.month - 1]}';
}

// "27 lug" — used for the week-range caption next to the nav arrows.
String formatDayMonthShort(DateTime date)
{
  return '${date.day} ${_monthNamesShort[date.month - 1]}';
}

// "27 dicembre" — a dated label without the weekday, for spans covering
// several days where naming one weekday would be misleading.
String formatDayMonthFull(DateTime date)
{
  return '${date.day} ${_monthNamesFull[date.month - 1]}';
}

// "Dal 20 al 22 agosto", collapsing the repeated month when both ends share
// one. Callers use it for multi-day spans; a single day keeps the fuller
// formatWeekdayColumnLabel instead.
String formatDateSpan(DateTime start, DateTime end)
{
  if (start.month == end.month && start.year == end.year)
  {
    return 'Dal ${start.day} al ${formatDayMonthFull(end)}';
  }

  return 'Dal ${formatDayMonthFull(start)} al ${formatDayMonthFull(end)}';
}

// "09:00" — display-only formatting. Distinct from json_parsing.dart's
// formatTimeOfDay, which produces "09:00:00" for requests sent to the
// backend.
String formatTimeOfDayShort(TimeOfDay time)
{
  return '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

// "09:00–13:00"
String formatTimeRange(TimeOfDay start, TimeOfDay end)
{
  return '${formatTimeOfDayShort(start)}–${formatTimeOfDayShort(end)}';
}

// "09:00–13:00", from the two ends said in minutes from midnight.
//
// The calendar works in minutes from end to end and only turns them into a
// TimeOfDay at the edges; this is one of those edges.
String formatMinutesRange(int startMinutes, int endMinutes)
{
  return formatTimeRange(timeOfDayFromMinutes(startMinutes), timeOfDayFromMinutes(endMinutes));
}

// A number of minutes, said the way a timetable says it: "2h", "2h 30m",
// "45m". Where hours and minutes both stand, they stand together.
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
