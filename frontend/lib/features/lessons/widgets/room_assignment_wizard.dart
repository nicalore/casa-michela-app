import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_check_mark.dart' show kPickedSurface;
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/room_item.dart';
import '../../association/widgets/room_card.dart' show roomCapacityLabel;
import '../../people/edit/widgets/person_edit_guide.dart';
import '../models/calendar_day.dart';
import '../models/room_supervision_item.dart';
import '../models/teacher_room_assignment_item.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'calendar_lesson_block.dart' show CalendarLeftBehind;
import 'person_avatar.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

// As wide as the card the arrows turn, and the window is that plus an arrow and
// a gap either side, plus the stack's own margin — the sum the other wizards of
// the app are built with.
const double _stepWidth = 720;
const double _dialogWidth = _stepWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap) + 64;

const double _teacherColumnWidth = 268;

// Under this the board stacks, the teachers over the rooms. Measured on the card
// itself and not on the window: the carousel takes an arrow and a gap off either
// side of what it is given, so the window is a poor guide to what is left for
// the two columns.
const double _twoColumnsMin = 600;

// How tall each of the two sides is allowed to get before it starts scrolling
// inside itself. Neither may take the window with it: the two are read together,
// and a list of teachers as long as the day would push every room off the screen.
const double _sideMaxHeight = 380;

// The one line each room of the second step is read on, and the cards picked
// under it. The bar is taller than a row in a stack of them would be: there is
// one of it per room, and it carries the whole answer.
const double _barHeight = 18;
const double _supervisorAvatarSize = 34;

// What a supervisor's card would like to be, and the air between two of them.
// They share the row out between themselves at this width or wider — see
// _RoomAssignmentWizardState._buildSupervisorCards.
const double _supervisorCardIdealWidth = 260;
const double _supervisorCardGap = 8;

// The muted grey every second line in this app is written in, on a card and on
// a picked card alike. Deliberately not the teal that a room's capacity takes on
// its own card: that one is read on white, and the same green on the mint the
// app tints a chosen card with is a pair of colours that fight.
final TextStyle _supervisorHoursStyle = GoogleFonts.plusJakartaSans(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.2,
  color: AppTheme.trialMutedText,
);

// The narrowest a stretch may be drawn. A quarter of an hour inside a window of
// six is under two pixels, and a shift nobody can see is a shift nobody checks.
const double _minBarWidth = 3;

// Longer than anything on the calendar's track, for the opposite reason:
// nothing here keeps up with a hand. What is worth seeing is the length itself
// moving — which hour has just stopped being red — and at a sixth of a second
// that is a flicker.
const Duration _fillDuration = Duration(milliseconds: 320);

// The teachers the day has called into the building, read off the lessons and
// not the availabilities: offering is not being convened, and only hours taught
// from the building count.
//
// Out here because the calendar asks the same question before the window
// exists: it decides whether the day ends in "Assegna stanze" or in publishing.
List<TeacherLane> teachersInBuilding(List<TeacherLane> lanes)
{
  return lanes
      .where((lane) => lane.lessons.any((lesson) => lesson.teacherMode == kPresenceMode))
      .toList();
}

// Whether the day's rooms are settled: everybody in the building has one, and
// every room is watched for all the hours it is taught in. Asked out here of
// what the server holds, so the calendar need not open the window to find out.
//
// The shifts are read as written and not recomputed: an hour added after the
// rooms were settled is an hour no stored shift reaches over.
bool isRoomPlanSettled({
  required List<TeacherLane> lanes,
  required List<TeacherRoomAssignmentItem> assignments,
  required List<RoomSupervisionItem> supervisions,
})
{
  final roomOf = {for (final row in assignments) row.teacherTaxCode: row.room.id};
  final occupied = <int, List<(int, int)>>{};

  for (final lane in lanes)
  {
    final room = roomOf[lane.teacherTaxCode];

    // Somebody in the building with nowhere to be. No amount of cover elsewhere
    // makes that a settled day.
    if (room == null)
    {
      return false;
    }

    occupied.putIfAbsent(room, () => []).addAll(_lessonSpans(lane));
  }

  final covered = <int, List<(int, int)>>{};

  for (final shift in supervisions)
  {
    covered.putIfAbsent(shift.room.id, () => []).add((shift.startMinutes, shift.endMinutes));
  }

  return occupied.entries.every((entry)
  {
    return subtractSpans(
      mergeSpans(entry.value),
      mergeSpans(covered[entry.key] ?? const []),
    ).isEmpty;
  });
}

// One stretch of somebody answering for a room as the window has drawn it,
// before anything is written. In minutes, which is what everything it is
// compared against is in.
class PlannedShift
{
  final int roomId;
  final String teacherTaxCode;
  final int startMinutes;
  final int endMinutes;

  const PlannedShift({
    required this.roomId,
    required this.teacherTaxCode,
    required this.startMinutes,
    required this.endMinutes,
  });

