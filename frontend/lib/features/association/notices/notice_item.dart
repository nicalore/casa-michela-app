import 'dart:typed_data';

import '../../../core/utils/json_parsing.dart';

// Mirrors NoticeRoleEnum in backend/app/models/notice.py, in the composer's order.
enum NoticeRole
{
  admin('ADMIN', 'Amministratori'),
  teacher('TEACHER', 'Docenti'),
  psychologist('PSYCHOLOGIST', 'Psicologi'),
  parent('PARENT', 'Genitori'),
  student('STUDENT', 'Studenti'),
  courseParticipant('COURSE_PARTICIPANT', 'Corsisti'),
  member('MEMBER', 'Associati');

  final String code;
  final String plural;

  const NoticeRole(this.code, this.plural);

  static NoticeRole? fromCode(String code)
  {
    for (final role in values)
    {
      if (role.code == code)
      {
        return role;
      }
    }

    return null;
  }

  static List<NoticeRole> parse(Object? value)
  {
    final roles = parseStringList(value).map(fromCode).whereType<NoticeRole>().toSet();

    return values.where(roles.contains).toList();
  }
}

class NoticeAttachmentItem
{
  final int id;
  final String fileName;
  final String contentType;
  final int size;

  const NoticeAttachmentItem({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.size,
  });

  factory NoticeAttachmentItem.fromJson(Map<String, dynamic> json)
  {
    return NoticeAttachmentItem(
      id: json['id'] as int,
      fileName: json['file_name'] as String,
      contentType: json['content_type'] as String,
      size: json['size'] as int,
    );
  }
}

class NoticeImageItem
{
  final String key;
  final int size;

  const NoticeImageItem({required this.key, required this.size});

  factory NoticeImageItem.fromJson(Map<String, dynamic> json)
  {
    return NoticeImageItem(key: json['key'] as String, size: json['size'] as int);
  }
}

class NoticeSummaryItem
{
  final int id;
  final String title;
  final String preview;
  final String authorTaxCode;
  final String authorName;
  final List<NoticeRole> recipients;
  final int attachmentCount;
  final DateTime createdAt;
  final DateTime? editedAt;
  // Both null unless pinned today; a pinned one without a day stays until unpinned.
  final DateTime? pinnedAt;
  final DateTime? pinnedUntil;

  const NoticeSummaryItem({
    required this.id,
    required this.title,
    required this.preview,
    required this.authorTaxCode,
    required this.authorName,
    required this.recipients,
    required this.attachmentCount,
    required this.createdAt,
    required this.editedAt,
    this.pinnedAt,
    this.pinnedUntil,
  });

  factory NoticeSummaryItem.fromJson(Map<String, dynamic> json)
  {
    return NoticeSummaryItem(
      id: json['id'] as int,
      title: json['title'] as String,
      preview: json['preview'] as String,
      authorTaxCode: json['author_tax_code'] as String,
      authorName: json['author_name'] as String,
      recipients: NoticeRole.parse(json['recipients']),
      attachmentCount: json['attachment_count'] as int,
      createdAt: parseInstant(json['created_at'])!.toLocal(),
      editedAt: parseInstant(json['edited_at'])?.toLocal(),
      pinnedAt: parseInstant(json['pinned_at'])?.toLocal(),
      pinnedUntil: parseDate(json['pinned_until']),
    );
  }

  // A role's copy: no recipients, no tax code, no pin's last day.
  factory NoticeSummaryItem.fromReceivedJson(Map<String, dynamic> json)
  {
    return NoticeSummaryItem(
      id: json['id'] as int,
      title: json['title'] as String,
      preview: json['preview'] as String,
      authorTaxCode: '',
      authorName: json['author_name'] as String,
      recipients: const [],
      attachmentCount: json['attachment_count'] as int,
      createdAt: parseInstant(json['created_at'])!.toLocal(),
      editedAt: parseInstant(json['edited_at'])?.toLocal(),
      pinnedAt: parseInstant(json['pinned_at'])?.toLocal(),
    );
  }

  bool get pinned => pinnedAt != null;

  NoticeSummaryItem unpinned()
  {
    return NoticeSummaryItem(
      id: id,
      title: title,
      preview: preview,
      authorTaxCode: authorTaxCode,
      authorName: authorName,
      recipients: recipients,
      attachmentCount: attachmentCount,
      createdAt: createdAt,
      editedAt: editedAt,
    );
  }

  bool isWrittenBy(String? taxCode) => taxCode != null && taxCode.toUpperCase() == authorTaxCode.toUpperCase();
}

class NoticeItem extends NoticeSummaryItem
{
  final String message;
  final int recipientCount;
  final List<NoticeAttachmentItem> attachments;
  final List<NoticeImageItem> images;
  final DateTime updatedAt;

  const NoticeItem({
    required super.id,
    required super.title,
    required super.preview,
    required super.authorTaxCode,
    required super.authorName,
    required super.recipients,
    required super.attachmentCount,
    required super.createdAt,
    required super.editedAt,
    super.pinnedAt,
    super.pinnedUntil,
    required this.message,
    required this.recipientCount,
    required this.attachments,
    required this.images,
    required this.updatedAt,
  });

