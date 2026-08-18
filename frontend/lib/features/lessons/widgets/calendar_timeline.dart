import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../models/person_option_item.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'calendar_lesson_block.dart';
import 'person_avatar.dart';

// The column of names on the left of the track. Grown with the rows: at
// fifty-eight pixels a block and two of them where a teacher takes two pupils at
// once, a face of thirty-four and a name of thirteen read as a caption to
// something else rather than as whose row it is.
const double kTimelineLeadingWidth = 216;

// The strip along the top the hours are written in.
const double kTimelineAxisHeight = 34;

// Under this the axis is too dense to aim at, and the window is recomputed on
// the content alone. Nothing legal can disappear that way: every drop that the
// server would accept falls inside an availability, and the content holds all
// of them.
const double kMinPixelsPerMinute = 1.1;

// How close to an edge the pointer has to get before the list starts moving
// under it, and how far it moves per frame.
const double _autoScrollMargin = 56;
const double _autoScrollStep = 8;

// What the ghost is showing: where the hour would go, and whether the answer
// to it is already on its way to the server.
class _GhostPreview
{
  final LessonPlacement placement;

  // True between the drop and the server's answer, for the cases nothing else
  // covers: a new hour and an hour gaining a pupil have no block on screen yet,
  // so without this the track would go blank for the length of a request.
  final bool isSaving;

  const _GhostPreview(this.placement, {this.isSaving = false});
}

// Moves the list while something is dragged near its edge; Flutter has no such
// thing outside ReorderableListView. onMove does not fire again while the
// pointer sits still, so every tick recomputes the preview from the last global
// position — which lands on a different lane as the content scrolls under it.
class _TimelineAutoScroller
{
  final ScrollController controller;
  final void Function() onTick;

  Timer? _timer;
  double _direction = 0;

  _TimelineAutoScroller({required this.controller, required this.onTick});

  // [distanceToTop] and [distanceToBottom] are how far the pointer is from the
  // two edges of the viewport, in pixels.
  void update({required double distanceToTop, required double distanceToBottom})
  {
    final direction = switch ((distanceToTop < _autoScrollMargin, distanceToBottom < _autoScrollMargin))
    {
      (true, false) => -1.0,
      (false, true) => 1.0,
      _ => 0.0,
    };

    if (direction == _direction)
    {
      return;
    }

    _direction = direction;
    _timer?.cancel();

    if (direction == 0)
    {
      _timer = null;

      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _step());
  }

  void _step()
  {
    if (!controller.hasClients)
    {
      return;
    }

    final position = controller.position;
    final target = (position.pixels + _direction * _autoScrollStep)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if (target == position.pixels)
    {
      stop();

      return;
    }

    position.jumpTo(target);
    onTick();
  }

  void stop()
  {
    _timer?.cancel();
    _timer = null;
    _direction = 0;
  }
}

// The grid behind the lanes. A painter and not seventy Containers, which is a
// tree the layout would walk for seventy lines.
class _AxisLabel extends StatelessWidget
{
  final TimelineMetrics metrics;
  final int minute;
  final bool isHour;

  const _AxisLabel({required this.metrics, required this.minute, required this.isHour});

  @override
  Widget build(BuildContext context)
  {
    return Positioned(
      // Centred on the tick, and let out of the box at either end: the first and
      // last labels would otherwise be clipped in half.
      left: metrics.xOf(minute) - 24,
      width: 48,
      bottom: 6,
      child: Center(
        child: Text(
          formatTimeOfDayShort(timeOfDayFromMinutes(minute)),
          style: GoogleFonts.plusJakartaSans(
            fontSize: isHour ? 11 : 9.5,
            fontWeight: isHour ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.4,
            color: isHour ? AppTheme.trialMutedText : AppTheme.trialMutedText.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// Hours and half hours drawn over the stretches, which cover the grid: an axis
// stopping at the first coloured rectangle cannot be read a block against. Only
// these two — the quarters stay under, as the grid a drag snaps to.
class _TimelineDivisionsPainter extends CustomPainter
{
  final TimelineMetrics metrics;

  const _TimelineDivisionsPainter({required this.metrics});

  @override
  void paint(Canvas canvas, Size size)
  {
    final hour = Paint()
      ..color = AppTheme.trialTealDeep.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    final half = Paint()
      ..color = AppTheme.trialTealDeep.withValues(alpha: 0.14)
      ..strokeWidth = 1;

    for (final minute in metrics.hourTicks())
    {
      final x = metrics.xOf(minute);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hour);
    }

    // Dashed by hand: Flutter draws no dashes, and a solid line here would read
    // as one more hour.
    for (final minute in metrics.halfTicks())
    {
      final x = metrics.xOf(minute);

      for (var y = 0.0; y < size.height; y += 8)
      {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 4, size.height)), half);
      }
    }
  }

  @override
  bool shouldRepaint(_TimelineDivisionsPainter oldDelegate)
  {
    return oldDelegate.metrics.windowStartMinutes != metrics.windowStartMinutes ||
        oldDelegate.metrics.windowEndMinutes != metrics.windowEndMinutes ||
        oldDelegate.metrics.trackWidth != metrics.trackWidth ||
        oldDelegate.metrics.trackHeight != metrics.trackHeight;
  }
}

class _TimelineGridPainter extends CustomPainter
{
  final TimelineMetrics metrics;

  const _TimelineGridPainter({required this.metrics});

  @override
  void paint(Canvas canvas, Size size)
  {
    final hour = Paint()
      ..color = AppTheme.trialLine
      ..strokeWidth = 1;

    final quarter = Paint()
      ..color = AppTheme.trialLine.withValues(alpha: 0.45)
      ..strokeWidth = 1;

    for (final minute in metrics.quarterTicks())
    {
      final x = metrics.xOf(minute);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), quarter);
    }

    for (final minute in metrics.hourTicks())
    {
      final x = metrics.xOf(minute);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hour);
    }

    for (var row = 1; row < metrics.rowCount; row++)
    {
      final y = metrics.topOfRow(row);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), quarter);
    }
  }

  @override
  bool shouldRepaint(_TimelineGridPainter oldDelegate)
  {
    return oldDelegate.metrics.windowStartMinutes != metrics.windowStartMinutes ||
        oldDelegate.metrics.windowEndMinutes != metrics.windowEndMinutes ||
        oldDelegate.metrics.trackWidth != metrics.trackWidth ||
        oldDelegate.metrics.rowCount != metrics.rowCount;
  }
}

