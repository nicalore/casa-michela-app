import 'dart:math' as math;

import '../../../core/utils/time_bucket.dart';
import '../models/activity_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../models/person_option_item.dart';
import 'opening_window.dart';

// Approved wording: the calendar row's badge and the warning when it happens.
const String kOnlineOnlyBadge = 'In sede - Solo lezioni online';

String onlineOnlyWarning(String teacher) =>
    '$teacher verrà in sede solo per lezioni online: ha dato disponibilità solo in presenza.';

// A teacher's band: they come in, yet every lesson is with a pupil at a screen and no
// activity brings them, so they come only to connect from the association's computers.
bool comesInForOnlineOnly(Iterable<LessonItem> lessons, Iterable<ScheduledActivity> activities)
{
  return lessons.isNotEmpty &&
      lessons.every((lesson) => lesson.mode == kOnlineMode) &&
      lessons.any((lesson) => lesson.teacherMode == kPresenceMode) &&
      !activities.any((activity) => activity.placement.teacherMode == kPresenceMode);
}

// One teacher of the publish confirmation's list: in the building for these hours.
typedef OnlineOnlyTeacher = ({PersonOptionItem teacher, int startMinutes, int endMinutes, int lessons});

List<OnlineOnlyTeacher> onlineOnlyTeachers(Iterable<TeacherLane> lanes)
{
  return [
    for (final lane in lanes)
      if (comesInForOnlineOnly(lane.lessons, lane.activities))
        (
          teacher: lane.teacher,
          startMinutes: lane.lessons.map((lesson) => lesson.startMinutes).reduce(math.min),
          endMinutes: lane.lessons.map((lesson) => lesson.endMinutes).reduce(math.max),
          lessons: lane.lessons.length,
        ),
  ];
}

// Every band and teacher among [lessons] that comes in for online lessons only.
Set<(TimeBucket, String)> onlineOnlyBands(Iterable<LessonItem> lessons, Iterable<ActivityItem> activities)
{
  final given = [for (final activity in activities) ?ScheduledActivity.of(activity)];

  return {
    for (final (band, teacher) in {for (final lesson in lessons) (lesson.band, lesson.teacherTaxCode)})
      if (comesInForOnlineOnly(
        lessons.where((lesson) => lesson.band == band && lesson.teacherTaxCode == teacher),
        given.where((activity) => activity.activity.band == band && activity.placement.teacherTaxCode == teacher),
      ))
        (band, teacher),
  };
}
