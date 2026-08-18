import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'availability_item.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

// One row of the calendar: a teacher, what they offered inside the band, and
// what has already been put on them.
//
// A row per teacher and not per availability, which is the shape the server
// enforces rather than a matter of taste: two lessons of the same teacher may
// not overlap *across both modes*, so two lanes for one person would be two
// lanes of which at most one can ever be busy — an invitation to do the one
// thing the server refuses.
class TeacherLane
{
  final String teacherTaxCode;
  final PersonOptionItem teacher;

  // Everything they offered that reaches into this band, in either mode. Not
  // clipped: the lesson has to fall inside one whole availability row, so the
  // row is what the rules are read against. The clipping is for the drawing.
  final List<AvailabilityItem> availabilities;

  // What is already planned on them in this band, earliest first.
  final List<LessonItem> lessons;

  const TeacherLane({
    required this.teacherTaxCode,
    required this.teacher,
    required this.availabilities,
    required this.lessons,
  });

  List<AvailabilityItem> availabilitiesIn(String mode)
  {
    return availabilities.where((slot) => slot.mode == mode).toList();
  }

  // The rows an hour of [lessonMode] could be taken out of, which is not the
  // same question as which rows are *in* that mode.
  //
  // A teacher in the building can take a pupil who is at a screen; one
  // connected from home cannot take a pupil sitting in front of them. So a
  // remote hour has both kinds of row open to it and a hour in the building
  // only its own — the rule [resolveAvailability] applies at the drop, read
  // here by whoever has to decide what to *offer*.
  List<AvailabilityItem> availabilitiesTaking(String lessonMode)
  {
    return availabilities
        .where((slot) => slot.mode == kPresenceMode || lessonMode == kOnlineMode)
        .toList();
  }

  // Where the teacher offered to be, per mode, clipped to the band and fused:
  // two rows written 09:00–11:00 and 11:00–13:00 are one stretch of the
  // morning, and a seam between them would draw a gap that is not there.
  List<(int, int)> spansIn(String mode, int bandStart, int bandEnd)
  {
    final spans = <(int, int)>[];

    for (final slot in availabilitiesIn(mode))
    {
      final clipped = intersectSpan(
        minutesOfTimeOfDay(slot.startTime),
        minutesOfTimeOfDay(slot.endTime),
        bandStart,
        bandEnd,
      );

      if (clipped != null)
      {
        spans.add(clipped);
      }
    }

    return mergeSpans(spans);
  }

  // Whether the two modes overlap anywhere in the band. Where they do, the
  // lane is drawn split in two halves for its whole width rather than in
  // alternating segments: a row that changes height halfway is unreadable.
  bool splitsModes(int bandStart, int bandEnd)
  {
    final presence = spansIn(kPresenceMode, bandStart, bandEnd);
    final online = spansIn(kOnlineMode, bandStart, bandEnd);

    return presence.any((a) => online.any((b) => spansOverlap(a.$1, a.$2, b.$1, b.$2)));
  }

  // The stretch of the band this row has anything in at all, availabilities
  // and lessons together. It is one of the two things the axis is sized on.
  List<(int, int)> contentSpans(int bandStart, int bandEnd)
  {
    return [
      ...spansIn(kPresenceMode, bandStart, bandEnd),
      ...spansIn(kOnlineMode, bandStart, bandEnd),
      for (final lesson in lessons) (lesson.startMinutes, lesson.endMinutes),
    ];
  }

  // Which sub-lane each lesson of this row is drawn in, and how many the row
  // needs.
  //
  // Two hours of one teacher may run together — a doposcuola works that way,
  // and the server caps it at two pupils rather than forbidding it — so a row
  // is not one line of blocks any more. Overlapping hours are stacked, and the
  // row grows to hold them.
  //
  // [memory] is where each lesson was drawn last time, by id. It is what keeps
  // the row still when one block is moved: without it, moving the lower of two
  // stacked hours to an earlier start renumbers both, and the block nobody
  // touched slides up as if it had been dragged too.
  ({List<int> laneOf, int laneCount}) subLanesWith([Map<int, int> memory = const {}])
  {
    return assignSubLanes(
      [for (final lesson in lessons) (lesson.startMinutes, lesson.endMinutes)],
      preferred: [for (final lesson in lessons) memory[lesson.id]],
    );
  }

  // The busiest moment of this teacher's band, in pupils. The same count the
  // server caps, shown in the head of the row so that a full teacher can be
  // seen before a drop is attempted on them.
  int get peakStudents
  {
    return peakConcurrentStudents([
      for (final lesson in lessons)
        (lesson.startMinutes, lesson.endMinutes, lesson.studentTaxCodes.length),
    ]);
  }
}

// Those in the building first, those only at a screen after them, and each
// group by name.
//
// It follows how a day is actually composed: the pupils who are here have to
// be given to somebody who is here, so the rows that can take them come first,
// and the remote-only teachers — who can only take remote pupils — sit
// together at the bottom where they read as the group they are.
int _byPresenceThenName(TeacherLane a, TeacherLane b)
{
  final aInBuilding = a.availabilitiesIn(kPresenceMode).isNotEmpty;
  final bInBuilding = b.availabilitiesIn(kPresenceMode).isNotEmpty;

  if (aInBuilding != bInBuilding)
  {
    return aInBuilding ? -1 : 1;
  }

  return a.teacher.fullName.toLowerCase().compareTo(b.teacher.fullName.toLowerCase());
}

// The rows of one day in one band, in the order they are drawn.
//
// A teacher with nothing offered in the band has no row: there is no legal
// place to drop anything on them. One with a lesson but no availability keeps
// theirs all the same — the data should not allow it, but if it ever does, a
// lesson nobody can see is worse than a row that looks odd.
List<TeacherLane> buildTeacherLanes({
  required List<AvailabilityItem> availabilities,
  required List<LessonItem> lessons,
  required DateTime day,
  required TimeBucket band,
})
{
  final bandStart = bandStartMinutes(band);
  final bandEnd = bandEndMinutes(band);

  final slotsByTeacher = <String, List<AvailabilityItem>>{};
  final lessonsByTeacher = <String, List<LessonItem>>{};
  final faces = <String, PersonOptionItem>{};

  for (final slot in availabilities)
  {
    if (!isSameDate(slot.date, day))
    {
      continue;
    }

    final start = minutesOfTimeOfDay(slot.startTime);
    final end = minutesOfTimeOfDay(slot.endTime);

    if (!spansOverlap(start, end, bandStart, bandEnd))
    {
      continue;
    }

    slotsByTeacher.putIfAbsent(slot.teacherTaxCode, () => []).add(slot);
    faces[slot.teacherTaxCode] = slot.teacher;
  }

  for (final lesson in lessons)
  {
    if (!isSameDate(lesson.date, day) || lesson.band != band)
    {
      continue;
    }

    lessonsByTeacher.putIfAbsent(lesson.teacherTaxCode, () => []).add(lesson);
    faces.putIfAbsent(lesson.teacherTaxCode, () => lesson.teacher);
  }

  final lanes = [
    for (final entry in faces.entries)
      TeacherLane(
        teacherTaxCode: entry.key,
        teacher: entry.value,
        availabilities: slotsByTeacher[entry.key] ?? <AvailabilityItem>[],
        lessons: (lessonsByTeacher[entry.key] ?? <LessonItem>[])
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)),
      ),
  ];

  return lanes..sort(_byPresenceThenName);
}
