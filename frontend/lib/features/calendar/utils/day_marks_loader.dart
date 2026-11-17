import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/utils/day_marks.dart';
import '../../association/models/opening_day_item.dart';
import '../../home/widgets/home_schedule_data.dart';
import '../../lessons/models/activity_item.dart';
import '../../lessons/models/calendar_publication_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/utils/opening_window.dart';

// Whether the reader has something of their own in a band.
typedef OwnBand = bool Function(DateTime day, TimeBucket band);

DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

// A published band is the reader's only where [isOwn] says so.
Set<DateTime> ownPublishedDays(List<CalendarPublicationItem> publications, OwnBand isOwn)
{
  return {
    for (final row in publications)
      if (isOwn(row.date, row.band)) _dayOf(row.date),
  };
}

// [own]: the reader's bands, to dot their published days; a failed read leaves the days unmarked.
Future<DayMarks> loadDayMarks(
  DateTime from,
  DateTime to, {
  Future<OwnBand>? own,
}) async
{
  final api = ApiService();

  try
  {
    final results = await Future.wait([
      api.getOpeningDays(dateFrom: from, dateTo: to, mode: kPresenceMode),
      api.getOpeningDays(dateFrom: from, dateTo: to, mode: kOnlineMode),
      if (own != null) api.getCalendarPublications(dateFrom: from, dateTo: to),
      ?own,
    ]);

    final opening = [
      ...results[0] as List<OpeningDayItem>,
      ...results[1] as List<OpeningDayItem>,
    ];

    return DayMarks(
      closed: {
        for (var day = from; !day.isAfter(to); day = addDays(day, 1))
          if (!isOpenOn(opening, day, kPresenceMode) && !isOpenOn(opening, day, kOnlineMode)) day,
      },
      busy: own == null
          ? const {}
          : ownPublishedDays(results[2] as List<CalendarPublicationItem>, results[3] as OwnBand),
    );
  }
  catch (_)
  {
    return DayMarks.none;
  }
}

// Convened only: availability alone dots nothing. Activities come unfiltered for an administrator.
Future<DayMarks> teacherDayMarks(DateTime from, DateTime to, String? taxCode)
{
  final api = ApiService();

  final Future<OwnBand> own = Future.wait([
    api.getLessons(dateFrom: from, dateTo: to, teacherTaxCode: taxCode),
    api.getCalendarActivities(dateFrom: from, dateTo: to),
  ]).then((results)
  {
    final Set<(DateTime, TimeBucket)> called = {
      for (final lesson in results[0] as List<LessonItem>)
        if (lesson.teacherTaxCode == taxCode) (_dayOf(lesson.date), lesson.band),
      for (final activity in results[1] as List<ActivityItem>)
        if (activity.isAssigned && activity.teacherTaxCode == taxCode) (_dayOf(activity.date), activity.band),
    };

    return (DateTime day, TimeBucket band) => called.contains((_dayOf(day), band));
  });

  return loadDayMarks(from, to, own: own);
}

Future<DayMarks> pupilDayMarks(DateTime from, DateTime to, Set<String> pupils)
{
  final Future<OwnBand> own = ApiService()
      .getPresences(dateFrom: from, dateTo: to)
      .then((rows)
      {
        final List<HomeSlot> slots = presenceSlots(
          rows.where((row) => pupils.contains(row.studentTaxCode)).toList(),
          named: false,
        );

        return (DateTime day, TimeBucket band) => slotsInBand(slots, day, band).isNotEmpty;
      });

  return loadDayMarks(from, to, own: own);
}
