import 'package:flutter/material.dart';

import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../notifications/notification_board.dart';
import '../models/person_item.dart';
import '../models/student_note_item.dart';
import '../utils/student_notes_strings.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/student_note_dialog.dart';
import '../widgets/student_notes_card.dart';

const double _cardsWidth = 1600;

// Any admin edits any technical note; methodological ones are read-only, teachers' only deletable.
// A teacher's: the administrators' notes on them, which any admin edits too.
class PersonObservationsTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  final bool pupil;
  final bool teacher;

  const PersonObservationsTab({
    super.key,
    required this.person,
    required this.onUpdate,
    required this.pupil,
    required this.teacher,
  });

  Future<void> _write(BuildContext context, StudentNoteKind kind, {StudentNoteItem? note}) async
  {
    if (!await showStudentNoteDialog(context, person, kind, note: note) || !context.mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: note == null ? kNoteCreated : kNoteEdited);
    onUpdate();
  }

  Future<void> _delete(BuildContext context, StudentNoteKind kind, StudentNoteItem note) async
  {
    if (!await confirmNoteDeletion(context) || !context.mounted)
    {
      return;
    }

    try
    {
      await ApiService().deleteStudentNote(person.fiscalCode, kind, note.id);

      if (kind == StudentNoteKind.teacher)
      {
        NotificationBoard.instance.dropTeacherNote(note.id);
      }

      if (context.mounted)
      {
        CustomSnackBar.show(context: context, message: kNoteDeletedDone);
      }

      onUpdate();
    }
    catch (error)
    {
      if (context.mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _cardsWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks([
                if (pupil) ...[
                  StudentNotesCard(
                    title: kTechnicalNotesTitle,
                    icon: Icons.edit_note_rounded,
                    taxCode: person.fiscalCode,
                    kind: StudentNoteKind.technical,
                    notes: person.technicalNotes ?? const [],
                    onAdd: () => _write(context, StudentNoteKind.technical),
                    mayChange: (_) => true,
                    onEdit: (note) => _write(context, StudentNoteKind.technical, note: note),
                    onDelete: (note) => _delete(context, StudentNoteKind.technical, note),
                  ),
                  const SizedBox(height: kPersonCardGap),
                  StudentNotesCard(
                    title: kMethodologicalNotesTitle,
                    icon: Icons.psychology_rounded,
                    taxCode: person.fiscalCode,
                    kind: StudentNoteKind.methodological,
                    notes: person.methodologicalNotes ?? const [],
                  ),
                  const SizedBox(height: kPersonCardGap),
                  StudentNotesCard(
                    title: kTeacherNotesTitle,
                    icon: Icons.rate_review_outlined,
                    taxCode: person.fiscalCode,
                    kind: StudentNoteKind.teacher,
                    notes: person.teacherNotes ?? const [],
                    mayChange: (_) => true,
                    onDelete: (note) => _delete(context, StudentNoteKind.teacher, note),
                  ),
                ],
                if (pupil && teacher) const SizedBox(height: kPersonCardGap),
                if (teacher)
                  StudentNotesCard(
                    title: kObservationsTitle,
                    icon: Icons.edit_note_rounded,
                    taxCode: person.fiscalCode,
                    kind: StudentNoteKind.administrator,
                    notes: person.administratorNotes ?? const [],
                    onAdd: () => _write(context, StudentNoteKind.administrator),
                    mayChange: (_) => true,
                    onEdit: (note) => _write(context, StudentNoteKind.administrator, note: note),
                    onDelete: (note) => _delete(context, StudentNoteKind.administrator, note),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
