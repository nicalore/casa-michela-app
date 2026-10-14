import '../../../core/utils/json_parsing.dart';

// One open day of the teachers' trend; convened counts lessons and activities alike.
class TeacherActivityDayItem
{
  final DateTime date;
  final int available;
  final int convened;
  final int lessonMinutes;

  const TeacherActivityDayItem({
    required this.date,
    required this.available,
    required this.convened,
    required this.lessonMinutes,
  });

  factory TeacherActivityDayItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherActivityDayItem(
      date: parseDate(json['date'])!,
      available: json['available'] as int,
      convened: json['convened'] as int,
      lessonMinutes: json['lesson_minutes'] as int,
    );
  }
}

class PresenceDayItem
{
  final DateTime date;
  final int studentCount;

  const PresenceDayItem({required this.date, required this.studentCount});

  factory PresenceDayItem.fromJson(Map<String, dynamic> json)
  {
    return PresenceDayItem(
      date: parseDate(json['date'])!,
      studentCount: json['student_count'] as int,
    );
  }
}
