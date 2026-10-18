import '../../../core/utils/week_range.dart';
import '../../lessons/models/calendar_publication_item.dart';

// Tomorrow opens once one of its bands is published: the morning's goes out the evening before.
DateTime lastViewableDay(DateTime today, List<CalendarPublicationItem> tomorrows)
{
  final DateTime tomorrow = addDays(today, 1);

  return tomorrows.any((row) => row.date.year == tomorrow.year && row.date.month == tomorrow.month && row.date.day == tomorrow.day)
      ? tomorrow
      : today;
}
