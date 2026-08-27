import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';

const double kStudentBlockHeight = 74;
const double kTeacherBlockHeight = 60;

double lessonBlockHeight(CalendarView view) =>
    view == CalendarView.byStudent ? kStudentBlockHeight : kTeacherBlockHeight;

const double kStretchBleed = 2;

const double kTimelineRowPadding = 8;
const double kTimelineSubLaneGap = 6;

double timelineRowHeight(int subLanes, CalendarView view)
{
  final lanes = subLanes < 1 ? 1 : subLanes;

  return 2 * kTimelineRowPadding +
      lanes * lessonBlockHeight(view) +
      (lanes - 1) * kTimelineSubLaneGap;
}

final double kTimelineRowHeight = timelineRowHeight(1, CalendarView.byTeacher);

const double kBlockHandleWidth = 10;

const Duration kDragAnswerDuration = Duration(milliseconds: 130);

const Duration kDragPickUpDuration = Duration(milliseconds: 170);

const double kBlockSideGap = 3;

const double kMinResizableBlockWidth = 48;

const Color kPreferredTeacherColor = AppTheme.trialViolet;
const Color kAvoidedTeacherColor = AppTheme.trialDeepWater;

const Color kSupervisorColor = AppTheme.trialTealDeep;

const String kLessonDoneLabel = 'Lezione svolta';

const String kRemoveFromCalendarLabel = 'RIMUOVI DAL CALENDARIO';

const String kRemoveFromCalendarAwayLabel = 'Rimuovi dal calendario';

const double _markGap = 4;

const String kSupervisorLabel = 'Responsabile di stanza';

const Duration kCalendarTooltipWait = Duration(milliseconds: 300);

// Longer: the pointer crosses the face column on its way to a row.
const Duration kTeacherExclusionTooltipWait = Duration(milliseconds: 600);

const String kExcludeTeacherLabel = 'Escludi dal calendario';

const String kReadmitTeacherLabel = 'Riaggiungi al calendario';

const double kExcludedLaneOpacity = 0.42;

const Duration kExcludedLaneFade = Duration(milliseconds: 220);

const Duration kExcludedLaneTravel = Duration(milliseconds: 340);

const Curve kExcludedLaneCurve = Curves.easeOutCubic;

Color lessonAccent(String mode) => mode == kOnlineMode ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

Color lessonSurface(String mode) => mode == kOnlineMode ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface;

IconData lessonModeIcon(String mode) =>
    mode == kOnlineMode ? Icons.videocam_outlined : Icons.home_work_outlined;

String lessonTitle(LessonItem lesson, {CalendarView view = CalendarView.byTeacher})
{
  if (view == CalendarView.byStudent)
  {
    return lesson.teacher.fullName;
  }

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

({String subject, String? disciplines}) lessonAbout(
  LessonItem lesson,
  List<MinistrySubjectItem> ministrySubjects,
)
{
  final subjects = <String>{
    for (final entry in lesson.bookings) bookingTitle(entry.booking, ministrySubjects),
  };

  final rest = [
    for (final name in lesson.disciplineNames)
      if (!subjects.contains(name)) name,
  ];

  return (
    subject: subjects.isEmpty ? 'Lezione' : subjects.join(' · '),
    disciplines: rest.isEmpty ? null : rest.join(', '),
  );
}

String lessonAboutLine(
  LessonItem lesson,
  List<MinistrySubjectItem> ministrySubjects, {
  required bool composing,
})
{
  final about = lessonAbout(lesson, ministrySubjects);

  if (!composing)
  {
    return about.subject;
  }

  final disciplines = lesson.disciplineNames;

  return disciplines.isEmpty ? about.subject : disciplines.join(', ');
}

({IconData icon, String label}) lessonWhere(LessonItem lesson)
{
  if (lesson.mode == kOnlineMode)
  {
    return (icon: lessonModeIcon(kOnlineMode), label: modeLabel(kOnlineMode));
  }

  final room = lesson.room?.name;

  if (room == null)
  {
    return (icon: lessonModeIcon(kPresenceMode), label: modeLabel(kPresenceMode));
  }

  return (icon: Icons.meeting_room_outlined, label: room);
}

bool isLessonPast(LessonItem lesson, DateTime now)
{
  if (!isSameDate(lesson.date, now))
  {
    return lesson.date.isBefore(DateTime(now.year, now.month, now.day));
  }

  return lesson.endMinutes <= minutesOfTimeOfDay(TimeOfDay.fromDateTime(now));
}

class CalendarGhostBlock extends StatelessWidget
{
  final String? label;
  final double width;

  final bool isSaving;

  final bool isAlongside;

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

    final tint = accent.withValues(alpha: isSaving ? 0.3 : 0.14);

    final Widget outline = AnimatedContainer(
      duration: kDragAnswerDuration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: label != null && (isAlongside || isSaving)
            ? Color.alphaBlend(tint, Colors.white)
            : tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: isAlongside ? 2.4 : 1.8),
      ),
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: kDragAnswerDuration,
      curve: Curves.easeOut,
      builder: (context, arrival, child) => Opacity(opacity: arrival, child: child),
      child: outline,
    );
  }
}

