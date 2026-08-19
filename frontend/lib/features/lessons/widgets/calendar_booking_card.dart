import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/booking_summary_item.dart';
import '../models/schedulable_booking.dart';
import '../utils/lesson_placement.dart';
import 'calendar_lesson_block.dart';

// The card is narrow — the panel it stands in is three hundred wide — so
// everything on it is written small and nothing is said twice.
const double _cardRadius = 16;

// The bar down the left side, painted in the colour of the mode: the same teal
// and the same amber the blocks on the track are drawn in, and the same shape it
// wears there — a rounded bar standing inside the card.
//
// Inside and not along the edge: the card outlines itself in gold under the
// pointer, and a coloured stripe welded to that edge made the two read as one
// thick two-coloured border. The inset is what keeps them two things.
const double _modeBarWidth = 4;
const double _modeBarInset = 9;

// Past this a discipline's name is cut short rather than pushing the card out of
// the panel. Two short names still sit side by side under it.
const double _disciplineMaxWidth = 232;

// One discipline of a request, as a small card of its own.
//
// A card and not a tag: where the request can still be split in two, this is
// the thing that gets picked up to take one discipline out and leave the rest
// behind, and something meant to be grabbed should look like it has edges.
//
// Lit means still to be placed; ticked and quiet means a lesson already
// carries it. Both are shown: a card that dropped the covered ones would keep
// changing shape as the day is composed, and the reason a request is finished
// is worth reading.
class DisciplineCard extends StatefulWidget
{
  final String label;
  final bool isCovered;

  // Off where the discipline cannot be taken out on its own — the last part
  // available has to carry everything still uncovered — with the reason written
  // under the card. Shown all the same: one that disappears is a question
  // nobody can ask about, while a quiet one is an answer with a reason.
  final bool isDraggable;

  final String? tooltip;

  const DisciplineCard({
    super.key,
    required this.label,
    required this.isCovered,
    this.isDraggable = false,
    this.tooltip,
  });

  @override
  State<DisciplineCard> createState() => _DisciplineCardState();
}

class _DisciplineCardState extends State<DisciplineCard>
{
  bool _hover = false;

  // Turquoise where it can be lifted, grey where it is only being reported. The
  // handle says it too, but the handle is small and the edge of the card is what
  // is seen first from a scan down the panel.
  //
  // Under the pointer the same turquoise, only firmer — and not the gold the
  // rest of the app answers with. Here the colour is not decoration: it is what
  // says this one can be taken out on its own, and swapping the hue away at the
  // moment somebody reaches for it takes the sentence back mid-gesture.
  Color get _borderColor
  {
    if (widget.isDraggable)
    {
      return AppTheme.trialTurquoise.withValues(alpha: _hover ? 1 : 0.6);
    }

    return widget.isCovered ? AppTheme.closedLine : AppTheme.trialLine;
  }

  Color get _surfaceColor
  {
    if (widget.isCovered)
    {
      return AppTheme.closedSurface;
    }

    return _hover && widget.isDraggable ? AppTheme.todaySurface : Colors.white;
  }

  @override
  Widget build(BuildContext context)
  {
    final covered = widget.isCovered;
    final draggable = widget.isDraggable;

    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(maxWidth: _disciplineMaxWidth),
      // Tighter on the left where the handle takes that side, so the two shapes
      // are the same height whether or not this one can be lifted.
      padding: EdgeInsets.fromLTRB(draggable ? 5 : 9, 6, 9, 6),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (covered) ...[
            const Icon(Icons.check_rounded, size: 13, color: AppTheme.trialMutedText),
            const SizedBox(width: 5),
          ]
          else if (draggable) ...[
            const Icon(Icons.drag_indicator, size: 14, color: AppTheme.trialTurquoise),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: covered ? AppTheme.trialMutedText : AppTheme.trialTealDeep,
              ),
            ),
          ),
        ],
      ),
    );

    final tooltip = widget.tooltip;

    return MouseRegion(
      cursor: draggable ? SystemMouseCursors.grab : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: tooltip == null ? card : Tooltip(message: tooltip, child: card),
    );
  }
}

// How much of a request has been planned, as a bar.
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

// Who the pupil asked for, and who they asked to avoid.
//
// Worth its own line on the card and not only a warning after the fact: a
// preference is something to plan *by*, and finding out about it from a
// snackbar once the hour is already written is finding out too late.
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
        // Deep water and not red: NOT_PREFERRED says who the hour should go to
        // last, not who it may not go to, and the calendar has to stay plannable
        // when the only competent teacher is the one being avoided.
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

