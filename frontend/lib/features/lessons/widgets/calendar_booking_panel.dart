import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/schedulable_booking.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import 'calendar_booking_card.dart';
import 'calendar_lesson_block.dart';
import 'person_avatar.dart';

// What the panel is wide standing beside the timeline, and how tall a pupil's
// block stands in the strip above it on a narrow window.
//
// The strip is deliberately shorter than a pupil's block usually is: it stands
// *above* the track on the windows that have no room for two columns, and those
// are the windows with the least height to give away. Whatever does not fit
// scrolls inside the block.
const double kBookingPanelWidth = 300;
const double kBookingStripHeight = 210;
const double kBookingBlockWidth = 288;

// How much of the band is still to be planned.
//
// Counted by request and not by card: one that has not been planned is offered
// under every stretch of hours the pupil gave in that mode, and there is still
// only one of it to plan.
//
// Out here rather than on the panel because the narrow calendar has to say the
// same number in its own switch, above a panel that has been told to stop
// saying it. Two counts of one thing is how the tab and the panel end up
// disagreeing about a day on the one screen that shows them together.
int openBookingCount(List<PresenceBookingGroup> groups)
{
  return groups
      .expand((group) => group.bookings)
      .where((entry) => !entry.isFullyCovered)
      .map((entry) => entry.id)
      .toSet()
      .length;
}

// The three shapes the panel is asked for, which are three screens and not
// three widths of one.
//
// It was a single `isColumn`, and the third shape is what broke it. Read off
// one bool, "laid out as a column" and "can be picked up" could not disagree —
// and the combination the narrow calendar needs is exactly the one that
// agreement was hiding: the column's order, with nothing draggable in it,
// because there is no track left to drop onto.
enum BookingPanelShape
{
  // Beside the track, at full height, with the whole column scrolling on its
  // own so the timeline keeps all of its own.
  column,

  // Above the track, the pupils running across it. Can be shut, and then it is
  // one line: the hours it gives back go to the track under it.
  strip,

  // The whole of a narrow screen, with no track anywhere. The heading is said
  // by the switch above it, and a card is opened with a tap.
  page,
}

// The chevron that shuts the strip and opens it again.
//
// Square, and outlined in gold under the pointer, because that is how this
// screen says "the pointer is here" everywhere else on it: the cards below do
// it, AppTodayButton in the header above does it, and the round close of a
// dialog does the coloured version of the same thing. Drawn as a shape that
// only filled — no line around it — it was the one control on the page
// answering the hand in a language of its own.
//
// Thirty-two and not the forty-four a paging arrow takes: this one stands on a
// line of text, and at the arrow's size it was taller than the heading it sits
// in.
class _ExpandToggle extends StatefulWidget
{
  final bool isExpanded;
  final VoidCallback onTap;

  const _ExpandToggle({required this.isExpanded, required this.onTap});

  @override
  State<_ExpandToggle> createState() => _ExpandToggleState();
}

class _ExpandToggleState extends State<_ExpandToggle>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return Tooltip(
      message: widget.isExpanded ? 'Nascondi le prenotazioni' : 'Mostra le prenotazioni',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            // The same beat the cards under it change on, so a pointer crossing
            // from one to the other is answered at one speed.
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hover ? AppTheme.trialGoldSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
                width: 1.5,
              ),
            ),
            child: Icon(
              widget.isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ),
      ),
    );
  }
}

// The pupil a block belongs to, and how much of them is left to do.
//
// One heading per pupil and not per stretch of hours: the same name appearing
// twice down the panel — the morning in the building, the evening at a screen —
// reads as two people, and whoever is composing a day thinks by pupil first.
// The hours come back one level down, where they decide something.
class _StudentHeader extends StatelessWidget
{
  final StudentBookingGroup student;

  const _StudentHeader({required this.student});

  String get _openLabel
  {
    final open = student.openCount;

    return switch (open)
    {
      0 => 'Tutto pianificato',
      1 => '1 prenotazione da pianificare',
      _ => '$open prenotazioni da pianificare',
    };
  }