// The hours along the top of the track.
class _TimelineAxis extends StatelessWidget
{
  final TimelineMetrics metrics;

  const _TimelineAxis({required this.metrics});

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: kTimelineAxisHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Half hours first, so a whole hour is never covered by one: most
          // lessons start on these. Only where there is room — under forty-four
          // pixels apart the labels touch.
          if (metrics.pixelsPerMinute * 30 >= 44)
            for (final minute in metrics.halfTicks())
              _AxisLabel(
                metrics: metrics,
                minute: minute,
                isHour: false,
              ),
          for (final minute in metrics.hourTicks())
            _AxisLabel(metrics: metrics, minute: minute, isHour: true),
        ],
      ),
    );
  }
}

// What a drag says about itself, as dragOutline answers it. Named because the
// record type appears in three signatures and spelling it out each time hides
// what it is.
typedef _DragOutline = ({(int, int)? window, String mode, Set<String> preferred, Set<String> avoided});

// How a stretch stands to whatever is being carried right now.
enum StretchReach
{
  // Nothing in hand: the stretch is just a stretch.
  idle,

  // The request in hand could be put here.
  open,

  // It could not — the pupil is not there, or the teacher is at home and the
  // pupil is not.
  closed,
}

// One stretch a teacher offered: brighter where a request in hand could go,
// faded where it could not. Modulated and not covered, since a rectangle laid
// over the track would hide the hours the eye is checking against.
class CalendarAvailabilityStretch extends StatelessWidget
{
  final String mode;
  final StretchReach reach;

  const CalendarAvailabilityStretch({
    super.key,
    required this.mode,
    this.reach = StretchReach.idle,
  });

  @override
  Widget build(BuildContext context)
  {
    final accent = lessonAccent(mode);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: switch (reach)
        {
          StretchReach.idle => lessonSurface(mode),
          // Not a different colour, the same one further on: the stretch is
          // being pointed at, not turned into something else.
          StretchReach.open => Color.alphaBlend(accent.withValues(alpha: 0.14), lessonSurface(mode)),
          StretchReach.closed => lessonSurface(mode).withValues(alpha: 0.35),
        },
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: switch (reach)
          {
            StretchReach.idle => accent.withValues(alpha: 0.28),
            StretchReach.open => accent.withValues(alpha: 0.85),
            StretchReach.closed => accent.withValues(alpha: 0.1),
          },
          width: reach == StretchReach.open ? 1.6 : 1,
        ),
      ),
    );
  }
}

// A stretch offered both ways, hatched in the second colour over the first: a
// band along the edge read as an underline flagging those hours, where a hatch
// reads as a second thing true of the same area. Under the hours, so it never
// crosses anything anybody has to read.
class _OnlineAlsoHatch extends StatelessWidget
{
  final StretchReach reach;

  const _OnlineAlsoHatch({this.reach = StretchReach.idle});

  @override
  Widget build(BuildContext context)
  {
    return ClipRRect(
      // Named, because a texture is the one thing on this screen that cannot be
      // found by what it is made of.
      key: const ValueKey('online-also'),
      borderRadius: BorderRadius.circular(8),
      child: CustomPaint(
        painter: _OnlineAlsoHatchPainter(
          alpha: switch (reach)
          {
            StretchReach.idle => 0.18,
            StretchReach.open => 0.34,
            StretchReach.closed => 0.06,
          },
        ),
      ),
    );
  }
}

class _OnlineAlsoHatchPainter extends CustomPainter
{
  final double alpha;

  const _OnlineAlsoHatchPainter({required this.alpha});

  // Far enough apart to stay a texture rather than a fill, close enough that a
  // quarter of an hour of stretch carries a line or two of it.
  static const double _spacing = 9;

  @override
  void paint(Canvas canvas, Size size)
  {
    final paint = Paint()
      ..color = lessonAccent(kOnlineMode).withValues(alpha: alpha)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Forty-five degrees, bottom left to top right, starting far enough off the
    // left edge that the first lines still cross the corner.
    for (var x = -size.height; x < size.width; x += _spacing)
    {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_OnlineAlsoHatchPainter oldDelegate) => oldDelegate.alpha != alpha;
}

// The two edges of the hours a pupil is there for, as dashed lines: it says
// where the window is without painting over anything inside it.
class _PresenceBoundsPainter extends CustomPainter
{
  final TimelineMetrics metrics;
  final (int, int)? presence;

  const _PresenceBoundsPainter({required this.metrics, this.presence});

  @override
  void paint(Canvas canvas, Size size)
  {
    final window = presence;

    if (window == null)
    {
      return;
    }

    final paint = Paint()
      ..color = AppTheme.trialTealDeep.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;

    for (final minute in [window.$1, window.$2])
    {
      if (minute <= metrics.windowStartMinutes || minute >= metrics.windowEndMinutes)
      {
        continue;
      }

      final x = metrics.xOf(minute);

      // Dashed by hand: Flutter draws no dashes, and a solid line here would
      // read as one more hour boundary among the ones the grid already has.
      for (var y = 0.0; y < size.height; y += 9)
      {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 5, size.height)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PresenceBoundsPainter oldDelegate)
  {
    return oldDelegate.presence != presence ||
        oldDelegate.metrics.windowStartMinutes != metrics.windowStartMinutes ||
        oldDelegate.metrics.trackWidth != metrics.trackWidth;
  }
}

// A teacher's face, with a ring and a badge where the request in hand names
// them: a star for somebody the pupil asked for, a crossed circle for somebody
// they would rather avoid.
class _MarkedAvatar extends StatelessWidget
{
  final PersonOptionItem teacher;
  final ({bool preferred, bool avoided}) standing;

  const _MarkedAvatar({required this.teacher, required this.standing});

  // As large as the row will hold, once the two lines beside the face have
  // taken their worst case. The ring and the badge are drawn in the six pixels
  // around it, which is why the box is larger than the circle.
  static const double _size = 62;

  @override
  Widget build(BuildContext context)
  {
    final marked = standing.preferred || standing.avoided;
    final accent = standing.preferred ? kPreferredTeacherColor : kAvoidedTeacherColor;

    return SizedBox(
      // Room for the badge to sit on the edge of the circle without the row
      // growing when it appears: the whole column would shift by two pixels
      // every time a card is picked up.
      width: _size + 6,
      height: _size + 6,
      child: Stack(
        children: [
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: marked ? accent : accent.withValues(alpha: 0),
                  width: 2,
                ),
              ),
              child: PersonAvatar(person: teacher, size: _size - 8),
            ),
          ),
          if (marked)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  standing.preferred ? Icons.star_rounded : Icons.do_not_disturb_on_rounded,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// The name at the head of a lane, with what the teacher offered under it.
class _LaneHeader extends StatelessWidget
{
  final TeacherLane lane;
  final int bandStart;
  final int bandEnd;

