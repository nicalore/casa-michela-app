import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/descender_room.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/booking_summary_item.dart';
import '../models/schedulable_booking.dart';
import '../utils/lesson_placement.dart';
import 'calendar_lesson_block.dart';

const double _cardRadius = 16;

const double _modeBarWidth = 4;
const double _modeBarInset = 9;

class _CoverageBar extends StatelessWidget
{
  final int scheduled;
  final int total;

  const _CoverageBar({required this.scheduled, required this.total});

  @override
  Widget build(BuildContext context)
  {
    final fraction = total <= 0 ? 0.0 : (scheduled / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: AppTheme.trialLine)),
            FractionallySizedBox(
              widthFactor: fraction,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppTheme.brandGradient),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherPreferences extends StatelessWidget
{
  final List<String> preferred;
  final List<String> notPreferred;

  const _TeacherPreferences({required this.preferred, required this.notPreferred});

  Widget _line({
    required IconData icon,
    required Color color,
    required String label,
    required List<String> names,
  })
  {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: DescenderRoom(
              child: Text(
                '$label ${names.join(', ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preferred.isNotEmpty)
          _line(
            icon: Icons.star_rounded,
            color: kPreferredTeacherColor,
            label: 'Preferiti:',
            names: preferred,
          ),
        if (notPreferred.isNotEmpty)
          _line(
            icon: Icons.do_not_disturb_on_outlined,
            color: kAvoidedTeacherColor,
            label: 'Da evitare:',
            names: notPreferred,
          ),
      ],
    );
  }
}

enum BookingDragMode
{
  immediate,

  longPress,

  none,
}

class CalendarBookingCard extends StatefulWidget
{
  final SchedulableBooking entry;
  final List<MinistrySubjectItem> ministrySubjects;

  final Map<String, String> teacherNames;

  final bool isGhosted;

  final BookingDragMode dragMode;

  final VoidCallback? onPlanRequested;

  final void Function(CalendarDragPayload? payload)? onDragChanged;

  final ValueListenable<CarriedPlacement>? carriedAt;

  const CalendarBookingCard({
    super.key,
    required this.entry,
    required this.ministrySubjects,
    this.teacherNames = const {},
    this.isGhosted = false,
    this.dragMode = BookingDragMode.immediate,
    this.onPlanRequested,
    this.onDragChanged,
    this.carriedAt,
  });

  @override
  State<CalendarBookingCard> createState() => _CalendarBookingCardState();
}

class _CalendarBookingCardState extends State<CalendarBookingCard>
{
  bool _hover = false;

  BookingSummaryItem get _booking => widget.entry.booking;

  String? get _discipline => dividedDisciplineName(
        widget.ministrySubjects,
        _booking.ministrySubjectId,
        _booking.associationSubjects.map((subject) => subject.id),
      );

  // A subject divided in disciplines: the discipline leads, its subject goes under it.
  String get _title => _discipline ?? bookingTitle(_booking, widget.ministrySubjects);

  String get _status
  {
    final entry = widget.entry;

    if (entry.isFullyCovered)
    {
      return 'Pianificata interamente';
    }

    if (entry.isLocked)
    {
      return 'Calendario pubblicato: riportalo in bozza';
    }

    final parts = <String>[];

    if (entry.remainingMinutes > 0)
    {
      parts.add('${formatMinutes(entry.remainingMinutes)} da pianificare');
    }

    if (entry.uncoveredDisciplineIds.isNotEmpty && entry.scheduledMinutes > 0)
    {
      final missing = entry.uncoveredDisciplineIds.length;
      parts.add(missing == 1 ? '1 disciplina scoperta' : '$missing discipline scoperte');
    }

    if (parts.isEmpty)
    {
      return 'Minuti terminati, ma qualcosa resta scoperto';
    }

    return parts.join(' · ');
  }

  String? get _splitNote
  {
    final entry = widget.entry;

    if (entry.isLocked || entry.isFullyCovered)
    {
      return null;
    }

    if (entry.isFull && entry.uncoveredDisciplineIds.isNotEmpty)
    {
      final names = _uncoveredNames.join(' e ');

      return 'Sono già state pianificate entrambe le ore: trascina $names su una lezione valida '
          'per unirla.';
    }

    if (entry.isFull && entry.remainingMinutes > 0)
    {
      return 'Sono già state pianificate due lezioni. Allungane una per pianificare i minuti rimanenti.';
    }

    if (entry.remainingMinutes > 0 && entry.remainingMinutes < minimumLessonMinutes(_booking.duration))
    {
      return 'Restano ${formatMinutes(entry.remainingMinutes)}. Una lezione dura almeno mezz\'ora: allunga una delle due '
          'già presenti.';
    }

    if (entry.parts.length + 1 >= kMaxLessonParts && entry.uncoveredDisciplineIds.length > 1)
    {
      final names = _uncoveredNames.join(' e ');

      return 'Restano $names: l\'ultima ora disponibile deve averle entrambe.';
    }

    return null;
  }

