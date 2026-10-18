import '../../core/utils/json_parsing.dart';
import '../association/notices/notice_item.dart';

// Mirrors AppUpdateRoleEnum in backend/app/models/app_update.py, in the composer's order.
enum UpdateRole
{
  admin('ADMIN', 'Amministratori'),
  teacher('TEACHER', 'Docenti'),
  psychologist('PSYCHOLOGIST', 'Psicologi'),
  parent('PARENT', 'Genitori'),
  student('STUDENT', 'Studenti');

  final String code;
  final String plural;

  const UpdateRole(this.code, this.plural);

  static List<UpdateRole> parse(Object? value)
  {
    final Set<String> codes = parseStringList(value).toSet();

    return [for (final role in values) if (codes.contains(role.code)) role];
  }
}

// A card of the IT managers' list.
class UpdateSummaryItem
{
  final int id;
  final String title;
  final String version;
  final String preview;
  final String authorName;
  final List<UpdateRole> recipients;
  final DateTime createdAt;
  final DateTime? editedAt;

  const UpdateSummaryItem({
    required this.id,
    required this.title,
    required this.version,
    required this.preview,
    required this.authorName,
    required this.recipients,
    required this.createdAt,
    required this.editedAt,
  });

  factory UpdateSummaryItem.fromJson(Map<String, dynamic> json)
  {
    return UpdateSummaryItem(
      id: json['id'] as int,
      title: json['title'] as String,
      version: json['version'] as String,
      preview: json['preview'] as String,
      authorName: json['author_name'] as String,
      recipients: UpdateRole.parse(json['recipients']),
      createdAt: parseInstant(json['created_at'])!.toLocal(),
      editedAt: parseInstant(json['edited_at'])?.toLocal(),
    );
  }
}

class UpdateItem extends UpdateSummaryItem
{
  final String message;
  final List<NoticeImageItem> images;
  final DateTime updatedAt;

  const UpdateItem({
    required super.id,
    required super.title,
    required super.version,
    required super.preview,
    required super.authorName,
    required super.recipients,
    required super.createdAt,
    required super.editedAt,
    required this.message,
    required this.images,
    required this.updatedAt,
  });

  factory UpdateItem.fromJson(Map<String, dynamic> json)
  {
    final UpdateSummaryItem summary = UpdateSummaryItem.fromJson(json);

    return UpdateItem(
      id: summary.id,
      title: summary.title,
      version: summary.version,
      preview: summary.preview,
      authorName: summary.authorName,
      recipients: summary.recipients,
      createdAt: summary.createdAt,
      editedAt: summary.editedAt,
      message: json['message'] as String,
      images: parseList(json['images'], NoticeImageItem.fromJson),
      // Sent back untouched: the server compares it to the millisecond.
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}

// What a reader is shown: no author, no recipients.
class UpdateReadingItem
{
  final int id;
  final String title;
  final String version;
  final String message;
  final List<NoticeImageItem> images;

  const UpdateReadingItem({
    required this.id,
    required this.title,
    required this.version,
    required this.message,
    required this.images,
  });

  factory UpdateReadingItem.fromJson(Map<String, dynamic> json)
  {
    return UpdateReadingItem(
      id: json['id'] as int,
      title: json['title'] as String,
      version: json['version'] as String,
      message: json['message'] as String,
      images: parseList(json['images'], NoticeImageItem.fromJson),
    );
  }

  factory UpdateReadingItem.of(UpdateItem update)
  {
    return UpdateReadingItem(
      id: update.id,
      title: update.title,
      version: update.version,
      message: update.message,
      images: update.images,
    );
  }
}

// What the composer hands over; the version goes only with a new one.
class UpdateDraft
{
  final String title;
  final String message;
  final List<UpdateRole> recipients;
  // Keyed by the key the message writes after image:.
  final Map<String, NoticeUpload> images;

  const UpdateDraft({
    required this.title,
    required this.message,
    required this.recipients,
    required this.images,
  });
}
