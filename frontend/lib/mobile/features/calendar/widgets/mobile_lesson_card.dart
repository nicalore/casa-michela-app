import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/ministry_subject_item.dart';
import '../../../../features/calendar/widgets/own_lesson_block.dart' show kSharedLessonIcon;
import '../../../../features/lessons/models/activity_item.dart';
import '../../../../features/lessons/models/calendar_day.dart';
import '../../../../features/lessons/models/lesson_item.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_activity_block.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_current_card.dart';

const double _radius = 14;

const double _barLeft = 8;
const double _barWidth = 4;
const double _barInset = 9;

const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 9, 9, 8);

const double _iconGap = 5;
const double _checkGap = 4;
const double _nameGap = 4;
const double _lineGap = 3;
const double _whereIconGap = 4;

const Color _pastAccent = Color(0xFF93A3AD);

const double kMobilePhoneCardScale = 1.1;
const double kMobileTabletCardScale = 1.15;

// Under this inner width a card drops its icons, as on the desktop.
const double _narrowWidth = 81;

// How far a word may shrink so a card never splits it across two lines.
const double _minWordFit = 0.75;

const Color _elapsedTint = Color(0x1CE4674F);

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x38041E2D), offset: Offset(0, 8), blurRadius: 18),
];

enum MobileEntryTime { upcoming, running, past }

const Decoration _runningRim = MobileCurrentCard(BorderRadius.all(Radius.circular(_radius)));

typedef MobileLessonWhere = ({IconData icon, String label, Color accent});

class MobileCalendarEntry
{
  final int startMinutes;
  final int endMinutes;

  final Color accent;
  final Color surface;
  final IconData icon;

  final String title;
  final String? subject;
  final String? disciplines;

  final String? modeWord;

  final MobileLessonWhere? where;

  final bool shared;

  final bool brief;

  final VoidCallback onTap;

  const MobileCalendarEntry({
    required this.startMinutes,
    required this.endMinutes,
    required this.accent,
    required this.surface,
    required this.icon,
    required this.title,
    this.subject,
    this.disciplines,
    this.modeWord,
    this.where,
    this.shared = false,
    this.brief = false,
    required this.onTap,
  });

  factory MobileCalendarEntry.lesson(
    LessonItem lesson,
    List<MinistrySubjectItem> ministrySubjects, {
    required VoidCallback onTap,
  })
  {
    final about = lessonAbout(lesson, ministrySubjects);

    return MobileCalendarEntry(
      startMinutes: lesson.startMinutes,
      endMinutes: lesson.endMinutes,
      accent: lessonAccent(lesson.mode),
      surface: Colors.white,
      icon: lessonModeIcon(lesson.mode),
      title: lessonTitle(lesson),
      subject: about.subject,
      disciplines: about.disciplines,
      modeWord: lesson.mode == kOnlineMode ? modeLabel(kOnlineMode) : null,
      onTap: onTap,
    );
  }

  factory MobileCalendarEntry.pupilLesson(
    LessonItem lesson,
    List<MinistrySubjectItem> ministrySubjects, {
    required VoidCallback onTap,
  })
  {
    final about = lessonAbout(lesson, ministrySubjects);

    return MobileCalendarEntry(
      startMinutes: lesson.startMinutes,
      endMinutes: lesson.endMinutes,
      accent: lessonAccent(lesson.mode),
      surface: Colors.white,
      icon: lessonModeIcon(lesson.mode),
      title: lessonTitle(lesson, view: CalendarView.byStudent),
      subject: about.subject,
      disciplines: about.disciplines,
      where: (
        icon: lessonWhere(lesson).icon,
        label: lessonWhere(lesson).label,
        accent: lessonWhereAccent(lesson),
      ),
      shared: lesson.isShared,
      brief: lesson.minutes <= kMinimumBandMinutes,
      onTap: onTap,
    );
  }

