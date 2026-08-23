import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../models/person_option_item.dart';
import '../models/room_day_plan.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'calendar_lesson_block.dart';
import 'person_avatar.dart';

const double kTimelineLeadingWidth = 216;

const double kTimelineAxisHeight = 34;

const double kMinPixelsPerMinute = 1.1;

const double _autoScrollMargin = 56;
const double _autoScrollStep = 8;

class _GhostPreview
{
  final LessonPlacement placement;

  final bool isSaving;

  const _GhostPreview(this.placement, {this.isSaving = false});
}

class _TimelineAutoScroller
{
  final ScrollController controller;
  final void Function() onTick;

  Timer? _timer;
  double _direction = 0;

  _TimelineAutoScroller({required this.controller, required this.onTick});

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

class CalendarNowLine extends StatelessWidget
{
  final TimelineMetrics metrics;

  final int minutes;

  const CalendarNowLine({super.key, required this.metrics, required this.minutes});

  @override
  Widget build(BuildContext context)
  {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _NowLinePainter(metrics: metrics, minutes: minutes),
          ),
        ),
      ),
    );
  }
}

const double _nowHeadRadius = 4;

class _NowLinePainter extends CustomPainter
{
  final TimelineMetrics metrics;
  final int minutes;

  const _NowLinePainter({required this.metrics, required this.minutes});

  @override
  void paint(Canvas canvas, Size size)
  {
    final x = metrics.xOf(minutes);

    final stroke = Paint()
      ..color = AppTheme.trialDanger
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
    canvas.drawCircle(
      Offset(x, 0),
      _nowHeadRadius,
      Paint()..color = AppTheme.trialDanger,
    );
  }