  // What is being carried, so the row can say whether this teacher is one the
  // pupil asked for or one they would rather avoid. It is the moment the answer
  // is worth having: the choice is being made now, not read back later.
  final ValueListenable<CarriedRequest?>? carried;

  const _LaneHeader({
    required this.lane,
    required this.bandStart,
    required this.bandEnd,
    this.carried,
  });

  // Which of the two lists this teacher is on, for whatever is in hand — a
  // request out of the panel or an hour already placed. Both name pupils, and
  // both pupils have named teachers.
  ({bool preferred, bool avoided}) _standingFor(CalendarDragPayload? payload)
  {
    if (payload == null)
    {
      return (preferred: false, avoided: false);
    }

    final outline = dragOutline(payload, bandStart: bandStart, bandEnd: bandEnd);

    return (
      preferred: outline.preferred.contains(lane.teacherTaxCode),
      avoided: outline.avoided.contains(lane.teacherTaxCode),
    );
  }

  // What the teacher offered, per mode, as a glyph and a duration.
  List<({String mode, int minutes})> get _offered
  {
    final offered = <({String mode, int minutes})>[];

    for (final mode in const [kPresenceMode, kOnlineMode])
    {
      final spans = lane.spansIn(mode, bandStart, bandEnd);

      if (spans.isEmpty)
      {
        continue;
      }

      offered.add((mode: mode, minutes: spans.fold<int>(0, (total, span) => total + span.$2 - span.$1)));
    }

    return offered;
  }

  @override
  Widget build(BuildContext context)
  {
    final listenable = carried;

    if (listenable == null)
    {
      return _buildHeader(const (preferred: false, avoided: false));
    }

    return ValueListenableBuilder<CarriedRequest?>(
      valueListenable: listenable,
      builder: (context, carried, _) => _buildHeader(_standingFor(carried?.payload)),
    );
  }

  Widget _buildHeader(({bool preferred, bool avoided}) standing)
  {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          // On the face and not the row: a tinted row shouts about a person
          // while covering nothing useful, where a ring and a badge is the shape
          // every app uses to qualify somebody.
          _MarkedAvatar(teacher: lane.teacher, standing: standing),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lane.teacher.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppTheme.trialOcean,
                  ),
                ),
                const SizedBox(height: 3),
                if (_offered.isEmpty)
                  Text(
                    'Nessuna disponibilità',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: AppTheme.trialMutedText,
                    ),
                  )
                else
                  // One line per mode: spelled out, a pair is wider than the
                  // column. The word as well as the glyph, since this is the one
                  // place the mode is said for the whole row — on the track it
                  // was repeated per stretch and covered by the hours.
                  for (final offer in _offered)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(lessonModeIcon(offer.mode), size: 13, color: lessonAccent(offer.mode)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${modeLabel(offer.mode)} · ${formatMinutes(offer.minutes)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                color: lessonAccent(offer.mode),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// One hour of a row, and the rectangle it is drawn in.
//
// Named rather than passed as four numbers because it is what a row is handed a
// list of, and what it keeps a copy of for the hours that have just left it.
typedef PlacedLesson = ({LessonItem lesson, double left, double width, double top});

// Three numbers and not one. Arriving is longest, since it is what the eye
// should follow; leaving is quicker, or the rectangle reads as the calendar not
// having heard; travel sits between.
const Duration _blockArrival = Duration(milliseconds: 220);
const Duration _blockDeparture = Duration(milliseconds: 200);
const Duration _blockTravel = Duration(milliseconds: 200);

// The hours of one teacher's row, with their coming and going drawn.
//
// A widget of its own because it is the one thing here that has to remember a
// frame ago: an hour fading out is an hour no longer in the data, kept on
// screen because something has to say where it went. Three answers — arrives,
// departs, travels — and every gesture is made of them.
//
// Splitting one hour in two is the three at once, and it decides how they are
// drawn: the survivor travels to its shorter length while the freed part
// arrives **under** it, so the retreating right edge uncovers the new piece at
// exactly the rate the old one gives the minutes up. Drawn over instead, the
// piece appears at full length beside a block that is still long.
class _LaneBlocks extends StatefulWidget
{
  final List<PlacedLesson> placed;

  // The block itself, which is the timeline's business: what may be dragged,
  // what opens a window, which hours are worth a mark.
  final Widget Function(PlacedLesson placed) builder;

  // The hour just carried clear of the calendar. It leaves from the strength
  // the hand left it at: brightening back to full in the frame before it
  // disappears is the one thing this gesture must not look like.
  final int? thrownAway;

  const _LaneBlocks({
    super.key,
    required this.placed,
    required this.builder,
    this.thrownAway,
  });

  @override
  State<_LaneBlocks> createState() => _LaneBlocksState();
}

class _LaneBlocksState extends State<_LaneBlocks>
{
  // Where the hours that have left last stood, and how visible they were when
  // they went. The strength is caught at the moment of leaving and not read as
  // it fades: what says it is true of one frame.
  final Map<int, ({PlacedLesson placed, double from})> _leaving = {};

  // And the ones that were not on the row a frame ago, which are the ones drawn
  // arriving. Held for as long as the block lives rather than cleared when the
  // fade ends: it is read once, when the block is first built, and clearing it
  // would only churn the order the row is drawn in.
  final Set<int> _arriving = {};

  @override
  void didUpdateWidget(_LaneBlocks oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    final was = {for (final entry in oldWidget.placed) entry.lesson.id: entry};
    final now = {for (final entry in widget.placed) entry.lesson.id: entry};

    final gone = [for (final id in was.keys) if (!now.containsKey(id)) id];

    for (final id in now.keys)
    {
      // Back before it had finished going. It happens on a refusal: the hour was
      // taken off the calendar, the server would not have it, and the page put
      // it back.
      _leaving.remove(id);

      if (was.containsKey(id))
      {
        continue;
      }

      // The same hour under a new number. Everything is drawn under a negative
      // id before the server sees it and replaced by the answer a round trip
      // later, which is a block leaving and another arriving at the same
      // rectangle: read literally, every hour placed would fade in twice.
      final replaced = gone.where((other) => _isSameRectangle(was[other]!, now[id]!)).firstOrNull;

      if (replaced != null)
      {
        gone.remove(replaced);

        continue;
      }

      _arriving.add(id);
    }

    for (final id in gone)
    {
      _leaving[id] = (
        placed: was[id]!,
        from: id == widget.thrownAway ? kLeftBehindOpacity : 1.0,
      );
    }

    // Nothing is remembered about an hour that is neither on the row nor on its
    // way off it.
    _arriving.removeWhere((id) => !now.containsKey(id));
  }

  static bool _isSameRectangle(PlacedLesson a, PlacedLesson b)
  {
    return a.left == b.left && a.width == b.width && a.top == b.top;
  }

  // An hour that is on the row: at its own rectangle, travelling there where it
  // has just been given another one.
  Widget _buildStanding(PlacedLesson placed)
  {
    final id = placed.lesson.id;

    return AnimatedPositioned(
      // Keyed by the lesson and not left to its place in the list: the lessons
      // of a row are ordered by hour, so moving one reorders them, and without
      // a key the two blocks would swap the state they carry — which hover is
      // lit, which edge is being dragged — under the pointer.
      key: ValueKey(id),
      duration: _blockTravel,
      curve: Curves.easeOutCubic,
      left: placed.left,
      width: placed.width,
      top: placed.top,
      height: kTimelineBlockHeight,
      child: TweenAnimationBuilder<double>(
        // The wrapper is there whether the hour is arriving or not, and only the
        // start of the tween differs. Wrapping one and not the other would change
        // the shape of the tree under the key the moment the fade ended, which
        // rebuilds the block and loses what it was holding.
        tween: Tween(begin: _arriving.contains(id) ? 0 : 1, end: 1),
        duration: _blockArrival,
        curve: Curves.easeOut,
        builder: _fade,
        child: widget.builder(placed),
      ),
    );
  }

  // An hour on its way out of where it stood, deaf to the pointer throughout:
  // one that still answers a click after being thrown away can be hit by
  // accident.
  Widget _buildLeaving(PlacedLesson placed, double from)
  {
    return Positioned(
      key: ValueKey('leaving-${placed.lesson.id}'),
      left: placed.left,
      width: placed.width,
      top: placed.top,
      height: kTimelineBlockHeight,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: from, end: 0.0),
          duration: _blockDeparture,
          curve: Curves.easeIn,
          // Dropped when it has finished going, and not on a timer of its own:
          // the animation is the thing that knows when it is over.
          onEnd: () => setState(() => _leaving.remove(placed.lesson.id)),
          builder: _fade,
          child: widget.builder(placed),
        ),
      ),
    );
  }

