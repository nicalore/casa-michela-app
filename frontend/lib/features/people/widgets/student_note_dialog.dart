import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/notices/notice_editor.dart';
import '../../association/notices/notice_embeds.dart';
import '../../association/notices/notice_item.dart';
import '../../association/notices/notice_markdown.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../models/person_item.dart';
import '../models/student_note_item.dart';
import '../utils/student_notes_strings.dart';
import 'student_note_text.dart';

const double _dialogWidth = 900;
const double _confirmWidth = 480;

const double _editorHeight = 300;

// As a notice's: the server refuses more.
const int _imagesMaxBytes = 15 * 1024 * 1024;

// A new note without [note]; true once saved.
Future<bool> showStudentNoteDialog(
  BuildContext context,
  PersonItem student,
  StudentNoteKind kind, {
  StudentNoteItem? note,
}) async
{
  if (note != null)
  {
    await preloadNoteImages(context, student.fiscalCode, kind, [note]);

    if (!context.mounted)
    {
      return false;
    }
  }

  final bool? saved = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'StudentNote',
    builder: (context) => _StudentNoteDialog(student: student, kind: kind, note: note),
  );

  return saved ?? false;
}

Future<bool> confirmNoteDeletion(BuildContext context) async
{
  final bool? confirmed = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmDeletion',
    builder: (confirmContext) => AppDialogStack(
      eyebrow: kDeletionEyebrow,
      title: kConfirmTitle,
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: kCancelLabel,
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: 52,
          fontSize: 14,
          onPressed: () => Navigator.pop(confirmContext, false),
        ),
        primary: AppGradientButton(
          label: kDeleteLabel,
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          height: 52,
          fontSize: 14,
          onPressed: () => Navigator.pop(confirmContext, true),
        ),
      ),
      children: [
        AppDialogPill(
          child: Text(
            kNoteDeleted,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

class _StudentNoteDialog extends StatefulWidget
{
  final PersonItem student;

  final StudentNoteKind kind;

  final StudentNoteItem? note;

  const _StudentNoteDialog({required this.student, required this.kind, required this.note});

  @override
  State<_StudentNoteDialog> createState() => _StudentNoteDialogState();
}

class _StudentNoteDialogState extends State<_StudentNoteDialog>
{
  final ApiService _apiService = ApiService();

  late final QuillController _controller = QuillController(
    document: noticeDocument(widget.note?.text ?? ''),
    selection: const TextSelection.collapsed(offset: 0),
  );

  late final NoticeImages _images = studentNoteImages(widget.student.fiscalCode, widget.kind, widget.note?.id);

  bool _saving = false;

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  // Only the images the text still shows count.
  int get _imagesBytes
  {
    final Map<String, int> saved = {for (final image in widget.note?.images ?? <NoticeImageItem>[]) image.key: image.size};
    int total = 0;

    for (final key in documentImageKeys(_controller.document))
    {
      total += _images.added[key]?.size ?? saved[key] ?? 0;
    }

    return total;
  }

  bool _fits(int bytes)
  {
    if (_imagesBytes + bytes <= _imagesMaxBytes)
    {
      return true;
    }

    CustomSnackBar.show(context: context, message: kImagesTooLarge, isError: true);

    return false;
  }

  String? _problem(String markdown)
  {
    if (markdown.isEmpty)
    {
      return kEmptyNote;
    }

    if (markdown.length > FieldLimits.studentNoteMarkdown)
    {
      return kNoteTooLong;
    }

    if (_imagesBytes > _imagesMaxBytes)
    {
      return kImagesTooLarge;
    }

    return null;
  }

  Future<void> _save() async
  {
    final String markdown = noticeMarkdown(_controller.document);
    final String? problem = _problem(markdown);

    if (problem != null)
    {
      CustomSnackBar.show(context: context, message: problem, isError: true);

      return;
    }

    if (_saving)
    {
      return;
    }

    setState(() => _saving = true);

    final Set<String> shown = documentImageKeys(_controller.document);
    final Map<String, NoticeUpload> added = {
      for (final entry in _images.added.entries)
        if (shown.contains(entry.key)) entry.key: entry.value,
    };

    try
    {
      final String code = widget.student.fiscalCode;
      final StudentNoteItem? note = widget.note;

      if (note == null)
      {
        await _apiService.createStudentNote(code, widget.kind, markdown, images: added);
      }
      else
      {
        await _apiService.updateStudentNote(code, widget.kind, note.id, markdown, images: added);
      }

      // Decoded by the editor already: the card shows them without fetching them back.
      _images.keep(added);

      if (mounted)
      {
        Navigator.of(context).pop(true);
      }
    }
    catch (error)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _saving = false);
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final PersonItem student = widget.student;
    final bool editing = widget.note != null;
    final bool technical = widget.kind == StudentNoteKind.technical;

    return AppDialogStack(
      eyebrow: switch ((technical, editing))
      {
        (true, true) => kEditTechnicalNoteEyebrow,
        (true, false) => kNewTechnicalNoteEyebrow,
        (false, true) => kEditNoteEyebrow,
        (false, false) => kNewNoteEyebrow,
      },
      title: '${student.firstName} ${student.lastName}',
      leading: PersonAvatar(person: student, size: PersonAvatar.titleSize),
      maxWidth: _dialogWidth,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: editing ? kSaveChangesLabel : kSaveLabel,
          icon: Icons.check_rounded,
          height: 52,
          fontSize: 14,
          busy: _saving,
          onPressed: _save,
        ),
      ),
      children: [
        AppScrollingDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                notesReadersHint(student.firstName),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: AppTheme.trialMutedText,
                ),
              ),
              const SizedBox(height: 14),
              NoticeEditor(
                controller: _controller,
                images: _images,
                height: _editorHeight,
                canAdd: _fits,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