  factory MobileCalendarEntry.activity(ScheduledActivity activity, {required VoidCallback onTap})
  {
    return MobileCalendarEntry(
      startMinutes: activity.startMinutes,
      endMinutes: activity.endMinutes,
      accent: kActivityAccent,
      surface: kActivitySurface,
      icon: kActivityIcon,
      title: activity.name,
      onTap: onTap,
    );
  }

  int get minutes => endMinutes - startMinutes;

  MobileEntryTime timeAt(int? nowMinutes, {required bool pastDay})
  {
    if (pastDay)
    {
      return MobileEntryTime.past;
    }

    if (nowMinutes == null || nowMinutes < startMinutes)
    {
      return MobileEntryTime.upcoming;
    }

    return nowMinutes < endMinutes ? MobileEntryTime.running : MobileEntryTime.past;
  }
}

// Shows only whole lines: drops from the bottom and shortens the hours to fit.
class MobileLessonCard extends StatelessWidget
{
  final MobileCalendarEntry entry;
  final MobileEntryTime time;

  // Share of the hours gone by, for a running entry.
  final double elapsed;

  // Overlapping another: the range alone, no length, mode or icon.
  final bool inColumn;

  // Landscape tablet track: time and the elapsed tint run left to right.
  final bool horizontal;

  // Card offset from its hours at each end, so the elapsed tint meets the now line.
  final double timeInset;

  // Type size on a tablet.
  final double scale;

  const MobileLessonCard({
    super.key,
    required this.entry,
    required this.time,
    this.elapsed = 0,
    this.inColumn = false,
    this.horizontal = false,
    this.timeInset = 0,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool past = time == MobileEntryTime.past;
    final bool running = time == MobileEntryTime.running;

    const BorderRadius radius = BorderRadius.all(Radius.circular(_radius));

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: entry.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: entry.surface,
            borderRadius: radius,
            boxShadow: _shadow,
          ),
          foregroundDecoration: running ? _runningRim : null,
          child: CustomPaint(
            painter: _CardPainter(
              accent: past ? _pastAccent : entry.accent,
              elapsed: running ? elapsed : null,
              horizontal: horizontal,
              timeInset: timeInset,
            ),
            child: Padding(
              padding: _padding,
              child: _CardBody(entry: entry, past: past, inColumn: inColumn, scale: scale),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardPainter extends CustomPainter
{
  final Color accent;
  final double? elapsed;
  final bool horizontal;
  final double timeInset;

  const _CardPainter({
    required this.accent,
    required this.elapsed,
    required this.horizontal,
    required this.timeInset,
  });

  @override
  void paint(Canvas canvas, Size size)
  {
    final double? elapsed = this.elapsed;

    final RRect bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(_barLeft, _barInset, _barWidth, size.height - 2 * _barInset),
      const Radius.circular(_barWidth / 2),
    );

    if (elapsed == null)
    {
      canvas.drawRRect(bar, Paint()..color = accent);

      return;
    }

    final double extent = horizontal ? size.width : size.height;
    final double reached = elapsed * (extent + 2 * timeInset) - timeInset;

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_radius)));
    canvas.drawRect(
      horizontal ? Rect.fromLTWH(0, 0, reached, size.height) : Rect.fromLTWH(0, 0, size.width, reached),
      Paint()..color = _elapsedTint,
    );
    canvas.restore();

    canvas.drawRRect(bar, Paint()..color = accent);

    if (!horizontal)
    {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, size.width, reached));
      canvas.drawRRect(bar, Paint()..color = MobilePalette.nowLine);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CardPainter oldDelegate)
  {
    return accent != oldDelegate.accent ||
        elapsed != oldDelegate.elapsed ||
        horizontal != oldDelegate.horizontal ||
        timeInset != oldDelegate.timeInset;
  }
}

class _CardBody extends StatelessWidget
{
  final MobileCalendarEntry entry;
  final bool past;
  final bool inColumn;
  final double scale;

