import '../../../core/utils/json_parsing.dart';
import 'member_trend_item.dart';
import 'student_presence_statistics_item.dart';

List<MemberTrendItem> monthlyTrendPoints(Object? value)
{
  return [
    for (final point in value as List<dynamic>)
      MemberTrendItem(
        year: point['year'] as int,
        month: point['month'] as int,
        totalMembers: point['count'] as int,
      ),
  ];
}

class TeacherPersonalStatisticsItem
{
  final double weeklyAverage;
  final int totalAvailabilities;

  // Always the last twelve months, whatever period is selected.
  final List<MemberTrendItem> monthlyTrend;

  // isBelowMonthlyThreshold is meaningful only when isSingleMonth is true.
  final bool isBelowWeeklyThreshold;
  final bool isSingleMonth;
  final bool isBelowMonthlyThreshold;

  // Rank is null when the count is zero.
  final int preferredCount;
  final int? preferredRank;
  final int notPreferredCount;
  final int? notPreferredRank;

  const TeacherPersonalStatisticsItem({
    required this.weeklyAverage,
    required this.totalAvailabilities,
    required this.monthlyTrend,
    required this.isBelowWeeklyThreshold,
    required this.isSingleMonth,
    required this.isBelowMonthlyThreshold,
    required this.preferredCount,
    required this.preferredRank,
    required this.notPreferredCount,
    required this.notPreferredRank,
  });

  factory TeacherPersonalStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherPersonalStatisticsItem(
      weeklyAverage: parseDouble(json['weekly_average']),
      totalAvailabilities: json['total_availabilities'] as int,
      monthlyTrend: monthlyTrendPoints(json['monthly_trend']),
      isBelowWeeklyThreshold: json['is_below_weekly_threshold'] as bool,
      isSingleMonth: json['is_single_month'] as bool,
      isBelowMonthlyThreshold: json['is_below_monthly_threshold'] as bool,
      preferredCount: json['preferred_count'] as int,
      preferredRank: json['preferred_rank'] as int?,
      notPreferredCount: json['not_preferred_count'] as int,
      notPreferredRank: json['not_preferred_rank'] as int?,
    );
  }
}

class StudentPersonalStatisticsItem
{
  final double weeklyPresenceDays;
  final int totalPresenceDays;

  // Always the last twelve months, whatever period is selected.
  final List<MemberTrendItem> monthlyTrend;

  final RequestedSubjectRankings requested;

  const StudentPersonalStatisticsItem({
    required this.weeklyPresenceDays,
    required this.totalPresenceDays,
    required this.monthlyTrend,
    required this.requested,
  });

  factory StudentPersonalStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return StudentPersonalStatisticsItem(
      weeklyPresenceDays: parseDouble(json['weekly_presence_days']),
      totalPresenceDays: json['total_presence_days'] as int,
      monthlyTrend: monthlyTrendPoints(json['monthly_trend']),
      requested: RequestedSubjectRankings.fromJson(json['requested'] as Map<String, dynamic>),
    );
  }
}