  TimeOfDay get startTime => TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);

  TimeOfDay get endTime => TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);

  // Whether a shift the server already holds is this same one, so that a board
  // confirmed without being changed writes nothing at all.
  bool matches(RoomSupervisionItem row)
  {
    return row.room.id == roomId &&
        row.teacherTaxCode == teacherTaxCode &&
        row.startMinutes == startMinutes &&
        row.endMinutes == endMinutes;
  }
}

// The hours a teacher is in the building for, end to end. What is between two
// of their lessons is theirs as well: nobody goes home for half an hour.
String _hoursLabel(TeacherLane lane)
{
  final spans = _lessonSpans(lane);

  if (spans.isEmpty)
  {
    return '';
  }

  return formatMinutesRange(spans.first.$1, spans.last.$2);
}

// When a teacher is actually in their room: the hours they teach from the
// building, merged where they run on.
//
// The lessons and not the availabilities — offering the afternoon is saying one
// could be here, and somebody whose last hour ends at five is gone at five. The
// room's occupied hours come off the same lessons, so a cover can never reach
// past the hours needing covering.
List<(int, int)> _lessonSpans(TeacherLane lane)
{
  return mergeSpans([
    for (final lesson in lane.lessons)
      if (lesson.teacherMode == kPresenceMode) (lesson.startMinutes, lesson.endMinutes),
  ]);
}

// One teacher, as a thing that can be picked up and put in a room. The handle
// is drawn and not implied by the cursor, which answers once the pointer is
// already on the card.
class _TeacherCard extends StatefulWidget
{
  final TeacherLane lane;

  // Where they were picked up from, so a room does not offer to accept somebody
  // it already holds.
  final int? fromRoomId;

  // Held first on the narrow layout, where the two sides are stacked and the
  // window scrolls: a card that came away with the first movement would take
  // the scroll with it.
  final bool longPress;

  const _TeacherCard({
    super.key,
    required this.lane,
    required this.fromRoomId,
    required this.longPress,
  });

  @override
  State<_TeacherCard> createState() => _TeacherCardState();
}

class _TeacherCardState extends State<_TeacherCard>
{
  bool _hover = false;

  Widget _buildBody({required bool inHand})
  {
    final lane = widget.lane;
    final hours = _hoursLabel(lane);
    final lessons = lane.lessons.where((lesson) => lesson.teacherMode == kPresenceMode).length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: _hover || inHand ? AppTheme.todaySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hover || inHand ? AppTheme.trialTealDeep : AppTheme.trialLine,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.drag_indicator_rounded, size: 18, color: AppTheme.trialMutedText),
          ),
          PersonAvatar(person: lane.teacher, size: PersonAvatar.listSize),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lane.teacher.fullName,
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
                  '$hours · ${lessons == 1 ? '1 lezione' : '$lessons lezioni'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final card = _buildBody(inHand: false);

    final payload = _CarriedTeacher(lane: widget.lane, fromRoomId: widget.fromRoomId);

    // The feedback lives in the Overlay, outside the app's own Material, and a
    // Text in there without one of its own throws. Opaque on purpose: what is
    // carried passes over the boxes it might land in, and a half-transparent
    // card is read against whatever happens to lie under it.
    final feedback = Material(
      type: MaterialType.transparency,
      child: SizedBox(width: _teacherColumnWidth, child: _buildBody(inHand: true)),
    );

    // Faded and left where it was: taking it out reflows the column under the
    // gesture, and the drag loses what it was anchored to. Faded over a moment
    // and not between two frames — the same hand-over the calendar's own cards
    // make, and for the same reason.
    final faded = CalendarLeftBehind(opacity: 0.35, child: card);

    final Widget draggable = widget.longPress
        ? LongPressDraggable<_CarriedTeacher>(
            data: payload,
            feedback: feedback,
            childWhenDragging: faded,
            child: card,
          )
        : Draggable<_CarriedTeacher>(
            data: payload,
            feedback: feedback,
            childWhenDragging: faded,
            child: card,
          );

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: draggable,
    );
  }
}

// What a teacher card carries. Deliberately not a bare tax code: a
// `DragTarget<String>` accepts any string dragged anywhere in the app.
class _CarriedTeacher
{
  final TeacherLane lane;
  final int? fromRoomId;

  const _CarriedTeacher({required this.lane, required this.fromRoomId});
}

// A place a teacher can be put down: a room, or the column they came from. One
// widget for both, since they are the same gesture answered the same way.
class _DropBox extends StatelessWidget
{
  final bool Function(_CarriedTeacher carried) accepts;
  final ValueChanged<_CarriedTeacher> onAccept;
  final Widget child;

  const _DropBox({
    required this.accepts,
    required this.onAccept,
    required this.child,
  });

  @override
  Widget build(BuildContext context)
  {
    return DragTarget<_CarriedTeacher>(
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) => onAccept(details.data),
      // The candidates are exactly what was carried over and would be taken — a
      // drag refused by onWillAccept never reaches this list. It is why there is
      // no hover flag of its own here: the one the framework already keeps
      // cannot fall out of step with the answer that produced it.
      builder: (context, candidate, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: candidate.isEmpty ? AppTheme.trialPaper : AppTheme.todaySurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: candidate.isEmpty ? AppTheme.trialLine : AppTheme.trialTealDeep,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: child,
      ),
    );
  }
}

