import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/lesson_item.dart';
import 'calendar_lesson_block.dart';

const double kCaptionLineHeight = 20;

const double kCaptionGap = 4;

// Between two captions sharing a line.
const double _captionSpacing = 14;

const double _iconSize = 13;
const double _iconGap = 5;

const double _padLeft = 4;
const double _padRight = 7;

const EdgeInsets _padding = EdgeInsets.fromLTRB(_padLeft, 0, _padRight, 0);

const double _border = 1.5;

// The box around the words: padding, border, the mode icon and its gap.
const double _chrome = _padLeft + _padRight + 2 * _border + _iconSize + _iconGap + 1;

// Narrowest a caption wraps to before it leans back from the right edge.
const double _narrowestCaption = 160;

// [width] null: one line as long as the words; otherwise they wrap on [lines] lines.
typedef CaptionSpot = ({double left, int line, int lines, double? width});

// What a row adds under its blocks for [lines] lines of captions.
double captionsExtent(int lines) => lines == 0 ? 0 : kCaptionGap + lines * kCaptionLineHeight;

int captionLinesOf(Map<int, CaptionSpot>? spots)
{
  return spots == null || spots.isEmpty ? 0 : spots.values.map((spot) => spot.line + spot.lines).reduce(math.max);
}

TextSpan _captionSpan(LessonItem lesson, List<MinistrySubjectItem> ministrySubjects)
{
  final accent = lessonAccent(lesson.mode);
  final topic = lessonTopic(lesson, ministrySubjects);

  final base = GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2);
  final quiet = base.copyWith(color: AppTheme.trialMutedText);

  return TextSpan(
    style: base,
    children: [
      TextSpan(
        text: formatTimeRange(lesson.startTime, lesson.endTime),
        style: base.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2, color: accent),
      ),
      const TextSpan(text: '  '),
      TextSpan(text: topic.discipline, style: base.copyWith(fontWeight: FontWeight.w700, color: AppTheme.trialOcean)),
      if (topic.subject case final subject?) TextSpan(text: ' ($subject)', style: quiet.copyWith(fontSize: 11)),
      // Wrapping, the dot stays with the words before it and the name keeps together.
      TextSpan(text: '\u00A0\u00A0·  ', style: quiet.copyWith(color: AppTheme.trialMutedText.withValues(alpha: 0.6))),
      TextSpan(text: lessonTitle(lesson).replaceAll(' ', '\u00A0'), style: base.copyWith(color: AppTheme.trialInk)),
    ],
  );
}

// As drawn inside [BlockTexts], at the text scale of [context].
double lessonCaptionWidth(BuildContext context, LessonItem lesson, List<MinistrySubjectItem> ministrySubjects)
{
  final painter = TextPainter(
    text: _captionSpan(lesson, ministrySubjects),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();

  final width = painter.width;

  painter.dispose();

  return _chrome + width;
}

// The lines the words take in a caption [width] wide.
int lessonCaptionLines(BuildContext context, LessonItem lesson, List<MinistrySubjectItem> ministrySubjects, double width)
{
  final painter = TextPainter(
    text: _captionSpan(lesson, ministrySubjects),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: math.max(1, width - _chrome));

  final lines = painter.computeLineMetrics().length;

  painter.dispose();

  return math.max(1, lines);
}

// Each caption under its block, wrapped short of the right edge, on the first free lines.
Map<int, CaptionSpot> placeLessonCaptions(
  List<LessonItem> lessons, {
  required double Function(int minutes) xOf,
  required double trackWidth,
  required double Function(LessonItem lesson) widthOf,
  required int Function(LessonItem lesson, double width) linesOf,
})
{
  final ordered = [...lessons]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  final ends = <double>[];
  final placed = <int, CaptionSpot>{};

  bool isFree(int line, int lines, double left)
  {
    for (var at = line; at < line + lines && at < ends.length; at++)
    {
      if (ends[at] + _captionSpacing > left)
      {
        return false;
      }
    }

    return true;
  }

  for (final lesson in ordered)
  {
    final natural = widthOf(lesson);
    final narrowest = math.min(natural, _narrowestCaption);
    final left = math.max(0.0, math.min(xOf(lesson.startMinutes) + kBlockSideGap, trackWidth - narrowest));
    final width = math.min(natural, trackWidth - left);
    final wraps = width < natural;
    final lines = wraps ? linesOf(lesson, width) : 1;

    var line = 0;

    while (!isFree(line, lines, left))
    {
      line++;
    }

    for (var at = line; at < line + lines; at++)
    {
      if (at == ends.length)
      {
        ends.add(0);
      }

      ends[at] = left + width;
    }

    placed[lesson.id] = (left: left, line: line, lines: lines, width: wraps ? width : null);
  }

  return placed;
}

class LessonCaption extends StatelessWidget
{
  final LessonItem lesson;

  final List<MinistrySubjectItem> ministrySubjects;

  final ValueListenable<int?> litLesson;

  final ValueChanged<bool> onHover;

  final VoidCallback? onTap;

  final CaptionSpot spot;

  const LessonCaption({
    super.key,
    required this.lesson,
    required this.ministrySubjects,
    required this.litLesson,
    required this.onHover,
    required this.spot,
    this.onTap,
  });

  @override
  Widget build(BuildContext context)
  {
    final accent = lessonAccent(lesson.mode);

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: ValueListenableBuilder<int?>(
          valueListenable: litLesson,
          builder: (context, lit, child)
          {
            final isLit = lit == lesson.id;

            // The page colour under the words keeps the half-hour lines from crossing them.
            // Sized outside the animation: the width follows the track and must never animate.
            return SizedBox(
              width: spot.width,
              height: spot.lines * kCaptionLineHeight - 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: _padding,
                decoration: BoxDecoration(
                  color: isLit ? AppTheme.trialGoldSurface : AppTheme.trialPaper,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isLit ? AppTheme.trialGold : AppTheme.trialPaper, width: _border),
                ),
                child: child,
              ),
            );
          },
          child: BlockTexts(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(lessonModeIcon(lesson.mode), size: _iconSize, color: accent),
                const SizedBox(width: _iconGap),
                if (spot.width == null)
                  Text.rich(_captionSpan(lesson, ministrySubjects), maxLines: 1, softWrap: false)
                else
                  Expanded(child: Text.rich(_captionSpan(lesson, ministrySubjects), maxLines: spot.lines)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