// How a card is picked up, which is not the same question as how the panel it
// stands in is laid out.
//
// It was a bool, and three answers is what broke it. The gesture belongs to the
// shape the panel is in and not to the width of the window: beside the track
// the pointer takes a card the moment it moves, above it the strip scrolls the
// same way a drag would travel and the two have to be told apart, and on a
// screen with no track at all there is nowhere to carry anything to.
enum BookingDragMode
{
  // A plain [Draggable]: the card comes away with the first movement.
  immediate,

  // A [LongPressDraggable]. The strip runs sideways and so does a drag, so the
  // press has to be held before it becomes one — otherwise every attempt to
  // scroll the pupils past picks one of them up instead.
  longPress,

  // Not at all. There is no track on screen to drop onto, and a card that can
  // be lifted and not put down is a gesture that can only end in a refusal.
  none,
}

// One request of one pupil, waiting to be put somewhere.
//
// The unit is the request and not the pupil, because the request is what can
// be planned: a pupil asking for three subjects is three things to place, on
// possibly three different teachers.
class CalendarBookingCard extends StatefulWidget
{
  final SchedulableBooking entry;
  final List<MinistrySubjectItem> ministrySubjects;

  // Who is who, by tax code: the booking carries the codes of the teachers it
  // named and nothing more, and a code is not a name anybody can read.
  final Map<String, String> teacherNames;

  // Whether this card is the one being dragged, so the original can stay in
  // place, faded, instead of being taken out from under the gesture.
  final bool isGhosted;

  // How the card is taken, or that it is not taken at all. See
  // [BookingDragMode]: whichever the answer, the click stays open — it is the
  // only way in where the drag is off, and the calmer one everywhere else.
  final BookingDragMode dragMode;

  // The written-out way of doing what the drag does quickly: choose the
  // length, tick the disciplines of this part, pick the teacher and the hour.
  // It is how a request is split with control, and the only way in at all where
  // the drag is off. Reached from the menu the card opens when it is clicked.
  final VoidCallback? onPlanRequested;

  // Announced the moment a drag begins and again when it ends, so the timeline
  // can light up where this request could go *before* the pointer reaches it.
  // Heard only through the track, the answer would arrive too late to be of use.
  final void Function(CalendarDragPayload? payload)? onDragChanged;

  // Where the track would put this request right now, so that what is in the
  // hand can say the hours it would take and go red where it may not go.
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

  // The three shapes of request read differently, the same way they do on the
  // pupil's own card: a ministry subject names itself and lists its
  // disciplines under it, while a lone discipline and a service are a name.
  String get _title
  {
    return switch (_booking.kind)
    {
      BookingRequestKind.ministrySubject => _ministrySubjectName(_booking.ministrySubjectId),
      BookingRequestKind.associationSubject => _booking.associationSubject?.name ?? 'Disciplina',
      BookingRequestKind.service => _booking.serviceName ?? 'Servizio',
    };
  }

  String _ministrySubjectName(int? id)
  {
    for (final subject in widget.ministrySubjects)
    {
      if (subject.id == id)
      {
        return subject.name;
      }
    }

    return 'Materia';
  }

  // What is left to do about this request, in one line.
  //
  // The two quantities are said together where both are open, because they
  // close at different speeds and reading only one of them is how a band gets
  // composed and then refuses to publish.
  String get _status
  {
    final entry = widget.entry;

    if (entry.isFullyCovered)
    {
      return 'Pianificata per intero';
    }

    if (entry.isLocked)
    {
      return 'Orario pubblicato: non modificabile';
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
      // Every minute spent and something still uncovered: the parts overlap on
      // a discipline and left another out, which is exactly the state that
      // passes in draft and stops the band from being published.
      return 'Minuti esauriti, ma qualcosa resta scoperto';
    }

    return parts.join(' · ');
  }

  // The sentence that explains why a single chip cannot be taken out on its
  // own, said in full so nobody has to work it out from the greyed chips.
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

    if (entry.remainingMinutes > 0 && entry.remainingMinutes < kMinimumBandMinutes)
    {
      return 'Restano ${formatMinutes(entry.remainingMinutes)}. Una lezione dura almeno mezz\'ora: allunga una delle due '
          'già presenti.';
    }

