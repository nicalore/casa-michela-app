import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/utils/day_marks.dart';
import '../../association/models/opening_day_item.dart';
import '../../lessons/models/calendar_publication_item.dart';
import '../../lessons/utils/opening_window.dart';

// [published]: days with a calendar out in any band; a failed read leaves the days unmarked.
Future<DayMarks> loadDayMarks(
  DateTime from,
  DateTime to, {
  bool published = false,
}) async
{
  final api = ApiService();

  try
  {
    final results = await Future.wait([
      api.getOpeningDays(dateFrom: from, dateTo: to, mode: kPresenceMode),
      api.getOpeningDays(dateFrom: from, dateTo: to, mode: kOnlineMode),
      if (published) api.getCalendarPublications(dateFrom: from, dateTo: to),
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
      busy: {
        if (published)
          for (final row in results[2] as List<CalendarPublicationItem>)
            DateTime(row.date.year, row.date.month, row.date.day),
      },
    );
  }
  catch (_)
  {
    return DayMarks.none;
  }
}