  @override
  Widget build(BuildContext context)
  {
    final done = student.openCount == 0;

    return Row(
      children: [
        // The size the app gives a face inside a list. It used to be two thirds
        // of that, which is a photograph nobody can recognise anybody in — and a
        // face too small to read is a face not worth the room it takes. The two
        // lines beside it are shorter than the circle, so the block grows by the
        // difference and by nothing else.
        PersonAvatar(person: student.student, size: PersonAvatar.listSize),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.student.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppTheme.trialOcean,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _openLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: done ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// One stretch of hours of one pupil: the world it is in, and when.
//
// Said with the glyph, the colour and the word all three, because it is the
// thing a placement is judged against and reading it wrong is a lesson written
// where the pupil is not. The two colours are the track's own, so a card in the
// panel and the block it becomes are the same colour before and after.
class _PresenceBand extends StatelessWidget
{
  final PresenceBookingGroup group;

  const _PresenceBand({required this.group});

  @override
  Widget build(BuildContext context)
  {
    final accent = lessonAccent(group.mode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: lessonSurface(group.mode),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(lessonModeIcon(group.mode), size: 14, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              modeLabel(group.mode).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: 1.1,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            group.hoursLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// Everything the day has asked for and not yet been given.
//
// Three levels down, and the drag lives on the middle one: the pupil is the
// block, the materia is the card that gets picked up, and the disciplines are
// the small cards inside it — one of which can be taken out on its own while
// there is still a second part to put it in.
//
// Where the drag lives at all is [shape]'s answer, and on the narrowest screens
// it is nowhere: there is no track beside or above this, and the card is opened
// with a tap onto the same window the drag was only ever a quick way into.
class CalendarBookingPanel extends StatelessWidget
{
  final List<PresenceBookingGroup> groups;
  final List<MinistrySubjectItem> ministrySubjects;

  // Who is who, by tax code, for the preferences a request carries.
  final Map<String, String> teacherNames;

  // Which of the three the panel is. See [BookingPanelShape].
  final BookingPanelShape shape;

  // Whether the strip is open. Shut, only its heading is left, and the two
  // hundred and ninety pixels that frees go to the timeline under it — which is
  // the whole reason it can be shut: the windows that stack the two are the
  // windows with the least height to give away.
  //
  // Meaningless in the other two shapes, and ignored by them.
  final bool isExpanded;

  final ValueChanged<bool>? onExpandedChanged;

  // The written-out way of planning one part, offered in the menu every card
  // opens when it is clicked.
  final void Function(SchedulableBooking entry)? onPlanRequested;

  // A drag started here, or ended. The timeline needs to know at once, so it can
  // show where the request could go before the pointer arrives.
  final void Function(CalendarDragPayload? payload)? onDragChanged;

  // Passed straight through to the cards: what is being carried says where it
  // would land, and it is the same answer the track's own blocks give.
  final ValueListenable<CarriedPlacement>? carriedAt;

  const CalendarBookingPanel({
    super.key,
    required this.groups,
    required this.ministrySubjects,
    this.teacherNames = const {},
    required this.shape,
    this.isExpanded = true,
    this.onExpandedChanged,
    this.onPlanRequested,
    this.onDragChanged,
    this.carriedAt,
  });

  // Derived from the shape and not passed in beside it, which here is honest:
  // there are three shapes, there are three gestures, and each shape really
  // does settle its own. It was the bool that lied, because two values cannot
  // say three things.
  BookingDragMode get _dragMode
  {
    return switch (shape)
    {
      BookingPanelShape.column => BookingDragMode.immediate,
      BookingPanelShape.strip => BookingDragMode.longPress,
      BookingPanelShape.page => BookingDragMode.none,
    };
  }

  // What is still open, and only that.
  //
  // There used to be a switch offering the planned ones too, and it was a
  // second way of seeing the day the day already had: what is planned is drawn
  // on the track beside this, in the hours it was put in. A list repeating it
  // out of place answered nothing the track was not already answering better,
  // and every card in it was inert.
  List<PresenceBookingGroup> get _visibleGroups
  {
    final filtered = <PresenceBookingGroup>[];

    for (final group in groups)
    {
      final open = group.bookings.where((entry) => !entry.isFullyCovered).toList();

      if (open.isNotEmpty)
      {
        filtered.add(PresenceBookingGroup(presence: group.presence, bookings: open));
      }
    }

    return filtered;
  }

  List<StudentBookingGroup> get _visibleStudents => groupByStudent(_visibleGroups);

  int get _openCount => openBookingCount(groups);

  String get _emptyMessage
  {
    if (groups.isEmpty)
    {
      return 'Nessuna prenotazione.';
    }

    return 'Tutte le prenotazioni sono pianificate.';
  }

  // The name of the panel, and how much of it is left.
  //
  // Dropped whole in [BookingPanelShape.page] and only there: the narrow
  // calendar carries a switch above this whose left half already reads "Da
  // pianificare", with the same count on it, and a heading repeating the
  // control immediately above it is the phrase said twice in ten pixels.
  Widget _buildHeader({required bool showToggle})
  {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Da pianificare',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
        Text(
          '$_openCount',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialTealDeep,
          ),
        ),
        if (showToggle) ...[
          const SizedBox(width: 4),
          _buildExpandToggle(),
        ],
      ],
    );
  }

  Widget _buildExpandToggle()
  {
    return _ExpandToggle(
      isExpanded: isExpanded,
      onTap: () => onExpandedChanged?.call(!isExpanded),
    );
  }

  Widget _buildEmpty()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        _emptyMessage,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.4,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }

  Widget _buildCard(SchedulableBooking entry)
  {
    return CalendarBookingCard(
      entry: entry,
      ministrySubjects: ministrySubjects,
      teacherNames: teacherNames,
      dragMode: _dragMode,
      onPlanRequested: onPlanRequested == null ? null : () => onPlanRequested!(entry),
      onDragChanged: onDragChanged,
      carriedAt: carriedAt,
    );
  }

  // One pupil, with every stretch of hours they have something open in.
  //
  // The block is paper and the materie inside it are white, so the nesting is
  // read as depth rather than counted: whatever is lighter than what surrounds
  // it is the thing that gets moved.
  Widget _buildStudentBlock(StudentBookingGroup student)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 13),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudentHeader(student: student),
          for (final group in student.presences) ...[
            const SizedBox(height: 12),
            _PresenceBand(group: group),
            for (final entry in group.bookings) ...[
              const SizedBox(height: 8),
              _buildCard(entry),
            ],
          ],
        ],
      ),
    );
  }

  // Beside the track: one pupil under the next, the whole column scrolling on
  // its own so the timeline keeps its full height.
  //
  // The same body serves the narrow screen, which is what the switch above it
  // buys: one of the two halves of the day at a time means this one is handed a
  // height of its own there too, and a column that has a height can go on
  // scrolling inside it exactly as it does beside the track.
  Widget _buildColumn({bool showTitle = true})
  {
    final visible = _visibleStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          _buildHeader(showToggle: false),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: visible.isEmpty
              ? SingleChildScrollView(child: _buildEmpty())
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: visible.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _buildStudentBlock(visible[index]),
                ),
        ),
      ],
    );
  }

  // Above the track, where there is not room for two columns: the pupils run
  // across instead of down, each block keeping its own shape and scrolling
  // inside itself. Vertically within a horizontal list, so the two gestures
  // never mean the same thing.
  Widget _buildStrip()
  {
    final header = _buildHeader(showToggle: true);

    // Shut, the heading is the whole of it, and the two hundred and ninety
    // pixels it was taking go to the timeline under it. Nothing slides: what is
    // below is an axis that would have to be re-laid at every frame of an
    // animation, and hours drifting upwards while their teachers stay put reads
    // as the day coming apart rather than as a panel folding.
    if (!isExpanded)
    {
      return header;
    }

    final visible = _visibleStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 16),
        if (visible.isEmpty)
          _buildEmpty()
        else
          SizedBox(
            height: kBookingStripHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: visible.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: kBookingBlockWidth,
                child: SingleChildScrollView(child: _buildStudentBlock(visible[index])),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return switch (shape)
    {
      BookingPanelShape.column => _buildColumn(),
      BookingPanelShape.strip => _buildStrip(),
      // The column again, minus its name: on a narrow screen the switch above
      // is already carrying it, with the same count on it.
      BookingPanelShape.page => _buildColumn(showTitle: false),
    };
  }
}
