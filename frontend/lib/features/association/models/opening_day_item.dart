import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';

class OpeningDayItem
{
  final int id;
  final DateTime date;
  final String mode;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isOverride;

  // Whether this row is a public holiday the calendar generation seeded on its
  // own (Natale, Pasqua, ...). Computed server-side — the table has no column
  // for it, holidays being stored as ordinary overrides — and used to leave
  // the recurring closures out of the edit/delete actions on variations.
  final bool isHoliday;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OpeningDayItem({
    required this.id,
    required this.date,
    required this.mode,
    this.startTime,
    this.endTime,
    required this.isOverride,
    this.isHoliday = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OpeningDayItem.fromJson(Map<String, dynamic> json)
  {
    return OpeningDayItem(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      mode: json['mode'] as String,
      startTime: parseOptionalTimeOfDay(json['start_time']),
      endTime: parseOptionalTimeOfDay(json['end_time']),
      isOverride: json['is_override'] as bool,
      isHoliday: json['is_holiday'] as bool? ?? false,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
