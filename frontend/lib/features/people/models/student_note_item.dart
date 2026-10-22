import '../../../core/utils/json_parsing.dart';
import '../../association/notices/notice_item.dart' show NoticeImageItem;

// Methodological by psychologists, technical by administrators, teacher after a lesson;
// administrator: an administrator's note on a teacher.
enum StudentNoteKind
{
  methodological('methodological-notes'),
  technical('technical-notes'),
  teacher('teacher-notes'),
  administrator('administrator-notes');

  // The collection under /people/{tax_code}/.
  final String path;

  const StudentNoteKind(this.path);
}

class StudentNoteItem
{
  final int id;
  // Markdown, but a teacher's note is plain text.
  final String text;
  final String authorTaxCode;
  final String authorName;
  final DateTime createdAt;

  // The images the text shows; a teacher's note has none.
  final List<NoticeImageItem> images;

  // A teacher's note only: the lesson it follows.
  final DateTime? lessonDate;
  final String? subject;

  const StudentNoteItem({
    required this.id,
    required this.text,
    required this.authorTaxCode,
    required this.authorName,
    required this.createdAt,
    this.images = const [],
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
      images: parseOptionalList(json['images'], NoticeImageItem.fromJson) ?? const [],
      lessonDate: parseDate(json['lesson_date']),
      subject: json['subject'] as String?,
    );
  }
}