const double kLeftBehindOpacity = 0.3;

class CalendarLeftBehind extends StatelessWidget
{
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

const double kDragFeedbackWidth = 212;

class CalendarDragFeedback extends StatelessWidget
{
  final String title;

  final String mode;

  final String hours;

  final double width;

  final String? awayLabel;

  // When left out, both fall back to the mode's own word and colour.
  final String? lead;

  final Color? accent;

  final ValueListenable<CarriedPlacement>? carriedAt;

  const CalendarDragFeedback({
    super.key,
    required this.title,
    required this.mode,
    required this.hours,
    this.width = kDragFeedbackWidth,
    this.awayLabel,
    this.lead,
    this.accent,
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: kDragPickUpDuration,
      curve: Curves.easeOutCubic,
      builder: (context, lift, child) => Opacity(
        opacity: lift,
        child: Transform.scale(scale: 0.92 + 0.08 * lift, child: child),
      ),
      child: card,
    );
  }

  Widget _at(CarriedPlacement carried)
  {
    final leaving = !carried.isOverTrack;
    final saysLeaving = leaving && awayLabel != null;

    final mark = leaving && awayLabel == null ? null : carriedMark(carried);

    final isWrong = mark?.accent == AppTheme.trialDanger;
    final accent = mark?.accent ?? this.accent ?? lessonAccent(mode);
    final span = carried.span;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        duration: kDragAnswerDuration,
        curve: Curves.easeOut,
        width: width,
        height: kTeacherBlockHeight,
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
                          : '${lead ?? modeLabel(mode)} · ${span == null ? hours : formatMinutesRange(span.$1, span.$2)}',
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

const IconData kAlongsideIcon = Icons.layers_rounded;

const IconData kMergePartsIcon = Icons.merge_rounded;

const IconData kJoinHourIcon = Icons.playlist_add_rounded;

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
    _ when carried.alongside => (icon: kAlongsideIcon, accent: AppTheme.trialTurquoise),
    _ => null,
  };
}

class CalendarLessonBlock extends StatefulWidget
{
  final LessonItem lesson;
  final double width;

  final bool hasWarning;

  final bool isPreferred;

  final CalendarView view;

  final List<MinistrySubjectItem> ministrySubjects;

  final bool isPast;

  final VoidCallback? onTap;

  final bool isMovable;

  final bool isComposing;

  final void Function(bool isLeftEdge, Offset globalPosition)? onEdgeDrag;

  final VoidCallback? onEdgeDragEnd;

  final ValueListenable<CarriedPlacement>? carriedAt;

  final VoidCallback? onDroppedOutside;

  final void Function(CalendarDragPayload? payload)? onDragChanged;