// One teacher of a room, picked or not. No tick: a card carries its state in
// its own colour, and the box beside the words belongs to the rows of a list.
//
// The width comes from outside — every card of a room is as wide as the longest
// hours among them. See [_RoomAssignmentWizardState._buildSupervisorCards].
class _SupervisorCard extends StatefulWidget
{
  final TeacherLane lane;
  final String hours;
  final double width;
  final bool isSelected;
  final VoidCallback onTap;

  const _SupervisorCard({
    super.key,
    required this.lane,
    required this.hours,
    required this.width,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SupervisorCard> createState() => _SupervisorCardState();
}

class _SupervisorCardState extends State<_SupervisorCard>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: widget.width,
          padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
          decoration: BoxDecoration(
            // White standing and the picked mint chosen, which is exactly what
            // the person cards do. Both ends opaque and both light, so the fade
            // between them stays light the whole way: it is fading *from*
            // transparent that goes muddy, transparent being black at zero
            // opacity.
            color: widget.isSelected ? kPickedSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            // Always there and usually invisible, so lighting up under the
            // pointer does not shift the words by two pixels.
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              PersonAvatar(person: widget.lane.teacher, size: _supervisorAvatarSize),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The name is the one thing here that may be cut: it is
                    // written again on the card the first step moves about, and
                    // a name is recognised long before its last letter.
                    Text(
                      widget.lane.teacher.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Shrunk to fit rather than cut, on the day a teacher turns
                    // up with more stretches than the row was divided for. The
                    // card does not change shape for it: its height is the
                    // face's, and the face is taller than these two lines.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(widget.hours, maxLines: 1, style: _supervisorHoursStyle),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// One stretch of a bar this frame. In minutes and not pixels, which is what
// the two answers being travelled between are written in.
typedef _Bar = ({double start, double end, double alpha});

double _lerp(double from, double to, double t) => from + (to - from) * t;

// Every stretch of a layer, part of the way from one answer to the next.
//
// Each new stretch comes out of whichever old one it shares the most minutes
// with, so two-until-four becoming two-until-six is one stretch whose far edge
// travels. The other cases fall out of the same rule: a stretch with nothing
// behind it opens from its middle, and one nothing came of closes onto its
// middle. A stretch two new ones come out of divides, which is what happened.
List<_Bar> _barsBetween(List<(int, int)> from, List<(int, int)> to, double t)
{
  final bars = <_Bar>[];
  final claimed = <int>{};

  for (final span in to)
  {
    var best = -1;
    var shared = 0;

    for (var index = 0; index < from.length; index++)
    {
      final common = intersectSpan(span.$1, span.$2, from[index].$1, from[index].$2);
      final minutes = common == null ? 0 : common.$2 - common.$1;

      if (minutes > shared)
      {
        shared = minutes;
        best = index;
      }
    }

    if (best < 0)
    {
      final middle = (span.$1 + span.$2) / 2;

      bars.add((
        start: _lerp(middle, span.$1.toDouble(), t),
        end: _lerp(middle, span.$2.toDouble(), t),
        alpha: t,
      ));

      continue;
    }

    claimed.add(best);

    bars.add((
      start: _lerp(from[best].$1.toDouble(), span.$1.toDouble(), t),
      end: _lerp(from[best].$2.toDouble(), span.$2.toDouble(), t),
      alpha: 1,
    ));
  }

  for (var index = 0; index < from.length; index++)
  {
    if (claimed.contains(index))
    {
      continue;
    }

    final span = from[index];
    final middle = (span.$1 + span.$2) / 2;

    bars.add((
      start: _lerp(span.$1.toDouble(), middle, t),
      end: _lerp(span.$2.toDouble(), middle, t),
      alpha: 1 - t,
    ));
  }

  return bars;
}

// One layer of a room's bar, drawn so a change grows out of what was there.
// Redrawn instead, the bar is one thing in one frame and another in the next,
// and what changed has to be worked out against a memory of a moment ago.
class _SpanBars extends StatefulWidget
{
  final List<(int, int)> spans;
  final Color color;
  final int windowStart;
  final int windowEnd;

  const _SpanBars({
    required this.spans,
    required this.color,
    required this.windowStart,
    required this.windowEnd,
  });

  @override
  State<_SpanBars> createState() => _SpanBarsState();
}

class _SpanBarsState extends State<_SpanBars> with SingleTickerProviderStateMixin
{
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _fillDuration,
    // Arrived: a room that opens with cover already on it is drawn covered, not
    // filled in front of somebody who has not touched anything yet.
    value: 1,
  );

  late final Animation<double> _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  late List<(int, int)> _from = widget.spans;

  @override
  void didUpdateWidget(_SpanBars oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (listEquals(oldWidget.spans, widget.spans))
    {
      return;
    }

    // From where it actually is and not from where the last change started: two
    // cards clicked in quick succession would otherwise send the bar back to the
    // length it had before the first of them and start again.
    _from = [
      for (final bar in _barsBetween(_from, oldWidget.spans, _progress.value))
        if (bar.alpha >= 0.5) (bar.start.round(), bar.end.round()),
    ];

    _controller.forward(from: 0);
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => CustomPaint(
          painter: _SpanBarsPainter(
            bars: _barsBetween(_from, widget.spans, _progress.value),
            color: widget.color,
            windowStart: widget.windowStart,
            windowEnd: widget.windowEnd,
          ),
        ),
      ),
    );
  }
}

class _SpanBarsPainter extends CustomPainter
{
  final List<_Bar> bars;
  final Color color;
  final int windowStart;
  final int windowEnd;

