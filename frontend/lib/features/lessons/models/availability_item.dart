import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import 'person_option_item.dart';

class AvailabilityItem
{
  final int id;
  final DateTime date;

  // 'presence' or 'online', matching the opening-hours modes.
  final String mode;

  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String teacherTaxCode;
  final PersonOptionItem teacher;
  final DateTime updatedAt;

  const AvailabilityItem({
    required this.id,
    required this.date,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.teacherTaxCode,
    required this.teacher,
    required this.updatedAt,
  });

  factory AvailabilityItem.fromJson(Map<String, dynamic> json)
  {
    return AvailabilityItem(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      mode: json['mode'] as String,
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      teacherTaxCode: json['teacher_tax_code'] as String,
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