    // The last part available has to take everything still uncovered with it:
    // there is no third to leave a leftover to. It is the drop that refuses it —
    // and this is the sentence saying why before anybody tries.
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

  // The names of the teachers the pupil named, in the order they were given.
  // A code with nobody behind it is dropped rather than shown raw: the person
  // may have been removed from the anagrafica since.
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

  // The disciplines worth listing *under* the title, which is not always all of
  // them: a discipline asked for on its own **is** the title, and a card
  // repeating its own name underneath itself is saying nothing twice as loudly.
  // What is left to do about it is the status line's job either way.
  List<AssociationSubjectOption> get _listedDisciplines
  {
    return _booking.kind == BookingRequestKind.ministrySubject ? _allDisciplines : const [];
  }

  // What the whole card carries when it is dragged: everything still
  // uncovered, or — where nothing is uncovered and only minutes are left — the
  // disciplines that were asked for, so that lengthening is still possible.
  Set<int> get _wholeCardDisciplines
  {
    final entry = widget.entry;

    return entry.uncoveredDisciplineIds.isEmpty ? entry.requestedDisciplineIds : entry.uncoveredDisciplineIds;
  }

  bool get _canDrag => widget.dragMode != BookingDragMode.none;

  // How the two sentences about the gesture open, which is not the same
  // sentence in the two modes.
  //
  // "Trascina" is a lie in the strip: there the press has to be held first, and
  // somebody who tries it the way they were told and watches the panel scroll
  // away instead concludes the card cannot be moved at all. The trailing space
  // is part of it, so the two callers read as one phrase.
  String get _verb => widget.dragMode == BookingDragMode.longPress ? 'Tieni premuto e trascina ' : 'Trascina ';

  // The two kinds of pick-up, built from one description of what is being
  // picked up.
  //
  // One place, because everything except the recogniser is the same in both and
  // the parts that are the same are the parts that are load-bearing: the anchor
  // the track reads a minute from, the feedback that says where it would land,
  // and the three callbacks that put the carried request down again. Written
  // twice, it is the second copy that stops being told about a change.
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
      // The pointer itself and not the corner of the feedback: the track turns
      // the drag position straight into a minute, and DragTargetDetails.offset
      // is otherwise the top-left of whatever is being carried.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback,
      // Faded and left where it was. Taking it out reflows the panel under the
      // gesture, and the drag loses the thing it was anchored to.
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
      isWholeRequest: true,
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