  const _SpanBarsPainter({
    required this.bars,
    required this.color,
    required this.windowStart,
    required this.windowEnd,
  });

  @override
  void paint(Canvas canvas, Size size)
  {
    final total = (windowEnd - windowStart).toDouble();
    final radius = Radius.circular(size.height / 2);

    for (final bar in bars)
    {
      if (bar.alpha <= 0)
      {
        continue;
      }

      final left = (bar.start - windowStart) / total * size.width;

      // The floor is scaled by how much of the stretch there is: at rest it is
      // the three pixels a quarter of an hour is given so that it can be seen at
      // all, and on the way in or out it lets the stretch come out of nothing
      // rather than snapping into existence three pixels wide.
      final width = math.max((bar.end - bar.start) / total * size.width, _minBarWidth * bar.alpha);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, width, size.height), radius),
        Paint()..color = color.withValues(alpha: color.a * bar.alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_SpanBarsPainter oldDelegate)
  {
    return oldDelegate.color != color ||
        oldDelegate.windowStart != windowStart ||
        oldDelegate.windowEnd != windowEnd ||
        !listEquals(oldDelegate.bars, bars);
  }
}

// The room's whole day on one line. One bar and not a row per teacher: the step
// answers a single question — is anything left uncovered — and a stack of bars
// made that a comparison by eye across rows.
//
// Two colours and not three: a supervisor's hours and the room's are the same
// lessons, so no cover ever stands beside the hours it covers.
class _RoomTimeline extends StatelessWidget
{
  final int windowStart;
  final int windowEnd;

  // The hours the room is taught in.
  final List<(int, int)> occupied;

  // The hours the chosen supervisors are in it for, merged.
  final List<(int, int)> covered;

  const _RoomTimeline({
    required this.windowStart,
    required this.windowEnd,
    required this.occupied,
    required this.covered,
  });

  @override
  Widget build(BuildContext context)
  {
    final radius = BorderRadius.circular(_barHeight / 2);

    final open = subtractSpans(occupied, covered);

    Widget layer(List<(int, int)> spans, Color color)
    {
      return _SpanBars(
        spans: spans,
        color: color,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
    }

    return SizedBox(
      height: _barHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.trialLine.withValues(alpha: 0.5),
                borderRadius: radius,
              ),
            ),
          ),
          Positioned.fill(child: layer(covered, AppTheme.trialTealDeep)),
          // Last, so a quarter of an hour left open is drawn over the cover
          // either side of it rather than under: the narrowest a stretch may be
          // drawn is wider than a quarter of an hour is worth, and of the two
          // ways to round it the one that keeps a gap visible is the safe one.
          Positioned.fill(child: layer(open, AppTheme.trialDanger)),
        ],
      ),
    );
  }
}

// The hours the bars under it are read against, on the hour.
//
// Every hour while they fit and every second one when they do not: the window
// is as long as the room is taught in, which on a full day is eight hours in
// four hundred pixels, and labels that overlap are worse than half as many.
class _TimeAxis extends StatelessWidget
{
  final int windowStart;
  final int windowEnd;

  const _TimeAxis({required this.windowStart, required this.windowEnd});

  @override
  Widget build(BuildContext context)
  {
    final total = (windowEnd - windowStart).toDouble();

    final style = GoogleFonts.plusJakartaSans(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0.3,
      color: AppTheme.trialMutedText,
    );

    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final width = constraints.maxWidth;

          // Every label wants about thirty-two pixels to itself. Whatever the
          // window is worth, the step is the first whole hour that buys them.
          final perHour = width / (total / 60);
          final step = perHour >= 32 ? 1 : math.max(2, (32 / perHour).ceil());

          final first = (windowStart / 60).ceil();
          final last = windowEnd ~/ 60;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var hour = first; hour <= last; hour += step)
                Positioned(
                  // Centred on its own mark, and let out of the box at the two
                  // ends: the first and last labels stand over the edge of the
                  // bar rather than being pulled inside it, which would put them
                  // over an hour that is not theirs.
                  left: (hour * 60 - windowStart) / total * width - 20,
                  width: 40,
                  top: 0,
                  child: Center(child: Text('$hour', style: style)),
                ),
            ],
          );
        },
      ),
    );
  }
}