  const CalendarLessonBlock({
    super.key,
    required this.lesson,
    required this.width,
    this.hasWarning = false,
    this.isPreferred = false,
    this.isPast = false,
    this.view = CalendarView.byTeacher,
    this.ministrySubjects = const [],
    this.onTap,
    this.isMovable = false,
    this.isComposing = false,
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

  bool _isResizing = false;

  bool _isClipped = false;

  bool _showsFullHours = true;

  bool _showsOnline = false;

  @override
  void initState()
  {
    super.initState();

    PaintingBinding.instance.systemFonts.addListener(_measure);
    _measureAfterFrame();
  }

  @override
  void didUpdateWidget(CalendarLessonBlock oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.width != widget.width ||
        oldWidget.lesson.id != widget.lesson.id ||
        oldWidget.lesson.room?.id != widget.lesson.room?.id ||
        oldWidget.view != widget.view)
    {
      _measureAfterFrame();
    }
  }

  void _measureAfterFrame()
  {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose()
  {
    PaintingBinding.instance.systemFonts.removeListener(_measure);
    super.dispose();
  }

  double get _textWidth
  {
    final horizontal = _isNarrow ? 6.0 : 10.0;

    return widget.width - 2 * kBlockSideGap - 2 * horizontal - 3 - 8;
  }

  bool get _isNarrow => widget.width < 110;

  bool get _isTight => widget.width < 80;

  void _measure()
  {
    if (!mounted)
    {
      return;
    }

    final room = _textWidth - _marksWidth;

    final showsFullHours = !_exceeds(TextSpan(text: _hours, style: _hoursStyle), room);
    final showsOnline = _saysOnline && !_exceeds(TextSpan(text: _hoursOnline, style: _hoursStyle), room);

    final clipped = _about.disciplines != null ||
        !showsFullHours ||
        (_saysOnline && !showsOnline) ||
        _exceeds(TextSpan(text: _title, style: _titleStyle), _textWidth) ||
        _exceeds(TextSpan(text: _aboutLine, style: _subtitleStyle), _textWidth) ||
        (_byStudent && _exceeds(_whereSpan(AppTheme.trialTealDeep), _textWidth - 15));

    if (clipped != _isClipped || showsFullHours != _showsFullHours || showsOnline != _showsOnline)
    {
      setState(()
      {
        _isClipped = clipped;
        _showsFullHours = showsFullHours;
        _showsOnline = showsOnline;
      });
    }
  }

  static bool _exceeds(InlineSpan span, double maxWidth)
  {
    if (maxWidth <= 0)
    {
      return true;
    }

    final painter = TextPainter(
      text: span,
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
        height: 1.1,
      );

  bool get _byStudent => widget.view == CalendarView.byStudent;

  bool get _saysOnline => !_byStudent && widget.lesson.mode == kOnlineMode;

  ({IconData icon, String label}) get _where => lessonWhere(widget.lesson);

  String get _fullDetails
  {
    final lesson = widget.lesson;
    final about = _about;

    final people = _byStudent
        ? [lesson.teacher.fullName]
        : [for (final entry in lesson.bookings) entry.presence.student.fullName];

    final mode = modeLabel(lesson.mode);

    return [
      '$_hours · ${formatMinutes(lesson.minutes)}',
      ...people,
      about.disciplines == null ? about.subject : '${about.subject}: ${about.disciplines}',
      _where.label,
      if (_where.label != mode) mode,
    ].join('\n');
  }

  String get _title => lessonTitle(widget.lesson, view: widget.view);

  String get _hours => formatTimeRange(widget.lesson.startTime, widget.lesson.endTime);

  String get _hoursOnline => '$_hours · ${modeLabel(kOnlineMode)}';

  String get _hoursShown
  {
    if (!_showsFullHours)
    {
      return formatTimeOfDayShort(widget.lesson.startTime);
    }

    return _saysOnline && _showsOnline ? _hoursOnline : _hours;
  }

  double get _marksWidth
  {
    var width = 0.0;

    if (widget.isPreferred)
    {
      width += 12;
    }

    if (widget.hasWarning)
    {
      width += (width > 0 ? 2 : 0) + 8;
    }

    if (widget.isPast)
    {
      width += (width > 0 ? _markGap : 0) + 13;
    }

    return width == 0 ? 0 : width + _markGap;
  }

  ({String subject, String? disciplines}) get _about => lessonAbout(widget.lesson, widget.ministrySubjects);

  String get _aboutLine => lessonAboutLine(
        widget.lesson,
        widget.ministrySubjects,
        composing: widget.isComposing,
      );

  Color get _whereAccent
  {
    return _where.icon == Icons.meeting_room_outlined
        ? AppTheme.trialTealDeep
        : lessonAccent(widget.lesson.mode);
  }

  TextSpan _whereSpan(Color accent)
  {
    return TextSpan(
      text: _where.label,
      style: _subtitleStyle.copyWith(fontWeight: FontWeight.w700, color: accent),
    );
  }

  bool get _canResize
  {
    return widget.isMovable && widget.onEdgeDrag != null && widget.width >= kMinResizableBlockWidth;
  }

  Widget _withSideGap(Widget child)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kBlockSideGap),
      child: child,
    );
  }

