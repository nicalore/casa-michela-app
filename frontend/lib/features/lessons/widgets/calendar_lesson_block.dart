import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';

const double kStudentBlockHeight = 80;
const double kTeacherBlockHeight = 64;

// Published blocks write the subject too, on a line of their own.
const double kPublishedStudentBlockHeight = 98;
const double kPublishedTeacherBlockHeight = 82;

double lessonBlockHeight(CalendarView view, {required bool composing})
{
  if (view == CalendarView.byStudent)
  {
    return composing ? kStudentBlockHeight : kPublishedStudentBlockHeight;
  }

  return composing ? kTeacherBlockHeight : kPublishedTeacherBlockHeight;
}

const double kStretchBleed = 2;

const double kTimelineRowPadding = 8;
const double kTimelineSubLaneGap = 6;

double timelineRowHeight(int subLanes, CalendarView view, {required bool composing})
{
  return timelineRowHeightOf(subLanes, lessonBlockHeight(view, composing: composing));
}

double timelineRowHeightOf(int subLanes, double blockHeight)
{
  final lanes = subLanes < 1 ? 1 : subLanes;

  return 2 * kTimelineRowPadding + lanes * blockHeight + (lanes - 1) * kTimelineSubLaneGap;
}

final double kTimelineRowHeight = timelineRowHeight(1, CalendarView.byTeacher, composing: true);

const double kBlockHandleWidth = 10;

const Duration kDragAnswerDuration = Duration(milliseconds: 130);

const Duration kDragPickUpDuration = Duration(milliseconds: 170);

const double kBlockSideGap = 3;

const double kMinResizableBlockWidth = 48;

const Color kPreferredTeacherColor = AppTheme.trialViolet;
const Color kAvoidedTeacherColor = AppTheme.trialDeepWater;

const Color kSupervisorColor = AppTheme.trialTealDeep;

const String kLessonDoneLabel = 'Lezione svolta';

// Blocks shorter than this carry a tooltip with the full account.
const int kTooltipBelowMinutes = 60;

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

// The teacher or the pupil on a block: darker than the muted text, which is hard to read there.
const Color kLessonPersonColor = Color(0xFF3E5260);

Color lessonAccent(String mode) => mode == kOnlineMode ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

Color lessonSurface(String mode) => mode == kOnlineMode ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface;

IconData lessonModeIcon(String mode) =>
    mode == kOnlineMode ? Icons.videocam_outlined : Icons.house_outlined;

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

  final bool divided = lesson.bookings.any((entry) => ministrySubjects
      .where((subject) => subject.id == entry.booking.ministrySubjectId)
      .any((subject) => subject.associationSubjects.length > 1));

  // A lone discipline adds nothing to an undivided subject; a divided one always says which.
  return (
    subject: subjects.isEmpty ? 'Lezione' : subjects.join(' · '),
    disciplines: rest.isEmpty || (rest.length < 2 && !divided) ? null : rest.join(', '),
  );
}

// The discipline leads; the subject follows only where it says more.
({String discipline, String? subject}) lessonTopic(LessonItem lesson, List<MinistrySubjectItem> ministrySubjects)
{
  final disciplines = lesson.disciplineNames;
  final subjects = [
    for (final name in {for (final entry in lesson.bookings) bookingTitle(entry.booking, ministrySubjects)})
      if (!disciplines.contains(name)) name,
  ];

  if (disciplines.isEmpty)
  {
    return (discipline: subjects.isEmpty ? 'Lezione' : subjects.join(' · '), subject: null);
  }

  return (discipline: disciplines.join(', '), subject: subjects.isEmpty ? null : subjects.join(' · '));
}

