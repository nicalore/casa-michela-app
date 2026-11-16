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

  // What the lessons brought in: the fees are not paid by the hour.
  int get lessonIncomeCents => totalIncomeCents - kind(kFeesIncome);

  int kind(String kind) => incomeByKind[kind] ?? 0;
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

  const AccountingStats({
    required this.months,
    required this.periodStart,
    required this.periodEnd,
    required this.payers,
    required this.volunteers,
    required this.firstYear,
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
