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
import 'own_day_timeline.dart';

// Taller than the admin blocks, to fit two lines of subject.
const double kOwnBlockHeight = 104;

const double _hoverBorder = 2;
const double _restBorder = 1.4;

const String _currentLabel = 'In corso';

const double _narrowFrom = 110;

const double _barInset = 8;
const double _barWidth = 3;
const double _barGap = 8;

const double _textInset = 10;

// Bar, insets, hovered border and the side gaps around a block on the timeline.
const double _chrome = _barInset + _barWidth + _barGap + _textInset + 2 * _hoverBorder + 2 * kBlockSideGap + 1;

const double _hoursIcon = 14;
const double _hoursIconGap = 5;
const double _pastMark = 4 + 16;

const double _whereIcon = 13;
const double _whereIconGap = 4;

// A long activity name may take its second line rather than widen the hour.
const double _widestActivityName = 180;

// Bar, insets and the hovered border beside the words; padding and that border above and below.
const double _frameSide = _barInset + _barWidth + _barGap + _textInset + 2 * _hoverBorder;
const double _frameTop = 2 * 6 + 2 * _hoverBorder;

const double _badgeFrame = 2 * 3 + 2 * 1;

const IconData kSharedLessonIcon = Icons.people_alt_outlined;

const String kSharedLessonLabel = 'In compresenza con un altro studente';

TextStyle _hoursStyle(Color accent) => GoogleFonts.plusJakartaSans(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      height: 1.15,
      color: accent,
    );

// The discipline, or an activity's name.
TextStyle get _titleStyle => GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: AppTheme.trialOcean,
    );

TextStyle get _subjectStyle => GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppTheme.trialOcean,
    );

TextStyle get _personStyle => GoogleFonts.plusJakartaSans(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: kLessonPersonColor,
    );

TextStyle get _badgeStyle => GoogleFonts.plusJakartaSans(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 1.1,
      color: AppTheme.modifiedAccent,
    );

// The hours row: the words, the icons beside them and, under way in the list, the badge.
double _hoursRowHeight(BuildContext context, {required bool past, required bool current})
{
  return [
    blockTextHeight(context, '0', _hoursStyle(AppTheme.trialInk), double.infinity),
    _hoursIcon,
    if (past) 16.0,
    if (current) blockTextHeight(context, '0', _badgeStyle, double.infinity) + _badgeFrame,
  ].reduce(math.max);
}

TextStyle _whereStyle(Color accent) => GoogleFonts.plusJakartaSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: accent,
    );

class _BlockFrame extends StatefulWidget
{
  final Color accent;
  final Color surface;
  final IconData icon;
  final List<String> hours;
  final bool isPast;
  final bool isCurrent;

  final VoidCallback? onTap;

  final Widget Function(bool narrow) body;

  const _BlockFrame({
    required this.accent,
    required this.surface,
    required this.icon,
    required this.hours,
    required this.isPast,
    this.isCurrent = false,
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

    final bool hovering = _isHovering && widget.onTap != null;

    return MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: CardGround(
            elapsed: ElapsedShare.of(context),
            surface: widget.surface,
            radius: 10,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hovering ? AppTheme.trialGold : accent.withValues(alpha: 0.45),
                  width: hovering ? _hoverBorder : _restBorder,
                ),
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
                        child: BlockTexts(
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
                                        Icon(widget.icon, size: _hoursIcon, color: accent),
                                        const SizedBox(width: _hoursIconGap),
                                      ],
                                      Expanded(
                                        child: Text.rich(
                                          lessonHoursSpan(widget.hours, _hoursStyle(accent)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!narrow && widget.isCurrent) ...[
                                        const SizedBox(width: 6),
                                        const _CurrentBadge(),
                                      ],
                                      if (!narrow && widget.isPast) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.check_rounded, size: 16, color: AppTheme.trialMutedText),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  widget.body(narrow),
                                ],
                              ),
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
        ),
      );
  }
}

