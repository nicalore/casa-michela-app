import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
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

// Below the wide window: three lines on the timeline, a row in the list.
const double kDenseOwnBlockHeight = 66;
const double kDenseOwnRowHeight = 56;

const double _denseRowTimeWidth = 44;

// Set by the lesson list below the wide window: its cards turn into rows.
class OwnListRows extends InheritedWidget
{
  const OwnListRows({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<OwnListRows>() != null;

  @override
  bool updateShouldNotify(OwnListRows oldWidget) => false;
}

const double _hoverBorder = 2;
const double _restBorder = 1.4;

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
const double _denseFrameTop = 2 * 5 + 2 * _hoverBorder;

const IconData kSharedLessonIcon = Icons.people_alt_outlined;

const String kSharedLessonLabel = 'In compresenza con un altro studente';

TextStyle _hoursStyle(Color accent, {bool dense = false}) => GoogleFonts.plusJakartaSans(
      fontSize: dense ? 11.5 : 12.5,
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

TextStyle get _denseTitleStyle => GoogleFonts.plusJakartaSans(
      fontSize: 14,
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

TextStyle get _densePersonStyle => GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: kLessonPersonColor,
    );

TextStyle _rowTimeStyle(Color accent) => GoogleFonts.plusJakartaSans(
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: accent,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle get _rowEndStyle => GoogleFonts.plusJakartaSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppTheme.trialMutedText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

// The hours row: the words, the icons beside them and, under way in the list, the badge.
double _hoursRowHeight(BuildContext context, {required bool past, required bool current, bool dense = false})
{
  return [
    blockTextHeight(context, '0', _hoursStyle(AppTheme.trialInk, dense: dense), double.infinity),
    _hoursIcon,
    if (past) 16.0,
    if (current) blockTextHeight(context, '0', currentBadgeStyle, double.infinity) + kCurrentBadgeFrame,
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

  final bool dense;

  // In the list below the wide window: the card is a row, start and end in a column, then these two lines.
  final ({String start, String end, String title, String detail})? row;

  const _BlockFrame({
    required this.accent,
    required this.surface,
    required this.icon,
    required this.hours,
    required this.isPast,
    this.isCurrent = false,
    required this.onTap,
    required this.body,
    this.dense = false,
    this.row,
  });

  @override
  State<_BlockFrame> createState() => _BlockFrameState();
}

class _BlockFrameState extends State<_BlockFrame>
{
  bool _isHovering = false;

  Widget _buildRow(({String start, String end, String title, String detail}) row)
  {
    final accent = widget.accent;
    final String detail = row.detail;

    return BlockTexts(
      child: Row(
        children: [
          const SizedBox(width: _barInset),
          SizedBox(
            width: _barWidth,
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(width: _barGap + 1),
          SizedBox(
            width: _denseRowTimeWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.start, maxLines: 1, softWrap: false, style: _rowTimeStyle(accent)),
                Text(row.end, maxLines: 1, softWrap: false, style: _rowEndStyle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _denseTitleStyle),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: _densePersonStyle),
                ],
              ],
            ),
          ),
          if (widget.isCurrent) ...[
            const SizedBox(width: 8),
            const CurrentLessonBadge(),
          ],
          if (widget.isPast) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_rounded, size: 16, color: AppTheme.trialMutedText),
          ],
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final accent = widget.accent;
    final dense = widget.dense;
    final row = widget.row;

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
            // Only the border fades: the padding changes with the window and must not animate.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hovering ? AppTheme.trialGold : accent.withValues(alpha: 0.45),
                  width: hovering ? _hoverBorder : _restBorder,
                ),
              ),
              // A Stack, not a Row: a flex would overflow at a few pixels wide.
              child: row != null ? _buildRow(row) : Padding(
                padding: EdgeInsets.symmetric(vertical: dense ? 5 : 6),
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
                                          Icon(widget.icon, size: dense ? _hoursIcon - 1 : _hoursIcon, color: accent),
                                          const SizedBox(width: _hoursIconGap),
                                        ],
                                        Expanded(
                                          child: Text.rich(
                                            lessonHoursSpan(widget.hours, _hoursStyle(accent, dense: dense)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!narrow && widget.isCurrent) ...[
                                          const SizedBox(width: 6),
                                          const CurrentLessonBadge(),
                                        ],
                                        if (!narrow && widget.isPast) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.check_rounded, size: 16, color: AppTheme.trialMutedText),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: dense ? 3 : 4),
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

  // A teacher changing room in the band reads the room on each lesson.
  final bool showsRoom;

  const OwnLessonBlock({
    super.key,
    required this.lesson,
    required this.ministrySubjects,
    required this.view,
    required this.isPast,
    this.isCurrent = false,
    this.onTap,
    this.showsRoom = false,
  });

  bool get _byStudent => view == CalendarView.byStudent;

  bool get _saysWhere => _byStudent || showsRoom;

  String get _title => lessonTitle(lesson, view: view);

  ({IconData icon, String label}) get _where => lessonWhere(lesson);

  Color get _whereAccent => lessonWhereAccent(lesson);

  List<String> get _hours => [
        formatTimeRange(lesson.startTime, lesson.endTime),
        formatMinutes(lesson.minutes),
        if (!_byStudent && lesson.mode == kOnlineMode) modeLabel(kOnlineMode),
      ];

  // Below the wide window the third line: who, and where when it says it.
  String get _denseLine => [_title, if (_saysWhere) _where.label].join(' · ');

  // A row of the list below the wide window: the ministry subject first, then the third line.
  String _rowDetail(({String discipline, String? subject}) topic)
  {
    return [
      ?topic.subject,
      _title,
      if (_saysWhere) _where.label else if (!_byStudent && lesson.mode == kOnlineMode) modeLabel(kOnlineMode),
    ].join(' · ');
  }

  // On the timeline: the width that writes each line whole.
  double neededWidth(BuildContext context, {bool dense = false})
  {
    final topic = lessonTopic(lesson, ministrySubjects);
    final hours = blockSpanWidth(context, lessonHoursSpan(_hours, _hoursStyle(lessonAccent(lesson.mode), dense: dense)));
    double capped(double width) => math.min(kWidestBlockLine, width);

    if (dense)
    {
      final lines = [
        _hoursIcon - 1 + _hoursIconGap + hours + (isPast ? _pastMark : 0),
        capped(blockLineWidth(context, topic.discipline, _denseTitleStyle)),
        capped(blockLineWidth(context, _denseLine, _densePersonStyle)),
      ];

      return lines.reduce(math.max) + _chrome;
    }

    final lines = [
      _hoursIcon + _hoursIconGap + hours + (isPast ? _pastMark : 0),
      capped(blockLineWidth(context, topic.discipline, _titleStyle)),
      if (topic.subject case final subject?) capped(blockLineWidth(context, subject, _subjectStyle)),
      capped(blockLineWidth(context, _title, _personStyle)),
      if (_saysWhere)
        _whereIcon + _whereIconGap + capped(blockLineWidth(context, _where.label, _whereStyle(_whereAccent))),
    ];

    return lines.reduce(math.max) + _chrome;
  }

  // At [width], the card's own: every line written, long ones wrapped; never under the usual.
  double heightAt(BuildContext context, double width, {bool dense = false})
  {
    if (dense)
    {
      final double line = blockTextHeight(context, '0', _densePersonStyle, double.infinity);
      final double title = blockTextHeight(context, '0', _denseTitleStyle, double.infinity);

      return math.max(
        kDenseOwnBlockHeight,
        _hoursRowHeight(context, past: isPast, current: isCurrent, dense: true) + 3 + title + 2 + line + _denseFrameTop,
      );
    }

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

    if (_saysWhere)
    {
      height += 3 + math.max(whereIcon == 0 ? 0.0 : _whereIcon, tall(_where.label, _whereStyle(_whereAccent), whereIcon));
    }

    return math.max(kOwnBlockHeight, height + _frameTop);
  }

  TimelineEntry asEntry(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;

    return (
      startMinutes: lesson.startMinutes,
      endMinutes: lesson.endMinutes,
      width: neededWidth(context, dense: dense),
      heightAt: (width) => heightAt(context, width, dense: dense),
      block: this,
    );
  }

  Widget _buildDenseBody(({String discipline, String? subject}) topic)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(topic.discipline, maxLines: 1, overflow: TextOverflow.ellipsis, style: _denseTitleStyle),
        const SizedBox(height: 2),
        Text(_denseLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: _densePersonStyle),
      ],
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
        if (_saysWhere) ...[
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
    final bool dense = AppBreakpoints.of(context).isDense;
    final bool row = dense && OwnListRows.of(context);

    return _BlockFrame(
      accent: lessonAccent(lesson.mode),
      surface: Colors.white,
      icon: lessonModeIcon(lesson.mode),
      hours: _hours,
      isPast: isPast,
      isCurrent: isCurrent,
      // Co-presence (lesson.isShared) is not shown to students and parents.
      onTap: onTap,
      dense: dense,
      row: row
          ? (
              start: formatTimeOfDayShort(lesson.startTime),
              end: formatTimeOfDayShort(lesson.endTime),
              title: topic.discipline,
              detail: _rowDetail(topic),
            )
          : null,
      body: (narrow) => dense ? _buildDenseBody(topic) : _buildBody(topic, narrow: narrow),
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
  double neededWidth(BuildContext context, {bool dense = false})
  {
    final line = blockSpanWidth(context, lessonHoursSpan(_hours, _hoursStyle(kActivityAccent, dense: dense)));
    final hours = _hoursIcon + _hoursIconGap + line + (isPast ? _pastMark : 0);
    final name = math.min(_widestActivityName, blockLineWidth(context, activity.name, dense ? _denseTitleStyle : _titleStyle));

    return math.max(hours, name) + _chrome;
  }

  // At [width], the card's own: the name written whole, wrapped; never under the usual.
  double heightAt(BuildContext context, double width, {bool dense = false})
  {
    final hours = _hoursRowHeight(context, past: isPast, current: isCurrent, dense: dense);
    final name = blockTextHeight(context, activity.name, dense ? _denseTitleStyle : _titleStyle, width - _frameSide);

    if (dense)
    {
      return math.max(kDenseOwnBlockHeight, hours + 3 + name + _denseFrameTop);
    }

    return math.max(kOwnBlockHeight, hours + 4 + name + _frameTop);
  }

  TimelineEntry asEntry(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;

    return (
      startMinutes: activity.startMinutes,
      endMinutes: activity.endMinutes,
      width: neededWidth(context, dense: dense),
      heightAt: (width) => heightAt(context, width, dense: dense),
      block: this,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final bool row = dense && OwnListRows.of(context);

    return _BlockFrame(
      accent: kActivityAccent,
      surface: kActivitySurface,
      icon: kActivityIcon,
      hours: _hours,
      isPast: isPast,
      isCurrent: isCurrent,
      onTap: onTap,
      dense: dense,
      row: row
          ? (
              start: formatTimeOfDayShort(timeOfDayFromMinutes(activity.startMinutes)),
              end: formatTimeOfDayShort(timeOfDayFromMinutes(activity.endMinutes)),
              title: activity.name,
              detail: '',
            )
          : null,
      body: (_) => Text(activity.name, style: dense ? _denseTitleStyle : _titleStyle),
    );
  }
}