// A room in the second step: what it is taught in, who is assigned to it, and
// which of them is answerable for it.
class _RoomPlan
{
  final RoomItem room;

  // The teachers put in it by the first step, in the order they are drawn.
  final List<TeacherLane> teachers;

  // The hours it is actually taught in, merged. The gaps are real: an empty
  // room needs nobody answerable for it.
  final List<(int, int)> occupied;

  // Who has been made answerable for it.
  final Set<String> supervisors;

  const _RoomPlan({
    required this.room,
    required this.teachers,
    required this.occupied,
    required this.supervisors,
  });

  bool get isEmpty => teachers.isEmpty || occupied.isEmpty;

  int get windowStart => occupied.first.$1;

  int get windowEnd => occupied.last.$2;

  // The hours one of its teachers would take on, which are the ones they teach.
  // Never outside [occupied], and not because anything clips it: that is built
  // out of these same lessons.
  List<(int, int)> coverageOf(TeacherLane lane) => _lessonSpans(lane);

  List<(int, int)> get covered
  {
    return mergeSpans([
      for (final lane in teachers)
        if (supervisors.contains(lane.teacherTaxCode)) ...coverageOf(lane),
    ]);
  }

  // Hours the room is taught in with nobody answerable for it. Empty is the
  // whole of what the second step is asking for.
  List<(int, int)> get uncovered => subtractSpans(occupied, covered);

  List<PlannedShift> get shifts
  {
    return [
      for (final lane in teachers)
        if (supervisors.contains(lane.teacherTaxCode))
          for (final span in coverageOf(lane))
            PlannedShift(
              roomId: room.id,
              teacherTaxCode: lane.teacherTaxCode,
              startMinutes: span.$1,
              endMinutes: span.$2,
            ),
    ];
  }
}

// Who is in which room, and who is answerable for each of them.
//
// A day and not a band: a teacher takes a room and stays in it. The window is
// opened from the band that has just been finished, and what it writes covers
// the whole day.
//
// Nothing is written until the last button: the two steps build a drawing, and
// confirming makes the day match it.
class RoomAssignmentWizard extends StatefulWidget
{
  final DateTime day;

  // The teachers with at least one hour in the building. See
  // [teachersInBuilding].
  final List<TeacherLane> lanes;

  final List<RoomItem> rooms;

  // What the day already says, so a window opened twice is opened onto its own
  // last answer rather than onto an empty board.
  final List<TeacherRoomAssignmentItem> assignments;
  final List<RoomSupervisionItem> supervisions;

  // The whole plan at once, against the assignments that were there when the
  // window opened. Null against a room means the teacher is to have none.
  final Future<bool> Function({
    required DateTime day,
    required List<TeacherRoomAssignmentItem> assignments,
    required Map<String, int?> rooms,
    required List<PlannedShift> shifts,
    required Function(String) onError,
  })? onSave;

  const RoomAssignmentWizard({
    super.key,
    required this.day,
    required this.lanes,
    required this.rooms,
    required this.assignments,
    this.supervisions = const [],
    this.onSave,
  });

  @override
  State<RoomAssignmentWizard> createState() => _RoomAssignmentWizardState();
}

class _RoomAssignmentWizardState extends State<RoomAssignmentWizard>
{
  // The board being built: teacher to room, with whoever is absent still to be
  // placed. Started from what the day already says and never carried over from
  // a previous opening — a room taken away between two of them has to be gone
  // from here as well.
  late final Map<String, int> _roomOf = _initialBoard();

  // Who is answerable for each room, by tax code.
  //
  // Only who and not when: the hours are worked out from the teacher's own,
  // every time they are asked for, so a selection made before a lesson moved
  // cannot go on claiming to cover an hour that is no longer there.
  late final Map<int, Set<String>> _supervisorsOf = _initialSupervisors();

  int _stepIndex = 0;
  bool _movingForward = true;

  bool _isSaving = false;

  Map<String, int> _initialBoard()
  {
    final rooms = {for (final room in widget.rooms) room.id};
    final board = <String, int>{};

    for (final assignment in widget.assignments)
    {
      // A room that has since left the catalogue is not offered here, so an old
      // assignment pointing at one is left out rather than drawn in a box that
      // is not on the board.
      if (rooms.contains(assignment.room.id))
      {
        board[assignment.teacherTaxCode] = assignment.room.id;
      }
    }

    return board;
  }

  Map<int, Set<String>> _initialSupervisors()
  {
    final supervisors = <int, Set<String>>{};

    for (final shift in widget.supervisions)
    {
      // Whoever holds a shift in a room is answerable for it, and how long the
      // stored shift ran is not read: the hours are recomputed from what the day
      // says now, so a shift written before a lesson was added comes back
      // reaching over the new one as well.
      if (_roomOf[shift.teacherTaxCode] == shift.room.id)
      {
        supervisors.putIfAbsent(shift.room.id, () => <String>{}).add(shift.teacherTaxCode);
      }
    }

    return supervisors;
  }

