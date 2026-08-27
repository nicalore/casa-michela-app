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

const double _stepWidth = 720;
const double _dialogWidth = _stepWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap) + 64;

const double _teacherColumnWidth = 268;

const double _twoColumnsMin = 600;

const double _sideMaxHeight = 380;

const double _barHeight = 18;
const double _supervisorAvatarSize = 34;

const double _supervisorCardIdealWidth = 260;
const double _supervisorCardGap = 8;

final TextStyle _supervisorHoursStyle = GoogleFonts.plusJakartaSans(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.2,
  color: AppTheme.trialMutedText,
);

// Keeps a 15-minute stretch visible: it would otherwise be under 2 px.
const double _minBarWidth = 3;

const Duration _fillDuration = Duration(milliseconds: 320);

List<TeacherLane> teachersInBuilding(List<TeacherLane> lanes)
{
  return lanes
      .where((lane) => lane.lessons.any((lesson) => lesson.teacherMode == kPresenceMode))
      .toList();
}

// Stored shift durations are ignored: a supervisor covers the hours they
// currently teach in the room, recomputed from today's lessons.
bool isRoomPlanSettled({
  required List<TeacherLane> lanes,
  required List<TeacherRoomAssignmentItem> assignments,
  required List<RoomSupervisionItem> supervisions,
})
{
  final roomOf = {for (final row in assignments) row.teacherTaxCode: row.room.id};
  final watching = {for (final shift in supervisions) (shift.room.id, shift.teacherTaxCode)};

  final occupied = <int, List<(int, int)>>{};
  final covered = <int, List<(int, int)>>{};

  for (final lane in lanes)
  {
    final room = roomOf[lane.teacherTaxCode];

    if (room == null)
    {
      return false;
    }

    final hours = _lessonSpans(lane);

    occupied.putIfAbsent(room, () => []).addAll(hours);

    if (watching.contains((room, lane.teacherTaxCode)))
    {
      covered.putIfAbsent(room, () => []).addAll(hours);
    }
  }

  return occupied.entries.every((entry)
  {
    return subtractSpans(
      mergeSpans(entry.value),
      mergeSpans(covered[entry.key] ?? const []),
    ).isEmpty;
  });
}

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

  bool matches(RoomSupervisionItem row)
  {
    return row.room.id == roomId &&
        row.teacherTaxCode == teacherTaxCode &&
        row.startMinutes == startMinutes &&
        row.endMinutes == endMinutes;
  }
}

String _hoursLabel(TeacherLane lane)
{
  final spans = _lessonSpans(lane);

  if (spans.isEmpty)
  {
    return '';
  }

  return formatMinutesRange(spans.first.$1, spans.last.$2);
}

// Only in-person lessons count — not availabilities, not attività.
List<(int, int)> _lessonSpans(TeacherLane lane)
{
  return mergeSpans([
    for (final lesson in lane.lessons)
      if (lesson.teacherMode == kPresenceMode) (lesson.startMinutes, lesson.endMinutes),
  ]);
}

class _TeacherCard extends StatefulWidget
{
  final TeacherLane lane;

  final int? fromRoomId;

  // Long-press drag on the stacked layout so a drag does not fight the scroll.
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

    // Material required: the feedback lives in the Overlay, where a bare Text throws.
    final feedback = Material(
      type: MaterialType.transparency,
      child: SizedBox(width: _teacherColumnWidth, child: _buildBody(inHand: true)),
    );

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

// Not a bare tax code: a `DragTarget<String>` would accept any string dragged in the app.
class _CarriedTeacher
{
  final TeacherLane lane;
  final int? fromRoomId;

  const _CarriedTeacher({required this.lane, required this.fromRoomId});
}

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
            color: widget.isSelected ? kPickedSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            // Border always present (transparent when idle) so hover does not shift layout.
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

// In minutes, not pixels.
typedef _Bar = ({double start, double end, double alpha});

double _lerp(double from, double to, double t) => from + (to - from) * t;

// Each new span interpolates from the old span it shares the most minutes with;
// unmatched spans open from, or close onto, their midpoint.
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
    // Start settled so pre-existing cover is not animated in.
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

    // Retarget from the bar's current position so rapid changes do not restart
    // from the pre-animation state.
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

      // Minimum width scales with alpha so appearing bars grow from nothing.
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

class _RoomTimeline extends StatelessWidget
{
  final int windowStart;
  final int windowEnd;

  final List<(int, int)> occupied;

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
          // Drawn last so a sliver of uncovered time wins over the cover around it.
          Positioned.fill(child: layer(open, AppTheme.trialDanger)),
        ],
      ),
    );
  }
}

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

          // ~32 px per label; step up to every 2nd+ hour when they would overlap.
          final perHour = width / (total / 60);
          final step = perHour >= 32 ? 1 : math.max(2, (32 / perHour).ceil());

          final first = (windowStart / 60).ceil();
          final last = windowEnd ~/ 60;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var hour = first; hour <= last; hour += step)
                Positioned(
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

class _RoomPlan
{
  final RoomItem room;

  final List<TeacherLane> teachers;

  final List<(int, int)> occupied;

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

  List<(int, int)> coverageOf(TeacherLane lane) => _lessonSpans(lane);

  List<(int, int)> get covered
  {
    return mergeSpans([
      for (final lane in teachers)
        if (supervisors.contains(lane.teacherTaxCode)) ...coverageOf(lane),
    ]);
  }

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

// Covers the whole day, not a band. Nothing is written until confirm.
class RoomAssignmentWizard extends StatefulWidget
{
  final DateTime day;

  final List<TeacherLane> lanes;

  final List<RoomItem> rooms;

  final List<TeacherRoomAssignmentItem> assignments;
  final List<RoomSupervisionItem> supervisions;

  // A null room means the teacher's assignment is removed.
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
  late final Map<String, int> _roomOf = _initialBoard();

  // Only who, not when: hours are recomputed from the teacher's current lessons.
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
      // Skip assignments to rooms no longer in the catalogue.
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
      // The shift follows the teacher: the database rejects a supervisor of a room they left.
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

  // Includes every teacher: a null room signals removal, not omission.
  Map<String, int?> get _desiredRooms
  {
    return {
      for (final lane in widget.lanes) lane.teacherTaxCode: _roomOf[lane.teacherTaxCode],
    };
  }

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
      Navigator.of(context).pop(true);
    }
  }

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

  Widget _buildTeacherCard(TeacherLane lane, {required int? fromRoomId, required bool longPress})
  {
    return _TeacherCard(
      key: ValueKey(lane.teacherTaxCode),
      lane: lane,
      fromRoomId: fromRoomId,
      longPress: longPress,
    );
  }

  // Capped only in the two-column layout: stacked, the page itself scrolls.
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

  Widget _buildPool({required bool twoColumns})
  {
    final waiting = _unassigned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSideTitle('Docenti convocati', trailing: waiting.isEmpty ? null : '${waiting.length}'),
        _DropBox(
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
      accepts: (carried) => carried.fromRoomId != room.id,
      onAccept: (carried) => _put(carried, room.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
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

    // Counted over the visible lanes: _roomOf may hold teachers this window is not about.
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

  Widget _buildSupervisorCards(_RoomPlan plan)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final available = constraints.maxWidth;

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
