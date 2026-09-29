import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/utils/day_marks.dart';
import '../../association/models/opening_day_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/utils/opening_window.dart';

// A null [teacherTaxCode] marks anyone's lessons; a failed reading leaves the days unmarked.
Future<DayMarks> loadDayMarks(
  DateTime from,
  DateTime to, {
  bool lessons = false,
  String? teacherTaxCode,
}) async
{
  final api = ApiService();

  try
  {
    final results = await Future.wait([
      api.getOpeningDays(dateFrom: from, dateTo: to, mode: kPresenceMode),
      api.getOpeningDays(dateFrom: from, dateTo: to, mode: kOnlineMode),
      if (lessons) api.getLessons(dateFrom: from, dateTo: to),
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
        if (lessons)
          for (final lesson in results[2] as List<LessonItem>)
            if (teacherTaxCode == null || lesson.teacherTaxCode == teacherTaxCode)
              DateTime(lesson.date.year, lesson.date.month, lesson.date.day),
      },
    );
  }
  catch (_)
  {
    return DayMarks.none;
  }
}
