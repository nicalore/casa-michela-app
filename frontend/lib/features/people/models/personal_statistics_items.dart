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

class SubjectHoursItem
{
  final String name;
  final int minutes;

  // Share over all entries in the period, not just the ones shown.
  final double percentage;

  const SubjectHoursItem({
    required this.name,
    required this.minutes,
    required this.percentage,
  });

  factory SubjectHoursItem.fromJson(Map<String, dynamic> json)
  {
    return SubjectHoursItem(
      name: json['name'] as String,
      minutes: json['minutes'] as int,
      percentage: parseDouble(json['percentage']),
    );
  }
}

class SubjectHoursRankings
{
  final List<SubjectHoursItem> ministrySubjects;
  final List<SubjectHoursItem> disciplines;
  final List<SubjectHoursItem> services;

  const SubjectHoursRankings({
    required this.ministrySubjects,
    required this.disciplines,
    required this.services,
  });

  List<SubjectHoursItem> of(RequestedSubjectKind kind)
  {
    return switch (kind)
    {
      RequestedSubjectKind.ministrySubject => ministrySubjects,
      RequestedSubjectKind.discipline => disciplines,
      RequestedSubjectKind.service => services,
    };
  }

  factory SubjectHoursRankings.fromJson(Map<String, dynamic> json)
  {
    return SubjectHoursRankings(
      ministrySubjects: parseList(json['ministry_subjects'], SubjectHoursItem.fromJson),
      disciplines: parseList(json['disciplines'], SubjectHoursItem.fromJson),
      services: parseList(json['services'], SubjectHoursItem.fromJson),
    );
  }
}

class PersonHoursItem
{
  final PersonOptionItem person;
  final int minutes;

  // Share over all entries in the period, not just the ones shown.
  final double percentage;

  const PersonHoursItem({
    required this.person,
    required this.minutes,
    required this.percentage,
  });

  factory PersonHoursItem.fromJson(Map<String, dynamic> json)
  {
    return PersonHoursItem(
      person: PersonOptionItem.fromJson(json['person'] as Map<String, dynamic>),
      minutes: json['minutes'] as int,
      percentage: parseDouble(json['percentage']),
    );
  }
}

class TeacherPersonalStatisticsItem
{
  final double weeklyAverage;
  final int totalAvailabilities;

  // Always the last twelve months, whatever period is selected.
  final List<MemberTrendItem> monthlyTrend;

  // Weeks already over with fewer days than asked.
  final int shortWeekCount;

  // isBelowMonthlyThreshold is meaningful only when isSingleMonth is true.
  final bool isSingleMonth;
  final bool isBelowMonthlyThreshold;

  final List<SubjectHoursItem> taughtDisciplines;
  final List<PersonHoursItem> topStudents;

  const TeacherPersonalStatisticsItem({
    required this.weeklyAverage,
    required this.totalAvailabilities,
    required this.monthlyTrend,
    required this.shortWeekCount,
    required this.isSingleMonth,
    required this.isBelowMonthlyThreshold,
    required this.taughtDisciplines,
    required this.topStudents,
  });

  factory TeacherPersonalStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherPersonalStatisticsItem(
      weeklyAverage: parseDouble(json['weekly_average']),
      totalAvailabilities: json['total_availabilities'] as int,
      monthlyTrend: monthlyTrendPoints(json['monthly_trend']),
      shortWeekCount: json['short_week_count'] as int,
      isSingleMonth: json['is_single_month'] as bool,
      isBelowMonthlyThreshold: json['is_below_monthly_threshold'] as bool,
      taughtDisciplines: parseList(json['taught_disciplines'], SubjectHoursItem.fromJson),
      topStudents: parseList(json['top_students'], PersonHoursItem.fromJson),
    );
  }
}

// Fetched separately from availabilities: the two have their own periods.
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

  final SubjectHoursRankings lessonHours;
  final List<PersonHoursItem> topTeachers;

  const StudentPersonalStatisticsItem({
    required this.weeklyPresenceDays,
    required this.totalPresenceDays,
    required this.monthlyTrend,
    required this.lessonHours,
    required this.topTeachers,
  });

  factory StudentPersonalStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return StudentPersonalStatisticsItem(
      weeklyPresenceDays: parseDouble(json['weekly_presence_days']),
      totalPresenceDays: json['total_presence_days'] as int,
      monthlyTrend: monthlyTrendPoints(json['monthly_trend']),
      lessonHours: SubjectHoursRankings.fromJson(json['lesson_hours'] as Map<String, dynamic>),
      topTeachers: parseList(json['top_teachers'], PersonHoursItem.fromJson),
    );
  }
}

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