  List<String> get _uncoveredNames
  {
    final uncovered = widget.entry.uncoveredDisciplineIds;

    return [
      for (final subject in _allDisciplines)
        if (uncovered.contains(subject.id)) subject.name,
    ];
  }

  List<String> _namesOf(List<String> taxCodes)
  {
    return [
      for (final taxCode in taxCodes)
        if (widget.teacherNames[taxCode] != null) widget.teacherNames[taxCode]!,
    ];
  }

  List<AssociationSubjectOption> get _allDisciplines
  {
    return switch (_booking.kind)
    {
      BookingRequestKind.ministrySubject => _booking.associationSubjects,
      BookingRequestKind.associationSubject =>
        _booking.associationSubject == null ? const [] : [_booking.associationSubject!],
      BookingRequestKind.service => const [],
    };
  }

  Set<int> get _wholeCardDisciplines
  {
    final entry = widget.entry;

    return entry.uncoveredDisciplineIds.isEmpty ? entry.requestedDisciplineIds : entry.uncoveredDisciplineIds;
  }

  bool get _canDrag => widget.dragMode != BookingDragMode.none;

  String get _verb => widget.dragMode == BookingDragMode.longPress ? 'Tieni premuto e trascina ' : 'Trascina ';

  Widget _draggableOf({
    required CalendarDragPayload payload,
    required Widget feedback,
    required Widget child,
  })
  {
    void started() => widget.onDragChanged?.call(payload);
    void ended(_) => widget.onDragChanged?.call(null);
    void canceled(_, _) => widget.onDragChanged?.call(null);

    final faded = CalendarLeftBehind(opacity: 0.35, child: child);

    if (widget.dragMode == BookingDragMode.longPress)
    {
      return LongPressDraggable<CalendarDragPayload>(
        data: payload,
        onDragStarted: started,
        onDragEnd: ended,
        onDraggableCanceled: canceled,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: feedback,
        childWhenDragging: faded,
        child: child,
      );
    }

    return Draggable<CalendarDragPayload>(
      data: payload,
      onDragStarted: started,
      onDragEnd: ended,
      onDraggableCanceled: canceled,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback,
      childWhenDragging: faded,
      child: child,
    );
  }

  Widget _wrapDraggable(Widget card)
  {
    final entry = widget.entry;

    if (!_canDrag || !entry.isPlaceable)
    {
      return card;
    }

    final disciplines = _wholeCardDisciplines;

    final payload = BookingDragPayload(
      entry: entry,
      disciplineIds: disciplines,
      minutes: entry.proposedMinutesFor(disciplines),
    );

    return _draggableOf(
      payload: payload,
      feedback: CalendarDragFeedback(
        title: _title,
        mode: entry.presence.mode,
        hours: formatMinutes(payload.minutes),
        carriedAt: widget.carriedAt,
      ),
      child: card,
    );
  }

  Widget _buildTitleRow({required bool canDrag})
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canDrag) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppTooltip(
              message: '${_verb}tutta la materia',
              child: const Icon(Icons.drag_indicator, size: 16, color: AppTheme.trialTurquoise),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DescenderRoom(
                child: Text(
                  _title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ),
              if (_discipline != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: DescenderRoom(
                    child: Text(
                      bookingTitle(_booking, widget.ministrySubjects),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppTheme.trialMutedText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatMinutes(_booking.duration),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialTealDeep,
          ),
        ),
      ],
    );
  }

  VoidCallback? get _onClick => widget.entry.isLocked ? null : widget.onPlanRequested;

  @override
  Widget build(BuildContext context)
  {
    final entry = widget.entry;
    final canDragCard = _canDrag && entry.isPlaceable;
    final note = _splitNote;
    final preferred = _namesOf(_booking.preferredTeacherTaxCodes);
    final notPreferred = _namesOf(_booking.notPreferredTeacherTaxCodes);
    final onClick = _onClick;

    final Widget card = Opacity(
      opacity: widget.isGhosted ? 0.35 : 1,
      child: MouseRegion(
        cursor: onClick == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: onClick,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
                width: 1.5,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  bottom: 12,
                  left: _modeBarInset,
                  width: _modeBarWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: lessonAccent(entry.presence.mode),
                      borderRadius: BorderRadius.circular(_modeBarWidth / 2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(_modeBarInset + _modeBarWidth + 9, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleRow(canDrag: canDragCard),
                      if (entry.scheduledMinutes > 0) ...[
                        const SizedBox(height: 10),
                        _CoverageBar(scheduled: entry.scheduledMinutes, total: _booking.duration),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: entry.isFullyCovered ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                        ),
                      ),
                      if (preferred.isNotEmpty || notPreferred.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _TeacherPreferences(preferred: preferred, notPreferred: notPreferred),
                      ],
                      if (note != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          note,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.modifiedAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return _wrapDraggable(card);
  }
}
