import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/week_range.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

// One supervision stretch; several per room. Coverage continuity is checked
// at publication. Keyed to the assignment: removing it removes the shifts.
class RoomSupervisionItem
{
  final int id;
  final DateTime date;
  final String teacherTaxCode;
  final PersonOptionItem teacher;
  final RoomOptionItem room;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  final DateTime createdAt;
  final DateTime updatedAt;

  const RoomSupervisionItem({
    required this.id,
    required this.date,
    required this.teacherTaxCode,
    required this.teacher,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.updatedAt,
  });

  int get startMinutes => minutesOfTimeOfDay(startTime);

  int get endMinutes => minutesOfTimeOfDay(endTime);

  factory RoomSupervisionItem.fromJson(Map<String, dynamic> json)
  {
    return RoomSupervisionItem(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      teacherTaxCode: json['teacher_tax_code'] as String,
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      room: RoomOptionItem.fromJson(json['room'] as Map<String, dynamic>),
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      createdAt: parseInstant(json['created_at'])!,
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
