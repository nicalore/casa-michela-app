import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../models/lesson_item.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';

// The block holds three lines — the hours, who is in it, what it is about. The
// hours are the first thing looked for, and reading them off the axis is not
// reading them.
const double kTimelineBlockHeight = 58;

// The air a row keeps above and below its blocks, and between two of them where
// the row is stacked.
const double kTimelineRowPadding = 8;
const double kTimelineSubLaneGap = 6;

// How tall a row with that many sub-lanes has to be. The air is inside the row
// on purpose: rows drawn edge to edge leave no band where a drop lands nowhere.
double timelineRowHeight(int subLanes)
{
  final lanes = subLanes < 1 ? 1 : subLanes;

  return 2 * kTimelineRowPadding + lanes * kTimelineBlockHeight + (lanes - 1) * kTimelineSubLaneGap;
}

// The height of a row with a single sub-lane, which is most of them.
final double kTimelineRowHeight = timelineRowHeight(1);

// The strip at either end a block is resized from. Ten pixels is small, but it
// is a strip and not a dot, and the cursor changes over it.
const double kBlockHandleWidth = 10;

// Shorter than anything else here: an outline taking a quarter second to admit
// it has been refused was lying for a quarter second. Long enough to be a fade
// rather than a switch, and no longer.
const Duration kDragAnswerDuration = Duration(milliseconds: 130);

// And how long what is picked up takes to arrive, or to be given up.
//
// Longer, because these are the two ends of the gesture rather than its middle:
// something appearing under the hand and something being handed back to the page.
const Duration kDragPickUpDuration = Duration(milliseconds: 170);

// So two hours that touch on the clock do not touch on the screen. The same air
// whether the hour can be resized or not, which is the point: taken from the
// resize strips, a card appeared at one width and shrank once the server
// answered.
const double kBlockSideGap = 3;

// Under this the handles step aside: they would leave twenty-eight pixels of
// body, and a block that cannot be grabbed is worse than one that cannot be
// resized from its edges. The dialog keeps the way in.
const double kMinResizableBlockWidth = 48;

// The colours of this screen and what each is allowed to mean. Kept distinct so
// the two questions — how the hour happens, and who it goes to — are not asked
// in the same voice.
//
//   deep teal   the hour is in the building
//   amber       the hour is at a screen
//   turquoise   where the hour would land, whatever kind of landing it is
//   violet      a teacher the pupil asked for
//   deep water  a teacher the pupil would rather avoid
//   red         it may not go there, or it is about to leave the day
//   gold        the hand is on it — a state of the pointer, not of the day

// A teacher named on the request, and which of the two lists they are on.
const Color kPreferredTeacherColor = AppTheme.trialViolet;
const Color kAvoidedTeacherColor = AppTheme.trialDeepWater;

Color lessonAccent(String mode) => mode == kOnlineMode ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

Color lessonSurface(String mode) => mode == kOnlineMode ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface;

// The glyph for a mode. The colour says it too, but a colour has to be learnt
// and there is no legend on this screen to learn it from.
IconData lessonModeIcon(String mode) =>
    mode == kOnlineMode ? Icons.videocam_outlined : Icons.home_work_outlined;

// What an hour is called: the pupil, or how many. Out here and not on the
// block, because the narrow calendar draws hours as a list too — and a lesson
// with two names is two lessons to whoever is looking for it.
String lessonTitle(LessonItem lesson)
{
  final students = lesson.bookings.map((entry) => entry.presence.student).toList();

  if (students.isEmpty)
  {
    return 'Lezione';
  }

  if (students.length == 1)
  {
    return students.single.fullName;
  }

  return '${students.length} alunni';
}

// Where an hour would land if let go now, and why it may not. The refusal is
// here and not in a snackbar after the drop: the point of judging a placement
// while the pointer is down is that the block can still be moved.
class CalendarGhostBlock extends StatelessWidget
{
  // Null where there is nothing to be read: while something is being carried
  // the outline lies under it, and what it would have said is worn by the thing
  // in the hand instead.
  final String? label;
  final double width;

