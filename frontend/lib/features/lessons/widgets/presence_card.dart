import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../core/utils/word_lists.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/opening_day_item.dart';
import '../../association/models/study_program_item.dart';
import '../../bookings/utils/booking_strings.dart' show addModeLabel, deleteModeBooking, kLessonEdited, kLessonIncomplete, lastLessonNote;
import '../../people/models/person_item.dart';
import '../utils/study_program_lookup.dart';
import '../models/band_offer.dart';
import '../models/booking_summary_item.dart';
import '../models/presence_group.dart';
import '../models/presence_item.dart';
import '../models/subject_request.dart';
import 'band_note_parts.dart';
import 'calendar_lesson_block.dart' show lessonModeIcon;
import 'person_avatar.dart';
import 'subject_request_tile.dart';
import 'subject_request_wizard.dart';
import '../utils/booking_window.dart';
import '../utils/booking_wizard_strings.dart' show bandNoteAction, kDeleteBandNote;
import '../utils/opening_window.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _confirmWidth = 480;

const double _pieceGap = 20;

const double _modeHeadingHeight = 36;
const double _addModeHeight = 32;

String _timeRangeLabel(PresenceItem presence)
{
  return formatTimeRange(presence.startTime, presence.endTime);
}

// A wizard over the details for one mode: all its hours, [subjectsOf]'s new subjects, or with [freeBands] the free bands.
typedef RequestModeEditor = void Function(String mode, {TimeBucket? subjectsOf, bool freeBands});

class PresenceCard extends StatefulWidget
{
  static const double height = 190;

  static const double denseHeight = 136;

  final PresenceGroup group;

  // The day as the page has it now: the details opened off this card follow it, wherever the card goes.
  final ValueListenable<PresenceGroup> follow;

  final List<MinistrySubjectItem> ministrySubjects;

  // Needed to work out which subjects the pupil's study programme allows.
  final List<PersonItem> students;
  final List<StudyProgramItem> studyPrograms;

  final List<PersonItem> teachers;

  // For the modes the day can still take.
  final List<OpeningDayItem> openingDays;

  final RequestModeEditor onEditMode;
  final VoidCallback onDelete;
  final void Function(String mode, {TimeBucket? band}) onDeleteMode;
  final void Function(TimeBucket band) onEditNote;
  final void Function(TimeBucket band) onDeleteNote;

  final Future<bool> Function(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError) onEditSubject;
  final Future<bool> Function(BookingSummaryItem booking, int presenceId, Function(String) onError) onDeleteSubject;

  // A day that can no longer change: the details open without their actions.
  final bool readOnly;

  // Subjects whose lesson has begun: shown without their actions.
  final Set<int> begunBookingIds;

  const PresenceCard({
    super.key,
    required this.group,
    required this.follow,
    required this.ministrySubjects,
    required this.students,
    required this.studyPrograms,
    required this.teachers,
    required this.openingDays,
    required this.onEditMode,
    required this.onDelete,
    required this.onDeleteMode,
    required this.onEditNote,
    required this.onDeleteNote,
    required this.onEditSubject,
    required this.onDeleteSubject,
    this.readOnly = false,
    this.begunBookingIds = const {},
  });

  @override
  State<PresenceCard> createState() => _PresenceCardState();
}

class _PresenceCardState extends State<PresenceCard>
{
  bool _isHovering = false;