  // The head of the card: the handle, the name of the materia, and how long it
  // was asked for.
  Widget _buildTitleRow({required bool canDrag})
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Said with a glyph and not only with the cursor: the cursor answers
        // once the pointer is already on the card, which is one move too late to
        // be the thing that tells you the card can be picked up at all.
        if (canDrag) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Tooltip(
              message: '${_verb}tutta la materia',
              child: const Icon(Icons.drag_indicator, size: 16, color: AppTheme.trialTurquoise),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
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

  // The disciplines the materia is made of, as their own small cards under a
  // label that says what they are — the level below the name, and the level a
  // single one of them can be dragged out of.
  //
  // That last part is said by the cards themselves and by nothing else here: the
  // handle each one wears, the turquoise it is outlined in, and the sentence
  // under the pointer. A line of prose under the row saying the same thing was
  // a third telling, and it cost two lines on the commonest card in the panel.
  Widget _buildDisciplines(List<AssociationSubjectOption> subjects, {required Set<int> covered, required bool canDrag})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISCIPLINE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: 1.1,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final subject in subjects)
              _buildDisciplineCard(subject, covered: covered.contains(subject.id), canDrag: canDrag),
          ],
        ),
      ],
    );
  }

  // What the click opens: the window on the whole request.
  //
  // Always the same one, whatever state the request is in — nothing planned,
  // half planned, or planned in two parts — because the window is the division
  // itself. Putting two parts back into one is one of the things done in there,
  // and it used to be a second command on this card asking a question of its
  // own.
  //
  // Off only where the band has been published: then there is nothing to change
  // until it is taken back down.
  VoidCallback? get _onClick => widget.entry.isLocked ? null : widget.onPlanRequested;

  @override
  Widget build(BuildContext context)
  {
    final entry = widget.entry;
    final covered = entry.coveredDisciplineIds;
    final canDragCard = _canDrag && entry.isPlaceable;
    final canDragOne = _canDrag && (entry.isPlaceable || entry.canJoinAPart);
    final disciplines = _listedDisciplines;
    final note = _splitNote;
    final preferred = _namesOf(_booking.preferredTeacherTaxCodes);
    final notPreferred = _namesOf(_booking.notPreferredTeacherTaxCodes);
    final onClick = _onClick;

    final Widget card = Opacity(
      opacity: widget.isGhosted ? 0.35 : 1,
      child: MouseRegion(
        // The hand and not the grab, the same way an hour already on the track
        // answers: both can be carried, and on both the click is the way in that
        // does not need a steady hand.
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
                // The mode, said again on the card itself and not only in the
                // band above it: the panel is scrolled, and a card read halfway
                // down it has to answer on its own whether this hour is in the
                // building or at a screen. Same two colours as the track.
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
                      // Only once there is something to measure. An empty bar
                      // says what the line under it already says, and pays for
                      // it with a band of nothing across a card that is mostly
                      // read in the state where nothing has been planned yet.
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
                      if (disciplines.isNotEmpty) ...[
                        const SizedBox(height: 11),
                        _buildDisciplines(disciplines, covered: covered, canDrag: canDragOne),
                      ],
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

  // A discipline of the request, draggable on its own where taking it out
  // alone would say something the whole card cannot.
  //
  // One already carried by an hour is draggable too, and that is the point: a
  // discipline may sit on **both** parts — two teachers taking turns on it —
  // and the panel is where that is asked for. It used to be the one thing the
  // drag could not express, while the window beside it could.
  //
  // What is *not* offered is dragging the only discipline left uncovered:
  // carrying it out on its own is carrying the whole card, and two gestures
  // meaning the same thing are one too many.
  // Whether taking this discipline out on its own is a gesture worth offering.
  //
  // Once the request has an hour, always: it can be dropped **on** that hour to
  // join it, which writes no hour and spends no minutes — so it stays possible
  // where nothing else is, both hours written or the last minutes gone.
  //
  // With nothing planned yet the answer is narrower, because the only thing a
  // drop can do there is make an hour. Dragging the one discipline still
  // uncovered is dragging the whole card, and a part that leaves something
  // uncovered needs another part to leave it to — half an hour at the least.
  bool _saysMoreAlone(int id, {required bool covered})
  {
    final entry = widget.entry;

    if (entry.canJoinAPart)
    {
      return true;
    }

    if (!covered && entry.uncoveredDisciplineIds.length <= 1)
    {
      return false;
    }

    return entry.uncoveredDisciplineIds.difference({id}).isEmpty ||
        entry.remainingMinutes >= 2 * kMinimumBandMinutes;
  }

  String _dragHint(AssociationSubjectOption subject, {required bool covered})
  {
    final entry = widget.entry;

    if (covered)
    {
      return '${subject.name} è già pianificata. ${_verb} per pianificarla anche in una '
          'seconda lezione.';
    }

    if (!entry.isPlaceable)
    {
      return 'Sono già state pianificate tutte le ore di lezione per questa materia. '
          '$_verb${subject.name} su una lezione già pianificata per unirla.';
    }

    if (entry.canJoinAPart)
    {
      return '$_verb${subject.name} su una lezione già in calendario per unirla, o su un\'ora '
          'libera per creare una nuova lezione.';
    }

    return '$_verb${subject.name} sull\'orario: le altre discipline restano da pianificare.';
  }

  Widget _buildDisciplineCard(AssociationSubjectOption subject, {required bool covered, required bool canDrag})
  {
    final entry = widget.entry;
    final draggable = canDrag && _saysMoreAlone(subject.id, covered: covered);

    final Widget chip = DisciplineCard(
      label: subject.name,
      isCovered: covered,
      isDraggable: draggable,
      // The same handle carries three different gestures, so they are told apart
      // in words: making an hour of this discipline alone, giving it to an hour
      // this materia already has, and giving a planned one a second teacher.
      tooltip: draggable ? _dragHint(subject, covered: covered) : null,
    );

    if (!draggable)
    {
      return chip;
    }

    final payload = BookingDragPayload(
      entry: entry,
      disciplineIds: {subject.id},
      minutes: entry.proposedMinutesFor({subject.id}),
    );

    return _draggableOf(
      payload: payload,
      feedback: CalendarDragFeedback(
        title: subject.name,
        mode: entry.presence.mode,
        hours: formatMinutes(payload.minutes),
        carriedAt: widget.carriedAt,
      ),
      child: chip,
    );
  }
}
