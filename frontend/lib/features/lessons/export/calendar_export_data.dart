import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/opening_day_item.dart';
import '../models/availability_item.dart';
import '../models/calendar_day.dart';
import '../models/calendar_publication_item.dart';
import '../models/lesson_item.dart';
import '../models/presence_item.dart';
import '../models/room_day_plan.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
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

  final (int, int)? window;

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
    required this.window,
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

  ({int teachers, int students, int lessons}) get counts
  {
    final all = lessons;

    return (
      teachers: all.map((lesson) => lesson.teacherTaxCode).toSet().length,
      students: all.expand((lesson) => lesson.studentTaxCodes).toSet().length,
      lessons: all.length,
    );
  }

}

CalendarExportData teachersExport({
  required List<AvailabilityItem> availabilities,
  required List<LessonItem> lessons,
  required List<OpeningDayItem> openingDays,
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
  ));

  final rooms = laneRoomLabels(lanes: called, plan: roomPlan);

  return _assemble(
    day: day,
    band: band,
    view: CalendarView.byTeacher,
    lanes: orderByRoom(lanes: called, rooms: rooms),
    roomByTeacher: rooms,
    ministrySubjects: ministrySubjects,
    openingDays: openingDays,
    publication: publication,
  );
}

CalendarExportData studentsExport({
  required List<PresenceItem> presences,
  required List<LessonItem> lessons,
  required List<OpeningDayItem> openingDays,
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
    openingDays: openingDays,
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
  required List<OpeningDayItem> openingDays,
  required CalendarPublicationItem? publication,
})
{
  final bandStart = bandStartMinutes(band);
  final bandEnd = bandEndMinutes(band);
  final opening = unionOpeningWindow(openingDays, day, band);

  return CalendarExportData(
    day: day,
    band: band,
    view: view,
    lanes: lanes,
    roomByTeacher: roomByTeacher,
    ministrySubjects: ministrySubjects,
    bandStart: bandStart,
    bandEnd: bandEnd,
    window: timelineWindow(
      bandStartMinutes: bandStart,
      bandEndMinutes: bandEnd,
      opening: opening == null ? null : (opening.startMinutes, opening.endMinutes),
      content: [
        for (final lane in lanes) ...lane.contentSpans(bandStart, bandEnd),
      ],
    ),
    publication: publication,
  );
}

String exportLessonWho(LessonItem lesson, CalendarView view)
{
  if (view == CalendarView.byStudent)
  {
    return lesson.teacher.fullName;
  }

  final students = [for (final entry in lesson.bookings) entry.presence.student.fullName]..sort();

  return students.isEmpty ? 'Lezione' : students.join(', ');
}

typedef ExportLessonFields = ({String hours, String who, String subject, String? place});

ExportLessonFields exportLessonFields(
  LessonItem lesson, {
  required CalendarView view,
  required List<MinistrySubjectItem> ministrySubjects,
})
{
  final about = lessonAbout(lesson, ministrySubjects);
  final byStudent = view == CalendarView.byStudent;
  final range = formatTimeRange(lesson.startTime, lesson.endTime);

  return (
    hours: !byStudent && lesson.mode == kOnlineMode ? '$range · ${modeLabel(kOnlineMode)}' : range,
    who: exportLessonWho(lesson, view),
    subject: about.disciplines == null ? about.subject : '${about.subject} (${about.disciplines})',
    place: byStudent ? lessonWhere(lesson).label : null,
  );
}

List<ExportLessonFields> exportLessonRows(CalendarExportData data)
{
  return [
    for (final lane in data.lanes)
      for (final lesson in lane.lessons)
        exportLessonFields(lesson, view: data.view, ministrySubjects: data.ministrySubjects),
  ];
}
