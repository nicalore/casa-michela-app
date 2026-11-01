import '../../../core/utils/time_bucket.dart';

const String kLessonsRoute = '/lessons';

// The calendar of one band, a screen of its own over Lezioni.
const String kLessonsCalendarSlug = 'calendar';

typedef LessonsCalendarTarget = ({DateTime day, TimeBucket band, bool fresh});

String _two(int value) => value.toString().padLeft(2, '0');

// [fresh] reads the day again even when Lezioni holds it, as a notification asks.
String lessonsCalendarLocation(DateTime day, TimeBucket band, {bool fresh = false})
{
  return Uri(
    path: '$kLessonsRoute/$kLessonsCalendarSlug',
    queryParameters: {
      'day': '${day.year}-${_two(day.month)}-${_two(day.day)}',
      'band': band.name,
      if (fresh) 'fresh': '1',
    },
  ).toString();
}

LessonsCalendarTarget? lessonsCalendarTarget(Map<String, String> query)
{
  final DateTime? day = DateTime.tryParse(query['day'] ?? '');
  final TimeBucket? band = TimeBucket.values.asNameMap()[query['band']];

  if (day == null || band == null)
  {
    return null;
  }

  return (day: DateTime(day.year, day.month, day.day), band: band, fresh: query['fresh'] == '1');
}
