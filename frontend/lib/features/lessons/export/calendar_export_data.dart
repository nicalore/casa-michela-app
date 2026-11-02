import 'dart:math' as math;

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
      lessons: all.length,
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

// One lesson of the list. The discipline leads and the subject follows, as on its block.
typedef ExportLessonFields = ({
  String hours,
  String who,
  String discipline,
  String? subject,
  String place,
});

ExportLessonFields exportLessonFields(
  LessonItem lesson, {
  required CalendarView view,
  required List<MinistrySubjectItem> ministrySubjects,
  LaneRoomLabel? room,
})
{
  final topic = lessonTopic(lesson, ministrySubjects);

  // By teacher, the room they hold the hour in; an online hour names none, even from the association.
  final seat = view == CalendarView.byTeacher && lesson.mode == kPresenceMode
      ? room?.roomAt(lesson.startMinutes, lesson.endMinutes)?.name
      : null;

  return (
    hours: formatTimeRange(lesson.startTime, lesson.endTime),
    who: exportLessonWho(lesson, view),
    discipline: topic.discipline,
    subject: topic.subject,
    place: seat ?? lessonWhere(lesson).label,
  );
}

List<ExportLessonFields> exportLessonRows(CalendarExportData data)
{
  return [
    for (final lane in data.lanes)
      for (final lesson in lane.lessons)
        exportLessonFields(
          lesson,
          view: data.view,
          ministrySubjects: data.ministrySubjects,
          room: data.roomByTeacher[lesson.teacherTaxCode],
        ),
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

// Two hours of a row running at the same time, by their places in the row.
typedef TogetherPair = ({int first, int second});

// Every two hours that overlap, pair by pair: no more than two lessons run at once. A null span
// (an activity) is nobody's pair.
List<TogetherPair> togetherPairs(List<(int, int)?> spans)
{
  return [
    for (var i = 0; i < spans.length; i++)
      for (var j = i + 1; j < spans.length; j++)
        if (_overlap(spans[i], spans[j])) (first: i, second: j),
  ];
}

bool _overlap((int, int)? a, (int, int)? b)
{
  return a != null && b != null && math.max(a.$1, b.$1) < math.min(a.$2, b.$2);
}

// Where the hours of a group run together, merged, in clock order.
List<(int, int)> sharedStretches(List<(int, int)> spans)
{
  final shared = <(int, int)>[
    for (var i = 0; i < spans.length; i++)
      for (var j = i + 1; j < spans.length; j++)
        (math.max(spans[i].$1, spans[j].$1), math.min(spans[i].$2, spans[j].$2)),
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
String togetherLabel(List<(int, int)> spans)
{
  final stretches = sharedStretches(spans).map((stretch) => formatMinutesRange(stretch.$1, stretch.$2));

  return 'Compresenza ${stretches.join(' e ')}';
}
