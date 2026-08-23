import 'package:flutter/material.dart' show TimeOfDay;

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'availability_item.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';
import 'presence_item.dart';

enum CalendarView
{
  byTeacher('Per docente'),
  byStudent('Per studente');

  final String label;

  const CalendarView(this.label);
}

enum CalendarSort
{
  room('Stanza'),

  firstName('Nome (A-Z)'),
  firstNameDesc('Nome (Z-A)'),
  lastName('Cognome (A-Z)'),
  lastNameDesc('Cognome (Z-A)'),

  arrival('Orario di arrivo');

  final String label;

  const CalendarSort(this.label);
}

enum CalendarLayout
{
  byHour('Per orario'),
  byLesson('Per lezioni');

  final String label;

  const CalendarLayout(this.label);
}

abstract class CalendarLane
{
  const CalendarLane();

  String get personTaxCode;

  PersonOptionItem get person;

  List<LessonItem> get lessons;

  List<(TimeOfDay, TimeOfDay)> rowsIn(String mode);

  List<(int, int)> spansIn(String mode, int bandStart, int bandEnd)
  {
    final spans = <(int, int)>[];

    for (final row in rowsIn(mode))
    {
      final clipped = intersectSpan(
        minutesOfTimeOfDay(row.$1),
        minutesOfTimeOfDay(row.$2),
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

  List<(int, int)> contentSpans(int bandStart, int bandEnd)
  {
    return [
      ...spansIn(kPresenceMode, bandStart, bandEnd),
      ...spansIn(kOnlineMode, bandStart, bandEnd),
      for (final lesson in lessons) (lesson.startMinutes, lesson.endMinutes),
    ];
  }

  ({List<int> laneOf, int laneCount}) subLanesWith([Map<int, int> memory = const {}])
  {
    return assignSubLanes(
      [for (final lesson in lessons) (lesson.startMinutes, lesson.endMinutes)],
      preferred: [for (final lesson in lessons) memory[lesson.id]],
    );
  }
}

class TeacherLane extends CalendarLane
{
  final String teacherTaxCode;
  final PersonOptionItem teacher;

  final List<AvailabilityItem> availabilities;

  @override
  final List<LessonItem> lessons;

  const TeacherLane({
    required this.teacherTaxCode,
    required this.teacher,
    required this.availabilities,
    required this.lessons,
  });

  @override
  String get personTaxCode => teacherTaxCode;

  @override
  PersonOptionItem get person => teacher;

  @override
  List<(TimeOfDay, TimeOfDay)> rowsIn(String mode)
  {
    return [for (final slot in availabilitiesIn(mode)) (slot.startTime, slot.endTime)];
  }

  List<AvailabilityItem> availabilitiesIn(String mode)
  {
    return availabilities.where((slot) => slot.mode == mode).toList();
  }

  List<AvailabilityItem> availabilitiesTaking(String lessonMode)
  {
    return availabilities
        .where((slot) => slot.mode == kPresenceMode || lessonMode == kOnlineMode)
        .toList();
  }

  bool splitsModes(int bandStart, int bandEnd)
  {
    final presence = spansIn(kPresenceMode, bandStart, bandEnd);
    final online = spansIn(kOnlineMode, bandStart, bandEnd);

    return presence.any((a) => online.any((b) => spansOverlap(a.$1, a.$2, b.$1, b.$2)));
  }

  int get peakStudents
  {
    return peakConcurrentStudents([
      for (final lesson in lessons)
        (lesson.startMinutes, lesson.endMinutes, lesson.studentTaxCodes.length),
    ]);
  }
}

List<({String mode, String said})> laneWhenLines(
  CalendarLane lane, {
  required int bandStart,
  required int bandEnd,
})
{
  return [
    for (final mode in const [kPresenceMode, kOnlineMode])
      for (final span in lane.spansIn(mode, bandStart, bandEnd))
        (mode: mode, said: '${modeLabel(mode)} ${formatMinutesRange(span.$1, span.$2)}'),
  ];
}

String laneWhenLabel(
  CalendarLane lane, {
  required int bandStart,
  required int bandEnd,
  required CalendarView view,
})
{
  final windows = laneWhenLines(lane, bandStart: bandStart, bandEnd: bandEnd);

  if (windows.isEmpty)
  {
    return whenNothingLabel(view);
  }

  return windows.map((window) => window.said).join(' · ');
}

String whenNothingLabel(CalendarView view) =>
    view == CalendarView.byStudent ? 'Nessuna presenza' : 'Nessuna disponibilità';

List<TeacherLane> convokedTeachers(List<TeacherLane> lanes)
{
  return lanes.where((lane) => lane.lessons.isNotEmpty).toList();
}

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

class StudentLane extends CalendarLane
{
  final String studentTaxCode;
  final PersonOptionItem student;

  final List<PresenceItem> presences;

  @override
  final List<LessonItem> lessons;

  const StudentLane({
    required this.studentTaxCode,
    required this.student,
    required this.presences,
    required this.lessons,
  });

  @override
  String get personTaxCode => studentTaxCode;

  @override
  PersonOptionItem get person => student;

  List<PresenceItem> presencesIn(String mode)
  {
    return presences.where((row) => row.mode == mode).toList();
  }

  @override
  List<(TimeOfDay, TimeOfDay)> rowsIn(String mode)
  {
    return [for (final row in presencesIn(mode)) (row.startTime, row.endTime)];
  }
}

List<StudentLane> attendingStudents(List<StudentLane> lanes)
{
  return lanes.where((lane) => lane.lessons.isNotEmpty).toList();
}

int _byBeingHereThenName(StudentLane a, StudentLane b)
{
  final aInBuilding = a.presencesIn(kPresenceMode).isNotEmpty;
  final bInBuilding = b.presencesIn(kPresenceMode).isNotEmpty;

  if (aInBuilding != bInBuilding)
  {
    return aInBuilding ? -1 : 1;
  }

  return a.student.fullName.toLowerCase().compareTo(b.student.fullName.toLowerCase());
}

List<StudentLane> buildStudentLanes({
  required List<PresenceItem> presences,
  required List<LessonItem> lessons,
  required DateTime day,
  required TimeBucket band,
})
{
  final bandStart = bandStartMinutes(band);
  final bandEnd = bandEndMinutes(band);

  final rowsByStudent = <String, List<PresenceItem>>{};
  final lessonsByStudent = <String, List<LessonItem>>{};
  final faces = <String, PersonOptionItem>{};

  for (final presence in presences)
  {
    if (!isSameDate(presence.date, day))
    {
      continue;
    }

    final start = minutesOfTimeOfDay(presence.startTime);
    final end = minutesOfTimeOfDay(presence.endTime);

    if (!spansOverlap(start, end, bandStart, bandEnd))
    {
      continue;
    }

    rowsByStudent.putIfAbsent(presence.studentTaxCode, () => []).add(presence);
    faces[presence.studentTaxCode] = presence.student;
  }

  for (final lesson in lessons)
  {
    if (!isSameDate(lesson.date, day) || lesson.band != band)
    {
      continue;
    }

    for (final entry in lesson.bookings)
    {
      final student = entry.presence.student;
      final written = lessonsByStudent.putIfAbsent(student.taxCode, () => []);

      if (written.any((other) => other.id == lesson.id))
      {
        continue;
      }

      written.add(lesson);
      faces.putIfAbsent(student.taxCode, () => student);
    }
  }

  final lanes = [
    for (final entry in faces.entries)
      StudentLane(
        studentTaxCode: entry.key,
        student: entry.value,
        presences: rowsByStudent[entry.key] ?? <PresenceItem>[],
        lessons: (lessonsByStudent[entry.key] ?? <LessonItem>[])
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)),
      ),
  ];

  return lanes..sort(_byBeingHereThenName);
}

int? laneArrival(CalendarLane lane, int bandStart, int bandEnd)
{
  final spans = lane.spansIn(kPresenceMode, bandStart, bandEnd);

  return spans.isEmpty ? null : spans.first.$1;
}

int _byFirstName(CalendarLane a, CalendarLane b)
{
  final name = a.person.firstName.toLowerCase().compareTo(b.person.firstName.toLowerCase());

  return name != 0 ? name : a.person.lastName.toLowerCase().compareTo(b.person.lastName.toLowerCase());
}

int _byLastName(CalendarLane a, CalendarLane b)
{
  final surname = a.person.lastName.toLowerCase().compareTo(b.person.lastName.toLowerCase());

  return surname != 0 ? surname : _byFirstName(a, b);
}

// The same order read backwards, tie-break and all: two people both called Anna
// come out by surname the other way round too. It is what "the same list upside
// down" means, and the only rule that can be said in one line.
Comparator<CalendarLane> _reversed(Comparator<CalendarLane> by)
{
  return (a, b) => by(b, a);
}

int _byArrival(CalendarLane a, CalendarLane b, int bandStart, int bandEnd)
{
  final first = laneArrival(a, bandStart, bandEnd);
  final second = laneArrival(b, bandStart, bandEnd);

  if (first == null || second == null)
  {
    if (first == second)
    {
      return _byFirstName(a, b);
    }

    return first == null ? 1 : -1;
  }

  return first == second ? _byFirstName(a, b) : first.compareTo(second);
}

List<T> orderLanes<T extends CalendarLane>({
  required List<T> lanes,
  required CalendarSort sort,
  required int bandStart,
  required int bandEnd,
})
{
  final Comparator<CalendarLane> by = switch (sort)
  {
    CalendarSort.room || CalendarSort.firstName => _byFirstName,
    CalendarSort.firstNameDesc => _reversed(_byFirstName),
    CalendarSort.lastName => _byLastName,
    CalendarSort.lastNameDesc => _reversed(_byLastName),
    CalendarSort.arrival => (a, b) => _byArrival(a, b, bandStart, bandEnd),
  };

  return [...lanes]..sort(by);
}