  Widget _buildHandle({required bool isLeft})
  {
    return CalendarBlockHandle(
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

    final payload = LessonDragPayload(lesson: widget.lesson);

    final Widget movable = Draggable<CalendarDragPayload>(
      data: payload,
      onDragStarted: () => widget.onDragChanged?.call(payload),
      onDragEnd: (_) => widget.onDragChanged?.call(null),
      affinity: Axis.horizontal,
      feedback: _buildDragFeedback(),
      childWhenDragging: CalendarLeftBehind(child: body),
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
        Positioned.fill(child: _withSideGap(movable)),
        Positioned(left: 0, top: 0, bottom: 0, width: kBlockHandleWidth, child: _buildHandle(isLeft: true)),
        Positioned(right: 0, top: 0, bottom: 0, width: kBlockHandleWidth, child: _buildHandle(isLeft: false)),
      ],
    );
  }

  Widget _buildWhere()
  {
    final accent = _whereAccent;

    return Row(
      children: [
        Icon(_where.icon, size: 11, color: accent),
        const SizedBox(width: 4),
        Expanded(
          child: Text.rich(
            _whereSpan(accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDragFeedback()
  {
    return CalendarDragFeedback(
      title: _title,
      mode: widget.lesson.mode,
      hours: _hours,
      width: widget.width,
      awayLabel: kRemoveFromCalendarAwayLabel,
      carriedAt: widget.carriedAt,
    );
  }

  Widget _buildBody()
  {
    final lesson = widget.lesson;
    final accent = lessonAccent(lesson.mode);

    final Widget block = MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(horizontal: _isTight ? 5 : (_isNarrow ? 6 : 10), vertical: 6),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _hoursShown,
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
                          if (widget.isPast) ...[
                            if (widget.isPreferred || widget.hasWarning) const SizedBox(width: _markGap),
                            const Tooltip(
                              message: kLessonDoneLabel,
                              child: Icon(Icons.check_rounded, size: 13, color: AppTheme.trialMutedText),
                            ),
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
                      const SizedBox(height: 1),
                      Text(
                        _aboutLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _subtitleStyle.copyWith(color: AppTheme.trialMutedText),
                      ),
                      if (_byStudent) ...[
                        const SizedBox(height: 2),
                        _buildWhere(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

    final Widget shown = AnimatedOpacity(
      duration: const Duration(milliseconds: 90),
      opacity: _isResizing ? 0 : 1,
      child: block,
    );

    if (!_isClipped)
    {
      return shown;
    }

    return Tooltip(
      message: _fullDetails,
      decoration: AppTheme.tooltipDecoration,
      textStyle: AppTheme.tooltipTextStyle,
      waitDuration: kCalendarTooltipWait,
      child: shown,
    );
  }
}

// Resize handle at either end of a block; shared by lessons and activities.
class CalendarBlockHandle extends StatefulWidget
{
  final bool isLeft;
  final void Function(Offset globalPosition) onDrag;
  final VoidCallback? onDragEnd;

  const CalendarBlockHandle({
    super.key,
    required this.isLeft,
    required this.onDrag,
    this.onDragEnd,
  });

  @override
  State<CalendarBlockHandle> createState() => _CalendarBlockHandleState();
}

class _CalendarBlockHandleState extends State<CalendarBlockHandle>
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
