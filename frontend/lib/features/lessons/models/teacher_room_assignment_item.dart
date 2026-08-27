import '../../../core/utils/json_parsing.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

// One per teacher per day (not per hour); only teachers in the building have one.
class TeacherRoomAssignmentItem
{
  final DateTime date;
  final String teacherTaxCode;
  final PersonOptionItem teacher;

  // Not [RoomItem]: the catalogue row insists on a created_at this lacks.
  final RoomOptionItem room;

  // Present only on the write's answer, not on later reads.
  final List<String> warnings;

  final DateTime createdAt;

  // Goes back as expected_updated_at when the room is moved.
  final DateTime updatedAt;

  const TeacherRoomAssignmentItem({
    required this.date,
    required this.teacherTaxCode,
    required this.teacher,
    required this.room,
    this.warnings = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherRoomAssignmentItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherRoomAssignmentItem(
      date: DateTime.parse(json['date'] as String),
      teacherTaxCode: json['teacher_tax_code'] as String,
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      room: RoomOptionItem.fromJson(json['room'] as Map<String, dynamic>),
      warnings: parseStringList(json['warnings']),
      createdAt: parseInstant(json['created_at'])!,
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
