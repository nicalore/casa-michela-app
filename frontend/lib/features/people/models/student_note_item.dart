import '../../../core/utils/json_parsing.dart';

// Methodological by psychologists, technical by administrators, teacher after a lesson.
enum StudentNoteKind
{
  methodological('methodological-notes'),
  technical('technical-notes'),
  teacher('teacher-notes');

  // The collection under /people/{tax_code}/.
  final String path;

  const StudentNoteKind(this.path);
}

class StudentNoteItem
{
  final int id;
  final String text;
  final String authorTaxCode;
  final String authorName;
  final DateTime createdAt;

  // A teacher's note only: the lesson it follows.
  final DateTime? lessonDate;
  final String? subject;

  const StudentNoteItem({
    required this.id,
    required this.text,
    required this.authorTaxCode,
    required this.authorName,
    required this.createdAt,
    this.lessonDate,
    this.subject,
  });

  factory StudentNoteItem.fromJson(Map<String, dynamic> json)
  {
    return StudentNoteItem(
      id: json['id'] as int,
      text: json['text'] as String,
      authorTaxCode: json['author_tax_code'] as String,
      authorName: json['author_name'] as String,
      createdAt: parseInstant(json['created_at'])!.toLocal(),
      lessonDate: parseDate(json['lesson_date']),
      subject: json['subject'] as String?,
    );
  }
}
