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

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _confirmWidth = 480;

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
  static const double height = 190;

  final PresenceGroup group;

  final List<MinistrySubjectItem> ministrySubjects;

  // Needed to work out which subjects the pupil's study programme allows.
  final List<PersonItem> students;
  final List<StudyProgramItem> studyPrograms;

  final List<PersonItem> teachers;

  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

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

  // A ValueNotifier so the dialog opened off this card sees later updates.
  late final ValueNotifier<PresenceGroup> _group = ValueNotifier(widget.group);

  @override
  void didUpdateWidget(PresenceCard oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // Post-frame: notifying the overlay dialog mid-build is an error.
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
          // Reuses the card state, not the dialog context about to become invalid.
          widget.onEditRequested(_showDetailsDialog);
        },
        onDelete: widget.onDelete,
        teachers: widget.teachers,
        onSaveSubject: _writeSubject,
        onDeleteSubject: (mode, booking)
        {
          Navigator.of(dialogContext).pop();
          _showSubjectDeletion(mode: mode, booking: booking);
        },
      ),
    );
  }

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

  // Returns the row as the page has it NOW, not as the dialog captured it:
  // a stale updated_at token would make the server answer 409.
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

  // The endpoints write a booking whole: any field left out of the payload is
  // emptied, not preserved.
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
              Expanded(
                child: Center(
                  child: bothWays
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

class _ModeColumn extends StatelessWidget
{
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
  final ValueListenable<PresenceGroup> group;

  final List<MinistrySubjectItem> ministrySubjects;

  final List<MinistrySubjectItem> offeredSubjects;

  final List<PersonItem> teachers;

  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

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
  // Cached across builds so an open row is not rebuilt out from under the user.
  final Map<int, ({DateTime updatedAt, SubjectRequestDraft draft})> _drafts = {};

  PresenceGroup get group => widget.group.value;

  SubjectRequestDraft _draftOf(BookingSummaryItem booking)
  {
    final held = _drafts[booking.id];

    if (held != null && held.updatedAt == booking.updatedAt)
    {
      return held.draft;
    }

    // Built from the whole booking: the wizard writes back whatever it was
    // handed, so a partial draft would wipe the missing fields.
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

  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmRequestDeletion',
      builder: (confirmContext) => AppDialogStack(
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

  Widget _buildFieldLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

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

  void _showSubjectWizard(BuildContext context, String mode, {required BookingSummaryItem existing})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectRequestWizard',
      builder: (context) => SubjectRequestWizard(
        mode: mode,
        draft: _draftOf(existing),
        ministrySubjects: widget.offeredSubjects,
        teachers: activeCollaborators(widget.teachers),
        isEditing: true,
        // The edited booking's own duration is excluded: the wizard counts it
        // itself, and counting it twice would read as over budget on open.
        minutesAvailable: group.minutesOfferedIn(mode),
        minutesTakenByOthers: group.minutesAskedFor(mode) - existing.duration,
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
      leading: PersonAvatar(person: group.student, size: PersonAvatar.titleSize),
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
        AppDialogPill(
          child: SelectionArea(
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