  // Between the drop and the server's answer. Filled rather than outlined, so
  // it reads as something happening instead of something being aimed at.
  final bool isSaving;

  // Landing on an hour already there: the row only grows a line once the second
  // hour exists. Shown as a heavier edge and nothing else — the trouble is never
  // the print below but the print above, fixed by the top being opaque. What it
  // lands on is said in the hand.
  final bool isAlongside;

  // Where it would not do. Only drawn for a gesture that carries nothing — an
  // edge being dragged — because there the track is in plain sight; whatever is
  // carried in the hand goes red instead, and a rectangle underneath it would
  // be a rectangle behind it.
  final bool isRefused;

  const CalendarGhostBlock({
    super.key,
    this.label,
    required this.width,
    this.isSaving = false,
    this.isAlongside = false,
    this.isRefused = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final accent = isRefused ? AppTheme.trialDanger : AppTheme.trialTurquoise;

    // No Tooltip on it, and it is not an oversight: the ghost lives inside an
    // IgnorePointer, so a tooltip could never be triggered — while still costing
    // a mouse-tracker registration and an animation controller every time the
    // pointer crosses into a new quarter of an hour.
    final tint = accent.withValues(alpha: isSaving ? 0.3 : 0.14);

    // Animated because all three things it says change under a moving pointer.
    // Switched outright, a drag along a busy row is a rectangle flickering
    // between two reds; faded, it is one outline changing its mind. The values
    // only change when the answer does, so idle frames cost nothing.
    final Widget outline = AnimatedContainer(
      duration: kDragAnswerDuration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        // Glass while nothing is read off it: with something in the hand the
        // hours are read there, and with an edge held the block has faded out.
        //
        // Opaque in the two states where an hour is drawn underneath — stretched
        // across, or written while the server is asked. Blended onto white it is
        // the same colour to look at and a wall to read against, where a plate
        // behind the words was a brick inside the outline.
        //
        // Words and an hour underneath, both: carried over an hour it stays
        // glass, since there the words are in the hand.
        color: label != null && (isAlongside || isSaving)
            ? Color.alphaBlend(tint, Colors.white)
            : tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: isAlongside ? 2.4 : 1.8),
      ),
      // Straight onto the outline, with no plate: what is behind it is either
      // the white card being stretched or the paler empty track, so a plate
      // defends against a case that does not arise.
      child: label == null
          ? const SizedBox.expand()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: isRefused ? AppTheme.trialDanger : AppTheme.trialTealDeep,
                  ),
                ),
              ),
            ),
    );

    // Faded in: the outline appears under what is carried, at the edge of the
    // eye, where arriving all at once reads as a flicker. Once only — the tween
    // is at its end by the next placement change. Where it goes is the ghost
    // layer's business in calendar_timeline.dart.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: kDragAnswerDuration,
      curve: Curves.easeOut,
      builder: (context, arrival, child) => Opacity(opacity: arrival, child: child),
      child: outline,
    );
  }
}

// How much is left behind while something is in the hand. Named because it is
// read from two sides: what draws the faded copy, and what has to know where a
// fade out starts — an hour thrown off the calendar leaves from here.
const double kLeftBehindOpacity = 0.3;

// What stays where something was picked up from. Faded and left in place, or
// the column reflows under the gesture and the drag loses its bearings.
//
// Faded over a moment, which is what this widget is for: the two are a few
// pixels apart when the gesture is recognised, and dropping one to a third in a
// single frame reads as a flash rather than a hand-over. One-shot, since the
// widget is only in the tree while the drag lasts.
class CalendarLeftBehind extends StatelessWidget
{
  // How much of it is left. A third or so — enough to keep the shape of the
  // list, not enough to be mistaken for something still there.
  final double opacity;

  final Widget child;

