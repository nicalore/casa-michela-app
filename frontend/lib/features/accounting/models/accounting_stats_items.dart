import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';
import '../../people/tabs/statistics/widgets/trend_band.dart';

// The annual membership and insurance fees, of every member, as one kind.
const String kFeesIncome = 'FEES';

// The kinds of money in, in the order the charts stack them.
const List<String> kIncomeKinds = ['PACKAGE', 'MONTH', 'HOURLY', 'AHEAD', 'WEEKEND_ONLINE', kFeesIncome];

class AccountingMonth
{
  final DateTime month;

  // From the pupils, their own annual fees included.
  final int incomeCents;

  // From everybody: the other members' annual fees too. The kinds add up to it.
  final int totalIncomeCents;
  final Map<String, int> incomeByKind;
  final int grossCents;
  final int netCents;

  // The pupils' lesson hours and the teachers' paid hours.
  final int pupilMinutes;
  final int paidMinutes;

  final int volunteerMinutes;

  // At each paid teacher's own rate.
  final int volunteerValueCents;

  const AccountingMonth({
    required this.month,
    required this.incomeCents,
    required this.totalIncomeCents,
    required this.incomeByKind,
    required this.grossCents,
    required this.netCents,
    required this.pupilMinutes,
    required this.paidMinutes,
    required this.volunteerMinutes,
    required this.volunteerValueCents,
  });

  factory AccountingMonth.fromJson(Map<String, dynamic> json)
  {
    return AccountingMonth(
      month: DateTime.parse(json['month'] as String),
      incomeCents: json['income_cents'] as int,
      totalIncomeCents: json['total_income_cents'] as int,
      incomeByKind: {
        for (final entry in (json['income_by_kind'] as Map<String, dynamic>).entries) entry.key: entry.value as int,
      },
      grossCents: json['gross_cents'] as int,
      netCents: json['net_cents'] as int,
      pupilMinutes: json['pupil_minutes'] as int,
      paidMinutes: json['paid_minutes'] as int,
      volunteerMinutes: json['volunteer_minutes'] as int,
      volunteerValueCents: json['volunteer_value_cents'] as int,
    );
  }

  int get withheldCents => grossCents - netCents;

  int get balanceCents => totalIncomeCents - grossCents;

  int kind(String kind) => incomeByKind[kind] ?? 0;
}

class PayerItem
{
  final PersonOptionItem person;
  final int cents;

  const PayerItem({required this.person, required this.cents});

  factory PayerItem.fromJson(Map<String, dynamic> json)
  {
    return PayerItem(
      person: PersonOptionItem.fromJson(json['person'] as Map<String, dynamic>),
      cents: json['cents'] as int,
    );
  }
}

// A pupil's monthly fees in the period against their hours at the cost per hour.
class FeePupilItem
{
  final PersonOptionItem person;

  // The latest month's fee.
  final int feeCents;
  final int months;
  final int paidCents;

  // Weekend online hours left out: they are paid apart.
  final int minutes;
  final int costCents;

  // Hours a month the fee pays for, in whole quarters.
  final int? evenMinutes;

  const FeePupilItem({
    required this.person,
    required this.feeCents,
    required this.months,
    required this.paidCents,
    required this.minutes,
    required this.costCents,
    required this.evenMinutes,
  });

  factory FeePupilItem.fromJson(Map<String, dynamic> json)
  {
    return FeePupilItem(
      person: PersonOptionItem.fromJson(json['person'] as Map<String, dynamic>),
      feeCents: json['fee_cents'] as int,
      months: json['months'] as int,
      paidCents: json['paid_cents'] as int,
      minutes: json['minutes'] as int,
      costCents: json['cost_cents'] as int,
      evenMinutes: json['even_minutes'] as int?,
    );
  }

  int get marginCents => paidCents - costCents;
}

class FeeBreakEvenItem
{
  final String level;
  final int feeCents;
  final int minutes;

  const FeeBreakEvenItem({required this.level, required this.feeCents, required this.minutes});

  factory FeeBreakEvenItem.fromJson(Map<String, dynamic> json)
  {
    return FeeBreakEvenItem(
      level: json['level'] as String,
      feeCents: json['fee_cents'] as int,
      minutes: json['minutes'] as int,
    );
  }
}

class AccountingStats
{
  // Twelve months: the last ones up to this, or a year from January.
  final List<AccountingMonth> months;

  // The first and the last month the figures add up.
  final DateTime periodStart;
  final DateTime periodEnd;

  final int payers;
  final int volunteers;
  final int firstYear;

  // Per hour from the start of the app's accounts, the set-up's pay left out; null without hours.
  // Lesson income per pupil hour, gross pay per teacher's paid hour, gross pay per pupil hour.
  final int? incomePerHourCents;
  final int? payPerHourCents;
  final int? lessonCostCents;
  final List<PayerItem> topPayers;

  // Lowest margin first.
  final List<FeePupilItem> feePupils;

  // The standard monthly fee of each level.
  final List<FeeBreakEvenItem> breakEven;

  const AccountingStats({
    required this.months,
    required this.periodStart,
    required this.periodEnd,
    required this.payers,
    required this.volunteers,
    required this.firstYear,
    required this.incomePerHourCents,
    required this.payPerHourCents,
    required this.lessonCostCents,
    required this.topPayers,
    required this.feePupils,
    required this.breakEven,
  });

  factory AccountingStats.fromJson(Map<String, dynamic> json)
  {
    return AccountingStats(
      months: [
        for (final month in json['months'] as List<dynamic>) AccountingMonth.fromJson(month as Map<String, dynamic>),
      ],
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      payers: json['payers'] as int,
      volunteers: json['volunteers'] as int,
      firstYear: json['first_year'] as int,
      incomePerHourCents: json['income_per_hour_cents'] as int?,
      payPerHourCents: json['pay_per_hour_cents'] as int?,
      lessonCostCents: json['lesson_cost_cents'] as int?,
      topPayers: parseList(json['top_payers'], PayerItem.fromJson),
      feePupils: parseList(json['fee_pupils'], FeePupilItem.fromJson),
      breakEven: parseList(json['break_even'], FeeBreakEvenItem.fromJson),
    );
  }

  List<AccountingMonth> get inPeriod => [
        for (final month in months)
          if (!month.month.isBefore(periodStart) && !month.month.isAfter(periodEnd)) month,
      ];

  // The months of the period on the chart; null when they are the whole of it or a year.
  TrendSpan? spanOf({required bool lastMonths})
  {
    final int first = months.indexWhere((month) => month.month == periodStart);
    final int last = months.indexWhere((month) => month.month == periodEnd);

    if (!lastMonths || first <= 0 || last < 0)
    {
      return null;
    }

    return (first: first, last: last);
  }

  int sum(int Function(AccountingMonth month) of) => inPeriod.fold(0, (total, month) => total + of(month));
}