  @override
  bool shouldRepaint(_NowLinePainter oldDelegate)
  {
    return oldDelegate.minutes != minutes ||
        oldDelegate.metrics.windowStartMinutes != metrics.windowStartMinutes ||
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

typedef _DragOutline = ({(int, int)? window, String mode, Set<String> preferred, Set<String> avoided});

enum StretchReach
{
  idle,

  open,

  closed,
}

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

class _OnlineAlsoHatch extends StatelessWidget
{
  final StretchReach reach;

  const _OnlineAlsoHatch({this.reach = StretchReach.idle});

  @override
  Widget build(BuildContext context)
  {
    return ClipRRect(
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

  static const double _spacing = 9;

  @override
  void paint(Canvas canvas, Size size)
  {
    final paint = Paint()
      ..color = lessonAccent(kOnlineMode).withValues(alpha: alpha)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var x = -size.height; x < size.width; x += _spacing)
    {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_OnlineAlsoHatchPainter oldDelegate) => oldDelegate.alpha != alpha;
}

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

class _MarkedAvatar extends StatelessWidget
{
  final PersonOptionItem person;
  final ({bool preferred, bool avoided}) standing;

  final bool isSupervisor;

  const _MarkedAvatar({
    required this.person,
    required this.standing,
    this.isSupervisor = false,
  });

  static const double _size = 62;

  ({Color accent, IconData icon, String message})? get _mark
  {
    if (standing.preferred)
    {
      return (
        accent: kPreferredTeacherColor,
        icon: Icons.star_rounded,
        message: 'Docente richiesto dall\'alunno',
      );
    }

    if (standing.avoided)
    {
      return (
        accent: kAvoidedTeacherColor,
        icon: Icons.do_not_disturb_on_rounded,
        message: 'Docente che l\'alunno preferirebbe evitare',
      );
    }

    if (isSupervisor)
    {
      return (
        accent: kSupervisorColor,
        icon: Icons.shield_rounded,
        message: kSupervisorLabel,
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context)
  {
    final mark = _mark;

    final ring = mark?.accent ?? kAvoidedTeacherColor.withValues(alpha: 0);

    return SizedBox(
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
                border: Border.all(color: ring, width: 2),
              ),
              child: PersonAvatar(person: person, size: _size - 8),
            ),
          ),
          if (mark != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Tooltip(
                message: mark.message,
                decoration: AppTheme.tooltipDecoration,
                textStyle: AppTheme.tooltipTextStyle,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: mark.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(mark.icon, size: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LaneHeader extends StatelessWidget
{
  final CalendarLane lane;
  final int bandStart;
  final int bandEnd;

  final CalendarView view;

  final LaneRoomLabel? room;

  final ValueListenable<CarriedRequest?>? carried;

  const _LaneHeader({
    required this.lane,
    required this.bandStart,
    required this.bandEnd,
    this.view = CalendarView.byTeacher,
    this.room,
    this.carried,
  });

  ({bool preferred, bool avoided}) _standingFor(CalendarDragPayload? payload)
  {
    if (payload == null)
    {
      return (preferred: false, avoided: false);
    }

    final outline = dragOutline(payload, bandStart: bandStart, bandEnd: bandEnd);

    return (
      preferred: outline.preferred.contains(lane.personTaxCode),
      avoided: outline.avoided.contains(lane.personTaxCode),
    );
  }

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

  List<Widget> _buildWhere(LaneRoomLabel room)
  {
    final name = room.roomName;
    final atHome = name == null;

    final accent = atHome ? lessonAccent(kOnlineMode) : AppTheme.trialTealDeep;

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              atHome ? lessonModeIcon(kOnlineMode) : Icons.meeting_room_outlined,
              size: 13,
              color: accent,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              name ?? modeLabel(kOnlineMode),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildHeader(({bool preferred, bool avoided}) standing)
  {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          _MarkedAvatar(
            person: lane.person,
            standing: standing,
            isSupervisor: room?.isSupervisor ?? false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lane.person.fullName,
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
                if (room != null)
                  ..._buildWhere(room!)
                else if (_offered.isEmpty)
                  Text(
                    view == CalendarView.byStudent ? 'Nessuna presenza' : 'Nessuna disponibilità',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: AppTheme.trialMutedText,
                    ),
                  )
                else
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

typedef PlacedLesson = ({LessonItem lesson, double left, double width, double top});

const Duration _blockArrival = Duration(milliseconds: 220);
const Duration _blockDeparture = Duration(milliseconds: 200);
const Duration _blockTravel = Duration(milliseconds: 200);

class _LaneBlocks extends StatefulWidget
{
  final List<PlacedLesson> placed;

  final Widget Function(PlacedLesson placed) builder;

  final int? thrownAway;

  final double blockHeight;

  const _LaneBlocks({
    super.key,
    required this.placed,
    required this.builder,
    required this.blockHeight,
    this.thrownAway,
  });

  @override
  State<_LaneBlocks> createState() => _LaneBlocksState();
}

class _LaneBlocksState extends State<_LaneBlocks>
{
  final Map<int, ({PlacedLesson placed, double from})> _leaving = {};

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
      _leaving.remove(id);

      if (was.containsKey(id))
      {
        continue;
      }

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

    _arriving.removeWhere((id) => !now.containsKey(id));
  }

  static bool _isSameRectangle(PlacedLesson a, PlacedLesson b)
  {
    return a.left == b.left && a.width == b.width && a.top == b.top;
  }

  Widget _buildStanding(PlacedLesson placed)
  {
    final id = placed.lesson.id;

    return AnimatedPositioned(
      key: ValueKey(id),
      duration: _blockTravel,
      curve: Curves.easeOutCubic,
      left: placed.left,
      width: placed.width,
      top: placed.top,
      height: widget.blockHeight,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: _arriving.contains(id) ? 0 : 1, end: 1),
        duration: _blockArrival,
        curve: Curves.easeOut,
        builder: _fade,
        child: widget.builder(placed),
      ),
    );
  }

  Widget _buildLeaving(PlacedLesson placed, double from)
  {
    return Positioned(
      key: ValueKey('leaving-${placed.lesson.id}'),
      left: placed.left,
      width: placed.width,
      top: placed.top,
      height: widget.blockHeight,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: from, end: 0.0),
          duration: _blockDeparture,
          curve: Curves.easeIn,
          onEnd: () => setState(() => _leaving.remove(placed.lesson.id)),
          builder: _fade,
          child: widget.builder(placed),
        ),
      ),
    );
  }

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
        for (final entry in _leaving.values) _buildLeaving(entry.placed, entry.from),
        for (final placed in widget.placed)
          if (_arriving.contains(placed.lesson.id)) _buildStanding(placed),
        for (final placed in widget.placed)
          if (!_arriving.contains(placed.lesson.id)) _buildStanding(placed),
      ],
    );
  }
}

class CalendarTimeline extends StatefulWidget
{
  final List<CalendarLane> lanes;
  final TimelineMetrics metrics;

  final CalendarView view;

  final bool isComposing;

  final List<MinistrySubjectItem> ministrySubjects;
  final int bandStart;
  final int bandEnd;

  final Map<int, int> subLaneOf;

  final Set<int> warnedLessonIds;

  final Set<int> preferredLessonIds;

  final Set<int> pastLessonIds;

  final Map<String, LaneRoomLabel> roomByTeacher;

  final int? nowMinutes;

  final void Function(LessonItem lesson)? onLessonTap;

  final LessonPlacement Function(CalendarDragPayload payload, String teacherTaxCode, int startMinutes)? onPlan;

  final Future<void> Function(CalendarDragPayload payload, LessonPlacement placement)? onDrop;

  final LessonPlacement Function(LessonItem lesson, int startMinutes, int endMinutes)? onPlanResize;

  final void Function(String refusal)? onRefused;

  final ValueListenable<CarriedRequest?>? carried;

  final void Function(LessonItem lesson)? onDroppedOutside;

  final void Function(CalendarDragPayload? payload)? onDragChanged;

  final ValueNotifier<CarriedPlacement>? carriedAt;

  final ScrollController? scrollController;
  final GlobalKey? viewportKey;

  const CalendarTimeline({
    super.key,
    required this.lanes,
    required this.metrics,
    required this.bandStart,
    required this.bandEnd,
    this.view = CalendarView.byTeacher,
    this.isComposing = false,
    this.ministrySubjects = const [],
    this.subLaneOf = const {},
    this.warnedLessonIds = const {},
    this.preferredLessonIds = const {},
    this.pastLessonIds = const {},
    this.roomByTeacher = const {},
    this.nowMinutes,
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
  final GlobalKey _trackKey = GlobalKey();

  final ValueNotifier<_GhostPreview?> _preview = ValueNotifier(null);

  int _ghostEpoch = 0;

  void _setPreview(_GhostPreview? preview)
  {
    if (preview != null && _preview.value == null)
    {
      _ghostEpoch++;
    }

    _preview.value = preview;
  }

  _TimelineAutoScroller? _autoScroller;

  final ValueNotifier<CarriedPlacement> _ownCarriedAt = ValueNotifier(CarriedPlacement.idle);

  ValueNotifier<CarriedPlacement> get _carriedAt => widget.carriedAt ?? _ownCarriedAt;

  CalendarDragPayload? _carried;
  Offset? _lastPointer;

  int? _thrownAway;

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

    if (oldWidget.scrollController != widget.scrollController ||
        (oldWidget.onPlan == null) != (widget.onPlan == null))
    {
      _autoScroller?.stop();
      _attachAutoScroller();
    }
  }

  bool get _isReadOnly => widget.onPlan == null;

  void _attachAutoScroller()
  {
    final controller = widget.scrollController;

    _autoScroller = controller == null || _isReadOnly
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

    _lastPlanned = null;

    _showPlacement(_planAt(payload, pointer));
  }

  void _showPlacement(LessonPlacement? placement)
  {
    if (placement?.signature != _preview.value?.placement.signature)
    {
      _setPreview(placement == null ? null : _GhostPreview(placement));
    }

    final lane = placement == null
        ? null
        : lanes.where((row) => row.personTaxCode == placement.teacherTaxCode).firstOrNull;

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

  List<CalendarLane> get lanes => widget.lanes;

  int get bandStart => widget.bandStart;

  int get bandEnd => widget.bandEnd;

  RenderBox? get _trackBox => _trackKey.currentContext?.findRenderObject() as RenderBox?;

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

    return plan(payload, lanes[row].personTaxCode, metrics.snappedMinutesAt(local.dx));
  }

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

    if (!placement.isValid)
    {
      _setPreview(null);
      widget.onRefused?.call(placement.refusal ?? kOutsideAvailabilityRefusal);
      _carriedAt.value = CarriedPlacement.idle;

      return;
    }

    _carriedAt.value = CarriedPlacement.idle;

    final needsGhost = placement.kind == LessonPlacementKind.create;

    _setPreview(needsGhost ? _GhostPreview(placement, isSaving: true) : null);

    await widget.onDrop?.call(details.data, placement);

    if (mounted)
    {
      _setPreview(null);
    }
  }

  List<Widget> _laneBackground(CalendarLane lane, double rowHeight, _DragOutline? outline, Set<String> competent)
  {
    final layers = <Widget>[];

    if (_isReadOnly)
    {
      return layers;
    }

    final presence = lane.spansIn(kPresenceMode, bandStart, bandEnd);
    final online = lane.spansIn(kOnlineMode, bandStart, bandEnd);
    final window = outline?.window;

    StretchReach reachOf(String mode, (int, int) span)
    {
      if (outline == null || window == null)
      {
        return StretchReach.idle;
      }

      if (!competent.contains(lane.personTaxCode))
      {
        return StretchReach.closed;
      }

      if (mode == kOnlineMode && outline.mode != kOnlineMode)
      {
        return StretchReach.closed;
      }

      final shared = intersectSpan(span.$1, span.$2, window.$1, window.$2);

      return shared != null && shared.$2 - shared.$1 >= kMinimumBandMinutes
          ? StretchReach.open
          : StretchReach.closed;
    }

    final inset = kTimelineRowPadding - kStretchBleed;

    for (final span in presence)
    {
      layers.add(Positioned(
        left: metrics.xOf(span.$1),
        width: metrics.widthOf(span.$1, span.$2),
        top: inset,
        height: rowHeight - 2 * inset,
        child: CalendarAvailabilityStretch(
          mode: kPresenceMode,
          reach: reachOf(kPresenceMode, span),
        ),
      ));
    }

    for (final span in online)
    {
      final alsoPresent = presence.any((other) => spansOverlap(span.$1, span.$2, other.$1, other.$2));

      layers.add(Positioned(
        left: metrics.xOf(span.$1),
        width: metrics.widthOf(span.$1, span.$2),
        top: inset,
        height: rowHeight - 2 * inset,
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

  double _topOfSubLane(int subLane)
  {
    return kTimelineRowPadding + subLane * (lessonBlockHeight(widget.view) + kTimelineSubLaneGap);
  }

  List<PlacedLesson> _lanePlacements(CalendarLane lane)
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
      isPast: widget.pastLessonIds.contains(lesson.id),
      view: widget.view,
      ministrySubjects: widget.ministrySubjects,
      onTap: widget.onLessonTap == null || lesson.isProvisional ? null : () => widget.onLessonTap!(lesson),
      isMovable: !lesson.isLocked && !lesson.isProvisional && widget.onPlan != null,
      isComposing: widget.isComposing,
      carriedAt: _carriedAt,
      onDragChanged: (payload)
      {
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

  int _ghostSubLane(CalendarLane lane, LessonPlacement placement)
  {
    final taken = <int>{};

    for (final lesson in lane.lessons)
    {
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

  bool _liesOnAnHour(CalendarLane lane, LessonPlacement placement)
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

  bool _wouldRunAlongside(CalendarLane lane, LessonPlacement placement)
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

  double _ghostTop(int row, int subLane)
  {
    final floor = metrics.heightOfRow(row) - kTimelineRowPadding - lessonBlockHeight(widget.view);

    return math.min(_topOfSubLane(subLane), math.max(kTimelineRowPadding, floor));
  }

  bool _hourIsDrawnFor(LessonPlacement placement)
  {
    for (final lane in lanes)
    {
      if (lane.personTaxCode != placement.teacherTaxCode)
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

  Widget _buildGhostLayer()
  {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ValueListenableBuilder<_GhostPreview?>(
          valueListenable: _preview,
          builder: (context, preview, _)
          {
            if (preview == null || (preview.isSaving && _hourIsDrawnFor(preview.placement)))
            {
              return const SizedBox.shrink();
            }

            final placement = preview.placement;

            final row = lanes.indexWhere((lane) => lane.personTaxCode == placement.teacherTaxCode);

            if (row < 0)
            {
              return const SizedBox.shrink();
            }

            final covers = _liesOnAnHour(lanes[row], placement);

            return Stack(
              children: [
                AnimatedPositioned(
                  key: ValueKey(_ghostEpoch),
                  duration: kDragAnswerDuration,
                  curve: Curves.easeOutCubic,
                  left: metrics.xOf(placement.startMinutes),
                  width: metrics.widthOf(placement.startMinutes, placement.endMinutes),
                  top: metrics.topOfRow(row) + _ghostTop(row, _ghostSubLane(lanes[row], placement)),
                  height: lessonBlockHeight(widget.view),
                  child: CalendarGhostBlock(
                    label: preview.isSaving ? 'Salvataggio…' : _ghostLabel(placement),
                    width: metrics.widthOf(placement.startMinutes, placement.endMinutes),
                    isSaving: preview.isSaving,
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

  Widget _buildTrackStack()
  {
    final now = widget.nowMinutes;

    return Stack(
      key: _trackKey,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _TimelineGridPainter(metrics: metrics)),
        ),
        _buildBackgroundLayer(),
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
            child: _LaneBlocks(
              blockHeight: lessonBlockHeight(widget.view),
              key: ValueKey(lanes[index].personTaxCode),
              placed: _lanePlacements(lanes[index]),
              builder: _buildLessonBlock,
              thrownAway: _thrownAway,
            ),
          ),

        if (now != null) CalendarNowLine(metrics: metrics, minutes: now),

        if (!_isReadOnly) _buildGhostLayer(),
      ],
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
                        view: widget.view,
                        room: widget.roomByTeacher[lanes[index].personTaxCode],
                        carried: widget.carried,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                height: metrics.trackHeight,
                child: _isReadOnly
                    ? _buildTrackStack()
                    : DragTarget<CalendarDragPayload>(
                        onWillAcceptWithDetails: (_) => true,
                        onMove: _onMove,
                        onLeave: (_)
                        {
                          _endDrag();
                          _carriedAt.value = CarriedPlacement.away;
                        },
                        onAcceptWithDetails: _onAccept,
                        builder: (context, candidates, rejected) => _buildTrackStack(),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
