import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/study_program_item.dart';
import '../../people/models/person_item.dart';
import '../utils/study_program_lookup.dart';
import '../models/booking_summary_item.dart';
import '../models/presence_group.dart';
import '../models/presence_item.dart';
import '../models/subject_request.dart';
import 'person_avatar.dart';
import 'subject_request_tile.dart';
import 'subject_request_wizard.dart';
import '../utils/booking_window.dart';
import '../utils/opening_window.dart';

// The height and type size every dialog of the app gives its buttons.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

// Narrow: a question of one sentence, and the two answers under it.
const double _confirmWidth = 480;

// Air between two pieces of the same window, the same the stack leaves between
// the ones it lays out itself.
const double _pieceGap = 20;

String _timeRangeLabel(PresenceItem presence)
{
  return formatTimeRange(presence.startTime, presence.endTime);
}

String _ministrySubjectName(List<MinistrySubjectItem> subjects, int id)
{
  for (final subject in subjects)
  {
    if (subject.id == id)
    {
      return subject.name;
    }
  }

  return 'Materia';
}

// The three shapes of request read differently: a ministry subject says which
// disciplines under it, while a lone discipline and a service are called by name
// and nothing more.
String _requestLabel(BookingSummaryItem request, List<MinistrySubjectItem> subjects)
{
  final duration = formatMinutes(request.duration);

  return switch (request.kind)
  {
    BookingRequestKind.ministrySubject => () {
        final name = _ministrySubjectName(subjects, request.ministrySubjectId!);
        final disciplines =
            request.associationSubjects.map((subject) => subject.name).join(', ');

        return '$name: $disciplines · $duration';
      }(),
    BookingRequestKind.associationSubject =>
      '${request.associationSubject!.name} · $duration',
    BookingRequestKind.service => '${request.serviceName!} · $duration',
  };
}

class PresenceCard extends StatefulWidget
{
  // Room for a name over three lines of hours and the count under them. A day
  // can hold more than three stretches, so the column counts what it cannot
  // show rather than making the card grow.
  static const double height = 190;

  // One pupil on one day, with every stretch of hours they asked for and
  // everything they asked to do inside them.
  final PresenceGroup group;

  final List<MinistrySubjectItem> ministrySubjects;

  // Only what the pupil's own study programme teaches can be asked for, so the
  // card has to be able to work out which subjects those are.
  final List<PersonItem> students;
  final List<StudyProgramItem> studyPrograms;

  // And who could teach them: a pupil may name up to three, as a preference.
  final List<PersonItem> teachers;

  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  // One subject changed from the card, without walking the whole window again:
  // the hours are what the wizard is for, and a duration typed wrong is not a
  // reason to go back through them. Changed and taken away, not added: a
  // subject in more is an answer to "what do they want to do", which is asked
  // by the window that writes the day and not by the one that reads it.
  final Future<bool> Function(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError) onEditSubject;
  final Future<bool> Function(BookingSummaryItem booking, int presenceId, Function(String) onError) onDeleteSubject;

  const PresenceCard({
    super.key,
    required this.group,
    required this.ministrySubjects,
    required this.students,
    required this.studyPrograms,
    required this.teachers,
    required this.onEditRequested,
    required this.onDelete,
    required this.onEditSubject,
    required this.onDeleteSubject,
  });

  @override
  State<PresenceCard> createState() => _PresenceCardState();
}

class _PresenceCardState extends State<PresenceCard>
{
  bool _isHovering = false;

  // The day, as something the window that opens off it can listen to. A window
  // that took a copy would show the day as it was when it opened: a subject
  // added from inside it would be written, land, and not appear.
  late final ValueNotifier<PresenceGroup> _group = ValueNotifier(widget.group);

