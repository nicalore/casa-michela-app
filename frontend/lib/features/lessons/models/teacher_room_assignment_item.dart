import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/week_range.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

// In [room] from [startTime] until the teacher's next row; the first row starts at midnight.
class TeacherRoomAssignmentItem
{
  final DateTime date;
  final String teacherTaxCode;
  final PersonOptionItem teacher;

  // Not [RoomItem]: the catalogue row insists on a created_at this lacks.
  final RoomOptionItem room;

  final TimeOfDay startTime;

  // Present only on the write's answer, not on later reads.
  final List<String> warnings;

  final DateTime createdAt;

  final DateTime updatedAt;

  const TeacherRoomAssignmentItem({
    required this.date,
    required this.teacherTaxCode,
    required this.teacher,
    required this.room,
    required this.startTime,
    this.warnings = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get startMinutes => minutesOfTimeOfDay(startTime);

  factory TeacherRoomAssignmentItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherRoomAssignmentItem(
      date: DateTime.parse(json['date'] as String),
      teacherTaxCode: json['teacher_tax_code'] as String,
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      room: RoomOptionItem.fromJson(json['room'] as Map<String, dynamic>),
      startTime: parseTimeOfDay(json['start_time']),
      warnings: parseStringList(json['warnings']),
      createdAt: parseInstant(json['created_at'])!,
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
