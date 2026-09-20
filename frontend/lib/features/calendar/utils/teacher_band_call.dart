import 'dart:math' as math;

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/models/activity_item.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/models/room_supervision_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/utils/timeline_geometry.dart';

typedef ModeSpan = ({String mode, int startMinutes, int endMinutes});

class TeacherBandCall
{
  final List<LessonItem> lessons;
  final List<ScheduledActivity> activities;

  // Clipped to the band and merged.
  final List<(int, int)> supervisions;

  const TeacherBandCall({
    required this.lessons,
    required this.activities,
    required this.supervisions,
  });

  bool get isEmpty => lessons.isEmpty && activities.isEmpty;

  List<(int, int)> get spans
  {
    return [
      for (final lesson in lessons) (lesson.startMinutes, lesson.endMinutes),
      for (final activity in activities) (activity.startMinutes, activity.endMinutes),
    ];
  }

  (int, int)? get hull
  {
    final all = spans;

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
      final own = [
        for (final lesson in lessons)
          if (lesson.teacherMode == mode) (lesson.startMinutes, lesson.endMinutes),
        for (final activity in activities)
          if (activity.placement.teacherMode == mode) (activity.startMinutes, activity.endMinutes),
      ];

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

  // One room per teacher per day, so the first lesson's room suffices.
  RoomOptionItem? get room => lessons.map((lesson) => lesson.room).nonNulls.firstOrNull;

  int get studentCount => {for (final lesson in lessons) ...lesson.studentTaxCodes}.length;

  // Overlapping lessons count once.
  int get lessonMinutes
  {
    final merged = mergeSpans([
      for (final lesson in lessons) (lesson.startMinutes, lesson.endMinutes),
    ]);

    return merged.fold(0, (total, span) => total + span.$2 - span.$1);
  }
}

// The server hands an administrator who also teaches everybody's lessons.
TeacherBandCall teacherBandCall({
  required DateTime day,
  required TimeBucket band,
  required List<LessonItem> lessons,
  required List<ActivityItem> activities,
  required List<RoomSupervisionItem> supervisions,
  required String? teacherTaxCode,
})
{
  bool isMine(String taxCode) => teacherTaxCode == null || taxCode == teacherTaxCode;

  final bandStart = bandStartMinutes(band);
  final bandEnd = bandEndMinutes(band);

  final own = [
    for (final lesson in lessons)
      if (isSameDate(lesson.date, day) && lesson.band == band && isMine(lesson.teacherTaxCode))
        lesson,
  ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  final given = <ScheduledActivity>[];

  for (final activity in activities)
  {
    final scheduled = ScheduledActivity.of(activity);

    if (scheduled != null &&
        isSameDate(activity.date, day) &&
        activity.band == band &&
        isMine(scheduled.teacherTaxCode))
    {
      given.add(scheduled);
    }
  }

  given.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  final shifts = <(int, int)>[];

  for (final shift in supervisions)
  {
    if (!isSameDate(shift.date, day) || !isMine(shift.teacherTaxCode))
    {
      continue;
    }

    final clipped = intersectSpan(shift.startMinutes, shift.endMinutes, bandStart, bandEnd);

    if (clipped != null)
    {
      shifts.add(clipped);
    }
  }

  return TeacherBandCall(
    lessons: own,
    activities: given,
    supervisions: mergeSpans(shifts),
  );
}

List<AvailabilityItem> availabilitiesIn({
  required DateTime day,
  required TimeBucket band,
  required List<AvailabilityItem> availabilities,
  required String? teacherTaxCode,
})
{
  final bandStart = bandStartMinutes(band);
  final bandEnd = bandEndMinutes(band);

  return [
    for (final slot in availabilities)
      if (isSameDate(slot.date, day) &&
          (teacherTaxCode == null || slot.teacherTaxCode == teacherTaxCode) &&
          spansOverlap(
            minutesOfTimeOfDay(slot.startTime),
            minutesOfTimeOfDay(slot.endTime),
            bandStart,
            bandEnd,
          ))
        slot,
  ];
}
