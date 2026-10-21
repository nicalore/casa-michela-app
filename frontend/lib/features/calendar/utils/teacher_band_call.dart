import 'dart:math' as math;

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/models/activity_item.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/models/person_option_item.dart';
import '../../lessons/models/room_supervision_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/utils/timeline_geometry.dart';

typedef ModeSpan = ({String mode, int startMinutes, int endMinutes});

class RoomSupervisor
{
  final PersonOptionItem person;

  // Clipped to the band and merged.
  final List<(int, int)> spans;

  final bool isSelf;

  const RoomSupervisor({required this.person, required this.spans, required this.isSelf});
}

// One room of the band: the hours of the teacher's own lessons there.
class RoomStay
{
  final RoomOptionItem room;
  final int startMinutes;
  final int endMinutes;

  // Whoever supervises the room while the teacher is there, the teacher included.
  final List<RoomSupervisor> supervisors;

  const RoomStay({
    required this.room,
    required this.startMinutes,
    required this.endMinutes,
    required this.supervisors,
  });
}

class TeacherBandCall
{
  final List<LessonItem> lessons;
  final List<ScheduledActivity> activities;

  // In clock order; more than one when the teacher changes room in the band.
  final List<RoomStay> rooms;

  const TeacherBandCall({
    required this.lessons,
    required this.activities,
    required this.rooms,
  });

  bool get changesRoom => rooms.length > 1;

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

  RoomOptionItem? get room => rooms.firstOrNull?.room;

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

  // The server gives each lesson the room of its hour; consecutive ones in a room are one stay.
  final stays = <({RoomOptionItem room, int startMinutes, int endMinutes})>[];

  for (final lesson in own)
  {
    final room = lesson.room;

    if (room == null)
    {
      continue;
    }

    final last = stays.lastOrNull;

    if (last != null && last.room.id == room.id)
    {
      stays.last = (room: room, startMinutes: last.startMinutes, endMinutes: math.max(last.endMinutes, lesson.endMinutes));

      continue;
    }

    stays.add((room: room, startMinutes: lesson.startMinutes, endMinutes: lesson.endMinutes));
  }

  return TeacherBandCall(
    lessons: own,
    activities: given,
    rooms: [
      for (final stay in stays)
        RoomStay(
          room: stay.room,
          startMinutes: stay.startMinutes,
          endMinutes: stay.endMinutes,
          supervisors: _supervisorsWhile(
            stay,
            day: day,
            bandStart: bandStart,
            bandEnd: bandEnd,
            supervisions: supervisions,
            teacherTaxCode: teacherTaxCode,
          ),
        ),
    ],
  );
}

// Only who overlaps the stay; their hours in the room are shown whole within the band.
List<RoomSupervisor> _supervisorsWhile(
  ({RoomOptionItem room, int startMinutes, int endMinutes}) stay, {
  required DateTime day,
  required int bandStart,
  required int bandEnd,
  required List<RoomSupervisionItem> supervisions,
  required String? teacherTaxCode,
})
{
  final people = <String, PersonOptionItem>{};
  final shifts = <String, List<(int, int)>>{};
  final present = <String>{};

  for (final shift in supervisions)
  {
    if (shift.room.id != stay.room.id || !isSameDate(shift.date, day))
    {
      continue;
    }

    final clipped = intersectSpan(shift.startMinutes, shift.endMinutes, bandStart, bandEnd);

    if (clipped == null)
    {
      continue;
    }

    people[shift.teacherTaxCode] = shift.teacher;
    (shifts[shift.teacherTaxCode] ??= []).add(clipped);

    if (spansOverlap(shift.startMinutes, shift.endMinutes, stay.startMinutes, stay.endMinutes))
    {
      present.add(shift.teacherTaxCode);
    }
  }

  return [
    for (final MapEntry(key: taxCode, value: spans) in shifts.entries)
      if (present.contains(taxCode))
        RoomSupervisor(
          person: people[taxCode]!,
          spans: mergeSpans(spans),
          isSelf: taxCode == teacherTaxCode,
        ),
  ]..sort((a, b) => a.spans.first.$1.compareTo(b.spans.first.$1));
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
