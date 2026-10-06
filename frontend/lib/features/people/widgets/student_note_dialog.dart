import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../models/person_item.dart';
import '../models/student_note_item.dart';
import '../utils/student_notes_strings.dart';

const double _dialogWidth = 900;
const double _confirmWidth = 480;

const int _lines = 10;

// A new note without [note]; true once saved.
Future<bool> showStudentNoteDialog(
  BuildContext context,
  PersonItem student,
  StudentNoteKind kind, {
  StudentNoteItem? note,
}) async
{
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

  late final TextEditingController _controller =
      TextEditingController(text: widget.note?.text ?? '');

  bool _saving = false;

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async
  {
    final String text = _controller.text.trim();

    if (text.isEmpty)
    {
      CustomSnackBar.show(context: context, message: kEmptyNote, isError: true);

      return;
    }

    setState(() => _saving = true);

    try
    {
      final String code = widget.student.fiscalCode;
      final StudentNoteItem? note = widget.note;

      if (note == null)
      {
        await _apiService.createStudentNote(code, widget.kind, text);
      }
      else
      {
        await _apiService.updateStudentNote(code, widget.kind, note.id, text);
      }

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
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              AppTextField(
                controller: _controller,
                label: technical ? kTechnicalNotesTitle : kMethodologicalNotesTitle,
                showLabel: false,
                hintText: '',
                minLines: _lines,
                maxLines: _lines,
                maxLength: FieldLimits.studentNote,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
