import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

class TeacherAvailabilityRankItem
{
  final PersonOptionItem teacher;
  final int availabilityCount;

  const TeacherAvailabilityRankItem({
    required this.teacher,
    required this.availabilityCount,
  });

  factory TeacherAvailabilityRankItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherAvailabilityRankItem(
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      availabilityCount: json['availability_count'] as int,
    );
  }
}

class LowAvailabilityTeacherItem
{
  final PersonOptionItem teacher;

  final double weeklyAverage;
  final int availabilityCount;

  const LowAvailabilityTeacherItem({
    required this.teacher,
    required this.weeklyAverage,
    required this.availabilityCount,
  });

  factory LowAvailabilityTeacherItem.fromJson(Map<String, dynamic> json)
  {
    return LowAvailabilityTeacherItem(
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      weeklyAverage: parseDouble(json['weekly_average']),
      availabilityCount: json['availability_count'] as int,
    );
  }
}

class TeacherAvailabilityStatisticsItem
{
  final double weeklyAverage;
  final int totalAvailabilities;
  final List<TeacherAvailabilityRankItem> topTeachers;
  final List<LowAvailabilityTeacherItem> lowAvailabilityTeachers;

  // lowMonthlyTeachers is empty on periods wider than a month; the card hides
  // that section then.
  final bool isSingleMonth;
  final List<LowAvailabilityTeacherItem> lowMonthlyTeachers;

  const TeacherAvailabilityStatisticsItem({
    required this.weeklyAverage,
    required this.totalAvailabilities,
    required this.topTeachers,
    required this.lowAvailabilityTeachers,
    required this.isSingleMonth,
    required this.lowMonthlyTeachers,
  });

  factory TeacherAvailabilityStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherAvailabilityStatisticsItem(
      weeklyAverage: parseDouble(json['weekly_average']),
      totalAvailabilities: json['total_availabilities'] as int,
      topTeachers: parseList(json['top_teachers'], TeacherAvailabilityRankItem.fromJson),
      lowAvailabilityTeachers:
          parseList(json['low_availability_teachers'], LowAvailabilityTeacherItem.fromJson),
      isSingleMonth: json['is_single_month'] as bool,
      lowMonthlyTeachers:
          parseList(json['low_monthly_teachers'], LowAvailabilityTeacherItem.fromJson),
    );
  }
}
