import '../../../core/utils/time_bucket.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

// An administrator's note to one teacher about one band, read by that teacher alone.
class CalendarTeacherNoteItem
{
  final TimeBucket band;
  final String teacherTaxCode;
  final String text;

  // Null once the writer's record is gone.
  final PersonOptionItem? author;

  const CalendarTeacherNoteItem({
    required this.band,
    required this.teacherTaxCode,
    required this.text,
    this.author,
  });

  factory CalendarTeacherNoteItem.fromJson(Map<String, dynamic> json)
  {
    final author = json['author'];

    return CalendarTeacherNoteItem(
      band: LessonItem.parseBand(json['band']),
      teacherTaxCode: json['teacher_tax_code'] as String,
      text: json['text'] as String,
      author: author is Map<String, dynamic> ? PersonOptionItem.fromJson(author) : null,
    );
  }
}
