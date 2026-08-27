import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/activity_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../models/room_day_plan.dart';
import 'calendar_activity_block.dart';
import 'calendar_lane_panel.dart';
import 'calendar_lesson_block.dart';

const double _modeBarWidth = 4;
const double _modeBarInset = 9;

class CalendarDayAgenda extends StatelessWidget
{
  final List<CalendarLane> lanes;

  final CalendarView view;

  final bool isComposing;

  final List<MinistrySubjectItem> ministrySubjects;

  final int bandStart;
  final int bandEnd;

  final Set<int> warnedLessonIds;
  final Set<int> preferredLessonIds;

  final Set<int> pastLessonIds;

  final Map<String, LaneRoomLabel> roomByTeacher;

  final Set<String> excludedTeachers;

  final void Function(CalendarLane lane, {required bool excluded})? onExcludedChanged;

  final void Function(LessonItem lesson)? onLessonTap;

  final void Function(ActivityItem activity)? onActivityTap;

  const CalendarDayAgenda({
    super.key,
    required this.lanes,
    required this.bandStart,
    required this.bandEnd,
    this.view = CalendarView.byTeacher,
    this.isComposing = false,
    this.ministrySubjects = const [],
    this.warnedLessonIds = const {},
    this.preferredLessonIds = const {},
    this.pastLessonIds = const {},
    this.roomByTeacher = const {},
    this.excludedTeachers = const {},
    this.onExcludedChanged,
    this.onLessonTap,
    this.onActivityTap,
  });

  int get _rowCount
  {
    return lanes.fold<int>(
      0,
      (total, lane) => total + lane.lessons.length + lane.activities.length,
    );
  }

  Widget _buildHeader()
  {
    return Row(
      children: [
        Expanded(
          child: Text(
            'In calendario',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
        Text(
          '$_rowCount',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialTealDeep,
          ),
        ),
      ],
    );
  }

  // Lessons and activities interleaved in clock order.
  List<Widget> _buildRows(CalendarLane lane)
  {
    final rows = <({int startMinutes, Widget row})>[
      for (final lesson in lane.lessons)
        (
          startMinutes: lesson.startMinutes,
          row: _AgendaRow(
            isComposing: isComposing,
            lesson: lesson,
            view: view,
            ministrySubjects: ministrySubjects,
            hasWarning: warnedLessonIds.contains(lesson.id),
            isPreferred: preferredLessonIds.contains(lesson.id),
            isPast: pastLessonIds.contains(lesson.id),
            onTap: onLessonTap == null || lesson.isProvisional ? null : () => onLessonTap!(lesson),
          ),
        ),
      for (final scheduled in lane.activities)
        (
          startMinutes: scheduled.startMinutes,
          row: _ActivityAgendaRow(
            scheduled: scheduled,
            onTap: onActivityTap == null ? null : () => onActivityTap!(scheduled.activity),
          ),
        ),
    ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return [for (final entry in rows) entry.row];
  }

  VoidCallback? _toggleExcluded(CalendarLane lane)
  {
    final say = onExcludedChanged;

    if (say == null || view != CalendarView.byTeacher)
    {
      return null;
    }

    return () => say(lane, excluded: !excludedTeachers.contains(lane.personTaxCode));
  }

  Widget _buildLaneBlock(CalendarLane lane)
  {
    final rows = _buildRows(lane);

    return CalendarLanePanel(
      lane: lane,
      view: view,
      bandStart: bandStart,
      bandEnd: bandEnd,
      room: roomByTeacher[lane.personTaxCode],
      isExcluded: excludedTeachers.contains(lane.personTaxCode),
      onToggleExcluded: _toggleExcluded(lane),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.isEmpty) ...[
            const SizedBox(height: 10),
            const CalendarLaneEmpty(),
          ],
          for (final row in rows) ...[
            const SizedBox(height: 8),
            row,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: lanes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _buildLaneBlock(lanes[index]),
          ),
        ),
      ],
    );
  }
}

class _AgendaRow extends StatefulWidget
{
  final LessonItem lesson;

  final CalendarView view;

  final bool isComposing;

  final List<MinistrySubjectItem> ministrySubjects;

  final bool hasWarning;
  final bool isPreferred;

  final bool isPast;

  final VoidCallback? onTap;

