import '../../../../../shared/widgets/filter_menu.dart';
import '../../../models/member_trend_item.dart';
import 'stats_constants.dart';

// Data preparation and filter options shared by every statistics tab. They are
// top level functions rather than methods, because none of them needs the state
// of the tab that calls them.

MemberTrendItem? _findPoint(List<MemberTrendItem> data, int year, {int? month})
{
  for (final item in data)
  {
    if (item.year != year)
    {
      continue;
    }

    if (month != null && item.month != month)
    {
      continue;
    }

    return item;
  }

  return null;
}

// Fills the gaps of a trend series with explicit zeros. The backend omits
// periods with no members, but a chart needs a continuous sequence.
List<MemberTrendItem> padTrendData(
  List<MemberTrendItem> rawData,
  String resolution,
  int startYear,
  int endYear,
)
{
  final padded = <MemberTrendItem>[];

  if (resolution == 'year')
  {
    for (var year = startYear; year <= endYear; year++)
    {
      padded.add(_findPoint(rawData, year) ?? MemberTrendItem(year: year, totalMembers: 0));
    }

    return padded;
  }

  final now = DateTime.now();

  for (var year = startYear; year <= endYear; year++)
  {
    final firstMonth = year == dataStartYear ? dataStartMonth : 1;
    final lastMonth = year == now.year ? now.month : 12;

    for (var month = firstMonth; month <= lastMonth; month++)
    {
      padded.add(_findPoint(rawData, year, month: month) ??
          MemberTrendItem(year: year, month: month, totalMembers: 0));
    }
  }

  return padded;
}

List<FilterOption<String>> resolutionOptions()
{
  return const [
    FilterOption(value: 'year', label: 'Annuale'),
    FilterOption(value: 'month', label: 'Mensile'),
  ];
}

// Every year with data, most recent first.
List<FilterOption<int>> yearOptions()
{
  final currentYear = DateTime.now().year;

  return List.generate(currentYear - dataStartYear + 1, (index) => currentYear - index)
      .map((year) => FilterOption(value: year, label: year.toString()))
      .toList();
}

// Months selectable for [selectedYear]. The first year only has data from
// [dataStartMonth] on, so offering earlier months would point at nothing.
List<FilterOption<int>> monthOptions(int selectedYear)
{
  final firstMonth = selectedYear == dataStartYear ? dataStartMonth : 1;

  return [
    for (var month = firstMonth; month <= 12; month++)
      FilterOption(value: month, label: monthAbbreviations[month - 1]),
  ];
}

// The whole window, as against one month inside it.
const String wholeWindowPeriod = 'all';

// How far back a ranking of appreciation reaches. The calendars older than a
// year are deleted, so a thirteenth month back would point at nothing.
const int appreciationMonthsWindow = 12;

String _periodValue(int year, int month)
{
  return '$year-${month.toString().padLeft(2, '0')}';
}

// The periods a ranking may be asked about: the whole window, then the current
// month and the eleven before it, most recent first.
//
// One pill and not a year beside a month: what is being chosen is a single
// period out of thirteen, and two pills would let a pair be picked that has
// nothing behind it.
List<FilterOption<String>> appreciationPeriodOptions()
{
  final now = DateTime.now();
  final options = <FilterOption<String>>[
    const FilterOption(value: wholeWindowPeriod, label: 'Ultimi 12 mesi'),
  ];

  for (var back = 0; back < appreciationMonthsWindow; back++)
  {
    // A month of zero or less is normalised into the year before it.
    final month = DateTime(now.year, now.month - back);

    options.add(
      FilterOption(
        value: _periodValue(month.year, month.month),
        label: '${monthAbbreviations[month.month - 1]} ${month.year}',
      ),
    );
  }

  return options;
}

// The year and month a period names, or null where it names the whole window.
({int year, int month})? periodParts(String period)
{
  if (period == wholeWindowPeriod)
  {
    return null;
  }

  final parts = period.split('-');

  return (year: int.parse(parts[0]), month: int.parse(parts[1]));
}
