import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/ministry_subject_item.dart';
import '../../../../features/lessons/models/activity_item.dart';
import '../../../../features/lessons/models/lesson_item.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_activity_block.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';

const double _radius = 14;

const double _barLeft = 8;
const double _barWidth = 4;
const double _barInset = 9;

const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 9, 9, 8);

const double _iconGap = 5;
const double _checkGap = 4;
const double _nameGap = 4;
const double _lineGap = 3;

const Color _pastAccent = Color(0xFF93A3AD);

const Color _elapsedTint = Color(0x1CE4674F);

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x38041E2D), offset: Offset(0, 8), blurRadius: 18),
];

enum MobileEntryTime { upcoming, running, past }

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
          decoration: BoxDecoration(color: entry.surface, borderRadius: radius, boxShadow: _shadow),
          foregroundDecoration: running
              ? BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: MobilePalette.currentRim,
                    width: MobilePalette.currentRimWidth,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                )
              : null,
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

  // Longest first; the last always fits somewhere.
  List<String> get _hourForms
  {
    final String range = formatMinutesRange(entry.startMinutes, entry.endMinutes);

    return [
      if (!inColumn) [range, formatMinutes(entry.minutes), ?entry.modeWord].join(' · '),
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

  (String, bool) _pickHours(double width, TextScaler scaler)
  {
    final List<String> forms = _hourForms;
    // Icons keep their size whatever the text scale.
    final double check = past ? 17 * scale + _checkGap : 0;
    final double icon = 15 * scale + _iconGap;

    if (!inColumn)
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

  @override
  Widget build(BuildContext context)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth;
        final double room = constraints.maxHeight;

        final (String hours, bool withIcon) = _pickHours(width, scaler);

        double used = _height(hours, _hoursStyle, scaler, width: width) + _nameGap;

        final int nameLines =
            used + _height(entry.title, _nameStyle, scaler, maxLines: 2, width: width) <= room ? 2 : 1;

        used += _height(entry.title, _nameStyle, scaler, maxLines: nameLines, width: width);

        final String? subject = entry.subject;
        final (int subjectLines, double subjectHeight) = subject == null
            ? (0, 0.0)
            : _fit(subject, _subjectStyle, scaler, width: width, room: room - used - _lineGap);
        final bool showsSubject = subjectLines > 0;

        if (showsSubject)
        {
          used += _lineGap + subjectHeight;
        }

        final String? disciplines = entry.disciplines;
        final (int disciplineLines, double _) = disciplines == null || !showsSubject || inColumn
            ? (0, 0.0)
            : _fit(disciplines, _disciplinesStyle, scaler, width: width, room: room - used - _lineGap);
        final bool showsDisciplines = disciplineLines > 0;

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
                      if (past) ...[
                        const SizedBox(width: _checkGap),
                        Icon(Icons.check_rounded, size: 17 * scale, color: MobilePalette.mutedText),
                      ],
                    ],
                  ),
                  const SizedBox(height: _nameGap),
                  Text(
                    entry.title,
                    maxLines: nameLines,
                    overflow: TextOverflow.ellipsis,
                    style: _nameStyle,
                  ),
                  if (showsSubject && subject != null) ...[
                    const SizedBox(height: _lineGap),
                    Text(subject, maxLines: subjectLines, overflow: TextOverflow.ellipsis, style: _subjectStyle),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
