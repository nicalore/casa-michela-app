import 'dart:math' as math;

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/utils/timeline_geometry.dart';
import 'teacher_band_call.dart' show ModeSpan;

class PupilBandPresence
{
  final String pupilTaxCode;

  // Clipped to the band, in the order given.
  final List<({String mode, int startMinutes, int endMinutes})> presences;

  final List<LessonItem> lessons;

  const PupilBandPresence({
    required this.pupilTaxCode,
    required this.presences,
    required this.lessons,
  });

  bool get isEmpty => presences.isEmpty && lessons.isEmpty;

  List<(int, int)> get lessonSpans => [for (final lesson in lessons) (lesson.startMinutes, lesson.endMinutes)];

  // Presences stretched by any lesson outside them.
  (int, int)? get hull
  {
    final all = [
      for (final row in presences) (row.startMinutes, row.endMinutes),
      ...lessonSpans,
    ];

    if (all.isEmpty)
    {
      return null;
    }

    return (
      all.map((span) => span.$1).reduce(math.min),
      all.map((span) => span.$2).reduce(math.max),
    );
  }

  List<ModeSpan> get byMode
  {
    final result = <ModeSpan>[];

    for (final mode in const [kPresenceMode, kOnlineMode])
    {
      final own = [for (final row in presences) if (row.mode == mode) (row.startMinutes, row.endMinutes)];

      if (own.isEmpty)
      {
        continue;
      }

      result.add((
        mode: mode,
        startMinutes: own.map((span) => span.$1).reduce(math.min),
        endMinutes: own.map((span) => span.$2).reduce(math.max),
      ));
    }

    return result;
  }

  // Overlapping lessons count once.
  int get lessonMinutes
  {
    return mergeSpans(lessonSpans).fold(0, (total, span) => total + span.$2 - span.$1);
  }
}

PupilBandPresence pupilBandPresence({
  required DateTime day,
  required TimeBucket band,
  required String pupilTaxCode,
  required List<PresenceItem> presences,
  required List<LessonItem> lessons,
})
{
  final bandStart = bandStartMinutes(band);
  final bandEnd = bandEndMinutes(band);

  final given = <({String mode, int startMinutes, int endMinutes})>[];

  for (final row in presences)
  {
    if (!isSameDate(row.date, day) || row.studentTaxCode != pupilTaxCode)
    {
      continue;
    }

    final clipped = intersectSpan(
      minutesOfTimeOfDay(row.startTime),
      minutesOfTimeOfDay(row.endTime),
      bandStart,
      bandEnd,
    );

    if (clipped != null)
    {
      given.add((mode: row.mode, startMinutes: clipped.$1, endMinutes: clipped.$2));
    }
  }

  final own = [
    for (final lesson in lessons)
      if (isSameDate(lesson.date, day) && lesson.band == band && lesson.studentTaxCodes.contains(pupilTaxCode))
        lesson,
  ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  return PupilBandPresence(pupilTaxCode: pupilTaxCode, presences: given, lessons: own);
}