  const _AgendaRow({
    required this.lesson,
    required this.view,
    required this.isComposing,
    required this.ministrySubjects,
    required this.hasWarning,
    required this.isPreferred,
    this.isPast = false,
    this.onTap,
  });

  @override
  State<_AgendaRow> createState() => _AgendaRowState();
}

class _AgendaRowState extends State<_AgendaRow>
{
  bool _hover = false;

  LessonItem get _lesson => widget.lesson;

  String get _about => lessonAboutLine(
        _lesson,
        widget.ministrySubjects,
        composing: widget.isComposing,
      );

  Widget _buildWhere()
  {
    final where = lessonWhere(_lesson);
    final accent = where.icon == Icons.meeting_room_outlined
        ? AppTheme.trialTealDeep
        : lessonAccent(_lesson.mode);

    return Row(
      children: [
        Icon(where.icon, size: 12, color: accent),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            where.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  Color get _borderColor
  {
    if (_hover && widget.onTap != null)
    {
      return AppTheme.trialGold;
    }

    return lessonAccent(_lesson.mode).withValues(alpha: 0.35);
  }

  Color get _accent => lessonAccent(_lesson.mode);

  Widget _buildTopRow()
  {
    final accent = _accent;

    return Row(
      children: [
        Icon(lessonModeIcon(_lesson.mode), size: 13, color: accent),
        const SizedBox(width: 5),
        Text(
          formatTimeRange(_lesson.startTime, _lesson.endTime),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: accent,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '· ${formatMinutes(_lesson.minutes)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
        if (widget.isPreferred) ...[
          const SizedBox(width: 6),
          const Tooltip(
            message: 'Docente richiesto dall\'alunno',
            child: Icon(Icons.star_rounded, size: 14, color: kPreferredTeacherColor),
          ),
        ],
        if (widget.hasWarning) ...[
          const SizedBox(width: 6),
          const Tooltip(
            message: 'Docente che l\'alunno preferirebbe evitare',
            child: Icon(Icons.circle, size: 9, color: kAvoidedTeacherColor),
          ),
        ],
        if (widget.isPast) ...[
          const SizedBox(width: 6),
          const Tooltip(
            message: kLessonDoneLabel,
            child: Icon(Icons.check_rounded, size: 14, color: AppTheme.trialMutedText),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final onTap = widget.onTap;

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor, width: 1.5),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                bottom: 10,
                left: _modeBarInset,
                width: _modeBarWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: lessonAccent(_lesson.mode),
                    borderRadius: BorderRadius.circular(_modeBarWidth / 2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(_modeBarInset + _modeBarWidth + 9, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopRow(),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lessonTitle(_lesson, view: widget.view),
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
                                _about,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                  color: AppTheme.trialMutedText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              _buildWhere(),
                            ],
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.trialMutedText),
                        ],
                      ],
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

class _ActivityAgendaRow extends StatefulWidget
{
  final ScheduledActivity scheduled;

  final VoidCallback? onTap;

  const _ActivityAgendaRow({required this.scheduled, this.onTap});

  @override
  State<_ActivityAgendaRow> createState() => _ActivityAgendaRowState();
}

class _ActivityAgendaRowState extends State<_ActivityAgendaRow>
{
  bool _hover = false;

  ScheduledActivity get _scheduled => widget.scheduled;

  Color get _borderColor
  {
    if (_hover && widget.onTap != null)
    {
      return AppTheme.trialGold;
    }

    return kActivityAccent.withValues(alpha: 0.35);
  }

  @override
  Widget build(BuildContext context)
  {
    final onTap = widget.onTap;
    final description = _scheduled.description;

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: kActivitySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor, width: 1.5),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                bottom: 10,
                left: _modeBarInset,
                width: _modeBarWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kActivityAccent,
                    borderRadius: BorderRadius.circular(_modeBarWidth / 2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(_modeBarInset + _modeBarWidth + 9, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(kActivityIcon, size: 13, color: kActivityAccent),
                        const SizedBox(width: 5),
                        Text(
                          activityHours(_scheduled),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: kActivityAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '· ${formatMinutes(_scheduled.minutes)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: AppTheme.trialMutedText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _scheduled.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: AppTheme.trialOcean,
                                ),
                              ),
                              if (description != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                    color: AppTheme.trialMutedText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.trialMutedText),
                        ],
                      ],
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