  List<TeacherLane> get _unassigned
  {
    return widget.lanes.where((lane) => !_roomOf.containsKey(lane.teacherTaxCode)).toList();
  }

  List<TeacherLane> _inRoom(int roomId)
  {
    return widget.lanes.where((lane) => _roomOf[lane.teacherTaxCode] == roomId).toList();
  }

  void _put(_CarriedTeacher carried, int? roomId)
  {
    final taxCode = carried.lane.teacherTaxCode;

    setState(()
    {
      // Their shift goes with them, in both directions. A teacher answerable for
      // a room they have left is what the database refuses outright — the shift
      // hangs off the assignment — and one carried into a new room arrives
      // watching over nothing until somebody says so.
      _supervisorsOf[carried.fromRoomId]?.remove(taxCode);

      if (roomId == null)
      {
        _roomOf.remove(taxCode);

        return;
      }

      _roomOf[taxCode] = roomId;
    });
  }

  void _toggleSupervisor(int roomId, String taxCode)
  {
    setState(()
    {
      final chosen = _supervisorsOf.putIfAbsent(roomId, () => <String>{});

      if (!chosen.remove(taxCode))
      {
        chosen.add(taxCode);
      }
    });
  }

  // What the board says, for every teacher the window is about.
  //
  // Every one of them and not only those in a room: a teacher dragged back out
  // is an assignment to be removed, and a map that only carried the placed ones
  // could not tell "taken out" from "never mentioned".
  Map<String, int?> get _desiredRooms
  {
    return {
      for (final lane in widget.lanes) lane.teacherTaxCode: _roomOf[lane.teacherTaxCode],
    };
  }

  // Every room with somebody in it, in the catalogue's order.
  List<_RoomPlan> get _plans
  {
    final plans = <_RoomPlan>[];

    for (final room in widget.rooms)
    {
      final teachers = _inRoom(room.id);

      if (teachers.isEmpty)
      {
        continue;
      }

      plans.add(_RoomPlan(
        room: room,
        teachers: teachers,
        occupied: mergeSpans([for (final lane in teachers) ..._lessonSpans(lane)]),
        supervisors: _supervisorsOf[room.id] ?? const <String>{},
      ));
    }

    return plans;
  }

  List<PlannedShift> get _desiredShifts => [for (final plan in _plans) ...plan.shifts];

  // What is in the way of confirming, and which step can do something about it.
  // Raised by the button and nowhere else: standing under the title, it put a
  // red sentence over the window from the first teacher dropped into a room.
  //
  // The rooms are asked about before the responsabili: a teacher with nowhere
  // to be cannot be made answerable for anywhere.
  ({String message, int step})? get _refusal
  {
    final waiting = _unassigned;

    if (waiting.isNotEmpty)
    {
      return (
        message: waiting.length == 1
            ? '${waiting.first.teacher.fullName} è in sede e non ha una stanza.'
            : '${waiting.length} docenti in sede non hanno una stanza.',
        step: 0,
      );
    }

    final short = _plans.where((plan) => !plan.isEmpty && plan.uncovered.isNotEmpty).toList();

    if (short.isEmpty)
    {
      return null;
    }

    if (short.length == 1)
    {
      final plan = short.first;
      final gap = plan.uncovered.first;

      return (
        message: '${plan.room.name} resta senza responsabile: ${formatMinutesRange(gap.$1, gap.$2)}.',
        step: 1,
      );
    }

    return (
      message: '${short.length} stanze restano senza responsabile in qualche ora di lezione.',
      step: 1,
    );
  }

  Future<void> _confirm() async
  {
    final save = widget.onSave;

    if (save == null || _isSaving)
    {
      return;
    }

    final refusal = _refusal;

    if (refusal != null)
    {
      CustomSnackBar.show(context: context, message: refusal.message, isError: true);

      // Onto the step that can do something about it. Refusing and leaving
      // whoever pressed the button where they were is an answer they have to go
      // looking for the question of.
      if (_stepIndex != refusal.step)
      {
        _goTo(refusal.step);
      }

      return;
    }

    setState(() => _isSaving = true);

    final saved = await save(
      day: widget.day,
      assignments: widget.assignments,
      rooms: _desiredRooms,
      shifts: _desiredShifts,
      onError: (message)
      {
        if (mounted)
        {
          CustomSnackBar.show(context: context, message: message, isError: true);
        }
      },
    );

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (saved)
    {
      // The answer travels with the pop and the confirmation is said by whoever
      // opened this: a banner raised here would be raised by a window on its way
      // out, over the page it is uncovering.
      Navigator.of(context).pop(true);
    }
  }

  // --- the pieces both steps are made of ------------------------------------