  const CalendarLeftBehind({super.key, this.opacity = kLeftBehindOpacity, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: opacity),
      duration: kDragPickUpDuration,
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

// About the width of an hour and a half, so what is in the hand is the size of
// what it is about to become. Measured on the longest first line, which is the
// answer the whole gesture aims at and not the one to cut short.
const double kDragFeedbackWidth = 212;

// What travels under the pointer. The same card whether the hour is on the
// track or still a request in the panel: one gesture aimed at one place.
//
// Three states in one shape so nothing jumps — the hours it would take, which
// the axis under a moving pointer cannot be read for; or red, saying which of
// the two refusals it is. In the hand and not on the track underneath, which
// would be behind it.
class CalendarDragFeedback extends StatelessWidget
{
  // What is being carried, in a word: the pupils of an hour already planned,
  // the materia or the discipline of a request that is not.
  final String title;

  // In the building or at a screen, for the stripe and the line above the name.
  final String mode;

  // What it is worth while the track has not said where it would land — the
  // hours of a planned lesson, the length proposed for a request.
  final String hours;

  final double width;

  // What letting go away from the track would do, where it does anything. Null
  // for a request coming out of the panel: out there nothing happens to it, and
  // a card gone red over a bin would be threatening something that is not on
  // the table.
  final String? awayLabel;

  // Where the track would put it, said in the hand: the hours are the answer
  // somebody is dragging *for*, and reading them off the axis under a moving
  // pointer is not reading them.
  final ValueListenable<CarriedPlacement>? carriedAt;

  const CalendarDragFeedback({
    super.key,
    required this.title,
    required this.mode,
    required this.hours,
    this.width = kDragFeedbackWidth,
    this.awayLabel,
    this.carriedAt,
  });

  @override
  Widget build(BuildContext context)
  {
    final listenable = carriedAt;

    final Widget card = listenable == null
        ? _at(CarriedPlacement.idle)
        : ValueListenableBuilder<CarriedPlacement>(
            valueListenable: listenable,
            builder: (context, carried, _) => _at(carried),
          );

    // Lifted into the hand rather than switched on there: built into the
    // Overlay at full size a few pixels from a card still drawn where it was,
    // the copy arrives as a bang. Runs once per gesture — the widget is built at
    // the start and only rebuilt after.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: kDragPickUpDuration,
      curve: Curves.easeOutCubic,
      builder: (context, lift, child) => Opacity(
        opacity: lift,
        // About its own middle, so a card anchored by the pointer and one
        // anchored by its own corner both grow in place.
        child: Transform.scale(scale: 0.92 + 0.08 * lift, child: child),
      ),
      child: card,
    );
  }

  Widget _at(CarriedPlacement carried)
  {
    final leaving = !carried.isOverTrack;
    final saysLeaving = leaving && awayLabel != null;

    // Off the track with nothing to say about it is the same as not having been
    // told anything yet: the card keeps its own colours rather than going red
    // over a consequence there is none of.
    final mark = leaving && awayLabel == null ? null : carriedMark(carried);

    final isWrong = mark?.accent == AppTheme.trialDanger;
    final accent = mark?.accent ?? lessonAccent(mode);
    final span = carried.span;

    // The feedback lives in the Overlay, outside the app's Material: a Text in
    // there without one of its own throws.
    //
    // Opaque throughout, which is the answer to two cards on top of each other:
    // a translucent tint printed its words on whatever lay underneath, in
    // precisely the states worth reading. Blended onto white it is the same
    // colour to look at and a wall to read against.
    //
    // Animated because this card is what the eye is on while the pointer moves,
    // and switched outright a drag along an alternating row strobes. Cheap: an
    // AnimatedContainer only starts when a value actually differs.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        duration: kDragAnswerDuration,
        curve: Curves.easeOut,
        width: width,
        height: kTimelineBlockHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isWrong
              ? Color.alphaBlend(AppTheme.trialDangerLight.withValues(alpha: 0.16), Colors.white)
              : mark == null
                  ? Colors.white
                  : Color.alphaBlend(accent.withValues(alpha: 0.14), Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mark == null ? AppTheme.trialGold : accent, width: 2),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: Row(
          children: [
            if (mark != null)
              Icon(mark.icon, size: 18, color: accent)
            else
              Container(
                width: 3,
                height: double.infinity,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The words take the same time to change colour as the card
                  // around them. Left to snap, they were the one part of the card
                  // that still announced each change instead of arriving at it —
                  // and they are the part being read.
                  AnimatedDefaultTextStyle(
                    duration: kDragAnswerDuration,
                    curve: Curves.easeOut,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: accent,
                    ),
                    child: Text(
                      saysLeaving
                          ? awayLabel!
                          // The hours it would take where it is now, and what it
                          // is worth where the track has not said. Never the two
                          // at once: one of them would be a lie by a quarter of
                          // an hour, and it is not obvious which.
                          : '${modeLabel(mode)} · ${span == null ? hours : formatMinutesRange(span.$1, span.$2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: kDragAnswerDuration,
                    curve: Curves.easeOut,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: isWrong ? AppTheme.trialDanger : AppTheme.trialOcean,
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// What letting go would do, as a glyph, the same wherever it is shown. Worn by
// whatever is carried and not drawn on the track, which is behind the thing the
// eye is on.

// Two pupils with the teacher at once.
const IconData kAlongsideIcon = Icons.layers_rounded;

// The two parts of one request go back to being one hour.
const IconData kMergePartsIcon = Icons.merge_rounded;

// A discipline joining an hour that request already has.
const IconData kJoinHourIcon = Icons.playlist_add_rounded;

// The mark whatever is carried wears. One answer for both feedbacks, which say
// the same thing about the same gesture. Null for an ordinary hour landing on
// empty track.
({IconData icon, Color accent})? carriedMark(CarriedPlacement carried)
{
  if (!carried.isOverTrack)
  {
    return (icon: Icons.delete_outline_rounded, accent: AppTheme.trialDanger);
  }

  if (carried.refusal != null)
  {
    return (icon: Icons.priority_high_rounded, accent: AppTheme.trialDanger);
  }

  return switch (carried.kind)
  {
    LessonPlacementKind.join => (icon: kJoinHourIcon, accent: AppTheme.trialTurquoise),
    LessonPlacementKind.merge => (icon: kMergePartsIcon, accent: AppTheme.trialTurquoise),
    // Turquoise like the other two: they are all the same answer — this is
    // where the hour would land — and the glyph is what tells them apart.
    _ when carried.alongside => (icon: kAlongsideIcon, accent: AppTheme.trialTurquoise),
    _ => null,
  };
}

// One lesson on the timeline. Its three gestures are siblings and not nested: a
// body that drags the hour, and two edges that stretch it. Nested, the two would
// share a gesture arena and the winner would be a matter of thresholds.
class CalendarLessonBlock extends StatefulWidget
{
  final LessonItem lesson;
  final double width;

  // Whether the hour is worth warning about — a teacher one of the pupils
  // named as not preferred. Recomputed by the caller from the bookings, and
  // not read off the server's answer, which is gone by the next reload.
  final bool hasWarning;

  // A teacher one of the pupils asked for. Worth a mark of its own, since
  // composing a day is largely about honouring these. Both can be true at once
  // in a group hour.
  final bool isPreferred;

  final VoidCallback? onTap;

  // Off where the hour cannot be moved at all: a published band is read-only
  // until somebody takes it back down.
  final bool isMovable;

  // One of the two edges is being dragged. The position is global, and the
  // timeline turns it into a minute: a delta accumulated over a long gesture
  // drifts, an absolute position cannot.
  final void Function(bool isLeftEdge, Offset globalPosition)? onEdgeDrag;

  final VoidCallback? onEdgeDragEnd;

  // Where the track would put this hour right now. Read by the feedback, which
  // is the thing the eye is on while the pointer is down: the hours it would
  // take, whether it may take them, and whether the pointer has left the track
  // altogether — where letting go takes the hour out of the day.
  final ValueListenable<CarriedPlacement>? carriedAt;

  // Let go away from the track: the gesture for taking the hour out of the day.
  final VoidCallback? onDroppedOutside;

  // The drag of this block began, or ended. What the track does with it is light
  // up the hours the pupils are there for — the same thing it does for a request
  // carried out of the panel.
  final void Function(CalendarDragPayload? payload)? onDragChanged;

  const CalendarLessonBlock({
    super.key,
    required this.lesson,
    required this.width,
    this.hasWarning = false,
    this.isPreferred = false,
    this.onTap,
    this.isMovable = false,
    this.onEdgeDrag,
    this.onEdgeDragEnd,
    this.carriedAt,
    this.onDroppedOutside,
    this.onDragChanged,
  });

  @override
  State<CalendarLessonBlock> createState() => _CalendarLessonBlockState();
}

class _CalendarLessonBlockState extends State<CalendarLessonBlock>
{
  bool _isHovering = false;

  // While an edge is dragged the block is not drawn at all and the outline is
  // the whole answer. Faded was not enough: a quarter-strength block is still at
  // its old length, reaching past the outline and reading as an hour that has
  // not moved.
  bool _isResizing = false;

  // Whether any of the three lines is clipped. One tooltip for the whole block
  // carrying everything: if any of it is cut, all of it is offered.
  bool _isClipped = false;

  @override
  void initState()
  {
    super.initState();

    // The fonts load after the first frame, and a string measured in the
    // fallback is not the width it will be drawn at. The same listener the
    // overflow labels of this app use puts it right once they arrive.
    PaintingBinding.instance.systemFonts.addListener(_measure);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(CalendarLessonBlock oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.width != widget.width || oldWidget.lesson.id != widget.lesson.id)
    {
      _measure();
    }
  }

  @override
  void dispose()
  {
    PaintingBinding.instance.systemFonts.removeListener(_measure);
    super.dispose();
  }

  // The width the three lines actually have: the block, less its padding, less
  // the mode bar and the air after it, less the glyph beside the hours.
  double get _textWidth
  {
    final horizontal = _isNarrow ? 6.0 : 10.0;

    return widget.width - 2 * horizontal - 3 - 8;
  }

  bool get _isNarrow => widget.width < 110;

  // Narrower still: half an hour on a busy day, minus the two resize strips, is
  // some thirty pixels of body. The glyph and its gap are sixteen of them, and
  // they were being asked for out of a row that did not have them.
  bool get _isTight => widget.width < 80;

  void _measure()
  {
    if (!mounted)
    {
      return;
    }

    final clipped = _exceeds(_hours, _hoursStyle, _textWidth - 16) ||
        _exceeds(_title, _titleStyle, _textWidth) ||
        (!_isNarrow && _exceeds(_subtitle, _subtitleStyle, _textWidth));

    if (clipped != _isClipped)
    {
      setState(() => _isClipped = clipped);
    }
  }

  static bool _exceeds(String text, TextStyle style, double maxWidth)
  {
    if (maxWidth <= 0)
    {
      return true;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    return painter.width > maxWidth;
  }

  TextStyle get _hoursStyle => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.15,
      );

  TextStyle get _titleStyle => GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        height: 1.15,
      );

  TextStyle get _subtitleStyle => GoogleFonts.plusJakartaSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        height: 1.15,
      );

  // Everything the block says, for when the block cannot say all of it.
  String get _fullDetails
  {
    final lesson = widget.lesson;

    // The room is left out on purpose. It is not the lesson's — it is where the
    // teacher was put for the whole day — so an hour naming it says the same
    // thing as every other hour of theirs, and the one place it is decided is
    // the window that hands the rooms out.
    return [
      '$_hours · ${formatMinutes(lesson.minutes)}',
      for (final entry in lesson.bookings) entry.presence.student.fullName,
      if (lesson.disciplines.isNotEmpty) lesson.disciplineNames.join(', '),
      modeLabel(lesson.mode),
    ].join('\n');
  }

  String get _title => lessonTitle(widget.lesson);

  String get _subtitle
  {
    final disciplines = widget.lesson.disciplineNames.join(', ');

    return disciplines.isEmpty ? 'Servizio' : disciplines;
  }

  String get _hours => formatTimeRange(widget.lesson.startTime, widget.lesson.endTime);

  bool get _canResize
  {
    // Under this the two strips would leave twenty-eight pixels of body, and a
    // block that cannot be grabbed is worse than one that cannot be stretched
    // from its edges. The dialog keeps that way open.
    return widget.isMovable && widget.onEdgeDrag != null && widget.width >= kMinResizableBlockWidth;
  }

  // The same hairline either side, whatever the hour can do: taken from the
  // resize strips, a card changed width as soon as the server replied.
  Widget _withSideGap(Widget child)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kBlockSideGap),
      child: child,
    );
  }

  // The strip at one end of the block, and the cursor that says what it does.
  Widget _buildHandle({required bool isLeft})
  {
    return _BlockHandle(
      isLeft: isLeft,
      onDrag: (position)
      {
        if (!_isResizing)
        {
          setState(() => _isResizing = true);
        }

        widget.onEdgeDrag!(isLeft, position);
      },
      onDragEnd: ()
      {
        if (_isResizing)
        {
          setState(() => _isResizing = false);
        }

        widget.onEdgeDragEnd?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final body = _buildBody();

    if (!widget.isMovable)
    {
      return _withSideGap(body);
    }

    // The whole hour carried somewhere else, anchored by its own top-left
    // rather than by the pointer: what the track then receives is the position
    // the block's left edge would take, so a block grabbed by its middle keeps
    // its grip without anybody measuring where the grip was.
    final payload = LessonDragPayload(lesson: widget.lesson);

    final Widget movable = Draggable<CalendarDragPayload>(
      data: payload,
      onDragStarted: () => widget.onDragChanged?.call(payload),
      onDragEnd: (_) => widget.onDragChanged?.call(null),
      // Horizontal only, so a vertical gesture over the track stays a scroll.
      affinity: Axis.horizontal,
      // A still copy and not the block itself: what travels under the pointer
      // is rebuilt every frame, and the real one carries a Tooltip, a
      // MouseRegion and an AnimatedContainer that would all run sixty times a
      // second for a rectangle that only has to move.
      feedback: _buildDragFeedback(),
      childWhenDragging: CalendarLeftBehind(child: body),
      // Nobody accepted the drop, which — for a block that started on the track
      // — means it was carried off it. That is the gesture for taking an hour out
      // of the day.
      onDraggableCanceled: (_, _)
      {
        widget.onDragChanged?.call(null);
        widget.onDroppedOutside?.call();
      },
      child: body,
    );

    if (!_canResize)
    {
      return _withSideGap(movable);
    }

    return Stack(
      children: [
        // The two strips lie **over** the ends of the card rather than in place
        // of them. Siblings of it and not its parent: see the class comment.
        Positioned.fill(child: _withSideGap(movable)),
        Positioned(left: 0, top: 0, bottom: 0, width: kBlockHandleWidth, child: _buildHandle(isLeft: true)),
        Positioned(right: 0, top: 0, bottom: 0, width: kBlockHandleWidth, child: _buildHandle(isLeft: false)),
      ],
    );
  }

  // The block as it looks while it is being carried: the same card the panel
  // hands over when a request is dragged out of it, because it is the same
  // gesture aimed at the same place.
  Widget _buildDragFeedback()
  {
    return CalendarDragFeedback(
      title: _title,
      mode: widget.lesson.mode,
      hours: _hours,
      width: widget.width,
      // Nobody accepted the drop and this hour came off the track: letting go
      // out there is how an hour is taken out of the day, and the card says so
      // before the hand opens.
      awayLabel: 'Rimuovi dal calendario',
      carriedAt: widget.carriedAt,
    );
  }

  Widget _buildBody()
  {
    final lesson = widget.lesson;
    final accent = lessonAccent(lesson.mode);

    // Room for two lines of text before the block is only a coloured bar.
    final isNarrow = _isNarrow;

    final Widget block = MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            // Tighter still on the narrowest hours, where the padding and the
            // bar between them were leaving the hours no room at all.
            padding: EdgeInsets.symmetric(horizontal: _isTight ? 5 : (isNarrow ? 6 : 10), vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovering ? AppTheme.trialGold : accent.withValues(alpha: 0.45),
                width: _isHovering ? 2 : 1.4,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                // The mode, said by a bar rather than by a word: at this size a
                // word would be the whole block.
                Container(
                  width: 3,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: _isTight ? 4 : 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The hours first, and written out. They are what is
                      // looked for on a calendar, and reading them off the axis
                      // is not reading them: two blocks a quarter of an hour
                      // apart look the same from a metre away.
                      Row(
                        children: [
                          // A glyph beside the hours: the colour says it too,
                          // but a colour has to be learnt. Off on the narrowest
                          // blocks, where the bar down the left says the mode
                          // and the tooltip says the rest.
                          if (!_isTight) ...[
                            Icon(lessonModeIcon(lesson.mode), size: 12, color: accent),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              _hours,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _hoursStyle.copyWith(color: accent),
                            ),
                          ),
                          if (widget.isPreferred)
                            const Icon(Icons.star_rounded, size: 12, color: kPreferredTeacherColor),
                          if (widget.hasWarning) ...[
                            if (widget.isPreferred) const SizedBox(width: 2),
                            const Icon(Icons.circle, size: 8, color: kAvoidedTeacherColor),
                          ],
                          if (lesson.isPublished) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_outline_rounded, size: 12, color: AppTheme.trialMutedText),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _titleStyle.copyWith(color: AppTheme.trialOcean),
                      ),
                      if (!isNarrow) ...[
                        const SizedBox(height: 1),
                        Text(
                          _subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _subtitleStyle.copyWith(color: AppTheme.trialMutedText),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

    // Out of the way while its own edge is being dragged, so that what is read
    // is the outline at the length the hour is about to have.
    final Widget shown = AnimatedOpacity(
      duration: const Duration(milliseconds: 90),
      opacity: _isResizing ? 0 : 1,
      child: block,
    );

    // The tooltip only where the block cannot show everything, and then it shows
    // everything. Always on, it repeated what was already legible and covered
    // the block beside it; never on, a clipped hour had no way of being read.
    if (!_isClipped)
    {
      return shown;
    }

    return Tooltip(
      message: _fullDetails,
      decoration: AppTheme.tooltipDecoration,
      textStyle: AppTheme.tooltipTextStyle,
      waitDuration: const Duration(milliseconds: 300),
      child: shown,
    );
  }
}

// One end of a block, dragged to stretch or shorten it. A GestureDetector and
// not a Draggable: there is nothing to land on, and a Draggable would want a
// target and a payload for a movement that has neither.
class _BlockHandle extends StatefulWidget
{
  final bool isLeft;
  final void Function(Offset globalPosition) onDrag;
  final VoidCallback? onDragEnd;

  const _BlockHandle({required this.isLeft, required this.onDrag, this.onDragEnd});

  @override
  State<_BlockHandle> createState() => _BlockHandleState();
}

class _BlockHandleState extends State<_BlockHandle>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => widget.onDrag(details.globalPosition),
        onHorizontalDragEnd: (_) => widget.onDragEnd?.call(),
        onHorizontalDragCancel: widget.onDragEnd,
        // Opaque, so the strip answers the hit test over its whole width
        // including the transparent part: a handle you have to find is not a
        // handle.
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _hover ? 1 : 0,
            child: Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.trialGold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
