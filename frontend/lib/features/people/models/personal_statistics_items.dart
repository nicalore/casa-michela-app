import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';
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

  const TeacherPersonalStatisticsItem({
    required this.weeklyAverage,
    required this.totalAvailabilities,
    required this.monthlyTrend,
    required this.isBelowWeeklyThreshold,
    required this.isSingleMonth,
    required this.isBelowMonthlyThreshold,
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
    );
  }
}

// Asked apart from the availabilities: the two carry periods of their own.
class TeacherAppreciationStatisticsItem
{
  final int score;

  // Null when no pupil had anything to say about the teacher.
  final int? rank;
  final int preferringStudentCount;
  final int avoidingStudentCount;

  const TeacherAppreciationStatisticsItem({
    required this.score,
    required this.rank,
    required this.preferringStudentCount,
    required this.avoidingStudentCount,
  });

  factory TeacherAppreciationStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherAppreciationStatisticsItem(
      score: json['score'] as int,
      rank: json['rank'] as int?,
      preferringStudentCount: json['preferring_student_count'] as int,
      avoidingStudentCount: json['avoiding_student_count'] as int,
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

// By name, each pupil once.
class TeacherAppreciationStudentsItem
{
  final List<PersonOptionItem> preferring;
  final List<PersonOptionItem> avoiding;

  const TeacherAppreciationStudentsItem({
    required this.preferring,
    required this.avoiding,
  });

  factory TeacherAppreciationStudentsItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherAppreciationStudentsItem(
      preferring: parseList(json['preferring'], PersonOptionItem.fromJson),
      avoiding: parseList(json['avoiding'], PersonOptionItem.fromJson),
    );
  }
}