// The range at full strength, its length and mode a step back.
TextSpan lessonHoursSpan(List<String> parts, TextStyle style)
{
  final quiet = style.copyWith(fontWeight: FontWeight.w600, color: style.color?.withValues(alpha: 0.72));

  return TextSpan(
    text: parts.first,
    style: style,
    children: [
      for (final part in parts.skip(1)) TextSpan(text: ' · $part', style: quiet),
    ],
  );
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

Color lessonWhereAccent(LessonItem lesson)
{
  return lessonWhere(lesson).icon == Icons.meeting_room_outlined ? AppTheme.trialTealDeep : lessonAccent(lesson.mode);
}

bool isLessonPast(LessonItem lesson, DateTime now)
{
  if (!isSameDate(lesson.date, now))
  {
    return lesson.date.isBefore(DateTime(now.year, now.month, now.day));
  }

  return lesson.endMinutes <= minutesOfTimeOfDay(TimeOfDay.fromDateTime(now));
}

bool isLessonRunning(LessonItem lesson, DateTime now)
{
  final minutes = minutesOfTimeOfDay(TimeOfDay.fromDateTime(now));

  return isSameDate(lesson.date, now) && lesson.startMinutes <= minutes && minutes < lesson.endMinutes;
}

// The now line and the tint of a card under way glide to each new minute together.
const Duration kNowGlide = Duration(milliseconds: 1200);

const Curve kNowGlideCurve = Curves.easeInOut;

Duration nowGlideOf(BuildContext context) => VisualEffects.of(context) ? kNowGlide : Duration.zero;

// Glides to its new place when the minute changes; follows a layout change at once.
class NowGlide extends StatefulWidget
{
  final int minutes;

  final double target;

  final Widget Function(BuildContext context, double value) builder;

  const NowGlide({super.key, required this.minutes, required this.target, required this.builder});

  @override
  State<NowGlide> createState() => _NowGlideState();
}

class _NowGlideState extends State<NowGlide> with SingleTickerProviderStateMixin
{
  late final AnimationController _glide = AnimationController(vsync: this);

  double _from = 0;

  double _valueTowards(double target)
  {
    if (!_glide.isAnimating)
    {
      return target;
    }

    return _from + (target - _from) * kNowGlideCurve.transform(_glide.value);
  }

  @override
  void didUpdateWidget(NowGlide oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    final duration = nowGlideOf(context);

    if (oldWidget.minutes != widget.minutes && oldWidget.target != widget.target && duration > Duration.zero)
    {
      _from = _valueTowards(oldWidget.target);
      _glide.duration = duration;
      _glide.forward(from: 0);
    }
  }

  @override
  void dispose()
  {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return AnimatedBuilder(
      animation: _glide,
      builder: (context, _) => widget.builder(context, _valueTowards(widget.target)),
    );
  }
}

// Surface, shadow and the tint of a card under way, apart from the hover's own animation.
class CardGround extends StatelessWidget
{
  final double? elapsed;

  final Color surface;

  final double radius;

  final Widget child;

  const CardGround({super.key, required this.elapsed, required this.surface, required this.radius, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: elapsed ?? 0),
      duration: nowGlideOf(context),
      curve: kNowGlideCurve,
      builder: (context, share, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          gradient: elapsed == null ? null : elapsedFill(share, surface),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      ),
      child: child,
    );
  }
}

// A card under way: the part gone by tinted in the now line's colour, up to where the line crosses.
Gradient? elapsedFill(double? share, Color surface)
{
  if (share == null)
  {
    return null;
  }

  final tint = Color.alphaBlend(AppTheme.trialDanger.withValues(alpha: 0.16), surface);
  final at = share.clamp(0.0, 0.999);

  // Two stops a hair apart, not one twice: a hover's lerp merges equal stops and blurs the edge.
  return LinearGradient(colors: [tint, tint, surface, surface], stops: [0, at, at + 0.001, 1]);
}

// How far [now] is across a card running from [left] to [right] on the same track.
double cardShare(double now, double left, double right)
{
  return right <= left ? 0 : ((now - left) / (right - left)).clamp(0.0, 1.0);
}

// Set around a card under way by whoever lays it out against the clock.
class ElapsedShare extends InheritedWidget
{
  final double share;

  const ElapsedShare({super.key, required this.share, required super.child});

  static double? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ElapsedShare>()?.share;

  @override
  bool updateShouldNotify(ElapsedShare oldWidget) => share != oldWidget.share;
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

  // Share of the card gone by, from its left edge, for a lesson under way.
  final double? elapsed;

  final VoidCallback? onTap;

  final bool isMovable;

  final bool isComposing;

  final void Function(bool isLeftEdge, Offset globalPosition)? onEdgeDrag;

  final VoidCallback? onEdgeDragEnd;

  final ValueListenable<CarriedPlacement>? carriedAt;

  final VoidCallback? onDroppedOutside;

  final void Function(CalendarDragPayload? payload)? onDragChanged;

  // Composing: the words would be cut, so the block shows its mode icon and a caption says them.
  final bool hasCaption;

  // The lesson whose block or caption is under the pointer; both light up.
  final ValueListenable<int?>? litLesson;

  final ValueChanged<bool>? onHover;

  const CalendarLessonBlock({
    super.key,
    required this.lesson,
    required this.width,
    this.hasWarning = false,
    this.isPreferred = false,
    this.isPast = false,
    this.elapsed,
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
    this.hasCaption = false,
    this.litLesson,
    this.onHover,
  });

  @override
  State<CalendarLessonBlock> createState() => _CalendarLessonBlockState();
}