  // A fade and nothing else. An hour coming up from nine tenths of itself is an
  // hour drawn at a size it is not: the rectangle it is going to keep is the one
  // it is drawn at from the first frame, and only its presence changes.
  static Widget _fade(BuildContext context, double value, Widget? child)
  {
    return Opacity(opacity: value, child: child);
  }

  @override
  Widget build(BuildContext context)
  {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Underneath, both of them, and for the same reason: what is leaving and
        // what is arriving are what an hour still on the row is being read
        // against. See the class comment for the split, which is where it shows.
        for (final entry in _leaving.values) _buildLeaving(entry.placed, entry.from),
        for (final placed in widget.placed)
          if (_arriving.contains(placed.lesson.id)) _buildStanding(placed),
        for (final placed in widget.placed)
          if (!_arriving.contains(placed.lesson.id)) _buildStanding(placed),
      ],
    );
  }
}

// The teachers of one day in one band. Lanes of one height on purpose: which
// row a position falls on is a division and not a search, and the air between
// rows is padding inside a row so there are no dead bands. Every drop the
// calendar accepts is resolved that way.
class CalendarTimeline extends StatefulWidget
{
  final List<TeacherLane> lanes;
  final TimelineMetrics metrics;
  final int bandStart;
  final int bandEnd;

  // Which sub-lane each lesson is drawn in, by id. Worked out by the caller,
  // which needs the same answer to size the rows.
  final Map<int, int> subLaneOf;

  // Which lessons deserve the amber dot, by id. Worked out by the caller from
  // the bookings rather than read off the server, so that it survives a
  // reload: the server only says it on the answer to the write.
  final Set<int> warnedLessonIds;

  // And which ones landed on a teacher a pupil asked for.
  final Set<int> preferredLessonIds;

  final void Function(LessonItem lesson)? onLessonTap;

  // Where would this land, and may it. Called on every pointer move while
  // something is being dragged, which is why the caller builds its index once
  // and this only reads it.
  final LessonPlacement Function(CalendarDragPayload payload, String teacherTaxCode, int startMinutes)? onPlan;

  // Let go on a placement that passed; refusals are answered under the pointer,
  // where they can still be acted on. Awaited, so the ghost can stay put.
  final Future<void> Function(CalendarDragPayload payload, LessonPlacement placement)? onDrop;

  // The same question for a block being stretched from one of its edges. Kept
  // apart from [onPlan] because a resize is a local gesture: it never changes
  // lane, and there is no drop target involved.
  final LessonPlacement Function(LessonItem lesson, int startMinutes, int endMinutes)? onPlanResize;

  // A placement was refused and the pointer let go anyway.
  final void Function(String refusal)? onRefused;

  // What is being carried, owned by the tab and written by both sides: the
  // panel is outside this widget, so a card picked up there would otherwise be
  // heard about only once the pointer reaches the track.
  final ValueListenable<CarriedRequest?>? carried;

  // An hour was let go away from the track. What that means is deletion, and the
  // caller is the one that confirms it.
  final void Function(LessonItem lesson)? onDroppedOutside;

  // A drag of one of these blocks began, or ended. Written to the same notifier
  // the panel writes to, so an hour being moved lights the track up exactly the
  // way a request out of the panel does.
  final void Function(CalendarDragPayload? payload)? onDragChanged;

  // Where what is being carried would land, read by this track's blocks and by
  // the panel's cards: a notifier handed in rather than kept private, since the
  // two feedbacks say the same thing and must not disagree.
  final ValueNotifier<CarriedPlacement>? carriedAt;

  // The scroll view the track lives inside, and the box that measures its
  // visible height. Both are needed for the list to move on its own when the
  // pointer reaches an edge with a lane still to go; left out, the drag simply
  // does not auto-scroll.
  final ScrollController? scrollController;
  final GlobalKey? viewportKey;