class OwnLessonBlock extends StatelessWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;

  final CalendarView view;

  final bool isPast;

  // Under way, in the list: a badge instead of the now line across it.
  final bool isCurrent;

  final VoidCallback? onTap;

  const OwnLessonBlock({
    super.key,
    required this.lesson,
    required this.ministrySubjects,
    required this.view,
    required this.isPast,
    this.isCurrent = false,
    this.onTap,
  });

  bool get _byStudent => view == CalendarView.byStudent;

  String get _title => lessonTitle(lesson, view: view);

  ({IconData icon, String label}) get _where => lessonWhere(lesson);

  Color get _whereAccent => lessonWhereAccent(lesson);

  List<String> get _hours => [
        formatTimeRange(lesson.startTime, lesson.endTime),
        formatMinutes(lesson.minutes),
        if (!_byStudent && lesson.mode == kOnlineMode) modeLabel(kOnlineMode),
      ];

  // On the timeline: the width that writes each line whole.
  double neededWidth(BuildContext context)
  {
    final topic = lessonTopic(lesson, ministrySubjects);
    final hours = blockSpanWidth(context, lessonHoursSpan(_hours, _hoursStyle(lessonAccent(lesson.mode))));
    double capped(double width) => math.min(kWidestBlockLine, width);

    final lines = [
      _hoursIcon + _hoursIconGap + hours + (isPast ? _pastMark : 0),
      capped(blockLineWidth(context, topic.discipline, _titleStyle)),
      if (topic.subject case final subject?) capped(blockLineWidth(context, subject, _subjectStyle)),
      capped(blockLineWidth(context, _title, _personStyle)),
      if (_byStudent)
        _whereIcon + _whereIconGap + capped(blockLineWidth(context, _where.label, _whereStyle(_whereAccent))),
    ];

    return lines.reduce(math.max) + _chrome;
  }

  // At [width], the card's own: every line written, long ones wrapped; never under the usual.
  double heightAt(BuildContext context, double width)
  {
    final topic = lessonTopic(lesson, ministrySubjects);
    final room = width - _frameSide;
    final whereIcon = width < _narrowFrom ? 0.0 : _whereIcon + _whereIconGap;

    double tall(String text, TextStyle style, [double inset = 0]) => blockTextHeight(context, text, style, room - inset);

    var height = _hoursRowHeight(context, past: isPast, current: isCurrent) + 4 + tall(topic.discipline, _titleStyle);

    if (topic.subject case final subject?)
    {
      height += 1 + tall(subject, _subjectStyle);
    }

    height += 4 + tall(_title, _personStyle);

    if (_byStudent)
    {
      height += 3 + math.max(whereIcon == 0 ? 0.0 : _whereIcon, tall(_where.label, _whereStyle(_whereAccent), whereIcon));
    }

    return math.max(kOwnBlockHeight, height + _frameTop);
  }

  TimelineEntry asEntry(BuildContext context)
  {
    return (
      startMinutes: lesson.startMinutes,
      endMinutes: lesson.endMinutes,
      width: neededWidth(context),
      heightAt: (width) => heightAt(context, width),
      block: this,
    );
  }

  Widget _buildWhere({required bool narrow})
  {
    final accent = _whereAccent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!narrow) ...[
          Icon(_where.icon, size: _whereIcon, color: accent),
          const SizedBox(width: _whereIconGap),
        ],
        Expanded(child: Text(_where.label, style: _whereStyle(accent))),
      ],
    );
  }

  Widget _buildBody(({String discipline, String? subject}) topic, {required bool narrow})
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Long lines wrap: the row grows to take them.
        Text(topic.discipline, style: _titleStyle),
        if (topic.subject case final subject?) ...[
          const SizedBox(height: 1),
          Text(subject, style: _subjectStyle),
        ],
        const SizedBox(height: 4),
        Text(_title, style: _personStyle),
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
    final topic = lessonTopic(lesson, ministrySubjects);

    return _BlockFrame(
      accent: lessonAccent(lesson.mode),
      surface: Colors.white,
      icon: lessonModeIcon(lesson.mode),
      hours: _hours,
      isPast: isPast,
      isCurrent: isCurrent,
      // Co-presence (lesson.isShared) is not shown to students and parents.
      onTap: onTap,
      body: (narrow) => _buildBody(topic, narrow: narrow),
    );
  }
}

class OwnActivityBlock extends StatelessWidget
{
  final ScheduledActivity activity;

  final bool isPast;

  final bool isCurrent;

  final VoidCallback? onTap;

  const OwnActivityBlock({
    super.key,
    required this.activity,
    required this.isPast,
    this.isCurrent = false,
    this.onTap,
  });

  List<String> get _hours => [activityHours(activity), formatMinutes(activity.minutes)];

  // On the timeline: the width that writes the hours and the name whole.
  double neededWidth(BuildContext context)
  {
    final line = blockSpanWidth(context, lessonHoursSpan(_hours, _hoursStyle(kActivityAccent)));
    final hours = _hoursIcon + _hoursIconGap + line + (isPast ? _pastMark : 0);
    final name = math.min(_widestActivityName, blockLineWidth(context, activity.name, _titleStyle));

    return math.max(hours, name) + _chrome;
  }

  // At [width], the card's own: the name written whole, wrapped; never under the usual.
  double heightAt(BuildContext context, double width)
  {
    final hours = _hoursRowHeight(context, past: isPast, current: isCurrent);
    final name = blockTextHeight(context, activity.name, _titleStyle, width - _frameSide);

    return math.max(kOwnBlockHeight, hours + 4 + name + _frameTop);
  }

  TimelineEntry asEntry(BuildContext context)
  {
    return (
      startMinutes: activity.startMinutes,
      endMinutes: activity.endMinutes,
      width: neededWidth(context),
      heightAt: (width) => heightAt(context, width),
      block: this,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return _BlockFrame(
      accent: kActivityAccent,
      surface: kActivitySurface,
      icon: kActivityIcon,
      hours: _hours,
      isPast: isPast,
      isCurrent: isCurrent,
      onTap: onTap,
      body: (_) => Text(activity.name, style: _titleStyle),
    );
  }
}

class _CurrentBadge extends StatelessWidget
{
  const _CurrentBadge();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.trialGoldSurface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.trialGold.withValues(alpha: 0.55)),
      ),
      child: Text(
        _currentLabel.toUpperCase(),
        maxLines: 1,
        softWrap: false,
        style: _badgeStyle,
      ),
    );
  }
}