  const _CardBody({
    required this.entry,
    required this.past,
    required this.inColumn,
    required this.scale,
  });

  TextStyle get _hoursStyle => GoogleFonts.plusJakartaSans(
        fontSize: 12.5 * scale,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        height: 1.25,
        color: past ? _pastAccent : entry.accent,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle get _nameStyle => GoogleFonts.plusJakartaSans(
        fontSize: (inColumn ? 15 : 15.5) * scale,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: past ? MobilePalette.mutedText : AppTheme.trialOcean,
      );

  TextStyle get _subjectStyle => GoogleFonts.plusJakartaSans(
        fontSize: 13 * scale,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: past ? MobilePalette.mutedText : AppTheme.trialInk,
      );

  TextStyle get _disciplinesStyle => GoogleFonts.plusJakartaSans(
        fontSize: 12 * scale,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: MobilePalette.mutedText,
      );

  TextStyle _whereStyle(Color accent) => GoogleFonts.plusJakartaSans(
        fontSize: 12 * scale,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: past ? _pastAccent : accent,
      );

  // Longest first; the last always fits somewhere.
  List<String> get _hourForms
  {
    final String range = formatMinutesRange(entry.startMinutes, entry.endMinutes);

    return [
      if (!inColumn && !entry.brief) [range, formatMinutes(entry.minutes), ?entry.modeWord].join(' · '),
      range,
      formatTimeOfDayShort(timeOfDayFromMinutes(entry.startMinutes)),
    ];
  }

  static TextPainter _measure(String text, TextStyle style, TextScaler scaler, {int maxLines = 1, double? width})
  {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width ?? double.infinity);
  }

  static double _height(String text, TextStyle style, TextScaler scaler, {int maxLines = 1, required double width})
  {
    final TextPainter painter = _measure(text, style, scaler, maxLines: maxLines, width: width);
    final double height = painter.height;

    painter.dispose();

    return height;
  }

  static double _width(String text, TextStyle style, TextScaler scaler)
  {
    final TextPainter painter = _measure(text, style, scaler);
    final double width = painter.width;

    painter.dispose();

    return width;
  }

  // Whole lines of [text] that fit in [room], and their height.
  static (int, double) _fit(String text, TextStyle style, TextScaler scaler, {required double width, required double room})
  {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: width);

    final List<LineMetrics> lines = painter.computeLineMetrics();

    painter.dispose();

    var count = 0;
    var height = 0.0;

    for (final line in lines)
    {
      if (height + line.height > room)
      {
        break;
      }

      count += 1;
      height += line.height;
    }