  const CalendarTimeline({
    super.key,
    required this.lanes,
    required this.metrics,
    required this.bandStart,
    required this.bandEnd,
    this.subLaneOf = const {},
    this.warnedLessonIds = const {},
    this.preferredLessonIds = const {},
    this.onLessonTap,
    this.onPlan,
    this.onPlanResize,
    this.onDrop,
    this.onRefused,
    this.carried,
    this.onDroppedOutside,
    this.onDragChanged,
    this.carriedAt,
    this.scrollController,
    this.viewportKey,
  });

  @override
  State<CalendarTimeline> createState() => _CalendarTimelineState();
}

class _CalendarTimelineState extends State<CalendarTimeline>
{
  // The Stack the lanes are drawn in: its RenderBox turns a global pointer
  // position into a lane and a minute. The DragTarget is inside the scroll view,
  // so globalToLocal already has the offset — nothing adds it by hand.
  final GlobalKey _trackKey = GlobalKey();

  // Not setState: the preview changes at pointer frequency, and rebuilding the
  // whole track sixty times a second to move one rectangle is how a drag starts
  // to stutter. Only the ghost layer listens.
  final ValueNotifier<_GhostPreview?> _preview = ValueNotifier(null);

  // How many times an outline has appeared out of nothing, used as its key to
  // tell two kinds of change apart: moved a quarter along it should travel,
  // shown again after being away it should simply be where it now is. A new key
  // rebuilds the AnimatedPositioned, which is the second case.
  int _ghostEpoch = 0;

  // The one way the outline is put up or taken down, so the epoch above cannot
  // fall out of step with what is on screen.
  void _setPreview(_GhostPreview? preview)
  {
    if (preview != null && _preview.value == null)
    {
      _ghostEpoch++;
    }

    _preview.value = preview;
  }

  _TimelineAutoScroller? _autoScroller;

  // Where the pointer is over, as what is being carried needs to hear it. The
  // caller's where there is one, so the panel's cards read the same value.
  final ValueNotifier<CarriedPlacement> _ownCarriedAt = ValueNotifier(CarriedPlacement.idle);

  ValueNotifier<CarriedPlacement> get _carriedAt => widget.carriedAt ?? _ownCarriedAt;

  // The last place the pointer was, in global coordinates. It is what the
  // auto-scroller replays on every tick: the pointer has not moved, but the
  // lanes under it have.
  CalendarDragPayload? _carried;
  Offset? _lastPointer;

  // The hour last carried clear of the calendar, which is the gesture that takes
  // one out of the day. Read by the row it is about to leave, so that it goes on
  // fading from where the hand left it instead of coming back to full strength
  // for the frame before it disappears.
  int? _thrownAway;

  // The lane and minute the last plan was made for: onMove fires at pointer
  // frequency, and without this the whole rule set runs again for three pixels
  // inside the same quarter of an hour.
  (int, int)? _lastPlanned;

  @override
  void initState()
  {
    super.initState();
    _attachAutoScroller();
  }