  Widget _buildSideTitle(String text, {String? trailing})
  {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                height: 1.2,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppTheme.trialTealDeep,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuiet(String message)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Text(
        message,
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

  Widget _buildRoomTitle(RoomItem room, {required bool occupied, String? trailing})
  {
    return Row(
      children: [
        Icon(
          occupied ? Icons.meeting_room_rounded : Icons.meeting_room_outlined,
          size: 18,
          color: occupied ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            room.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ],
    );
  }

  // --- the first step: who is in which room ---------------------------------

  Widget _buildTeacherCard(TeacherLane lane, {required int? fromRoomId, required bool longPress})
  {
    return _TeacherCard(
      key: ValueKey(lane.teacherTaxCode),
      lane: lane,
      fromRoomId: fromRoomId,
      longPress: longPress,
    );
  }

  // What a side may be before it scrolls inside itself, capped only in the
  // two-column layout: stacked, a box scrolling inside a page that scrolls is
  // two ways of moving the same list.
  Widget _buildScrollingSide({required bool capped, required Widget child})
  {
    if (!capped)
    {
      return child;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _sideMaxHeight),
      child: SingleChildScrollView(child: child),
    );
  }

  // The teachers still to be put somewhere, and the place a teacher is dropped
  // to take their room away.
  Widget _buildPool({required bool twoColumns})
  {
    final waiting = _unassigned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSideTitle('Docenti convocati', trailing: waiting.isEmpty ? null : '${waiting.length}'),
        _DropBox(
          // Only somebody who is in a room: dropping a waiting teacher back among
          // the waiting is a gesture with no consequence, and a box that lights
          // up for it promises one.
          accepts: (carried) => carried.fromRoomId != null,
          onAccept: (carried) => _put(carried, null),
          child: waiting.isEmpty
              ? _buildQuiet('Tutti i docenti in sede hanno una stanza.')
              : _buildScrollingSide(
                  capped: twoColumns,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < waiting.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _buildTeacherCard(waiting[i], fromRoomId: null, longPress: !twoColumns),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRoomBox(RoomItem room, {required bool twoColumns})
  {
    final inside = _inRoom(room.id);

    return _DropBox(
      // Not the room they are already in: the drop would write what is already
      // written, and a box lighting up under a card it already holds says the
      // gesture does something.
      accepts: (carried) => carried.fromRoomId != room.id,
      onAccept: (carried) => _put(carried, room.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
            // Said only where somebody counted it: a room nobody measured is not
            // a room with no seats in it.
            child: _buildRoomTitle(
              room,
              occupied: inside.isNotEmpty,
              trailing: roomCapacityLabel(room.capacity),
            ),
          ),
          if (inside.isEmpty)
            _buildQuiet('Vuota.')
          else
            for (var i = 0; i < inside.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _buildTeacherCard(inside[i], fromRoomId: room.id, longPress: !twoColumns),
            ],
        ],
      ),
    );
  }

  Widget _buildRooms({required bool twoColumns})
  {
    if (widget.rooms.isEmpty)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSideTitle('Stanze'),
          _buildQuiet('Nessuna stanza disponibile. Aggiungine una in Associazione › Stanze.'),
        ],
      );
    }

    // Counted over the teachers on the board and not over the map: the map is
    // started from the day's assignments, and one belonging to somebody this
    // window is not about would be counted into a total of cards you can see.
    final assigned = widget.lanes.where((lane) => _roomOf.containsKey(lane.teacherTaxCode)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSideTitle('Stanze', trailing: assigned == 0 ? null : '$assigned assegnati'),
        _buildScrollingSide(
          capped: twoColumns,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.rooms.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildRoomBox(widget.rooms[i], twoColumns: twoColumns),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoard()
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final twoColumns = constraints.maxWidth >= _twoColumnsMin;

        if (!twoColumns)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPool(twoColumns: false),
              const SizedBox(height: 22),
              _buildRooms(twoColumns: false),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: _teacherColumnWidth, child: _buildPool(twoColumns: true)),
            const SizedBox(width: 22),
            Expanded(child: _buildRooms(twoColumns: true)),
          ],
        );
      },
    );
  }

  // --- the second step: who answers for each room ---------------------------

  Widget _buildLegendEntry(Color color, String label)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageVerdict(_RoomPlan plan)
  {
    final gaps = plan.uncovered;
    final covered = gaps.isEmpty;

    final message = covered
        ? 'Ha un responsabile per tutte le ore di lezione.'
        : 'Senza responsabile: ${gaps.map((gap) => formatMinutesRange(gap.$1, gap.$2)).join(', ')}.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          covered ? Icons.verified_rounded : Icons.warning_amber_rounded,
          size: 16,
          color: covered ? AppTheme.trialTealDeep : AppTheme.trialDanger,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: covered ? AppTheme.trialTealDeep : AppTheme.trialDanger,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomShifts(_RoomPlan plan)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRoomTitle(
            plan.room,
            occupied: true,
            trailing: formatMinutesRange(plan.windowStart, plan.windowEnd),
          ),
          const SizedBox(height: 12),
          _TimeAxis(windowStart: plan.windowStart, windowEnd: plan.windowEnd),
          const SizedBox(height: 4),
          _RoomTimeline(
            windowStart: plan.windowStart,
            windowEnd: plan.windowEnd,
            occupied: plan.occupied,
            covered: plan.covered,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _buildLegendEntry(AppTheme.trialTealDeep, 'Con responsabile'),
              _buildLegendEntry(AppTheme.trialDanger, 'Da coprire'),
              _buildLegendEntry(AppTheme.trialLine.withValues(alpha: 0.5), 'Stanza vuota'),
            ],
          ),
          const SizedBox(height: 14),
          _buildSupervisorCards(plan),
          const SizedBox(height: 14),
          _buildCoverageVerdict(plan),
        ],
      ),
    );
  }

  // The cards share the row between themselves rather than each measuring its
  // own words: measured, the width depends on the font having loaded and on the
  // insets being right to the pixel, and what gave way was the hours.
  Widget _buildSupervisorCards(_RoomPlan plan)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final available = constraints.maxWidth;

        // As many as fit at the width a card would like, and never fewer than
        // one: on a narrow window a card takes the whole row.
        final columns = math.max(
          1,
          (available + _supervisorCardGap) ~/ (_supervisorCardIdealWidth + _supervisorCardGap),
        );

        final width = (available - (columns - 1) * _supervisorCardGap) / columns;

        return Wrap(
          spacing: _supervisorCardGap,
          runSpacing: _supervisorCardGap,
          children: [
            for (final lane in plan.teachers)
              _SupervisorCard(
                key: ValueKey('${plan.room.id}:${lane.teacherTaxCode}'),
                lane: lane,
                hours: _coverageLabel(plan, lane),
                width: width,
                isSelected: plan.supervisors.contains(lane.teacherTaxCode),
                onTap: () => _toggleSupervisor(plan.room.id, lane.teacherTaxCode),
              ),
          ],
        );
      },
    );
  }

  // What choosing them would buy: the hours they are in that room for, which
  // are the hours they teach in it.
  String _coverageLabel(_RoomPlan plan, TeacherLane lane)
  {
    return plan.coverageOf(lane).map((span) => formatMinutesRange(span.$1, span.$2)).join(', ');
  }

  Widget _buildShifts()
  {
    final plans = _plans.where((plan) => !plan.isEmpty).toList();

    if (plans.isEmpty)
    {
      return _buildQuiet('Nessuna stanza occupata.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < plans.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _buildRoomShifts(plans[i]),
        ],
      ],
    );
  }

  // --- the window -----------------------------------------------------------

  ({String question, String hint}) get _guide
  {
    return switch (_stepIndex)
    {
      0 => (
        question: 'A quali stanze sono assegnati i docenti?',
        hint: 'Trascina ogni docente dentro una stanza.',
      ),
      _ => (
        question: 'Chi sono i responsabili?',
        hint: 'Assegna almeno un responsabile a ogni stanza.\nLa presenza dei responsabili deve coprire tutti gli orari di lezione.',
      ),
    };
  }

  void _goTo(int step)
  {
    setState(()
    {
      _movingForward = step > _stepIndex;
      _stepIndex = step.clamp(0, 1);
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final guide = _guide;

    return AppDialogStack(
      eyebrow: 'Passo ${_stepIndex + 1} di 2 · ${formatWeekdayColumnLabel(widget.day)} ${widget.day.year}',
      title: 'Stanze e responsabili',
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'CONFERMA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _confirm,
        ),
      ),
      children: [
        AppCarouselFrame(
          index: _stepIndex,
          movingForward: _movingForward,
          maxContentWidth: _stepWidth,
          canGoBack: _stepIndex > 0,
          canGoForward: _stepIndex < 1,
          onBack: () => _goTo(_stepIndex - 1),
          onForward: () => _goTo(_stepIndex + 1),
          header: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _stepWidth),
              child: AppDialogPill(
                expand: true,
                child: PersonEditGuide(question: guide.question, hint: guide.hint),
              ),
            ),
          ),
          child: AppDialogPill(
            expand: true,
            child: _stepIndex == 0 ? _buildBoard() : _buildShifts(),
          ),
        ),
      ],
    );
  }
}

// Opens the window on the day the calendar is showing.
//
// Answers true where the plan was written, so whoever opened it can say so:
// the confirmation belongs over the calendar the window uncovers, and not over
// the window on its way out.
Future<bool?> showRoomAssignmentWizard({
  required BuildContext context,
  required DateTime day,
  required List<TeacherLane> lanes,
  required List<RoomItem> rooms,
  required List<TeacherRoomAssignmentItem> assignments,
  List<RoomSupervisionItem> supervisions = const [],
  Future<bool> Function({
    required DateTime day,
    required List<TeacherRoomAssignmentItem> assignments,
    required Map<String, int?> rooms,
    required List<PlannedShift> shifts,
    required Function(String) onError,
  })? onSave,
})
{
  return showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'Stanze e responsabili',
    builder: (dialogContext) => RoomAssignmentWizard(
      day: day,
      lanes: lanes,
      rooms: rooms,
      assignments: assignments,
      supervisions: supervisions,
      onSave: onSave,
    ),
  );
}