  @override
  void didUpdateWidget(PresenceCard oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // Handed on after the frame rather than during it: this runs while the
    // page is building, and the window listening is somewhere else entirely —
    // in the overlay — where being marked dirty mid-build is an error.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        _group.value = widget.group;
      }
    });
  }

  @override
  void dispose()
  {
    _group.dispose();
    super.dispose();
  }

  void _showDetailsDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RequestDetails',
      builder: (dialogContext) => _RequestDetailsDialogContent(
        group: _group,
        ministrySubjects: widget.ministrySubjects,
        offeredSubjects: offeredSubjects,
        onEditRequested: ()
        {
          Navigator.of(dialogContext).pop();
          // The reopen callback reuses the card state, not the dialog context
          // that is about to become invalid.
          widget.onEditRequested(_showDetailsDialog);
        },
        onDelete: widget.onDelete,
        teachers: widget.teachers,
        // Added, changed and taken away where they stand: the window does not
        // close to ask, and does not have to be found again afterwards.
        onSaveSubject: _writeSubject,
        onDeleteSubject: (mode, booking)
        {
          Navigator.of(dialogContext).pop();
          _showSubjectDeletion(mode: mode, booking: booking);
        },
      ),
    );
  }

  // The subjects a pupil may ask for: the ones their own study programme
  // teaches. A subject nobody teaches them is one nobody can honour.
  List<MinistrySubjectItem> get offeredSubjects
  {
    for (final student in widget.students)
    {
      if (student.fiscalCode == widget.group.studentTaxCode)
      {
        final allowed = allowedMinistrySubjectIds(student, widget.studyPrograms);

        return widget.ministrySubjects.where((subject) => allowed.contains(subject.id)).toList();
      }
    }

    return const [];
  }

  // Which stretch of the day a subject hangs from, and the row as the page has
  // it now.
  //
  // Not always the first one: a day written before its stretches were
  // rearranged can hold it anywhere, and changed against the wrong stretch the
  // write lands while the page refreshes a row that did not move.
  //
  // The row comes back with it, as the page has it now and not as the window
  // had it when it opened. Between the two the day can have been read again —
  // changing its stretches rewrites the subjects hanging off them — and the
  // updated_at the window pocketed on the way in is then a token the server no
  // longer recognises: it answers 409, and an edit that was never sent reads as
  // an edit that was not saved.
  ({int presenceId, BookingSummaryItem booking})? _whereItHangs(BookingSummaryItem booking)
  {
    for (final slot in widget.group.slots)
    {
      for (final row in slot.bookings)
      {
        if (row.id == booking.id)
        {
          return (presenceId: slot.id, booking: row);
        }
      }
    }

    return null;
  }

  // What a row handed back, written where the pupil's day keeps it — all of it,
  // and not the subject and the length alone. Both endpoints write a booking
  // whole: what a save leaves out is not left as it was, it is emptied, so a
  // subject saved by halves comes back with its topic, its notes, its kind of
  // hour and both lists of teachers wiped.
  Future<bool> _writeSubject(BookingSummaryItem existing, SubjectRequestDraft draft) async
  {
    if (!draft.isComplete)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Servono la materia, almeno una disciplina e la durata.',
        isError: true,
      );

      return false;
    }

    // Read again now and not when the dialog opened: between the two the day
    // can have changed underneath, and with it the subject's concurrency
    // token.
    final held = _whereItHangs(existing);

    if (held == null)
    {
      return false;
    }

    void showError(String message)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    }

    final subject = draft.toJson();

    final success =
        await widget.onEditSubject(held.booking, held.presenceId, subject, showError);

    if (!mounted)
    {
      return success;
    }

    if (success)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Materia modificata con successo!',
        isError: false,
      );
    }

    return success;
  }

  void _showSubjectDeletion({required String mode, required BookingSummaryItem booking})
  {
    final presenceId = _whereItHangs(booking)?.presenceId;

    if (presenceId == null)
    {
      return;
    }

    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmSubjectDeletion',
      builder: (confirmContext) => _ConfirmSubjectDeletion(
        label: _requestLabel(booking, widget.ministrySubjects),
        // The refusal is said rather than swallowed: a delete that the server
        // turned down and nobody mentioned is a delete that looks broken.
        onConfirmed: () => widget.onDeleteSubject(booking, presenceId, (message)
        {
          if (mounted)
          {
            CustomSnackBar.show(context: context, message: message, isError: true);
          }
        }),
        onClosed: _showDetailsDialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final group = widget.group;
    final presence = group.slotsFor(kPresenceMode);
    final online = group.slotsFor(kOnlineMode);

    // Both ways stand side by side, each with its own hours under it; one way
    // alone has nothing to be compared against, so it takes the middle instead
    // of leaving an empty half.
    final bothWays = presence.isNotEmpty && online.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: _showDetailsDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: EntityCardGrid.preferredWidth,
          height: PresenceCard.height,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            // Gold under the pointer, the same mark a module card takes on the
            // dashboard and a person takes in the anagrafiche.
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OverflowTooltipText(
                text: group.student.fullName,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppTheme.trialOcean,
                ),
              ),
              const SizedBox(height: 12),
              // Centred in the room the name leaves rather than hung from the
              // top of it: the card is the same height whatever the day holds,
              // and a day with one stretch on it would otherwise be a line of
              // hours with a hole underneath.
              Expanded(
                child: Center(
                  child: bothWays
                      // Sized to the taller of the two columns, which is what
                      // gives the line between them something to be as tall as.
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _ModeColumn(mode: kPresenceMode, group: group)),
                              Container(
                                width: 1,
                                margin: const EdgeInsets.symmetric(horizontal: 14),
                                color: AppTheme.trialLine,
                              ),
                              Expanded(child: _ModeColumn(mode: kOnlineMode, group: group)),
                            ],
                          ),
                        )
                      : _ModeColumn(
                          mode: presence.isNotEmpty ? kPresenceMode : kOnlineMode,
                          group: group,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// One way of being there, with the hours given for it stacked underneath and
// what was asked for inside them counted at the foot.
class _ModeColumn extends StatelessWidget
{
  // What the card is tall enough to hold.
  static const int maxLines = 3;

  final String mode;
  final PresenceGroup group;

  const _ModeColumn({required this.mode, required this.group});

  @override
  Widget build(BuildContext context)
  {
    final online = mode == kOnlineMode;
    final accent = online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

    final slots = group.slotsFor(mode);
    final requests = group.requestsFor(mode);

    // Past what fits, the last line counts what it is standing in front of
    // rather than letting the column run off the bottom of the card. The window
    // that opens off it has all of them.
    final fits = slots.length <= maxLines;
    final shown = fits ? slots : slots.take(maxLines - 1).toList();
    final hidden = fits ? const <PresenceItem>[] : slots.sublist(maxLines - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              online ? Icons.videocam_outlined : Icons.home_work_outlined,
              size: 15,
              color: AppTheme.trialMutedText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                modeLabel(mode).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        for (final slot in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            // Brought down to the column rather than cut short by it: the hours
            // are eleven characters whatever happens, and a column narrowed by a
            // phone must still show all eleven.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _timeRangeLabel(slot),
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ),
        if (hidden.isNotEmpty)
          Tooltip(
            // The ones left off, in full: the count says how many there are,
            // and the pointer says which.
            message: hidden.map(_timeRangeLabel).join('\n'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hidden.length == 1 ? '+1 orario' : '+${hidden.length} orari',
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 5),
        // What the hours are for. Hours with nothing asked for inside them are a
        // request still to be filled in, so the line says so rather than being
        // left out.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            requests.isEmpty
                ? 'Nessuna materia'
                : (requests.length == 1
                    ? '1 materia · ${formatMinutes(group.minutesAskedFor(mode))}'
                    : '${requests.length} materie · ${formatMinutes(group.minutesAskedFor(mode))}'),
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
      ],
    );
  }
}

// One stretch of hours, in the window that opens off the card.
class _TimeSlotLabel extends StatelessWidget
{
  final String label;

  const _TimeSlotLabel({required this.label});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }
}

