import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
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
import '../models/band_offer.dart';
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

class PresenceCard extends StatefulWidget
{
  static const double height = 190;

  final PresenceGroup group;

  final List<MinistrySubjectItem> ministrySubjects;

  // Needed to work out which subjects the pupil's study programme allows.
  final List<PersonItem> students;
  final List<StudyProgramItem> studyPrograms;

  final List<PersonItem> teachers;

  // Opens the wizard over the details; [onSaved] closes them once the edit is saved.
  final void Function(VoidCallback onSaved) onEditRequested;
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
        // Over the details, which stay put: closing and reopening them replayed their entrance.
        onEditRequested: () => widget.onEditRequested(() => Navigator.of(dialogContext).pop()),
        onDelete: widget.onDelete,
        teachers: widget.teachers,
        studentStudyProgramId: _studentStudyProgramId,
        studentGender: _student?.gender,
        onSaveSubject: _writeSubject,
        onDeleteSubject: (mode, booking) => _showSubjectDeletion(dialogContext, booking: booking),
      ),
    );
  }

  PersonItem? get _student
  {
    for (final student in widget.students)
    {
      if (student.fiscalCode == widget.group.studentTaxCode)
      {
        return student;
      }
    }

    return null;
  }

  List<MinistrySubjectItem> get offeredSubjects
  {
    final student = _student;

    if (student == null)
    {
      return const [];
    }

    final allowed = allowedMinistrySubjectIds(student, widget.studyPrograms);

    return widget.ministrySubjects.where((subject) => allowed.contains(subject.id)).toList();
  }

  int? get _studentStudyProgramId
  {
    final student = _student;

    return student == null ? null : currentStudyProgramId(student);
  }

  // The row as the page has it now, not as the dialog captured it: a stale updated_at gets a 409.
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

  // The endpoints write a booking whole: omitted fields are emptied, not kept.
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

  void _showSubjectDeletion(BuildContext dialogContext, {required BookingSummaryItem booking})
  {
    final presenceId = _whereItHangs(booking)?.presenceId;

    if (presenceId == null)
    {
      return;
    }

    showBlurredDialog<void>(
      context: dialogContext,
      barrierLabel: 'ConfirmSubjectDeletion',
      builder: (confirmContext) => _ConfirmSubjectDeletion(
        label: bookingTitle(booking, widget.ministrySubjects),
        onConfirmed: () => widget.onDeleteSubject(booking, presenceId, (message)
        {
          if (mounted)
          {
            CustomSnackBar.show(context: context, message: message, isError: true);
          }
        }),
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
                child: LayoutBuilder(
                  builder: (context, constraints)
                  {
                    final double room = constraints.maxHeight;

                    return Center(
                      child: bothWays
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _ModeColumn(mode: kPresenceMode, group: group, room: room)),
                                  Container(
                                    width: 1,
                                    margin: const EdgeInsets.symmetric(horizontal: 14),
                                    color: AppTheme.trialLine,
                                  ),
                                  Expanded(child: _ModeColumn(mode: kOnlineMode, group: group, room: room)),
                                ],
                              ),
                            )
                          : _ModeColumn(
                              mode: presence.isNotEmpty ? kPresenceMode : kOnlineMode,
                              group: group,
                              room: room,
                            ),
                    );
                  },
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
  static const double _labelGap = 7;
  // The text's own line height spaces the hours: a wider gap fitted only two.
  static const double _lineGap = 1;
  static const double _totalGap = 5;

  final String mode;
  final PresenceGroup group;

  final double room;

  const _ModeColumn({required this.mode, required this.group, required this.room});

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppTheme.trialMutedText,
      );

  TextStyle get _hoursStyle => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: mode == kOnlineMode ? AppTheme.modifiedAccent : AppTheme.trialTealDeep,
      );

  TextStyle get _moreStyle => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialMutedText,
      );

  TextStyle get _totalStyle => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialMutedText,
      );

  // As Text lays it out: with the ambient style and the reader's text size.
  static double _lineHeight(BuildContext context, TextStyle style)
  {
    final painter = TextPainter(
      text: TextSpan(text: '00:00–00:00', style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double height = painter.height;
    painter.dispose();

    return height;
  }

  // All hours, or one line fewer than fit so the last says how many are left.
  int _shownCount(BuildContext context, int count)
  {
    final double header = math.max(15, _lineHeight(context, _labelStyle));
    final double fixed = header + _labelGap + _totalGap + _lineHeight(context, _totalStyle);
    final double line = _lineHeight(context, _hoursStyle) + _lineGap;
    final double more = _lineHeight(context, _moreStyle) + _lineGap;

    // A hair of slack for rounding, so a column that just fits is not cut short.
    final double free = room - fixed + 0.5;

    if (count * line <= free)
    {
      return count;
    }

    return ((free - more) / line).floor().clamp(0, count - 1);
  }

  @override
  Widget build(BuildContext context)
  {
    final online = mode == kOnlineMode;

    final slots = group.slotsFor(mode);
    final requests = group.requestsFor(mode);

    final int shownCount = _shownCount(context, slots.length);
    final shown = slots.take(shownCount).toList();
    final hidden = slots.skip(shownCount).toList();

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
                style: _labelStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: _labelGap),
        for (final slot in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: _lineGap),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_timeRangeLabel(slot), maxLines: 1, style: _hoursStyle),
            ),
          ),
        if (hidden.isNotEmpty)
          Tooltip(
            message: hidden.map(_timeRangeLabel).join('\n'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: _lineGap),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hidden.length == 1 ? '+1 orario' : '+${hidden.length} orari',
                  maxLines: 1,
                  style: _moreStyle,
                ),
              ),
            ),
          ),
        const SizedBox(height: _totalGap),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            requests.isEmpty
                ? 'Nessuna materia'
                : (requests.length == 1
                    ? '1 materia · ${formatMinutes(group.minutesAskedFor(mode))}'
                    : '${requests.length} materie · ${formatMinutes(group.minutesAskedFor(mode))}'),
            maxLines: 1,
            style: _totalStyle,
          ),
        ),
      ],
    );
  }
}

