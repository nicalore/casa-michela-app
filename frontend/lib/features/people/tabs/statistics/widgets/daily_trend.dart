import '../../../../../core/utils/week_range.dart';
import '../../../../../shared/widgets/filter_menu.dart';
import 'stats_constants.dart';

const String kTrendByDay = 'day';
const String kTrendByWeek = 'week';
const String kTrendByMonth = 'month';

List<FilterOption<String>> trendResolutionOptions()
{
  return const [
    FilterOption(value: kTrendByDay, label: 'Giornaliera'),
    FilterOption(value: kTrendByWeek, label: 'Settimanale'),
    FilterOption(value: kTrendByMonth, label: 'Mensile'),
  ];
}

// Consecutive open days of one day, week (from Monday) or month; [days] index the daily series.
class TrendBucket
{
  final String resolution;
  final List<int> days;
  final DateTime first;
  final DateTime last;

  const TrendBucket({
    required this.resolution,
    required this.days,
    required this.first,
    required this.last,
  });

  bool get isAverage => resolution != kTrendByDay;

  String get axisLabel
  {
    if (resolution == kTrendByMonth)
    {
      return '${monthAbbreviations[first.month - 1]}\n${first.year}';
    }

    return formatDayMonthShort(first);
  }

  String get title
  {
    if (resolution == kTrendByMonth)
    {
      return formatMonthYear(first);
    }

    return isSameDate(first, last) ? formatWeekdayColumnLabel(first) : formatDateSpan(first, last);
  }

  // Averaged over the open days in the bucket, not over calendar days.
  double valueOf(List<int> daily)
  {
    var total = 0;

    for (final index in days)
    {
      total += daily[index];
    }

    return total / days.length;
  }
}

DateTime _bucketKey(DateTime day, String resolution)
{
  return switch (resolution)
  {
    kTrendByWeek => startOfWeek(day),
    kTrendByMonth => DateTime(day.year, day.month),
    _ => DateTime(day.year, day.month, day.day),
  };
}

// [dates] must be in order, as the backend sends them.
List<TrendBucket> trendBuckets(List<DateTime> dates, String resolution)
{
  final buckets = <TrendBucket>[];
  DateTime? key;
  var days = <int>[];

  void close()
  {
    if (days.isNotEmpty)
    {
      buckets.add(TrendBucket(resolution: resolution, days: days, first: dates[days.first], last: dates[days.last]));
    }
  }

  for (var index = 0; index < dates.length; index++)
  {
    final current = _bucketKey(dates[index], resolution);

    if (current != key)
    {
      close();
      key = current;
      days = <int>[];
    }

    days.add(index);
  }

  close();

  return buckets;
}

// Nothing reads "0", never "0.0".
String formatTrendCount(double value, {required bool average})
{
  final shown = average ? value.toStringAsFixed(1) : '${value.round()}';

  return shown == '0.0' ? '0' : shown;
}

// Singular only for a plain 1: a decimal such as 1.0 reads in the plural.
String trendCountLabel(String shown, {required String one, required String many})
{
  return shown == '1' ? one : many;
}