class _RequestDetailsDialogContent extends StatefulWidget
{
  /// The day, listened to rather than copied: a subject written from in here
  /// lands on the page, and the page hands it back through this.
  final ValueListenable<PresenceGroup> group;

  final List<MinistrySubjectItem> ministrySubjects;

  /// What the pupil's own programme teaches: what may be chosen, as against
  /// what has to be named.
  final List<MinistrySubjectItem> offeredSubjects;

  final List<PersonItem> teachers;

  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  /// Null where the subject is a new one being written.
  final Future<bool> Function(BookingSummaryItem existing, SubjectRequestDraft draft) onSaveSubject;
  final void Function(String mode, BookingSummaryItem booking) onDeleteSubject;

  const _RequestDetailsDialogContent({
    required this.group,
    required this.ministrySubjects,
    required this.offeredSubjects,
    required this.teachers,
    required this.onEditRequested,
    required this.onDelete,
    required this.onSaveSubject,
    required this.onDeleteSubject,
  });

  @override
  State<_RequestDetailsDialogContent> createState() => _RequestDetailsDialogContentState();
}

class _RequestDetailsDialogContentState extends State<_RequestDetailsDialogContent>
{
  // The stored subjects, as drafts, kept from one build to the next: rebuilt
  // every time, the rows would lose the one that is open under the reader's
  // hands.
  final Map<int, ({DateTime updatedAt, SubjectRequestDraft draft})> _drafts = {};

