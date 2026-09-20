import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../lessons/models/activity_item.dart';
import '../../lessons/models/calendar_day.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_activity_block.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';

// Taller than the admin's 60 to fit two lines of subject.
const double kOwnBlockHeight = 104;

const double _hoverBorder = 2;
const double _restBorder = 1.4;

const double _narrowFrom = 110;

const double _barInset = 8;
const double _barWidth = 3;
const double _barGap = 8;

const double _textInset = 10;

const IconData kSharedLessonIcon = Icons.people_alt_outlined;

const String kSharedLessonLabel = 'In compresenza con un altro studente';

TextStyle _hoursStyle(Color accent) => GoogleFonts.plusJakartaSans(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      height: 1.15,
      color: accent,
    );

TextStyle get _nameStyle => GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: AppTheme.trialOcean,
    );

TextStyle get _subjectStyle => GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: AppTheme.trialInk,
    );

TextStyle get _disciplinesStyle => GoogleFonts.plusJakartaSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: AppTheme.trialMutedText,
    );

class _BlockFrame extends StatefulWidget
{
  final Color accent;
  final Color surface;
  final IconData icon;
  final String hours;
  final String? details;
  final bool isPast;

  final bool isShared;

  final VoidCallback? onTap;

  final Widget Function(bool narrow) body;

  const _BlockFrame({
    required this.accent,
    required this.surface,
    required this.icon,
    required this.hours,
    required this.details,
    required this.isPast,
    this.isShared = false,
    required this.onTap,
    required this.body,
  });

  @override
  State<_BlockFrame> createState() => _BlockFrameState();
}

class _BlockFrameState extends State<_BlockFrame>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    final accent = widget.accent;
    final details = widget.details;

    final Widget block = MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: widget.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovering && widget.onTap != null ? AppTheme.trialGold : accent.withValues(alpha: 0.45),
                width: _isHovering && widget.onTap != null ? _hoverBorder : _restBorder,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            // A Stack, not a Row: a flex would overflow at a few pixels wide.
            child: LayoutBuilder(
              builder: (context, constraints)
              {
                final narrow = constraints.maxWidth < _narrowFrom;

                // A Positioned refuses a negative width.
                final left = math.min(_barInset + _barWidth + _barGap, constraints.maxWidth);
                final right = math.min(_textInset, constraints.maxWidth - left);

                return Stack(
                  children: [
                    Positioned(
                      left: _barInset,
                      top: 0,
                      bottom: 0,
                      width: _barWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    // Cut from the bottom when the body does not fit: never a debug overflow.
                    Positioned.fill(
                      left: left,
                      right: right,
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (!narrow) ...[
                                    Icon(widget.icon, size: 14, color: accent),
                                    const SizedBox(width: 5),
                                  ],
                                  Expanded(
                                    child: Text(
                                      widget.hours,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _hoursStyle(accent),
                                    ),
                                  ),
                                  if (!narrow && widget.isShared) ...[
                                    const SizedBox(width: 4),
                                    const Tooltip(
                                      message: kSharedLessonLabel,
                                      child: Icon(kSharedLessonIcon, size: 15, color: AppTheme.trialMutedText),
                                    ),
                                  ],
                                  if (!narrow && widget.isPast) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.check_rounded, size: 16, color: AppTheme.trialMutedText),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              widget.body(narrow),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

    if (details == null)
    {
      return block;
    }

    return Tooltip(
      message: details,
      decoration: AppTheme.tooltipDecoration,
      textStyle: AppTheme.tooltipTextStyle,
      waitDuration: kCalendarTooltipWait,
      child: block,
    );
  }
}

class OwnLessonBlock extends StatelessWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;

  final CalendarView view;

  final bool isPast;

  final bool onTimeline;

  final VoidCallback? onTap;

  const OwnLessonBlock({
    super.key,
    required this.lesson,
    required this.ministrySubjects,
    required this.view,
    required this.isPast,
    this.onTimeline = true,
    this.onTap,
  });

  bool get _byStudent => view == CalendarView.byStudent;

  bool get _isTight => onTimeline && lesson.minutes <= kMinimumBandMinutes;

  bool get _hasTooltip => onTimeline && lesson.minutes < kTooltipBelowMinutes;

  String get _title => lessonTitle(lesson, view: view);

  ({IconData icon, String label}) get _where => lessonWhere(lesson);

  Color get _whereAccent
  {
    return _where.icon == Icons.meeting_room_outlined ? AppTheme.trialTealDeep : lessonAccent(lesson.mode);
  }

  String get _hours
  {
    final range = formatTimeRange(lesson.startTime, lesson.endTime);

    if (_isTight)
    {
      return range;
    }

    final length = '$range · ${formatMinutes(lesson.minutes)}';

    return !_byStudent && lesson.mode == kOnlineMode ? '$length · ${modeLabel(kOnlineMode)}' : length;
  }

  Widget _buildWhere({required bool narrow})
  {
    final accent = _whereAccent;

    return Row(
      children: [
        if (!narrow) ...[
          Icon(_where.icon, size: 13, color: accent),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            _where.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _disciplinesStyle.copyWith(fontWeight: FontWeight.w700, color: accent),
          ),
        ),
      ],
    );
  }

  String _details(({String subject, String? disciplines}) about)
  {
    return [
      _title,
      about.subject,
      ?about.disciplines,
      if (_byStudent) _where.label,
    ].join('\n');
  }

  Widget _buildBody(({String subject, String? disciplines}) about, {required bool narrow})
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          maxLines: _isTight && !_byStudent ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: _nameStyle,
        ),
        const SizedBox(height: 3),
        Text(about.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: _subjectStyle),
        if (about.disciplines != null) ...[
          const SizedBox(height: 2),
          Text(
            about.disciplines!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _disciplinesStyle,
          ),
        ],
        if (_byStudent) ...[
          const SizedBox(height: 3),
          _buildWhere(narrow: narrow),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final about = lessonAbout(lesson, ministrySubjects);

    return _BlockFrame(
      accent: lessonAccent(lesson.mode),
      surface: Colors.white,
      icon: lessonModeIcon(lesson.mode),
      hours: _hours,
      details: _hasTooltip ? _details(about) : null,
      isPast: isPast,
      isShared: _byStudent && lesson.isShared,
      onTap: onTap,
      body: (narrow) => _buildBody(about, narrow: narrow),
    );
  }
}

class OwnActivityBlock extends StatelessWidget
{
  final ScheduledActivity activity;

  final bool isPast;

  final bool onTimeline;

  final VoidCallback? onTap;

  const OwnActivityBlock({
    super.key,
    required this.activity,
    required this.isPast,
    this.onTimeline = true,
    this.onTap,
  });

  String get _fullHours => '${activityHours(activity)} · ${formatMinutes(activity.minutes)}';

  bool get _isTight => onTimeline && activity.minutes <= kMinimumBandMinutes;

  String get _hours => _isTight ? activityHours(activity) : _fullHours;

  bool get _hasTooltip => onTimeline && activity.minutes < kTooltipBelowMinutes;

  @override
  Widget build(BuildContext context)
  {
    return _BlockFrame(
      accent: kActivityAccent,
      surface: kActivitySurface,
      icon: kActivityIcon,
      hours: _hours,
      details: _hasTooltip ? activityDetails(activity) : null,
      isPast: isPast,
      onTap: onTap,
      body: (_) => Text(
        activity.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _nameStyle,
      ),
    );
  }
}