  factory NoticeItem.fromJson(Map<String, dynamic> json)
  {
    final summary = NoticeSummaryItem.fromJson(json);

    return NoticeItem(
      id: summary.id,
      title: summary.title,
      preview: summary.preview,
      authorTaxCode: summary.authorTaxCode,
      authorName: summary.authorName,
      recipients: summary.recipients,
      attachmentCount: summary.attachmentCount,
      createdAt: summary.createdAt,
      editedAt: summary.editedAt,
      pinnedAt: summary.pinnedAt,
      pinnedUntil: summary.pinnedUntil,
      message: json['message'] as String,
      recipientCount: json['recipient_count'] as int,
      attachments: parseList(json['attachments'], NoticeAttachmentItem.fromJson),
      images: parseList(json['images'], NoticeImageItem.fromJson),
      // Sent back untouched: the server compares it to the millisecond.
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }

  // A reader's copy carries no recipients and no tax code: nothing to edit with.
  factory NoticeItem.fromReadingJson(Map<String, dynamic> json)
  {
    final DateTime createdAt = parseInstant(json['created_at'])!.toLocal();
    final List<NoticeAttachmentItem> attachments = parseList(json['attachments'], NoticeAttachmentItem.fromJson);

    return NoticeItem(
      id: json['id'] as int,
      title: json['title'] as String,
      preview: '',
      authorTaxCode: '',
      authorName: json['author_name'] as String,
      recipients: const [],
      attachmentCount: attachments.length,
      createdAt: createdAt,
      editedAt: parseInstant(json['edited_at'])?.toLocal(),
      message: json['message'] as String,
      recipientCount: 0,
      attachments: attachments,
      images: parseList(json['images'], NoticeImageItem.fromJson),
      updatedAt: createdAt,
    );
  }
}

// A line of the home card.
class NoticeHeadlineItem
{
  final int id;
  final String title;
  final String authorName;
  final DateTime createdAt;
  final bool pinned;

  const NoticeHeadlineItem({
    required this.id,
    required this.title,
    required this.authorName,
    required this.createdAt,
    required this.pinned,
  });

  factory NoticeHeadlineItem.fromJson(Map<String, dynamic> json)
  {
    return NoticeHeadlineItem(
      id: json['id'] as int,
      title: json['title'] as String,
      authorName: json['author_name'] as String,
      createdAt: parseInstant(json['created_at'])!.toLocal(),
      pinned: json['pinned'] as bool,
    );
  }
}

typedef NoticeRecipientCount = ({int people, int emails});

// A file chosen in the composer, not yet on the server.
class NoticeUpload
{
  final String fileName;
  final Uint8List bytes;
  // Null lets the server guess from the name.
  final String? mimeType;

  const NoticeUpload({required this.fileName, required this.bytes, this.mimeType});

  int get size => bytes.length;
}

// What the composer hands over; keptAttachmentIds only when editing.
class NoticeDraft
{
  final String title;
  final String message;
  final List<NoticeRole> recipients;
  final List<NoticeUpload> attachments;
  // Keyed by the key the message writes after image:.
  final Map<String, NoticeUpload> images;
  final List<int> keptAttachmentIds;

  const NoticeDraft({
    required this.title,
    required this.message,
    required this.recipients,
    required this.attachments,
    required this.images,
    this.keptAttachmentIds = const [],
  });
}

// Pinned first, the latest pinned on top; then by sending. Newest first mirrors the server.
List<NoticeSummaryItem> noticeListingOrder(Iterable<NoticeSummaryItem> notices, {bool oldestFirst = false})
{
  final List<NoticeSummaryItem> pinned = notices.where((notice) => notice.pinned).toList()
    ..sort((a, b) => b.pinnedAt!.compareTo(a.pinnedAt!));
  final List<NoticeSummaryItem> others = notices.where((notice) => !notice.pinned).toList()
    ..sort((a, b) => oldestFirst ? a.createdAt.compareTo(b.createdAt) : b.createdAt.compareTo(a.createdAt));

  return [...pinned, ...others];
}

// The day's first notice, or where that day would fall among the unpinned ones; a pinned match only if no other.
int? noticeIndexForDay(List<NoticeSummaryItem> notices, DateTime day, {required bool oldestFirst})
{
  int? pinnedMatch;

  for (var index = 0; index < notices.length; index++)
  {
    final NoticeSummaryItem notice = notices[index];
    final DateTime sent = DateTime(notice.createdAt.year, notice.createdAt.month, notice.createdAt.day);

    if (notice.pinned)
    {
      if (pinnedMatch == null && sent == day)
      {
        pinnedMatch = index;
      }

      continue;
    }

    if (sent == day)
    {
      return index;
    }

    if (oldestFirst ? sent.isAfter(day) : sent.isBefore(day))
    {
      return pinnedMatch ?? index;
    }
  }

  return notices.isEmpty ? null : (pinnedMatch ?? notices.length - 1);
}
