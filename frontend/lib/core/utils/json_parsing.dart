import 'package:flutter/material.dart';

// Display-only date: keeps whatever zone DateTime.parse infers.
DateTime? parseDate(Object? value)
{
  return value == null ? null : DateTime.parse(value as String);
}

// Parses "HH:MM:SS"; seconds are ignored.
TimeOfDay parseTimeOfDay(Object? value)
{
  final parts = (value as String).split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

// Like [parseTimeOfDay] but null stays null: no time means a full-day closure.
TimeOfDay? parseOptionalTimeOfDay(Object? value)
{
  return value == null ? null : parseTimeOfDay(value);
}

// Formats back into the "HH:MM:SS" the backend expects.
String formatTimeOfDay(TimeOfDay time)
{
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute:00';
}

// "YYYY-MM-DD" for a Python `date` field.
String formatDateOnly(DateTime date)
{
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

// DateTime.parse returns local time for numeric offsets like +00:00, and
// toIso8601String then emits no offset: forcing UTC keeps the round trip lossless.
DateTime? parseInstant(Object? value)
{
  return value == null ? null : DateTime.parse(value as String).toUtc();
}

// Keeps null distinct from empty: null means the section was not included.
List<T>? parseOptionalList<T>(Object? value, T Function(Map<String, dynamic>) fromJson)
{
  if (value == null)
  {
    return null;
  }

  return parseList(value, fromJson);
}

// An absent key is a contract violation; the cast is left to throw.
List<T> parseList<T>(Object? value, T Function(Map<String, dynamic>) fromJson)
{
  return (value as List<dynamic>)
      .map((element) => fromJson(element as Map<String, dynamic>))
      .toList();
}

List<String> parseStringList(Object? value)
{
  return (value as List<dynamic>?)?.map((element) => element.toString()).toList() ?? [];
}

// A whole JSON number arrives as int; a direct cast to double throws.
double parseDouble(Object? value)
{
  return (value as num).toDouble();
}

double? parseOptionalDouble(Object? value)
{
  return value == null ? null : (value as num).toDouble();
}