class _TimeSlotLabel extends StatelessWidget
{
  final String label;
  final bool online;

  const _TimeSlotLabel({required this.label, required this.online});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: online ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep,
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

  final int? studentStudyProgramId;

  // For gender agreement in the subject wizard's copy.
  final String? studentGender;

  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  final Future<bool> Function(BookingSummaryItem existing, SubjectRequestDraft draft) onSaveSubject;
  final void Function(String mode, BookingSummaryItem booking) onDeleteSubject;

  const _RequestDetailsDialogContent({
    required this.group,
    required this.ministrySubjects,
    required this.offeredSubjects,
    required this.teachers,
    required this.studentStudyProgramId,
    required this.studentGender,
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

  TimeBucket? _bandOf(BookingSummaryItem booking)
  {
    for (final slot in group.slots)
    {
      if (slot.bookings.any((held) => held.id == booking.id))
      {
        return bucketFor(slot.startTime);
      }
    }

    return null;
  }

  SubjectRequestDraft _draftOf(BookingSummaryItem booking)
  {
    final held = _drafts[booking.id];

    if (held != null && held.updatedAt == booking.updatedAt)
    {
      return held.draft;
    }

    // From the whole booking: the wizard writes back all it was handed, so a partial draft wipes fields.
    final draft = SubjectRequestDraft.fromBooking(
      booking,
      ministrySubjectName: ministrySubjectName(
        widget.ministrySubjects,
        booking.ministrySubjectId,
        fallback: '',
      ),
      band: _bandOf(booking),
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
    final teachers = askableTeachers(activeCollaborators(widget.teachers), group.notPreferredTeacherTaxCodes);
    final offered = {for (final teacher in teachers) teacher.fiscalCode};

    // The picker shows only these, so drop the rest from the draft or they could never be removed.
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectRequestWizard',
      builder: (context) => SubjectRequestWizard(
        mode: mode,
        draft: _draftOf(existing)..preferredTeacherTaxCodes.retainWhere(offered.contains),
        ministrySubjects: widget.offeredSubjects,
        teachers: teachers,
        studentStudyProgramId: widget.studentStudyProgramId,
        studentName: group.student.firstName,
        studentGender: widget.studentGender,
        isEditing: true,
        // The edited booking's own duration is excluded: the wizard counts it itself.
        // Its own band only: an administrator never moves a booked subject.
        bands: [
          for (final offer in groupBandOffers(group, mode, skip: existing))
            if (offer.band == _bandOf(existing)) offer,
        ],
        minutesByDisciplineTakenByOthers:
            group.minutesByDiscipline(mode, band: _bandOf(existing), skip: existing),
        onSave: (draft) => widget.onSaveSubject(existing, draft),
      ),
    );
  }

  List<Widget> _buildBand(String mode, TimeBucket band, {required bool first})
  {
    final slots = group.slotsFor(mode, band: band);
    final stored = group.requestsFor(mode, band: band);

    return [
      if (!first)
        Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 18), color: AppTheme.trialLine),
      Row(
        children: [
          Text(
            bandLabel(band).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.trialMutedText,
            ),
          ),
          if (haveBookingsClosed(group.date, band, romeNow())) ...[
            const SizedBox(width: 6),
            const Tooltip(
              message: 'Prenotazioni chiuse',
              child: Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.trialMutedText),
            ),
          ],
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final slot in slots)
            _TimeSlotLabel(label: _timeRangeLabel(slot), online: mode == kOnlineMode),
        ],
      ),
      _buildFieldLabel('Materie richieste'),
      SubjectRequestList(
        requests: [for (final booking in stored) _draftOf(booking)],
        ministrySubjects: widget.ministrySubjects,
        teachers: widget.teachers,
        onEdit: (index) => _showSubjectWizard(context, mode, existing: stored[index]),
        onRemove: (index) => widget.onDeleteSubject(mode, stored[index]),
      ),
    ];
  }

  Widget _buildMode(String mode)
  {
    final bands = group.bandsFor(mode);

    return AppDialogPill(
      expand: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeLabel(modeLabel(mode), first: true),
          if (bands.isEmpty)
            _buildEmpty('Non richiesto.')
          else
            for (final (i, band) in bands.indexed) ..._buildBand(mode, band, first: i == 0),
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

  const _ConfirmSubjectDeletion({
    required this.label,
    required this.onConfirmed,
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
          onPressed: () => Navigator.pop(context),
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
            Navigator.pop(context);
            onConfirmed();
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
