import '../../../../../core/language/app_language.dart';
import '../../../../../core/utils/rome_clock.dart';
import '../../../../../shared/widgets/filter_menu.dart';
import '../../../models/member_trend_item.dart';
import 'stats_constants.dart';

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

// The backend omits periods with no members; a chart needs a continuous series.
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

  final now = romeNow();

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
  return [
    FilterOption(value: 'year', label: tr('Annuale', 'Yearly')),
    FilterOption(value: 'month', label: tr('Mensile', 'Monthly')),
  ];
}

List<FilterOption<int>> yearOptions()
{
  final currentYear = romeNow().year;

  return List.generate(currentYear - dataStartYear + 1, (index) => currentYear - index)
      .map((year) => FilterOption(value: year, label: year.toString()))
      .toList();
}

// The first year only has data from [dataStartMonth] on.
List<FilterOption<int>> monthOptions(int selectedYear)
{
  final firstMonth = selectedYear == dataStartYear ? dataStartMonth : 1;

  return [
    for (var month = firstMonth; month <= 12; month++)
      FilterOption(value: month, label: monthAbbreviations[month - 1]),
  ];
}

// A period is one string: 'last-N' trailing months or a single month 'YYYY-MM'.

// Calendars older than a year are deleted, so no month further back exists.
const int statsMonthsWindow = 12;

const String defaultStatsPeriod = 'last-12';

// What the home's month shows, so a figure followed there reads the same.
const String kThisMonthStatsPeriod = 'last-1';

// Exactly one of the two shapes is set, mirroring the backend's parameters.
typedef StatsPeriod = ({int? months, int? year, int? month});

String _monthPeriodValue(int year, int month)
{
  return '$year-${month.toString().padLeft(2, '0')}';
}

String statsPeriodLabel(String value)
{
  return statsPeriodOptions().firstWhere((option) => option.value == value).label;
}

// "rispetto all'1 attivo", "agli 8 attivi", "ai 12 attivi".
String comparedToActive(int count)
{
  if (count == 1)
  {
    return tr("rispetto all'1 attivo", 'out of the 1 active');
  }

  return tr('rispetto ${_takesGli(count) ? 'agli' : 'ai'} $count attivi', 'out of the $count active');
}

// Read aloud: zero, otto, undici, ottanta, ottocento, also before "mila"; mille is not.
bool _takesGli(int count)
{
  if (count >= 1000)
  {
    final int thousands = count ~/ 1000;

    return thousands > 1 && _takesGli(thousands);
  }

  return count == 0 || count == 8 || count == 11 || (count >= 80 && count < 90) || (count >= 800 && count < 900);
}

List<FilterOption<String>> statsPeriodOptions()
{
  final now = romeNow();

  final options = <FilterOption<String>>[
    FilterOption(value: kThisMonthStatsPeriod, label: tr('Questo mese', 'This month')),
    for (var months = 2; months <= statsMonthsWindow; months++)
      FilterOption(value: 'last-$months', label: tr('Ultimi $months mesi', 'Last $months months')),
  ];

  for (var back = 0; back < statsMonthsWindow; back++)
  {
    // A month of zero or less is normalised into the year before it.
    final month = DateTime(now.year, now.month - back);

    options.add(
      FilterOption(
        value: _monthPeriodValue(month.year, month.month),
        label: '${monthAbbreviations[month.month - 1]} ${month.year}',
      ),
    );
  }

  return options;
}

StatsPeriod statsPeriodParts(String period)
{
  if (period.startsWith('last-'))
  {
    return (months: int.parse(period.substring(5)), year: null, month: null);
  }

  final parts = period.split('-');

  return (months: null, year: int.parse(parts[0]), month: int.parse(parts[1]));
}

// A month of zero or less is normalised into the year before it.
DateTime statsPeriodStart(String period)
{
  final parts = statsPeriodParts(period);
  final months = parts.months;

  if (months == null)
  {
    return DateTime(parts.year!, parts.month!);
  }

  final now = romeNow();

  return DateTime(now.year, now.month - months + 1);
}
