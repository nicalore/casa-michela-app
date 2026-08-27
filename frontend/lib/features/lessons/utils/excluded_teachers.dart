import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../models/activity_item.dart';
import '../models/lesson_item.dart';

// What an excluded teacher's row was holding; both go back to the panel.
typedef HandedBack = ({int lessons, int activities});

String handedBackSentence(HandedBack back)
{
  final parts = [
    if (back.lessons > 0) back.lessons == 1 ? '1 lezione' : '${back.lessons} lezioni',
    // "attività" is invariable in the plural.
    if (back.activities > 0) '${back.activities} attività',
  ];

  final verb = back.lessons + back.activities == 1 ? 'è tornata' : 'sono tornate';

  return '${parts.join(' e ')} $verb da pianificare.';
}

// Local mirror of the server's exclusion: lessons are removed, activities
// stay but become unassigned. Computed here so the UI does not wait on a
// read-back; the counts are compared against the server's answer.
typedef RowTakenOff = ({
  List<LessonItem> lessons,
  List<ActivityItem> activities,
  HandedBack back,
});

RowTakenOff takeTheRowOff({
  required List<LessonItem> lessons,
  required List<ActivityItem> activities,
  required DateTime day,
  required TimeBucket band,
  required String teacherTaxCode,
})
{
  bool theirs(DateTime other, TimeBucket otherBand, String? otherTaxCode)
  {
    return isSameDate(other, day) && otherBand == band && otherTaxCode == teacherTaxCode;
  }

  final kept = <LessonItem>[];
  var taken = 0;

  for (final lesson in lessons)
  {
    if (theirs(lesson.date, lesson.band, lesson.teacherTaxCode))
    {
      taken++;

      continue;
    }

    kept.add(lesson);
  }

  final panel = <ActivityItem>[];
  var handed = 0;

  for (final activity in activities)
  {
    if (!theirs(activity.date, activity.band, activity.teacherTaxCode))
    {
      panel.add(activity);

      continue;
    }

    handed++;

    panel.add(
      activity.asWritten(
        name: activity.name,
        description: activity.description,
        placement: null,
      ),
    );
  }

  return (
    lessons: kept,
    activities: panel,
    back: (lessons: taken, activities: handed),
  );
}