  PresenceGroup get group => widget.group.value;

  SubjectRequestDraft _draftOf(BookingSummaryItem booking)
  {
    final held = _drafts[booking.id];

    if (held != null && held.updatedAt == booking.updatedAt)
    {
      return held.draft;
    }

    // Everything the row holds, not only what a summary shows: the card that
    // opens off it reads the topic, the notes and the two lists of teachers, and
    // the wizard that edits it would write back whatever it was handed — so a
    // draft built out of half a booking is a booking about to lose the other
    // half.
    final draft = SubjectRequestDraft.fromBooking(
      booking,
      ministrySubjectName: ministrySubjectName(
        widget.ministrySubjects,
        booking.ministrySubjectId,
        fallback: '',
      ),
    );

    _drafts[booking.id] = (updatedAt: booking.updatedAt, draft: draft);

    return draft;
  }

  // Two full buttons rather than two words in a corner: this one throws a whole
  // day's request away, and the answer that does it should not be quieter than
  // the one that walks away from it.
  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmRequestDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        // ANNULLA is already the way out of this one.
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: 'ELIMINA',
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              Navigator.pop(context);
              widget.onDelete();
            },
          ),
        ),
        children: [
          AppDialogPill(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'La prenotazione di '),
                  TextSpan(
                    text: group.student.fullName,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' di ${formatAvailableDayLabel(group.date).toLowerCase()} '
                        'verrà eliminata definitivamente',
                  ),
                ],
              ),
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
  }

  // Small, tracked and muted over the value it names: the same pairing the
  // settings cards use, and the same the top bar uses over a role.
  Widget _buildFieldLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

  // The two ways of being there are two blocks of the same shape, one under the
  // other: what names them is an eyebrow and not a field's label.
  Widget _buildModeLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppEyebrow(text),
    );
  }

  Widget _buildFact(String label, String value)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, first: true),
        Text(
          value,
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialInk,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String text)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // The same window the day is written in, opened over the one that reads it:
  // a subject is asked the same way wherever it is asked.
  void _showSubjectWizard(BuildContext context, String mode, {required BookingSummaryItem existing})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectRequestWizard',
      builder: (context) => SubjectRequestWizard(
        mode: mode,
        draft: _draftOf(existing),
        ministrySubjects: widget.offeredSubjects,
        // Only those still collaborating: a teacher who has stopped will not
        // take the lesson, and offering them is offering a preference nobody
        // will honour.
        teachers: activeCollaborators(widget.teachers),
        isEditing: true,
        // How much time the pupil gives in this mode, and how much the other
        // subjects have already taken: next to the duration it says how much is
        // left. The one being edited does not count among the others — the
        // wizard counts its duration itself, and counting it twice would call it
        // over budget the moment it opened.
        minutesAvailable: group.minutesOfferedIn(mode),
        minutesTakenByOthers: group.minutesAskedFor(mode) - existing.duration,
        // And the same reckoning per discipline, for the ceiling each of them
        // carries on its own: a subject can fit in the pupil's time and still
        // be the third hour of that discipline in one day.
        minutesByDisciplineTakenByOthers:
            group.minutesByDiscipline(mode, skip: existing),
        onSave: (draft) => widget.onSaveSubject(existing, draft),
      ),
    );
  }

  Widget _buildMode(String mode)
  {
    final slots = group.slotsFor(mode);
    final stored = group.requestsFor(mode);

    return AppDialogPill(
      expand: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeLabel(modeLabel(mode), first: true),
          if (slots.isEmpty)
            _buildEmpty('Non richiesto.')
          else ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final slot in slots) _TimeSlotLabel(label: _timeRangeLabel(slot)),
                ],
              ),
            ),
            _buildFieldLabel('Materie richieste'),
            // Without the button that adds one: from here the day is read and
            // what is there is put right. One more subject is an answer to the
            // "what do they want to do" question, which is asked by editing the
            // request and not by looking at it.
            SubjectRequestList(
              requests: [for (final booking in stored) _draftOf(booking)],
              ministrySubjects: widget.ministrySubjects,
              teachers: widget.teachers,
              onEdit: (index) => _showSubjectWizard(context, mode, existing: stored[index]),
              onRemove: (index) => widget.onDeleteSubject(mode, stored[index]),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return ValueListenableBuilder<PresenceGroup>(
      valueListenable: widget.group,
      builder: (context, _, _) => _buildWindow(context),
    );
  }

  Widget _buildWindow(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Richiesta',
      title: group.student.fullName,
      // Who they are, before what they asked for: the request belongs to a
      // pupil, and the face is recognised before the surname is read.
      leading: PersonAvatar(person: group.student, size: PersonAvatar.titleSize),
      // Wider than the windows that ask one column of questions: this one holds
      // the two ways of being there beside each other, and each of them holds
      // rows with a subject, its disciplines and how long on them. At 760 the
      // two columns were 350 apiece and every row was three lines of wrapping.
      maxWidth: 1040,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'ELIMINA',
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => _showDeleteConfirmation(context),
        ),
        primary: AppGradientButton(
          label: 'MODIFICA',
          icon: Icons.edit_outlined,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: widget.onEditRequested,
        ),
      ),
      children: [
        // As wide as the two facts on it and no wider: stretched across a
        // window this wide, a date and a name would be two words adrift in a
        // band of white.
        AppDialogPill(
          // Selection stops at the body: the buttons underneath are not text
          // you would ever want to drag a cursor through.
          child: SelectionArea(
            // Two facts of a few words each: side by side they are one line of
            // the window rather than a column as tall as the two ways of being
            // there standing under it.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFact('Giornata', formatAvailableDayLabel(group.date)),
                const SizedBox(width: 32),
                _buildFact('Richiesta da', group.booker.fullName),
              ],
            ),
          ),
        ),
        // Both ways of being there side by side, each with the hours given for
        // it and what was asked for inside them. They are two halves of one
        // day, and reading them one under the other made the second look like a
        // footnote to the first. Where the window is too narrow to hold two
        // columns, they stack rather than being squeezed.
        LayoutBuilder(
          builder: (context, constraints)
          {
            final pieces = [
              for (final mode in const [kPresenceMode, kOnlineMode]) _buildMode(mode),
            ];

            if (constraints.maxWidth < 720)
            {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pieces.first,
                  const SizedBox(height: _pieceGap),
                  pieces.last,
                ],
              );
            }

            // Each as tall as what it holds, rather than both as tall as the
            // taller: a row that opens into a form makes one side much longer
            // than the other, and stretching the short one to match it is a
            // column of white as tall as a page.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: pieces.first),
                const SizedBox(width: _pieceGap),
                Expanded(child: pieces.last),
              ],
            );
          },
        ),
      ],
    );
  }
}


// Taking one subject off a request: it is one line of a day rather than the day
// itself, but it is still something thrown away for good.
class _ConfirmSubjectDeletion extends StatelessWidget
{
  final String label;
  final Future<bool> Function() onConfirmed;
  final VoidCallback onClosed;

  const _ConfirmSubjectDeletion({
    required this.label,
    required this.onConfirmed,
    required this.onClosed,
  });

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Eliminazione',
      title: 'Confermi?',
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'ANNULLA',
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: ()
          {
            Navigator.pop(context);
            onClosed();
          },
        ),
        primary: AppGradientButton(
          label: 'ELIMINA',
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () async
          {
            Navigator.pop(context);
            await onConfirmed();
            onClosed();
          },
        ),
      ),
      children: [
        AppDialogPill(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'La materia '),
                TextSpan(
                  text: label,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' verrà tolta dalla richiesta.'),
              ],
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ],
    );
  }
}