class _CalendarLessonBlockState extends State<CalendarLessonBlock>
{
  bool _isHovering = false;

  bool _isResizing = false;

  // Index into [_hourForms]: the longest that fits.
  int _hoursForm = 0;

  @override
  void initState()
  {
    super.initState();

    PaintingBinding.instance.systemFonts.addListener(_measure);
    widget.litLesson?.addListener(_relight);
    _measureAfterFrame();
  }

  @override
  void didUpdateWidget(CalendarLessonBlock oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.litLesson != widget.litLesson)
    {
      oldWidget.litLesson?.removeListener(_relight);
      widget.litLesson?.addListener(_relight);
    }

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
    widget.litLesson?.removeListener(_relight);
    super.dispose();
  }

  bool _wasLit = false;

  bool get _isLitByPartner => widget.litLesson?.value == widget.lesson.id;

  void _relight()
  {
    if (mounted && _isLitByPartner != _wasLit)
    {
      setState(() => _wasLit = _isLitByPartner);
    }
  }

  bool get _isLit => _isHovering || _isLitByPartner;

  void _hover(bool isHovering)
  {
    setState(() => _isHovering = isHovering);
    widget.onHover?.call(isHovering);
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
    final forms = _hourForms;

    var form = forms.indexWhere((parts) => !_exceeds(lessonHoursSpan(parts, _blockHoursStyle), room));

    if (form < 0)
    {
      form = forms.length - 1;
    }

    if (form != _hoursForm)
    {
      setState(() => _hoursForm = form);
    }
  }

  // Published blocks write every line whole; composing ones with a caption say it there.
  bool get _hasTooltip => widget.isComposing && !widget.hasCaption && widget.lesson.minutes < kTooltipBelowMinutes;

  bool get _isSliver => widget.isComposing && widget.hasCaption;

  Widget _buildSliver(Color accent)
  {
    return Row(
      children: [
        Container(
          width: 3,
          height: double.infinity,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
        ),
        // Shrinks rather than crossing the edge when the block is only a few pixels wide.
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Icon(lessonModeIcon(widget.lesson.mode), size: 16, color: accent),
            ),
          ),
        ),
      ],
    );
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

  bool get _byStudent => widget.view == CalendarView.byStudent;

  bool get _saysOnline => !_byStudent && widget.lesson.mode == kOnlineMode;

  ({IconData icon, String label}) get _where => lessonWhere(widget.lesson);

  String get _composingDetails
  {
    final topic = _topic;

    return [
      '$_hours · ${formatMinutes(widget.lesson.minutes)}',
      topic.discipline,
      ?topic.subject,
      _title,
      if (_byStudent) _where.label,
    ].join('\n');
  }

  String get _title => lessonTitle(widget.lesson, view: widget.view);

  String get _hours => formatTimeRange(widget.lesson.startTime, widget.lesson.endTime);

  // Longest first; the mode goes before the length, the end before the start.
  List<List<String>> get _hourForms
  {
    final length = formatMinutes(widget.lesson.minutes);

    return [
      if (_saysOnline) [_hours, length, modeLabel(kOnlineMode)],
      [_hours, length],
      [_hours],
      [formatTimeOfDayShort(widget.lesson.startTime)],
    ];
  }

  List<String> get _hoursShown
  {
    final forms = _hourForms;

    return forms[math.min(_hoursForm, forms.length - 1)];
  }

  double get _marksWidth
  {
    if (_isNarrow)
    {
      return 0;
    }

    return _blockMarksWidth(preferred: widget.isPreferred, warned: widget.hasWarning, past: widget.isPast);
  }

  ({String discipline, String? subject}) get _topic => lessonTopic(widget.lesson, widget.ministrySubjects);

  Color get _whereAccent
  {
    return _where.icon == Icons.meeting_room_outlined
        ? AppTheme.trialTealDeep
        : lessonAccent(widget.lesson.mode);
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

  // Published blocks wrap a long line, the row grows to take it; composing ones say it in a caption.
  int? get _lineCap => widget.isComposing ? 1 : null;

  TextOverflow get _lineCut => widget.isComposing ? TextOverflow.ellipsis : TextOverflow.clip;

  Widget _buildWhere()
  {
    final accent = _whereAccent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_where.icon, size: _blockWhereIcon, color: accent),
        const SizedBox(width: _blockWhereIconGap),
        Expanded(
          child: Text(
            _where.label,
            maxLines: _lineCap,
            overflow: _lineCut,
            style: _blockWhereStyle.copyWith(color: accent),
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
        onEnter: (_) => _hover(true),
        onExit: (_) => _hover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: CardGround(
            elapsed: widget.elapsed,
            surface: Colors.white,
            radius: 10,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(horizontal: _isSliver ? 2 : (_isTight ? 5 : (_isNarrow ? 6 : 10)), vertical: _blockPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isLit ? AppTheme.trialGold : accent.withValues(alpha: 0.45),
                  width: _isLit ? 2 : 1.4,
                ),
              ),
              child: _isSliver ? _buildSliver(accent) : BlockTexts(
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
                    // Clipped: the block still has its composing height for a moment after publishing.
                    Expanded(
                      child: ClipRect(
                        clipper: const _BlockFaceClip(),
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minHeight: 0,
                          maxHeight: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      lessonHoursSpan(_hoursShown, _blockHoursStyle.copyWith(color: accent)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Too narrow for the marks: they would push past the edge.
                                  if (!_isNarrow) ...[
                                    if (widget.isPreferred)
                                      const Icon(Icons.star_rounded, size: 12, color: kPreferredTeacherColor),
                                    if (widget.hasWarning) ...[
                                      if (widget.isPreferred) const SizedBox(width: 2),
                                      const Icon(Icons.circle, size: 8, color: kAvoidedTeacherColor),
                                    ],
                                    if (widget.isPast) ...[
                                      if (widget.isPreferred || widget.hasWarning) const SizedBox(width: _markGap),
                                      const AppTooltip(
                                        message: kLessonDoneLabel,
                                        child: Icon(Icons.check_rounded, size: 13, color: AppTheme.trialMutedText),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                              SizedBox(height: widget.isComposing ? 2 : 3),
                              Text(
                                _topic.discipline,
                                maxLines: _lineCap,
                                overflow: _lineCut,
                                style: _blockDisciplineStyle,
                              ),
                              // Composing blocks keep their height: no subject line.
                              if (!widget.isComposing && _topic.subject != null) ...[
                                const SizedBox(height: 1),
                                Text(
                                  _topic.subject!,
                                  maxLines: _lineCap,
                                  overflow: _lineCut,
                                  style: _blockSubjectStyle,
                                ),
                              ],
                              SizedBox(height: widget.isComposing ? 2 : 4),
                              Text(
                                _title,
                                maxLines: _lineCap,
                                overflow: _lineCut,
                                style: _blockPersonStyle,
                              ),
                              if (_byStudent) ...[
                                const SizedBox(height: 2),
                                _buildWhere(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

    final Widget shown = AnimatedOpacity(
      duration: const Duration(milliseconds: 90),
      opacity: _isResizing ? 0 : 1,
      child: block,
    );

    if (!_hasTooltip)
    {
      return shown;
    }

    return AppTooltip(
      message: _composingDetails,
      decoration: AppTheme.tooltipDecoration,
      textStyle: AppTheme.tooltipTextStyle,
      waitDuration: kCalendarTooltipWait,
      child: shown,
    );
  }
}

TextStyle get _blockHoursStyle => GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      height: 1.15,
    );

TextStyle get _blockDisciplineStyle => GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      height: 1.12,
      color: AppTheme.trialOcean,
    );

TextStyle get _blockSubjectStyle => GoogleFonts.plusJakartaSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppTheme.trialOcean,
    );

TextStyle get _blockPersonStyle => GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.15,
      color: kLessonPersonColor,
    );

TextStyle get _blockWhereStyle => GoogleFonts.plusJakartaSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );

const double _blockPadding = 6;

const double _blockWhereIcon = 12;
const double _blockWhereIconGap = 4;

// Down to the block's edge: the font's descenders reach below a line shorter than 1.26.
class _BlockFaceClip extends CustomClipper<Rect>
{
  const _BlockFaceClip();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, -_blockPadding, size.width, size.height + _blockPadding);

  @override
  bool shouldReclip(_BlockFaceClip oldClipper) => false;
}

// Without the ambient style (theme letter spacing): texts draw as measured, wherever measured.
class BlockTexts extends StatelessWidget
{
  final Widget child;

  const BlockTexts({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DefaultTextStyle(style: const TextStyle(), child: child);
}

// As a Text inside [BlockTexts] draws it, at the text scale of [context].
double blockLineWidth(BuildContext context, String text, TextStyle style)
{
  return blockSpanWidth(context, TextSpan(text: text, style: style));
}

double blockSpanWidth(BuildContext context, InlineSpan span)
{
  final painter = TextPainter(
    text: span,
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();

  final width = painter.width;

  painter.dispose();

  return width;
}

double _blockMarksWidth({required bool preferred, required bool warned, required bool past})
{
  var width = 0.0;

  if (preferred)
  {
    width += 12;
  }

  if (warned)
  {
    width += (width > 0 ? 2 : 0) + 8;
  }

  if (past)
  {
    width += (width > 0 ? _markGap : 0) + 13;
  }

  return width == 0 ? 0 : width + _markGap;
}

// Side gaps, the hovered border, the colour bar and its gap, at the given padding.
double _blockChrome({required double padding, required double barGap})
{
  return 2 * kBlockSideGap + 2 * padding + 2 * 2 + 3 + barGap;
}

// Composing: would the block cut its hours, its discipline or its person? The length may go.
bool composingBlockCutsText(
  BuildContext context,
  LessonItem lesson,
  double width, {
  required List<MinistrySubjectItem> ministrySubjects,
  bool warned = false,
  bool preferred = false,
})
{
  final tight = width < 80;
  final narrow = width < 110;
  final room = width - _blockChrome(padding: tight ? 5 : (narrow ? 6 : 10), barGap: tight ? 4 : 8);
  final marks = narrow ? 0.0 : _blockMarksWidth(preferred: preferred, warned: warned, past: false);

  return blockLineWidth(context, formatTimeRange(lesson.startTime, lesson.endTime), _blockHoursStyle) > room - marks ||
      blockLineWidth(context, lessonTopic(lesson, ministrySubjects).discipline, _blockDisciplineStyle) > room ||
      blockLineWidth(context, lessonTitle(lesson), _blockPersonStyle) > room;
}

// No line widens a published block past this: a longer one wraps instead.
const double kWidestBlockLine = 240;

// Published: the width for every line, the teacher's mode included, long ones wrapped.
double publishedLessonBlockWidth(
  BuildContext context,
  LessonItem lesson, {
  required CalendarView view,
  required List<MinistrySubjectItem> ministrySubjects,
  bool past = false,
  bool warned = false,
  bool preferred = false,
})
{
  final topic = lessonTopic(lesson, ministrySubjects);
  final marks = _blockMarksWidth(preferred: preferred, warned: warned, past: past);
  final hours = [
    formatTimeRange(lesson.startTime, lesson.endTime),
    formatMinutes(lesson.minutes),
    if (view == CalendarView.byTeacher && lesson.mode == kOnlineMode) modeLabel(kOnlineMode),
  ];

  double capped(double width) => math.min(kWidestBlockLine, width);

  final lines = [
    blockSpanWidth(context, lessonHoursSpan(hours, _blockHoursStyle)) + marks,
    capped(blockLineWidth(context, topic.discipline, _blockDisciplineStyle)),
    if (topic.subject case final subject?) capped(blockLineWidth(context, subject, _blockSubjectStyle)),
    capped(blockLineWidth(context, lessonTitle(lesson, view: view), _blockPersonStyle)),
    if (view == CalendarView.byStudent)
      _blockWhereIcon + _blockWhereIconGap + capped(blockLineWidth(context, lessonWhere(lesson).label, _blockWhereStyle)),
  ];

  return lines.reduce(math.max) + _blockChrome(padding: 10, barGap: 8) + 1;
}

// As a Text inside [BlockTexts] lays [text] out within [width].
double blockTextHeight(BuildContext context, String text, TextStyle style, double width)
{
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: math.max(1, width));

  final height = painter.height;

  painter.dispose();

  return height;
}

// Published: the height for every line at [width], long ones wrapped; never under the usual.
double publishedLessonBlockHeight(
  BuildContext context,
  LessonItem lesson,
  double width, {
  required CalendarView view,
  required List<MinistrySubjectItem> ministrySubjects,
})
{
  final topic = lessonTopic(lesson, ministrySubjects);
  final room = width - _blockChrome(padding: 10, barGap: 8);

  double tall(String text, TextStyle style, [double inset = 0]) => blockTextHeight(context, text, style, room - inset);

  var height = tall('0', _blockHoursStyle) + 3 + tall(topic.discipline, _blockDisciplineStyle);

  if (topic.subject case final subject?)
  {
    height += 1 + tall(subject, _blockSubjectStyle);
  }

  height += 4 + tall(lessonTitle(lesson, view: view), _blockPersonStyle);

  if (view == CalendarView.byStudent)
  {
    final where = tall(lessonWhere(lesson).label, _blockWhereStyle, _blockWhereIcon + _blockWhereIconGap);

    height += 2 + math.max(_blockWhereIcon, where);
  }

  // Padding and the hovered border, top and bottom.
  return math.max(lessonBlockHeight(view, composing: false), height + 2 * _blockPadding + 2 * 2);
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