  void _showDetailsDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RequestDetails',
      builder: (dialogContext) => _RequestDetailsDialogContent(
        group: widget.follow,
        ministrySubjects: widget.ministrySubjects,
        offeredSubjects: offeredSubjects,
        teachers: widget.teachers,
        openingDays: widget.openingDays,
        studentStudyProgramId: _studentStudyProgramId,
        studentGender: _student?.gender,
        onEditMode: widget.onEditMode,
        onDelete: widget.onDelete,
        onDeleteMode: widget.onDeleteMode,
        onEditNote: widget.onEditNote,
        onDeleteNote: widget.onDeleteNote,
        onEditSubject: widget.onEditSubject,
        onDeleteSubject: widget.onDeleteSubject,
        readOnly: widget.readOnly,
        begunBookingIds: widget.begunBookingIds,
      ),
    );
  }

  // The notes of the day's bands, in clock order.
  List<(TimeBucket, String)> get _notes
  {
    final PresenceGroup group = widget.group;

    return [
      for (final band in TimeBucket.values)
        if (bandNoteOf(group.slots.where((slot) => bucketFor(slot.startTime) == band)) case final String note)
          (band, note),
    ];
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

  @override
  Widget build(BuildContext context)
  {
    final List<(TimeBucket, String)> notes = _notes;
    final Widget card = _buildCard(context, marked: notes.isNotEmpty);

    if (notes.isEmpty)
    {
      return card;
    }

    final bool dense = AppBreakpoints.of(context).isDense;

    return Stack(
      children: [
        card,
        Positioned(
          top: dense ? 11 : 16,
          right: dense ? 13 : 18,
          child: AppTooltip(
            richMessage: notes.length == 1
                ? bandNoteTip(notes.single.$2)
                : bandNotesTip([for (final (band, note) in notes) '${bandLabel(band)}: $note']),
            child: Icon(kBandNoteIcon, size: dense ? 17 : 20, color: AppTheme.trialOceanText),
          ),
        ),
      ],
    );
  }

  // [marked]: the note's sign sits in the corner, so the name keeps clear of it on both sides.
  Widget _buildCard(BuildContext context, {required bool marked})
  {
    final group = widget.group;
    final presence = group.slotsFor(kPresenceMode);
    final online = group.slotsFor(kOnlineMode);

    final bothWays = presence.isNotEmpty && online.isNotEmpty;
    final bool dense = AppBreakpoints.of(context).isDense;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: _showDetailsDialog,
        child: SizedBox(
          width: EntityCardGrid.preferredWidth,
          height: dense ? PresenceCard.denseHeight : PresenceCard.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(dense ? 20 : 30),
              border: Border.all(
                color: _isHovering
                    ? AppTheme.trialGold
                    : AppTheme.trialGold.withValues(alpha: 0),
                width: 2,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Padding(
              padding: dense ? const EdgeInsets.fromLTRB(14, 12, 14, 12) : const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: marked ? (dense ? 12 : 18) : 0),
                    child: OverflowTooltipText(
                      text: group.student.fullName,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: dense ? 15 : 19,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: AppTheme.trialOceanText,
                      ),
                    ),
                  ),
                  SizedBox(height: dense ? 8 : 12),
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
                                      Expanded(
                                        child: _ModeColumn(mode: kPresenceMode, group: group, room: room, dense: dense),
                                      ),
                                      Container(
                                        width: 1,
                                        margin: const EdgeInsets.symmetric(horizontal: 14),
                                        color: AppTheme.trialLine,
                                      ),
                                      Expanded(
                                        child: _ModeColumn(mode: kOnlineMode, group: group, room: room, dense: dense),
                                      ),
                                    ],
                                  ),
                                )
                              : _ModeColumn(
                                  mode: presence.isNotEmpty ? kPresenceMode : kOnlineMode,
                                  group: group,
                                  room: room,
                                  dense: dense,
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeColumn extends StatelessWidget
{
  static const double _labelGap = 7;
  // The text's own line height spaces the hours: a wider gap fits only two.
  static const double _lineGap = 1;
  static const double _totalGap = 5;

  final String mode;
  final PresenceGroup group;

  final double room;

  final bool dense;

  const _ModeColumn({required this.mode, required this.group, required this.room, this.dense = false});

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: dense ? 9.5 : 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppTheme.trialMutedText,
      );

  TextStyle get _hoursStyle => GoogleFonts.plusJakartaSans(
        fontSize: dense ? 14 : 15,
        fontWeight: FontWeight.w700,
        color: mode == kOnlineMode ? AppTheme.modifiedAccent : AppTheme.presenceAccentText,
      );

  TextStyle get _moreStyle => GoogleFonts.plusJakartaSans(
        fontSize: dense ? 13 : 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialMutedText,
      );

  TextStyle get _totalStyle => GoogleFonts.plusJakartaSans(
        fontSize: dense ? 11.5 : 12,
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
              lessonModeIcon(mode),
              size: dense ? 14 : 15,
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
          AppTooltip(
            message: hidden.map(_timeRangeLabel).join('\n'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: _lineGap),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hidden.length == 1 ? tr('+1 orario', '+1 time') : tr('+${hidden.length} orari', '+${hidden.length} times'),
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
                ? tr('Nessuna materia', 'No subjects')
                : (requests.length == 1
                    ? '${tr('1 prenotazione', '1 booking')}$kFigureSeparator${formatMinutes(group.minutesAskedFor(mode))}'
                    : '${tr('${requests.length} prenotazioni', '${requests.length} bookings')}$kFigureSeparator${formatMinutes(group.minutesAskedFor(mode))}'),
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
        color: online ? AppTheme.modifiedAccentSurface : AppTheme.presenceBadge,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: online ? AppTheme.modifiedAccent : AppTheme.presenceAccentText,
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

  final List<OpeningDayItem> openingDays;

  final RequestModeEditor onEditMode;
  final VoidCallback onDelete;
  final void Function(String mode, {TimeBucket? band}) onDeleteMode;
  final void Function(TimeBucket band) onEditNote;
  final void Function(TimeBucket band) onDeleteNote;

  final Future<bool> Function(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError) onEditSubject;
  final Future<bool> Function(BookingSummaryItem booking, int presenceId, Function(String) onError) onDeleteSubject;

  final bool readOnly;

  final Set<int> begunBookingIds;

  const _RequestDetailsDialogContent({
    required this.group,
    required this.ministrySubjects,
    required this.offeredSubjects,
    required this.teachers,
    required this.openingDays,
    required this.studentStudyProgramId,
    required this.studentGender,
    required this.onEditMode,
    required this.onDelete,
    required this.onDeleteMode,
    required this.onEditNote,
    required this.onDeleteNote,
    required this.onEditSubject,
    required this.onDeleteSubject,
    this.readOnly = false,
    this.begunBookingIds = const {},
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

    // From the whole booking: the wizard writes back all it gets, so a partial draft wipes fields.
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

  void _showError(String message)
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message, isError: true);
    }
  }

  // The row as the page has it now, not as the window captured it: a stale updated_at gets a 409.
  ({int presenceId, String mode, BookingSummaryItem booking})? _whereItHangs(BookingSummaryItem booking)
  {
    for (final slot in group.slots)
    {
      for (final row in slot.bookings)
      {
        if (row.id == booking.id)
        {
          return (presenceId: slot.id, mode: slot.mode, booking: row);
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
      _showError(kLessonIncomplete);

      return false;
    }

    final held = _whereItHangs(existing);

    if (held == null)
    {
      return false;
    }

    final success = await widget.onEditSubject(held.booking, held.presenceId, draft.toJson(), _showError);

    if (success && mounted)
    {
      CustomSnackBar.show(context: context, message: kLessonEdited, isError: false);
    }

    return success;
  }

  void _showSubjectDeletion(BookingSummaryItem booking)
  {
    final held = _whereItHangs(booking);

    if (held == null)
    {
      return;
    }

    final String mode = held.mode;
    final TimeBucket? band = _bandOf(booking);

    // The last lesson of a band takes the band's hours with it.
    final bool last = group.requestsFor(mode, band: band).length == 1;
    final bool emptiesDay = last && group.slots.every((slot) => slot.mode == mode && bucketFor(slot.startTime) == band);

    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmSubjectDeletion',
      builder: (confirmContext) => _ConfirmSubjectDeletion(
        label: bookingTitle(booking, widget.ministrySubjects),
        discipline: bookingDisciplineLabel(booking, widget.ministrySubjects),
        note: last ? lastLessonNote(mode, band: band) : '',
        onConfirmed: ()
        {
          if (emptiesDay)
          {
            Navigator.pop(context);
            widget.onDelete();
          }
          else if (last)
          {
            widget.onDeleteMode(mode, band: band);
          }
          else
          {
            widget.onDeleteSubject(booking, held.presenceId, _showError);
          }
        },
      ),
    );
  }

  static String _otherMode(String mode) => mode == kPresenceMode ? kOnlineMode : kPresenceMode;

  bool _isBooked(String mode) => group.slotsFor(mode).isNotEmpty;

  // A mode not asked yet goes in a band the association opens for it and the other mode leaves free.
  bool _canAdd(String mode)
  {
    final Set<TimeBucket?> taken = {for (final slot in group.slots) bucketFor(slot.startTime)};

    return TimeBucket.values.any((band) =>
        !taken.contains(band) && openingWindowFor(widget.openingDays, group.date, mode, band) != null);
  }

  // [mode] null: the whole day.
  void _showDeleteConfirmation(BuildContext context, {String? mode})
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmRequestDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: tr('Eliminazione', 'Deletion'),
        title: tr('Confermi?', 'Confirm?'),
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: tr('ANNULLA', 'CANCEL'),
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialVioletText,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: tr('ELIMINA', 'DELETE'),
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDangerText,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);

              if (mode == null)
              {
                Navigator.pop(context);
                widget.onDelete();
              }
              else
              {
                widget.onDeleteMode(mode);
              }
            },
          ),
        ),
        children: [
          AppDialogPill(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: tr(
                      mode == null
                          ? 'La prenotazione di '
                          : 'La prenotazione ${mode == kOnlineMode ? kOnScreen : kInBuilding} di ',
                      '',
                    ),
                  ),
                  TextSpan(
                    text: group.student.fullName,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: tr(
                      ' di ${formatAvailableDayInSentence(group.date)} '
                          'verrà eliminata definitivamente',
                      "'s ${mode == null ? '' : '${mode == kOnlineMode ? 'online' : 'in-person'} '}booking on "
                          '${formatAvailableDayInSentence(group.date)} will be permanently deleted',
                    ),
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

  Widget _buildModeAction(IconData icon, Color color, String tooltip, VoidCallback onTap)
  {
    return AppTooltip(
      message: tooltip,
      child: FadeHoverIconButton(icon: icon, color: color, hoverColor: AppTheme.trialGoldSurface, onTap: onTap),
    );
  }

  List<Widget> _buildModeActions(BuildContext context, String mode)
  {
    if (widget.readOnly)
    {
      return const [];
    }

    if (!_isBooked(mode))
    {
      return [
        if (_canAdd(mode))
          AppGradientButton(
            label: addModeLabel(mode),
            icon: Icons.add_rounded,
            height: _addModeHeight,
            fontSize: 11,
            radius: _addModeHeight / 2,
            horizontalPadding: 16,
            onPressed: () => widget.onEditMode(mode, freeBands: true),
          ),
      ];
    }

    return [
      _buildModeAction(Icons.schedule_rounded, AppTheme.trialTealDeepText, tr('Modifica gli orari', 'Edit the times'), () => widget.onEditMode(mode)),
      // With one mode alone it would do what the footer's ELIMINA does.
      if (_isBooked(_otherMode(mode)))
        _buildModeAction(
          Icons.delete_outline_rounded,
          AppTheme.trialDangerText,
          deleteModeBooking(mode),
          () => _showDeleteConfirmation(context, mode: mode),
        ),
    ];
  }

  // As tall with or without its buttons, so the two pieces start alike.
  Widget _buildModeHeading(BuildContext context, String mode)
  {
    return SizedBox(
      height: _modeHeadingHeight,
      child: Row(
        children: [
          Expanded(child: AppEyebrow(modeLabel(mode))),
          ..._buildModeActions(context, mode),
        ],
      ),
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
        onSave: (draft) => _writeSubject(existing, draft),
      ),
    );
  }

  List<Widget> _buildBand(String mode, TimeBucket band, {required bool first})
  {
    final slots = group.slotsFor(mode, band: band);
    final stored = group.requestsFor(mode, band: band);

    // Hours all over (their end come): the band's subjects stay as they are, as the server holds them.
    final DateTime now = romeNow();
    final bool locked = widget.readOnly || slots.every((slot) => hasBegun(group.date, slot.endTime, now));
    final String? note = bandNoteOf(slots);

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
            AppTooltip(
              message: tr('Prenotazioni chiuse', 'Bookings closed'),
              child: Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.trialMutedText),
            ),
          ],
          if (!locked && note == null) ...[
            const Spacer(),
            _buildModeAction(kBandNoteIcon, AppTheme.trialTealDeepText, bandNoteAction(null), () => widget.onEditNote(band)),
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
      if (note != null) ...[
        const SizedBox(height: 16),
        BandNoteWell(
          note: note,
          trailing: locked
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeAction(Icons.edit_outlined, AppTheme.trialTealDeepText, bandNoteAction(note), () => widget.onEditNote(band)),
                    _buildModeAction(Icons.delete_outline_rounded, AppTheme.trialDangerText, kDeleteBandNote, () => widget.onDeleteNote(band)),
                  ],
                ),
        ),
      ],
      _buildFieldLabel(tr('Discipline richieste', 'Disciplines requested')),
      SubjectRequestList(
        requests: [for (final booking in stored) _draftOf(booking)],
        ministrySubjects: widget.ministrySubjects,
        teachers: widget.teachers,
        studentGender: widget.studentGender,
        onEdit: locked ? null : (index) => _showSubjectWizard(context, mode, existing: stored[index]),
        onRemove: locked ? null : (index) => _showSubjectDeletion(stored[index]),
        isLocked: (index) => widget.begunBookingIds.contains(stored[index].id),
        onAdd: locked ? null : () => widget.onEditMode(mode, subjectsOf: band),
      ),
    ];
  }

  Widget _buildMode(BuildContext context, String mode)
  {
    final bands = group.bandsFor(mode);

    return AppDialogPill(
      expand: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeHeading(context, mode),
          if (bands.isEmpty)
            _buildEmpty(tr('Non richiesto.', 'Not requested.'))
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
      eyebrow: tr('Richiesta', 'Request'),
      title: group.student.fullName,
      leading: PersonAvatar(person: group.student, size: PersonAvatar.titleSize),
      maxWidth: 1040,
      footer: widget.readOnly ? null : AppDialogFooter.single(
        AppGradientButton(
          label: tr('ELIMINA', 'DELETE'),
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDangerText,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => _showDeleteConfirmation(context),
        ),
      ),
      children: [
        AppDialogPill(
          child: SelectionArea(
            // The second fact goes under the first when the window is too narrow for both.
            child: Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _buildFact(tr('Giornata', 'Day'), formatAvailableDayLabel(group.date)),
                _buildFact(tr('Richiesta da', 'Requested by'), group.booker.fullName),
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints)
          {
            final pieces = [
              for (final mode in const [kPresenceMode, kOnlineMode]) _buildMode(context, mode),
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

  // "Materia - Disciplina" when the discipline is named.
  final String? discipline;

  // What else goes with it, after the sentence.
  final String note;

  final VoidCallback onConfirmed;

  const _ConfirmSubjectDeletion({
    required this.label,
    required this.discipline,
    required this.note,
    required this.onConfirmed,
  });

  String get _ending => discipline == null
      ? tr(' verrà tolta dalla richiesta.', ' will be taken off the request.')
      : tr(' verrà rimossa dalla richiesta.', ' will be removed from the request.');

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: tr('Eliminazione', 'Deletion'),
      title: tr('Confermi?', 'Confirm?'),
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: tr('ANNULLA', 'CANCEL'),
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialVioletText,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(context),
        ),
        primary: AppGradientButton(
          label: tr('ELIMINA', 'DELETE'),
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDangerText,
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
                if (discipline == null) TextSpan(text: tr('La materia ', 'The subject ')),
                TextSpan(
                  text: discipline ?? label,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '$_ending$note'),
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