    return (count, height);
  }

  (String, bool) _pickHours(double width, TextScaler scaler, {required bool narrow})
  {
    final List<String> forms = _hourForms;
    // Icons keep their size whatever the text scale.
    final double check = narrow ? 0 : (past ? 17 * scale + _checkGap : 0) + (entry.shared ? 16 * scale + _checkGap : 0);
    final double icon = 15 * scale + _iconGap;

    if (!inColumn && !narrow)
    {
      for (final form in forms)
      {
        if (_width(form, _hoursStyle, scaler) + icon + check <= width)
        {
          return (form, true);
        }
      }
    }

    for (final form in forms)
    {
      if (_width(form, _hoursStyle, scaler) + check <= width)
      {
        return (form, false);
      }
    }

    return (forms.last, false);
  }

  static TextStyle _wholeWords(String text, TextStyle style, TextScaler scaler, double width)
  {
    final double widest = text.split(' ').fold(0.0, (widest, word) => math.max(widest, _width(word, style, scaler)));

    if (widest <= width || widest == 0)
    {
      return style;
    }

    // A hair under the exact ratio, so rounding never wraps the word after all.
    return style.copyWith(fontSize: style.fontSize! * math.max(_minWordFit, width / widest * 0.98));
  }

  @override
  Widget build(BuildContext context)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth;
        final double room = constraints.maxHeight;
        final bool narrow = width < _narrowWidth;

        final (String hours, bool withIcon) = _pickHours(width, scaler, narrow: narrow);

        final String headline = entry.brief ? entry.subject ?? entry.title : entry.title;
        final TextStyle nameStyle = _wholeWords(headline, _nameStyle, scaler, width);

        double used = _height(hours, _hoursStyle, scaler, width: width) + _nameGap;

        final int nameLines =
            used + _height(headline, nameStyle, scaler, maxLines: 2, width: width) <= room ? 2 : 1;

        used += _height(headline, nameStyle, scaler, maxLines: nameLines, width: width);

        final String? subject = entry.brief ? null : entry.subject;
        final TextStyle subjectStyle = subject == null ? _subjectStyle : _wholeWords(subject, _subjectStyle, scaler, width);
        final (int subjectLines, double subjectHeight) = subject == null
            ? (0, 0.0)
            : _fit(subject, subjectStyle, scaler, width: width, room: room - used - _lineGap);
        final bool showsSubject = subjectLines > 0;

        if (showsSubject)
        {
          used += _lineGap + subjectHeight;
        }

        final String? disciplines = entry.brief ? null : entry.disciplines;
        final (int fitting, double fittingHeight) = disciplines == null || !showsSubject || inColumn
            ? (0, 0.0)
            : _fit(disciplines, _disciplinesStyle, scaler, width: width, room: room - used - _lineGap);
        // Narrow, a single line cut short: the words are too long to stack.
        final int disciplineLines = narrow ? math.min(1, fitting) : fitting;
        final double disciplineHeight = narrow && fitting > 1
            ? _height(disciplines!, _disciplinesStyle, scaler, width: width)
            : fittingHeight;
        final bool showsDisciplines = disciplineLines > 0;

        if (showsDisciplines)
        {
          used += _lineGap + disciplineHeight;
        }

        // Last, as on the desktop, so it goes first; a narrow card keeps it on one line.
        final MobileLessonWhere? where = entry.brief ? null : entry.where;
        final double whereIcon = inColumn || narrow ? 0 : 14 * scale;
        final (int whereFitting, double _) = where == null
            ? (0, 0.0)
            : _fit(
                where.label,
                _whereStyle(where.accent),
                scaler,
                width: width - whereIcon - (whereIcon == 0 ? 0 : _whereIconGap),
                room: room - used - _lineGap,
              );
        final int whereLines = narrow ? math.min(1, whereFitting) : whereFitting;
        final bool showsWhere = where != null && whereLines > 0 && used + _lineGap + whereIcon <= room;

        // Hours and name stay even when too tall, cut by the clip. No ambient
        // style (theme letter spacing), so the lines match those measured above.
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minHeight: 0,
            maxHeight: double.infinity,
            child: DefaultTextStyle(
              style: const TextStyle(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (withIcon) ...[
                        Icon(entry.icon, size: 15 * scale, color: past ? _pastAccent : entry.accent),
                        const SizedBox(width: _iconGap),
                      ],
                      Expanded(
                        child: Text(hours, maxLines: 1, overflow: TextOverflow.ellipsis, style: _hoursStyle),
                      ),
                      if (entry.shared && !narrow) ...[
                        const SizedBox(width: _checkGap),
                        Icon(kSharedLessonIcon, size: 16 * scale, color: MobilePalette.mutedText),
                      ],
                      if (past && !narrow) ...[
                        const SizedBox(width: _checkGap),
                        Icon(Icons.check_rounded, size: 17 * scale, color: MobilePalette.mutedText),
                      ],
                    ],
                  ),
                  const SizedBox(height: _nameGap),
                  Text(
                    headline,
                    maxLines: nameLines,
                    overflow: TextOverflow.ellipsis,
                    style: nameStyle,
                  ),
                  if (showsSubject && subject != null) ...[
                    const SizedBox(height: _lineGap),
                    Text(subject, maxLines: subjectLines, overflow: TextOverflow.ellipsis, style: subjectStyle),
                  ],
                  if (showsDisciplines && disciplines != null) ...[
                    const SizedBox(height: _lineGap),
                    Text(
                      disciplines,
                      maxLines: disciplineLines,
                      overflow: TextOverflow.ellipsis,
                      style: _disciplinesStyle,
                    ),
                  ],
                  if (showsWhere) ...[
                    const SizedBox(height: _lineGap),
                    _WhereLine(
                      where: where,
                      style: _whereStyle(where.accent),
                      iconSize: whereIcon,
                      past: past,
                      maxLines: whereLines,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// The "Per lezioni" card: never cut, as tall as its lines.
class MobileLessonListCard extends StatelessWidget
{
  final MobileCalendarEntry entry;
  final MobileEntryTime time;

  final double scale;

  const MobileLessonListCard({
    super.key,
    required this.entry,
    required this.time,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool past = time == MobileEntryTime.past;
    final Color accent = past ? _pastAccent : entry.accent;

    const BorderRadius radius = BorderRadius.all(Radius.circular(_radius));

    final String head = [
      formatMinutesRange(entry.startMinutes, entry.endMinutes),
      formatMinutes(entry.minutes),
      ?entry.modeWord,
    ].join(' · ');
    final String? subject = entry.subject;
    final String? disciplines = entry.disciplines;
    final MobileLessonWhere? where = entry.where;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: entry.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: entry.surface,
            borderRadius: radius,
            boxShadow: _shadow,
          ),
          foregroundDecoration: time == MobileEntryTime.running ? _runningRim : null,
          child: CustomPaint(
            painter: _CardPainter(accent: accent, elapsed: null, horizontal: false, timeInset: 0),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 11 * scale, 12, 12 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(entry.icon, size: 15 * scale, color: accent),
                      const SizedBox(width: _iconGap),
                      Expanded(
                        child: Text(
                          head,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5 * scale,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            height: 1.25,
                            color: accent,
                          ),
                        ),
                      ),
                      if (entry.shared) ...[
                        const SizedBox(width: _checkGap),
                        Icon(kSharedLessonIcon, size: 16 * scale, color: MobilePalette.mutedText),
                      ],
                      if (past) ...[
                        const SizedBox(width: _checkGap),
                        Icon(Icons.check_rounded, size: 17 * scale, color: MobilePalette.mutedText),
                      ],
                    ],
                  ),
                  const SizedBox(height: _nameGap),
                  Text(
                    entry.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5 * scale,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: past ? MobilePalette.mutedText : AppTheme.trialOcean,
                    ),
                  ),
                  if (subject != null) ...[
                    const SizedBox(height: _lineGap),
                    Text(
                      subject,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: past ? MobilePalette.mutedText : AppTheme.trialInk,
                      ),
                    ),
                  ],
                  if (disciplines != null) ...[
                    const SizedBox(height: _lineGap),
                    Text(
                      disciplines,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: MobilePalette.mutedText,
                      ),
                    ),
                  ],
                  if (where != null) ...[
                    const SizedBox(height: _lineGap),
                    _WhereLine(
                      where: where,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: past ? _pastAccent : where.accent,
                      ),
                      iconSize: 14 * scale,
                      past: past,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WhereLine extends StatelessWidget
{
  final MobileLessonWhere where;
  final TextStyle style;

  // Zero drops the icon.
  final double iconSize;

  final bool past;

  final int? maxLines;

  const _WhereLine({
    required this.where,
    required this.style,
    required this.iconSize,
    required this.past,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (iconSize > 0) ...[
          Icon(where.icon, size: iconSize, color: past ? _pastAccent : where.accent),
          const SizedBox(width: _whereIconGap),
        ],
        Expanded(child: Text(where.label, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );
  }
}
