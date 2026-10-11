import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../association/notices/notice_embeds.dart';
import '../../association/notices/notice_message_view.dart';
import '../models/person_item.dart';
import '../models/student_note_item.dart';

// Kept for the session: a key names one image for good, so nothing goes stale.
final Map<String, Uint8List> _loaded = {};
final Map<String, Future<Uint8List>> _fetched = {};

// A note not saved yet has no id, so nothing to fetch.
NoticeImages studentNoteImages(String taxCode, StudentNoteKind kind, int? noteId)
{
  return NoticeImages(
    fetcher: noteId == null ? null : (key) => ApiService().fetchStudentNoteImage(taxCode, kind, noteId, key),
    loaded: _loaded,
    fetched: _fetched,
  );
}

// Fetched and decoded before the notes are shown, so they open at their full height.
Future<void> preloadNoteImages(
  BuildContext context,
  String taxCode,
  StudentNoteKind kind,
  Iterable<StudentNoteItem> notes,
) async
{
  try
  {
    await Future.wait([
      for (final note in notes)
        if (note.images.isNotEmpty)
          studentNoteImages(taxCode, kind, note.id).preload(context, [for (final image in note.images) image.key]),
    ]);
  }
  catch (_)
  {
    // A missing image is fetched again in the note, under a placeholder.
  }
}

Future<void> preloadStudentNoteImages(BuildContext context, PersonItem student) async
{
  await Future.wait([
    preloadNoteImages(context, student.fiscalCode, StudentNoteKind.technical, student.technicalNotes ?? const []),
    preloadNoteImages(context, student.fiscalCode, StudentNoteKind.methodological, student.methodologicalNotes ?? const []),
  ]);
}

// [style] must use the registered PlusJakartaSans family: Markdown sets other weights.
class StudentNoteText extends StatelessWidget
{
  final String taxCode;
  final StudentNoteKind kind;
  final StudentNoteItem note;
  final TextStyle style;

  const StudentNoteText({
    super.key,
    required this.taxCode,
    required this.kind,
    required this.note,
    required this.style,
  });

  @override
  Widget build(BuildContext context)
  {
    // Teachers write plain text.
    if (kind == StudentNoteKind.teacher)
    {
      return Text(note.text, style: style);
    }

    return NoticeMessageView(
      // A changed text is a new document: the view reads its message once.
      key: ValueKey((kind, note.id, note.text)),
      message: note.text,
      images: studentNoteImages(taxCode, kind, note.id),
      textStyle: style,
      tight: true,
    );
  }
}
