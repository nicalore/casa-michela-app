import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../people/models/person_face.dart';
import '../models/activity_item.dart';
import '../models/availability_item.dart';
import '../models/calendar_day.dart';
import '../models/calendar_publication_item.dart';
import '../models/lesson_item.dart';
import '../models/presence_item.dart';
import '../models/room_day_plan.dart';
import '../utils/opening_window.dart';
import '../widgets/calendar_lesson_block.dart';

class CalendarExportData
{
  final DateTime day;
  final TimeBucket band;

  final CalendarView view;

  final List<CalendarLane> lanes;

  final Map<String, LaneRoomLabel> roomByTeacher;

  final List<MinistrySubjectItem> ministrySubjects;

  final int bandStart;
  final int bandEnd;

  final CalendarPublicationItem? publication;

  const CalendarExportData({
    required this.day,
    required this.band,
    required this.view,
    required this.lanes,
    required this.roomByTeacher,
    required this.ministrySubjects,
    required this.bandStart,
    required this.bandEnd,
    required this.publication,
  });

  bool get isByStudent => view == CalendarView.byStudent;

  List<LessonItem> get lessons
  {
    final byId = <int, LessonItem>{
      for (final lane in lanes)
        for (final lesson in lane.lessons) lesson.id: lesson,
    };

    return byId.values.toList()..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  List<ScheduledActivity> get activities
  {
    final byId = <int, ScheduledActivity>{
      for (final lane in lanes)
        for (final activity in lane.activities) activity.id: activity,
    };

    return byId.values.toList()..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  // Teacher count includes teachers convoked only for activities.
  ({int teachers, int students, int lessons, int activities}) get counts
  {
    final all = lessons;
    final given = activities;

    return (
      teachers: {
        ...all.map((lesson) => lesson.teacherTaxCode),
        ...given.map((activity) => activity.teacherTaxCode),
      }.length,
      students: all.expand((lesson) => lesson.studentTaxCodes).toSet().length,
      lessons: {
        for (final lane in lanes)
          for (final stretch in exportStretches(this, lane)) stretch.first.id,
      }.length,
      activities: given.length,
    );
  }

}

CalendarExportData teachersExport({
  required List<AvailabilityItem> availabilities,
  required List<LessonItem> lessons,
  required List<ActivityItem> activities,
  required List<MinistrySubjectItem> ministrySubjects,
  required RoomDayPlan? roomPlan,
  required CalendarPublicationItem? publication,
  required DateTime day,
  required TimeBucket band,
})
{
  final called = convokedTeachers(buildTeacherLanes(
    availabilities: availabilities,
    lessons: lessons,
    day: day,
    band: band,
    activities: activities,
  ));

  final rooms = laneRoomLabels(lanes: called, plan: roomPlan);

  return _assemble(
    day: day,
    band: band,
    view: CalendarView.byTeacher,
    lanes: orderByRoom(lanes: called, rooms: rooms),
    roomByTeacher: rooms,
    ministrySubjects: ministrySubjects,
    publication: publication,
  );
}

CalendarExportData studentsExport({
  required List<PresenceItem> presences,
  required List<LessonItem> lessons,
  required List<MinistrySubjectItem> ministrySubjects,
  required CalendarPublicationItem? publication,
  required DateTime day,
  required TimeBucket band,
})
{
  final attending = attendingStudents(buildStudentLanes(
    presences: presences,
    lessons: lessons,
    day: day,
    band: band,
  ));

  return _assemble(
    day: day,
    band: band,
    view: CalendarView.byStudent,
    lanes: orderLanes(
      lanes: attending,
      sort: CalendarSort.firstName,
      bandStart: bandStartMinutes(band),
      bandEnd: bandEndMinutes(band),
    ),
    roomByTeacher: const {},
    ministrySubjects: ministrySubjects,
    publication: publication,
  );
}

CalendarExportData _assemble({
  required DateTime day,
  required TimeBucket band,
  required CalendarView view,
  required List<CalendarLane> lanes,
  required Map<String, LaneRoomLabel> roomByTeacher,
  required List<MinistrySubjectItem> ministrySubjects,
  required CalendarPublicationItem? publication,
})
{
  return CalendarExportData(
    day: day,
    band: band,
    view: view,
    lanes: lanes,
    roomByTeacher: roomByTeacher,
    ministrySubjects: ministrySubjects,
    bandStart: bandStartMinutes(band),
    bandEnd: bandEndMinutes(band),
    publication: publication,
  );
}

String exportLessonWho(LessonItem lesson, CalendarView view)
{
  if (view == CalendarView.byStudent)
  {
    return lesson.teacher.fullName;
  }

  final students = [for (final entry in lesson.bookings) entry.presence.student]..sort(compareByName);

  return students.isEmpty ? 'Lezione' : students.map((student) => student.fullName).join(', ');
}

// One strip of the list. The discipline leads and the subject follows, as on its block.
typedef ExportLessonFields = ({
  String hours,
  String who,
  String discipline,
  String? subject,
  String place,
});

ExportLessonFields exportStretchFields(CalendarExportData data, List<LessonItem> stretch)
{
  final lesson = stretch.first;
  final topic = lessonTopic(lesson, data.ministrySubjects);

  // By teacher, the room they hold the hour in; an online hour names none, even from the association.
  final seat = data.view == CalendarView.byTeacher && lesson.mode == kPresenceMode
      ? data.roomByTeacher[lesson.teacherTaxCode]?.roomAt(lesson.startMinutes, lesson.endMinutes)?.name
      : null;

  return (
    hours: formatTimeRange(lesson.startTime, stretch.last.endTime),
    who: exportLessonWho(lesson, data.view),
    discipline: topic.discipline,
    subject: topic.subject,
    place: seat ?? lessonWhere(lesson).label,
  );
}

bool _continues(CalendarExportData data, LessonItem before, LessonItem after)
{
  final first = exportStretchFields(data, [before]);
  final second = exportStretchFields(data, [after]);

  return before.endMinutes == after.startMinutes &&
      before.teacherTaxCode == after.teacherTaxCode &&
      setEquals(before.studentTaxCodes, after.studentTaxCodes) &&
      (first.discipline, first.subject, first.place) == (second.discipline, second.subject, second.place);
}

// A row's lessons as printed, in clock order: those reading the same, each starting as the one
// before ends, are one stretch, even with another lesson held alongside them.
List<List<LessonItem>> exportStretches(CalendarExportData data, CalendarLane lane)
{
  final lessons = [...lane.lessons]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  final stretches = <List<LessonItem>>[];

  for (final lesson in lessons)
  {
    final open = stretches.where((stretch) => _continues(data, stretch.last, lesson)).firstOrNull;

    if (open == null)
    {
      stretches.add([lesson]);
    }
    else
    {
      open.add(lesson);
    }
  }

  return stretches;
}

List<ExportLessonFields> exportLessonRows(CalendarExportData data)
{
  return [
    for (final lane in data.lanes)
      for (final stretch in exportStretches(data, lane)) exportStretchFields(data, stretch),
  ];
}

typedef ExportActivityFields = ({String hours, String name, String? description});

ExportActivityFields exportActivityFields(ScheduledActivity scheduled)
{
  return (
    hours: formatMinutesRange(scheduled.startMinutes, scheduled.endMinutes),
    name: scheduled.name,
    description: scheduled.description,
  );
}

// Hours of a row all running at one moment, by their places in the row, each group as large as it
// gets: a chain (the first ends before the third begins) is two groups, never one. A null span (an
// activity) is in none.
List<List<int>> togetherGroups(List<(int, int)?> spans)
{
  // Every group is all running at the latest of its starts.
  final running = [
    for (final moment in {for (final span in spans) if (span != null) span.$1})
      [
        for (final (index, span) in spans.indexed)
          if (span != null && span.$1 <= moment && moment < span.$2) index,
      ],
  ]..sort((a, b) => b.length.compareTo(a.length));

  final groups = <List<int>>[];

  for (final candidate in running)
  {
    if (candidate.length > 1 && !groups.any((group) => candidate.every(group.contains)))
    {
      groups.add(candidate);
    }
  }

  return groups..sort((a, b) => a.first != b.first ? a.first.compareTo(b.first) : a.last.compareTo(b.last));
}

// Where [own] runs alongside any of [others], merged, in clock order.
List<(int, int)> sharedStretches((int, int) own, List<(int, int)> others)
{
  final shared = <(int, int)>[
    for (final other in others) (math.max(own.$1, other.$1), math.min(own.$2, other.$2)),
  ].where((stretch) => stretch.$1 < stretch.$2).toList()..sort((a, b) => a.$1.compareTo(b.$1));

  final merged = <(int, int)>[];

  for (final stretch in shared)
  {
    if (merged.isNotEmpty && stretch.$1 <= merged.last.$2)
    {
      merged.last = (merged.last.$1, math.max(merged.last.$2, stretch.$2));
    }
    else
    {
      merged.add(stretch);
    }
  }

  return merged;
}

// E.g. "Compresenza 14:30–15:00 e 15:15–15:30".
String togetherLabel((int, int) own, List<(int, int)> others)
{
  final stretches = sharedStretches(own, others).map((stretch) => formatMinutesRange(stretch.$1, stretch.$2));

  return 'Compresenza ${stretches.join(' e ')}';
}
