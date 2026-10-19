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
import '../../../../shared/widgets/descender_room.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_current_card.dart';
import '../../../shared/widgets/mobile_tour.dart';

const double _radius = 14;

const EdgeInsets _tourInflate = EdgeInsets.all(4);

const double _barLeft = 8;
const double _barWidth = 4;
const double _barInset = 9;

const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 9, 9, 8);

const double _iconGap = 5;
const double _checkGap = 4;
const double _titleGap = 4;
const double _subjectGap = 1;
const double _personGap = 4;
const double _whereGap = 2;
const double _whereIconGap = 4;

const Color _pastAccent = Color(0xFF93A3AD);

const double kMobilePhoneCardScale = 1.1;
const double kMobileTabletCardScale = 1.15;

// Under this inner width a card drops its icons.
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

  // The discipline, or an activity's name.
  final String title;
  final String? subject;
  final String? person;

  final String? modeWord;

  final MobileLessonWhere? where;

  final bool shared;

  final VoidCallback onTap;

  final String? tourId;

  const MobileCalendarEntry({
    required this.startMinutes,
    required this.endMinutes,
    required this.accent,
    required this.surface,
    required this.icon,
    required this.title,
    this.subject,
    this.person,
    this.modeWord,
    this.where,
    this.shared = false,
    required this.onTap,
    this.tourId,
  });

  factory MobileCalendarEntry.lesson(
    LessonItem lesson,
    List<MinistrySubjectItem> ministrySubjects, {
    required VoidCallback onTap,
    String? tourId,
  })
  {
    final topic = lessonTopic(lesson, ministrySubjects);

    return MobileCalendarEntry(
      startMinutes: lesson.startMinutes,
      endMinutes: lesson.endMinutes,
      accent: lessonAccent(lesson.mode),
      surface: Colors.white,
      icon: lessonModeIcon(lesson.mode),
      title: topic.discipline,
      subject: topic.subject,
      person: lessonTitle(lesson),
      modeWord: lesson.mode == kOnlineMode ? modeLabel(kOnlineMode) : null,
      onTap: onTap,
      tourId: tourId,
    );
  }

  factory MobileCalendarEntry.pupilLesson(
    LessonItem lesson,
    List<MinistrySubjectItem> ministrySubjects, {
    required VoidCallback onTap,
    String? tourId,
  })
  {
    final topic = lessonTopic(lesson, ministrySubjects);

    return MobileCalendarEntry(
      startMinutes: lesson.startMinutes,
      endMinutes: lesson.endMinutes,
      accent: lessonAccent(lesson.mode),
      surface: Colors.white,
      icon: lessonModeIcon(lesson.mode),
      title: topic.discipline,
      subject: topic.subject,
      person: lessonTitle(lesson, view: CalendarView.byStudent),
      where: (
        icon: lessonWhere(lesson).icon,
        label: lessonWhere(lesson).label,
        accent: lessonWhereAccent(lesson),
      ),
      // Co-presence hidden from students and parents for now.
      // shared: lesson.isShared,
      onTap: onTap,
      tourId: tourId,
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

// The height that writes every line of a card whole at [width]; the timeline gives it that.
double mobileCardHeight(
  MobileCalendarEntry entry, {
  required double width,
  required TextScaler scaler,
  required bool past,
  bool inColumn = false,
  double scale = 1,
})
{
  final body = _CardBody(entry: entry, past: past, inColumn: inColumn, scale: scale);

  return _padding.vertical + body._lay(width - _padding.horizontal, double.infinity, scaler).height;
}

// The narrowest card that still writes its hours in their longest form, icon included.
double mobileCardHoursWidth(
  MobileCalendarEntry entry, {
  required TextScaler scaler,
  required bool past,
  bool inColumn = false,
  double scale = 1,
})
{
  final body = _CardBody(entry: entry, past: past, inColumn: inColumn, scale: scale);

  return _padding.horizontal + body._fullHoursWidth(scaler) + 1;
}

// Shows only whole lines: drops from the bottom and shortens the hours to fit.
class MobileLessonCard extends StatelessWidget
{
  final MobileCalendarEntry entry;
  final MobileEntryTime time;

  // Share of the card the now line has crossed, for a running entry.
  final double elapsed;

  // Overlapping another: the range alone, no length, mode or icon.
  final bool inColumn;

  // Landscape tablet track: time and the elapsed tint run left to right.
  final bool horizontal;

  // Type size on a tablet.
  final double scale;

  const MobileLessonCard({
    super.key,
    required this.entry,
    required this.time,
    this.elapsed = 0,
    this.inColumn = false,
    this.horizontal = false,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool past = time == MobileEntryTime.past;
    final bool running = time == MobileEntryTime.running;

    const BorderRadius radius = BorderRadius.all(Radius.circular(_radius));

    return MobileTourTarget(
      id: entry.tourId,
      inflate: _tourInflate,
      radius: _radius + _tourInflate.left,
      child: Semantics(
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
            // The tint glides with the now line to each new minute.
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: elapsed),
              duration: nowGlideOf(context),
              curve: kNowGlideCurve,
              builder: (context, reached, child) => CustomPaint(
                painter: _CardPainter(
                  accent: past ? _pastAccent : entry.accent,
                  elapsed: running ? reached : null,
                  horizontal: horizontal,
                ),
                child: child,
              ),
              child: Padding(
                padding: _padding,
                child: _CardBody(entry: entry, past: past, inColumn: inColumn, scale: scale),
              ),
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

  const _CardPainter({
    required this.accent,
    required this.elapsed,
    required this.horizontal,
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
    final double reached = elapsed * extent;

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
        horizontal != oldDelegate.horizontal;
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

  TextStyle get _hoursStyle => _cardHoursStyle(scale: scale, color: past ? _pastAccent : entry.accent);

  TextStyle get _titleStyle => _cardTitleStyle(scale: scale, past: past, inColumn: inColumn);

  TextStyle get _subjectStyle => _cardSubjectStyle(scale: scale, past: past);

  TextStyle get _personStyle => _cardPersonStyle(scale: scale);

  TextStyle _whereStyle(Color accent) => _cardWhereStyle(scale: scale, color: past ? _pastAccent : accent);

  // Longest first; the last always fits somewhere.
  List<List<String>> get _hourForms
  {
    final String range = formatMinutesRange(entry.startMinutes, entry.endMinutes);

    return [
      if (!inColumn) [range, formatMinutes(entry.minutes), ?entry.modeWord],
      [range],
      [formatTimeOfDayShort(timeOfDayFromMinutes(entry.startMinutes))],
    ];
  }

  TextSpan _hoursSpan(List<String> parts) => lessonHoursSpan(parts, _hoursStyle);

  static TextPainter _measure(InlineSpan span, TextScaler scaler, {int maxLines = 1, double? width})
  {
    return TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width ?? double.infinity);
  }

  static double _height(String text, TextStyle style, TextScaler scaler, {int maxLines = 1, required double width})
  {
    final TextPainter painter = _measure(TextSpan(text: text, style: style), scaler, maxLines: maxLines, width: width);
    final double height = painter.height;

    painter.dispose();

    return height;
  }

  static double _spanWidth(InlineSpan span, TextScaler scaler)
  {
    final TextPainter painter = _measure(span, scaler);
    final double width = painter.width;

    painter.dispose();

    return width;
  }

  static double _width(String text, TextStyle style, TextScaler scaler) => _spanWidth(TextSpan(text: text, style: style), scaler);

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

  double _fullHoursWidth(TextScaler scaler)
  {
    final double check = (past ? 17 * scale + _checkGap : 0) + (entry.shared ? 16 * scale + _checkGap : 0);
    final double icon = inColumn ? 0 : 15 * scale + _iconGap;

    return math.max(_narrowWidth, _spanWidth(_hoursSpan(_hourForms.first), scaler) + icon + check);
  }

  (List<String>, bool) _pickHours(double width, TextScaler scaler, {required bool narrow})
  {
    final List<List<String>> forms = _hourForms;
    // Icons keep their size whatever the text scale.
    final double check = narrow ? 0 : (past ? 17 * scale + _checkGap : 0) + (entry.shared ? 16 * scale + _checkGap : 0);
    final double icon = 15 * scale + _iconGap;

    if (!inColumn && !narrow)
    {
      for (final form in forms)
      {
        if (_spanWidth(_hoursSpan(form), scaler) + icon + check <= width)
        {
          return (form, true);
        }
      }
    }

    for (final form in forms)
    {
      if (_spanWidth(_hoursSpan(form), scaler) + check <= width)
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

  // One optional line under the title: its style and how many of its lines fit.
  (TextStyle, int, double) _optional(String? text, TextStyle style, TextScaler scaler, double width, double room)
  {
    if (text == null)
    {
      return (style, 0, 0.0);
    }

    final TextStyle fitted = _wholeWords(text, style, scaler, width);
    final (int lines, double height) = _fit(text, fitted, scaler, width: width, room: room);

    return (fitted, lines, height);
  }

  // Whole lines only, dropped from the bottom when [room] is short; words never split.
  _CardLines _lay(double width, double room, TextScaler scaler)
  {
    final bool narrow = width < _narrowWidth;

    final (List<String> hours, bool withIcon) = _pickHours(width, scaler, narrow: narrow);

    // Icons keep their size at any text scale: below 1 they stand taller than the words.
    final double hoursIcons = [
      if (withIcon) 15 * scale,
      if (entry.shared && !narrow) 16 * scale,
      if (past && !narrow) 17 * scale,
    ].fold(0.0, math.max);

    double used = math.max(_height(hours.first, _hoursStyle, scaler, width: width), hoursIcons) + _titleGap;

    // Hours and the first line of the title stay even when too tall, cut by the clip.
    final TextStyle titleStyle = _wholeWords(entry.title, _titleStyle, scaler, width);
    final (int titleFitting, double titleHeight) = _fit(entry.title, titleStyle, scaler, width: width, room: room - used);
    final int titleLines = math.max(1, titleFitting);

    used += titleFitting > 0 ? titleHeight : _height(entry.title, titleStyle, scaler, width: width);

    final (TextStyle subjectStyle, int subjectLines, double subjectHeight) =
        _optional(entry.subject, _subjectStyle, scaler, width, room - used - _subjectGap);

    if (subjectLines > 0)
    {
      used += _subjectGap + subjectHeight;
    }

    final bool subjectCut = entry.subject != null && subjectLines == 0;

    final (TextStyle personStyle, int personLines, double personHeight) = subjectCut
        ? (_personStyle, 0, 0.0)
        : _optional(entry.person, _personStyle, scaler, width, room - used - _personGap);

    if (personLines > 0)
    {
      used += _personGap + personHeight;
    }

    // Last, so it is the first to go.
    final MobileLessonWhere? where = entry.where;
    final double whereIcon = inColumn || narrow ? 0 : 14 * scale;
    final double whereWidth = width - whereIcon - (whereIcon == 0 ? 0 : _whereIconGap);
    final (TextStyle whereStyle, int whereLines, double whereHeight) = personLines == 0 && entry.person != null
        ? (_whereStyle(entry.accent), 0, 0.0)
        : _optional(where?.label, _whereStyle(where?.accent ?? entry.accent), scaler, whereWidth, room - used - _whereGap);

    if (whereLines > 0)
    {
      used += _whereGap + math.max(whereHeight, whereIcon);
    }

    return (
      hours: hours,
      withIcon: withIcon,
      titleStyle: titleStyle,
      titleLines: titleLines,
      subjectStyle: subjectStyle,
      subjectLines: subjectLines,
      personStyle: personStyle,
      personLines: personLines,
      whereStyle: whereStyle,
      whereIcon: whereIcon,
      whereLines: whereLines,
      height: used,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth;
        final bool narrow = width < _narrowWidth;

        final _CardLines lines = _lay(width, constraints.maxHeight, scaler);
        final String? subject = entry.subject;
        final String? person = entry.person;
        final MobileLessonWhere? where = entry.where;

        // No ambient style (theme letter spacing), so the lines match those measured above.
        return ClipRect(
          clipper: const _CardFaceClip(),
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
                      if (lines.withIcon) ...[
                        Icon(entry.icon, size: 15 * scale, color: past ? _pastAccent : entry.accent),
                        const SizedBox(width: _iconGap),
                      ],
                      Expanded(
                        child: Text.rich(_hoursSpan(lines.hours), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  const SizedBox(height: _titleGap),
                  DescenderRoom(
                    child: Text(
                      entry.title,
                      maxLines: lines.titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: lines.titleStyle,
                    ),
                  ),
                  if (lines.subjectLines > 0 && subject != null) ...[
                    const SizedBox(height: _subjectGap),
                    DescenderRoom(child: Text(subject, maxLines: lines.subjectLines, overflow: TextOverflow.ellipsis, style: lines.subjectStyle)),
                  ],
                  if (lines.personLines > 0 && person != null) ...[
                    const SizedBox(height: _personGap),
                    DescenderRoom(child: Text(person, maxLines: lines.personLines, overflow: TextOverflow.ellipsis, style: lines.personStyle)),
                  ],
                  if (lines.whereLines > 0 && where != null) ...[
                    const SizedBox(height: _whereGap),
                    _WhereLine(
                      where: where,
                      style: lines.whereStyle,
                      iconSize: lines.whereIcon,
                      past: past,
                      maxLines: lines.whereLines,
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

// The card's whole face: the font's descenders reach below a 1.25 line, into the padding.
class _CardFaceClip extends CustomClipper<Rect>
{
  const _CardFaceClip();

  @override
  Rect getClip(Size size)
  {
    return Rect.fromLTRB(-_padding.left, -_padding.top, size.width + _padding.right, size.height + _padding.bottom);
  }

  @override
  bool shouldReclip(_CardFaceClip oldClipper) => false;
}

typedef _CardLines = ({
  List<String> hours,
  bool withIcon,
  TextStyle titleStyle,
  int titleLines,
  TextStyle subjectStyle,
  int subjectLines,
  TextStyle personStyle,
  int personLines,
  TextStyle whereStyle,
  double whereIcon,
  int whereLines,
  double height,
});

TextStyle _cardHoursStyle({required double scale, required Color color}) => GoogleFonts.plusJakartaSans(
      fontSize: 12.5 * scale,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      height: 1.25,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle _cardTitleStyle({required double scale, required bool past, bool inColumn = false}) => GoogleFonts.plusJakartaSans(
      fontSize: (inColumn ? 15 : 15.5) * scale,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: past ? MobilePalette.mutedText : AppTheme.trialOcean,
    );

TextStyle _cardSubjectStyle({required double scale, required bool past}) => GoogleFonts.plusJakartaSans(
      fontSize: 12.5 * scale,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: past ? MobilePalette.mutedText : AppTheme.trialOcean,
    );

TextStyle _cardPersonStyle({required double scale}) => GoogleFonts.plusJakartaSans(
      fontSize: 13 * scale,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: MobilePalette.mutedText,
    );

TextStyle _cardWhereStyle({required double scale, required Color color}) => GoogleFonts.plusJakartaSans(
      fontSize: 12 * scale,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: color,
    );

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

    final List<String> head = [
      formatMinutesRange(entry.startMinutes, entry.endMinutes),
      formatMinutes(entry.minutes),
      ?entry.modeWord,
    ];
    final String? subject = entry.subject;
    final String? person = entry.person;
    final MobileLessonWhere? where = entry.where;

    final Widget card = Semantics(
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
            painter: _CardPainter(accent: accent, elapsed: null, horizontal: false),
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
                        child: Text.rich(
                          lessonHoursSpan(head, _cardHoursStyle(scale: scale, color: accent)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: _titleGap),
                  Text(entry.title, style: _cardTitleStyle(scale: scale, past: past)),
                  if (subject != null) ...[
                    const SizedBox(height: _subjectGap),
                    Text(subject, style: _cardSubjectStyle(scale: scale, past: past)),
                  ],
                  if (person != null) ...[
                    const SizedBox(height: _personGap),
                    Text(person, style: _cardPersonStyle(scale: scale)),
                  ],
                  if (where != null) ...[
                    const SizedBox(height: _whereGap),
                    _WhereLine(
                      where: where,
                      style: _cardWhereStyle(scale: scale, color: past ? _pastAccent : where.accent),
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

    return MobileTourTarget(
      id: entry.tourId,
      inflate: _tourInflate,
      radius: _radius + _tourInflate.left,
      child: card,
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
        Expanded(child: DescenderRoom(child: Text(where.label, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style))),
      ],
    );
  }
}
