import '../../../../core/utils/week_range.dart';
import '../../models/opening_day_item.dart';

// Hours in force per weekday (1-7): latest non-override occurrence of each
// weekday within the next week, so a future change is not shown as today's
// schedule. Read from the generated calendar rather than weekly_templates:
// templates can hold future or superseded rows.
Map<int, List<OpeningDayItem>> currentScheduleByWeekday(List<OpeningDayItem> days, DateTime today)
{
  final horizon = addDays(today, 6);
  final chosenDate = <int, DateTime>{};
  final schedule = <int, List<OpeningDayItem>>{};

  final inWindow = days.where((d) => !d.isOverride && !d.date.isAfter(horizon)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  for (final day in inWindow)
  {
    final weekday = day.date.weekday;
    final chosen = chosenDate[weekday];

    if (chosen == null || day.date.isAfter(chosen))
    {
      chosenDate[weekday] = day.date;
      schedule[weekday] = [day];
    }
    else if (isSameDate(chosen, day.date))
    {
      schedule[weekday]!.add(day);
    }
  }

  return schedule;
}
