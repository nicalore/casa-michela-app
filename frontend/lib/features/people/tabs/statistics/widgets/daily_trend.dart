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
// No [days] means a stretch of the period before the first open day ever, which reads zero.
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

  DateTime get axisDay => _bucketKey(first, resolution);

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
    if (days.isEmpty)
    {
      return 0;
    }

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

DateTime _nextKey(DateTime key, String resolution)
{
  return switch (resolution)
  {
    kTrendByWeek => addDays(key, 7),
    kTrendByMonth => DateTime(key.year, key.month + 1),
    _ => addDays(key, 1),
  };
}

// Whole buckets only: a zero day sharing a bucket with open days would dilute their average.
List<TrendBucket> _bucketsBefore(DateTime firstDay, DateTime from, String resolution)
{
  final end = _bucketKey(firstDay, resolution);
  final buckets = <TrendBucket>[];

  for (var key = _bucketKey(from, resolution); key.isBefore(end); key = _nextKey(key, resolution))
  {
    buckets.add(
      TrendBucket(
        resolution: resolution,
        days: const [],
        first: key.isBefore(from) ? from : key,
        last: addDays(_nextKey(key, resolution), -1),
      ),
    );
  }

  return buckets;
}

// [dates] must be in order, as the backend sends them.
// A period starting at [from] before [firstOpenDay] reads zero up to it; a closure stays a gap.
List<TrendBucket> trendBuckets(
  List<DateTime> dates,
  String resolution, {
  DateTime? from,
  DateTime? firstOpenDay,
})
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

  if (from == null || firstOpenDay == null || dates.isEmpty || !firstOpenDay.isAfter(from))
  {
    return buckets;
  }

  return [..._bucketsBefore(dates.first, from, resolution), ...buckets];
}

int _daysApart(DateTime from, DateTime to)
{
  return DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

// Each bucket's place from 0 to 1 by calendar days, so closures keep their real length.
// The axis starts at [from], also when the period opens with a closure.
List<double> trendPositions(List<TrendBucket> buckets, {DateTime? from})
{
  if (buckets.length < 2)
  {
    return [for (final _ in buckets) 0.5];
  }

  final start = from == null ? buckets.first.axisDay : _bucketKey(from, buckets.first.resolution);
  final span = _daysApart(start, buckets.last.axisDay);

  return [for (final bucket in buckets) _daysApart(start, bucket.axisDay) / span];
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