  @override
  void didUpdateWidget(CalendarTimeline oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController)
    {
      _autoScroller?.stop();
      _attachAutoScroller();
    }
  }

  void _attachAutoScroller()
  {
    final controller = widget.scrollController;

    _autoScroller = controller == null
        ? null
        : _TimelineAutoScroller(controller: controller, onTick: _replayLastPointer);
  }

  void _replayLastPointer()
  {
    final payload = _carried;
    final pointer = _lastPointer;

    if (payload == null || pointer == null)
    {
      return;
    }

    // The pointer has not moved, the lanes under it have — so the memo of which
    // slot was last planned is stale by definition and gets cleared.
    _lastPlanned = null;

    _showPlacement(_planAt(payload, pointer));
  }

  // Where what the pointer is over becomes what is drawn. The refusal is not
  // announced from here but travels on [carriedAt], which goes back to nothing
  // when the pointer moves somewhere better: a callback could only say "here is
  // another one". [onRefused] is for the release.
  void _showPlacement(LessonPlacement? placement)
  {
    if (placement?.signature != _preview.value?.placement.signature)
    {
      _setPreview(placement == null ? null : _GhostPreview(placement));
    }

    final lane = placement == null
        ? null
        : lanes.where((row) => row.teacherTaxCode == placement.teacherTaxCode).firstOrNull;

    _carriedAt.value = CarriedPlacement(
      span: placement == null ? null : (placement.startMinutes, placement.endMinutes),
      refusal: placement?.refusal,
      alongside: lane != null && placement != null && _wouldRunAlongside(lane, placement),
      kind: placement?.kind,
    );
  }

  void _endDrag()
  {
    _autoScroller?.stop();
    _carried = null;
    _lastPointer = null;
    _lastPlanned = null;
    _setPreview(null);
    _carriedAt.value = CarriedPlacement.idle;
  }

  @override
  void dispose()
  {
    _autoScroller?.stop();
    _preview.dispose();
    _ownCarriedAt.dispose();
    super.dispose();
  }

  TimelineMetrics get metrics => widget.metrics;

  List<TeacherLane> get lanes => widget.lanes;

  int get bandStart => widget.bandStart;

  int get bandEnd => widget.bandEnd;

  RenderBox? get _trackBox => _trackKey.currentContext?.findRenderObject() as RenderBox?;

  // The left edge in both cases, for two reasons: a card is carried with the
  // pointer as anchor, so its edge is the pointer; a block is carried with its
  // own top-left, so the edge follows the grip without measuring it.
  LessonPlacement? _planAt(CalendarDragPayload payload, Offset globalPosition)
  {
    final plan = widget.onPlan;
    final box = _trackBox;

    if (plan == null || box == null)
    {
      return null;
    }

    final local = box.globalToLocal(globalPosition);
    final row = metrics.rowAt(local.dy);

    if (row == null)
    {
      return null;
    }

    return plan(payload, lanes[row].teacherTaxCode, metrics.snappedMinutesAt(local.dx));
  }

  // Read off the absolute position and not accumulated from the deltas, which
  // would drift a quarter of an hour over a long drag.
  void _onEdgeDrag(LessonItem lesson, bool isLeftEdge, Offset globalPosition)
  {
    final resize = widget.onPlanResize;
    final box = _trackBox;

    if (resize == null || box == null)
    {
      return;
    }

    final minute = metrics.snappedMinutesAt(box.globalToLocal(globalPosition).dx);

    _showPlacement(isLeftEdge
        ? resize(lesson, minute, lesson.endMinutes)
        : resize(lesson, lesson.startMinutes, minute));
  }

  void _onEdgeDragEnd()
  {
    final placement = _preview.value?.placement;
    _setPreview(null);

    if (placement == null)
    {
      _carriedAt.value = CarriedPlacement.idle;

      return;
    }

    // Before the hand is emptied, for the reason given in _onAccept.
    if (!placement.isValid)
    {
      widget.onRefused?.call(placement.refusal ?? kTooShortRefusal);
      _carriedAt.value = CarriedPlacement.idle;

      return;
    }

    _carriedAt.value = CarriedPlacement.idle;

    final lesson = lanes
        .expand((lane) => lane.lessons)
        .where((lesson) => lesson.id == placement.lessonId)
        .firstOrNull;

    if (lesson != null)
    {
      widget.onDrop?.call(LessonDragPayload(lesson: lesson), placement);
    }
  }

  void _onMove(DragTargetDetails<CalendarDragPayload> details)
  {
    _carried = details.data;
    _lastPointer = details.offset;

    if (_hasMovedToNewSlot(details.offset))
    {
      _showPlacement(_planAt(details.data, details.offset));
    }

    final viewport = _viewportBox;

    if (viewport != null)
    {
      final local = viewport.globalToLocal(details.offset);

      _autoScroller?.update(
        distanceToTop: local.dy,
        distanceToBottom: viewport.size.height - local.dy,
      );
    }
  }

  RenderBox? get _viewportBox => widget.viewportKey?.currentContext?.findRenderObject() as RenderBox?;

  // Whether the pointer has reached a lane or a quarter of an hour it was not
  // in before. Everything the plan depends on is one of those two.
  bool _hasMovedToNewSlot(Offset globalPosition)
  {
    final box = _trackBox;

    if (box == null)
    {
      return true;
    }

    final local = box.globalToLocal(globalPosition);
    final row = metrics.rowAt(local.dy);

    if (row == null)
    {
      _lastPlanned = null;

      return true;
    }

    final slot = (row, metrics.snappedMinutesAt(local.dx));

    if (slot == _lastPlanned)
    {
      return false;
    }

    _lastPlanned = slot;

    return true;
  }

  Future<void> _onAccept(DragTargetDetails<CalendarDragPayload> details) async
  {
    final placement = _planAt(details.data, details.offset) ?? _preview.value?.placement;

    _autoScroller?.stop();
    _carried = null;
    _lastPointer = null;
    _lastPlanned = null;

    if (placement == null)
    {
      _setPreview(null);
      _carriedAt.value = CarriedPlacement.idle;

      return;
    }

    // The refusal is handed over before the hand is emptied, and the order is
    // the whole point: what is on screen is the banner this gesture raised, and
    // the caller is being given the chance to let it stand rather than take it
    // down and put an identical one back up.
    if (!placement.isValid)
    {
      _setPreview(null);
      widget.onRefused?.call(placement.refusal ?? kOutsideAvailabilityRefusal);
      _carriedAt.value = CarriedPlacement.idle;

      return;
    }

    _carriedAt.value = CarriedPlacement.idle;

    // A move or resize is already drawn when the request goes out, so the ghost
    // has nothing left to say. A new hour has no block yet, and there the ghost
    // stays until the answer arrives: an empty stretch of track for the length
    // of a request reads as the drop having been thrown away.
    final needsGhost = placement.kind == LessonPlacementKind.create;

    _setPreview(needsGhost ? _GhostPreview(placement, isSaving: true) : null);

    await widget.onDrop?.call(details.data, placement);

    if (mounted)
    {
      _setPreview(null);
    }
  }

  // Where the teacher offered to be, drawn under the hours at the full height
  // of the row: rows grow to hold stacked hours, so halves per mode would line
  // up with nothing. Both modes over one stretch put the online one in a band
  // along the bottom.
  //
  // Nothing is written on the stretches: the mode belongs beside the teacher's
  // name, said once for the row, or it is repeated per stretch and covered by
  // the blocks.
  //
  // [request] modulates each stretch — brighter where it could go — rather than
  // laying a shade over the hours the eye is checking against.
  List<Widget> _laneBackground(TeacherLane lane, double rowHeight, _DragOutline? outline, Set<String> competent)
  {
    final layers = <Widget>[];
    final presence = lane.spansIn(kPresenceMode, bandStart, bandEnd);
    final online = lane.spansIn(kOnlineMode, bandStart, bandEnd);
    final window = outline?.window;

    StretchReach reachOf(String mode, (int, int) span)
    {
      if (outline == null || window == null)
      {
        return StretchReach.idle;
      }

      // A teacher who cannot teach this has no stretch that would take it, so
      // the whole row goes quiet: what is left lit is exactly the list of people
      // the hour could go to.
      if (!competent.contains(lane.teacherTaxCode))
      {
        return StretchReach.closed;
      }

      // A teacher at home cannot have a pupil in the building in front of them,
      // so an online stretch is only open to a remote hour.
      if (mode == kOnlineMode && outline.mode != kOnlineMode)
      {
        return StretchReach.closed;
      }

      final shared = intersectSpan(span.$1, span.$2, window.$1, window.$2);

      return shared != null && shared.$2 - shared.$1 >= kMinimumBandMinutes
          ? StretchReach.open
          : StretchReach.closed;
    }

    for (final span in presence)
    {
      layers.add(Positioned(
        left: metrics.xOf(span.$1),
        width: metrics.widthOf(span.$1, span.$2),
        top: 3,
        height: rowHeight - 6,
        child: CalendarAvailabilityStretch(
          mode: kPresenceMode,
          reach: reachOf(kPresenceMode, span),
        ),
      ));
    }

    for (final span in online)
    {
      // Where the teacher is also in the building over the same minutes, the
      // online offer is a hatch over the stretch that is already there: two
      // surfaces stacked would only muddy the colour of both.
      final alsoPresent = presence.any((other) => spansOverlap(span.$1, span.$2, other.$1, other.$2));

      layers.add(Positioned(
        left: metrics.xOf(span.$1),
        width: metrics.widthOf(span.$1, span.$2),
        top: 3,
        height: rowHeight - 6,
        child: alsoPresent
            ? _OnlineAlsoHatch(reach: reachOf(kOnlineMode, span))
            : CalendarAvailabilityStretch(
                mode: kOnlineMode,
                reach: reachOf(kOnlineMode, span),
              ),
      ));
    }

    return layers;
  }

  // One builder for the whole track and not one per row: the answer depends on
  // a single value, and forty listeners would rebuild for one notification.
  Widget _buildBackgroundLayer()
  {
    final listenable = widget.carried;

    if (listenable == null)
    {
      return _backgroundStack(null, const {});
    }

    return ValueListenableBuilder<CarriedRequest?>(
      valueListenable: listenable,
      builder: (context, carried, _) => _backgroundStack(
        carried == null ? null : dragOutline(carried.payload, bandStart: bandStart, bandEnd: bandEnd),
        carried?.competentTeachers ?? const {},
      ),
    );
  }

  Widget _backgroundStack(_DragOutline? outline, Set<String> competent)
  {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            children: [
              for (var index = 0; index < lanes.length; index++)
                Positioned(
                  top: metrics.topOfRow(index),
                  left: 0,
                  right: 0,
                  height: metrics.heightOfRow(index),
                  child: Stack(
                    children: _laneBackground(lanes[index], metrics.heightOfRow(index), outline, competent),
                  ),
                ),
              // The two edges of the pupil's own hours, over the stretches and
              // under the lessons: it is a boundary, and a boundary belongs on
              // top of the surfaces it bounds.
              Positioned.fill(
                child: CustomPaint(
                  painter: _PresenceBoundsPainter(metrics: metrics, presence: outline?.window),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The top of a sub-lane inside its row.
  static double _topOfSubLane(int subLane)
  {
    return kTimelineRowPadding + subLane * (kTimelineBlockHeight + kTimelineSubLaneGap);
  }

  // Every hour of a row and where it is drawn in it, for [_LaneBlocks] to
  // animate between one answer and the next.
  List<PlacedLesson> _lanePlacements(TeacherLane lane)
  {
    return [
      for (final lesson in lane.lessons)
        (
          lesson: lesson,
          left: metrics.xOf(lesson.startMinutes),
          width: metrics.widthOf(lesson.startMinutes, lesson.endMinutes),
          top: _topOfSubLane(widget.subLaneOf[lesson.id] ?? 0),
        ),
    ];
  }

  Widget _buildLessonBlock(PlacedLesson placed)
  {
    final lesson = placed.lesson;

    return CalendarLessonBlock(
      lesson: lesson,
      width: placed.width,
      hasWarning: widget.warnedLessonIds.contains(lesson.id),
      isPreferred: widget.preferredLessonIds.contains(lesson.id),
      // Nothing may be asked of an hour the server has not answered for yet:
      // it has no id there, so every one of these would be a request about a
      // lesson that does not exist. The wait is one round trip long.
      onTap: widget.onLessonTap == null || lesson.isProvisional ? null : () => widget.onLessonTap!(lesson),
      isMovable: !lesson.isPublished && !lesson.isProvisional && widget.onPlan != null,
      carriedAt: _carriedAt,
      onDragChanged: (payload)
      {
        // A hand on something else has nothing to do with the last hour thrown
        // away, and this is where that is forgotten. Set on the throw, cleared
        // on the next pick-up: between the two it is read exactly once, by the
        // row the hour is leaving.
        if (payload != null)
        {
          _thrownAway = null;
        }

        widget.onDragChanged?.call(payload);
      },
      onDroppedOutside: widget.onDroppedOutside == null
          ? null
          : ()
            {
              _carriedAt.value = CarriedPlacement.idle;
              _thrownAway = lesson.id;
              widget.onDroppedOutside!(lesson);
            },
      onEdgeDrag: widget.onPlanResize == null
          ? null
          : (isLeftEdge, position) => _onEdgeDrag(lesson, isLeftEdge, position),
      onEdgeDragEnd: _onEdgeDragEnd,
    );
  }

  // The first sub-lane free over the proposed stretch — the same greedy answer
  // the row will give once the hour is written, so the outline is on the line
  // the hour ends up on. Keeping the line an hour already had left the outline
  // on a line it was about to leave, since a stacked hour is on the second line
  // because of the one it overlaps.
  int _ghostSubLane(TeacherLane lane, LessonPlacement placement)
  {
    final taken = <int>{};

    for (final lesson in lane.lessons)
    {
      // Neither the hour being rewritten nor the one a merge is about to remove:
      // both are still drawn where they are, and neither will be there once this
      // is written. Counting the moved hour's own old place was what pushed the
      // outline onto a second line whenever it was nudged along its own row.
      if (lesson.id == placement.lessonId || lesson.id == placement.deleteLessonId)
      {
        continue;
      }

      if (spansOverlap(placement.startMinutes, placement.endMinutes, lesson.startMinutes, lesson.endMinutes))
      {
        taken.add(widget.subLaneOf[lesson.id] ?? 0);
      }
    }

    var subLane = 0;

    while (taken.contains(subLane))
    {
      subLane++;
    }

    return subLane;
  }

  // Whether the outline covers an hour on screen — a different question from
  // the one below, since the other half of a merge stays there and is not
  // somebody to be alongside. Left out: the hour in the hand, which is leaving,
  // and the one being resized, which is not drawn while its edge is held.
  bool _liesOnAnHour(TeacherLane lane, LessonPlacement placement)
  {
    final carried = _carried;

    final leaving = switch (carried)
    {
      LessonDragPayload(:final lesson) => lesson.id,
      _ => placement.kind == LessonPlacementKind.resize ? placement.lessonId : null,
    };

    for (final lesson in lane.lessons)
    {
      if (lesson.id == leaving)
      {
        continue;
      }

      if (spansOverlap(placement.startMinutes, placement.endMinutes, lesson.startMinutes, lesson.endMinutes))
      {
        return true;
      }
    }

    return false;
  }

  // Whether the hour would run alongside one already there. Allowed, so not a
  // refusal, but not ordinary either — and an outline near a block says nothing
  // about which of the two it means.
  bool _wouldRunAlongside(TeacherLane lane, LessonPlacement placement)
  {
    for (final lesson in lane.lessons)
    {
      if (lesson.id == placement.lessonId || lesson.id == placement.deleteLessonId)
      {
        continue;
      }

      if (spansOverlap(placement.startMinutes, placement.endMinutes, lesson.startMinutes, lesson.endMinutes))
      {
        return true;
      }
    }

    return false;
  }

  // Nothing at all while something is carried: the outline is under the block
  // or card in the hand, and a sentence written behind what you are looking at
  // is a sentence nobody reads. The words are left for the two cases with an
  // empty hand — an edge being dragged, and the wait for the server.
  String? _ghostLabel(LessonPlacement placement)
  {
    if (_carried != null)
    {
      return null;
    }

    return '${formatTimeRange(
      timeOfDayFromMinutes(placement.startMinutes),
      timeOfDayFromMinutes(placement.endMinutes),
    )} · ${formatMinutes(placement.minutes)}';
  }

  // Kept inside the row whatever sub-lane it would take: the row is as tall as
  // the hours already written, so an outline claiming a line that does not exist
  // yet was drawn over the teacher underneath.
  double _ghostTop(int row, int subLane)
  {
    final floor = metrics.heightOfRow(row) - kTimelineRowPadding - kTimelineBlockHeight;

    return math.min(_topOfSubLane(subLane), math.max(kTimelineRowPadding, floor));
  }

  // Matched on the lane and the two ends, which is all the outline knows and
  // all it needs: what it looks for is the page's own drawing of this drop.
  bool _hourIsDrawnFor(LessonPlacement placement)
  {
    for (final lane in lanes)
    {
      if (lane.teacherTaxCode != placement.teacherTaxCode)
      {
        continue;
      }

      for (final lesson in lane.lessons)
      {
        if (lesson.startMinutes == placement.startMinutes && lesson.endMinutes == placement.endMinutes)
        {
          return true;
        }
      }
    }

    return false;
  }

  // The block that follows the pointer, over everything else and answering
  // nothing: a ghost that took a hit test would steal the drop from the track
  // under it.
  Widget _buildGhostLayer()
  {
    return Positioned.fill(
      child: IgnorePointer(
        // Its own layer: the ghost moves a dozen times a second and the grid
        // under it never does, and without this they repaint together.
        child: RepaintBoundary(
          child: ValueListenableBuilder<_GhostPreview?>(
          valueListenable: _preview,
          builder: (context, preview, _)
          {
            // Gone the moment the hour it stands for is on the track, which is
            // before the server answers. Read here and not written into the
            // notifier, since a rebuild cannot be asked for from inside one.
            if (preview == null || (preview.isSaving && _hourIsDrawnFor(preview.placement)))
            {
              return const SizedBox.shrink();
            }

            final placement = preview.placement;

            // Drawn whatever the answer is: the sentence has moved to the hand,
            // and what is left — the outline and the frosting under it — is what
            // says which hour is about to be landed on.

            final row = lanes.indexWhere((lane) => lane.teacherTaxCode == placement.teacherTaxCode);

            if (row < 0)
            {
              return const SizedBox.shrink();
            }

            // Whatever the answer is: an outline that may not go where it is
            // lies on top of an hour just the same, and the one underneath has
            // to be told apart from it.
            final covers = _liesOnAnHour(lanes[row], placement);

            return Stack(
              children: [
                // Slid between quarters rather than redrawn at each: the
                // placement is snapped, so under a smoothly moving pointer the
                // outline would stutter fifteen minutes at a time. Trailing it
                // keeps the gesture continuous while the answer stays discrete.
                //
                // Vertically too, so a drag into another teacher's row is
                // something the eye follows rather than has to go and find.
                //
                // The key stops it flying in from the far side — see
                // [_ghostEpoch].
                AnimatedPositioned(
                  key: ValueKey(_ghostEpoch),
                  duration: kDragAnswerDuration,
                  curve: Curves.easeOutCubic,
                  left: metrics.xOf(placement.startMinutes),
                  width: metrics.widthOf(placement.startMinutes, placement.endMinutes),
                  top: metrics.topOfRow(row) + _ghostTop(row, _ghostSubLane(lanes[row], placement)),
                  height: kTimelineBlockHeight,
                  child: CalendarGhostBlock(
                    label: preview.isSaving ? 'Salvataggio…' : _ghostLabel(placement),
                    width: metrics.widthOf(placement.startMinutes, placement.endMinutes),
                    isSaving: preview.isSaving,
                    // Blurred where it lands on top of an hour that is already
                    // there, so that the two are told apart at a glance instead
                    // of reading as one block with two borders.
                    isAlongside: covers,
                    isRefused: placement.refusal != null,
                  ),
                ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: kTimelineLeadingWidth),
            Expanded(child: _TimelineAxis(metrics: metrics)),
          ],
        ),
        const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: kTimelineLeadingWidth,
              child: Column(
                children: [
                  for (var index = 0; index < lanes.length; index++)
                    SizedBox(
                      height: metrics.heightOfRow(index),
                      child: _LaneHeader(
                        lane: lanes[index],
                        bandStart: bandStart,
                        bandEnd: bandEnd,
                        carried: widget.carried,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                height: metrics.trackHeight,
                // One target over the whole track rather than one per lane.
                // Per-lane targets fire onLeave at every row crossed — a ghost
                // that flickers its way down the list — and turn the seam
                // between two rows into a place where a drop lands nowhere.
                child: DragTarget<CalendarDragPayload>(
                  // Always true, and it matters: answering false stops onMove
                  // from firing, and the ghost then cannot say *why* the place
                  // under the pointer will not do. The refusal happens on the
                  // release instead.
                  onWillAcceptWithDetails: (_) => true,
                  onMove: _onMove,
                  onLeave: (_)
                  {
                    _endDrag();
                    // After the reset and not before it: off the track there is
                    // no placement left to show, and letting go out there is
                    // what takes an hour out of the day.
                    _carriedAt.value = CarriedPlacement.away;
                  },
                  onAcceptWithDetails: _onAccept,
                  builder: (context, candidates, rejected) => Stack(
                    key: _trackKey,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _TimelineGridPainter(metrics: metrics)),
                      ),
                      _buildBackgroundLayer(),
                      // Over the stretches, under the hours themselves.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _TimelineDivisionsPainter(metrics: metrics),
                          ),
                        ),
                      ),
                      for (var index = 0; index < lanes.length; index++)
                        Positioned(
                          top: metrics.topOfRow(index),
                          left: 0,
                          right: 0,
                          height: metrics.heightOfRow(index),
                          // Keyed by the teacher and not by the place in the
                          // list, which reorders whenever the day does: a row
                          // remembers which hours are arriving and leaving.
                          child: _LaneBlocks(
                            key: ValueKey(lanes[index].teacherTaxCode),
                            placed: _lanePlacements(lanes[index]),
                            builder: _buildLessonBlock,
                            thrownAway: _thrownAway,
                          ),
                        ),

                      _buildGhostLayer(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
