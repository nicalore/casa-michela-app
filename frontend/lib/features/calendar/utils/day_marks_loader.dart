import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/utils/day_marks.dart';
import '../../association/models/opening_day_item.dart';
import '../../home/widgets/home_schedule_data.dart';
import '../../lessons/models/calendar_publication_item.dart';
import '../../lessons/utils/opening_window.dart';

// A published band is the reader's only where their own hours touch it.
Set<DateTime> ownPublishedDays(List<CalendarPublicationItem> publications, List<HomeSlot> own)
{
  return {
    for (final row in publications)
      if (slotsInBand(own, row.date, row.band).isNotEmpty) DateTime(row.date.year, row.date.month, row.date.day),
  };
}

// [own]: the reader's hours, to dot their published days; a failed read leaves the days unmarked.
Future<DayMarks> loadDayMarks(
  DateTime from,
  DateTime to, {
  Future<List<HomeSlot>>? own,
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
          : ownPublishedDays(results[2] as List<CalendarPublicationItem>, results[3] as List<HomeSlot>),
    );
  }
  catch (_)
  {
    return DayMarks.none;
  }
}

// Both lists hold everybody's rows for an administrator, hence the filter.
Future<DayMarks> teacherDayMarks(DateTime from, DateTime to, String? taxCode)
{
  final Future<List<HomeSlot>> own = ApiService()
      .getAvailabilities(dateFrom: from, dateTo: to)
      .then((rows) => availabilitySlots(rows.where((row) => row.teacherTaxCode == taxCode).toList()));

  return loadDayMarks(from, to, own: own);
}

Future<DayMarks> pupilDayMarks(DateTime from, DateTime to, Set<String> pupils)
{
  final Future<List<HomeSlot>> own = ApiService()
      .getPresences(dateFrom: from, dateTo: to)
      .then((rows) => presenceSlots(rows.where((row) => pupils.contains(row.studentTaxCode)).toList(), named: false));

  return loadDayMarks(from, to, own: own);
}
