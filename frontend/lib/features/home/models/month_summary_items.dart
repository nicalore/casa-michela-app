import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

// What /home says about the month so far: days already lived, hours already
// held.
class TeacherMonthSummaryItem
{
  final int totalAvailabilities;
  final double weeklyAvailabilities;

  final bool isBelowMonthlyThreshold;
  final bool isBelowWeeklyThreshold;

  final int workedMinutes;

  // Null for a teacher with no hourly rate; the amount as the backend
  // serialises its decimal.
  final String? grossCompensation;

  const TeacherMonthSummaryItem({
    required this.totalAvailabilities,
    required this.weeklyAvailabilities,
    required this.isBelowMonthlyThreshold,
    required this.isBelowWeeklyThreshold,
    required this.workedMinutes,
    this.grossCompensation,
  });

  factory TeacherMonthSummaryItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherMonthSummaryItem(
      totalAvailabilities: json['total_availabilities'] as int,
      weeklyAvailabilities: parseDouble(json['weekly_availabilities']),
      isBelowMonthlyThreshold: json['is_below_monthly_threshold'] as bool,
      isBelowWeeklyThreshold: json['is_below_weekly_threshold'] as bool,
      workedMinutes: json['worked_minutes'] as int,
      grossCompensation: json['gross_compensation']?.toString(),
    );
  }
}

class PupilMonthFiguresItem
{
  final PersonOptionItem student;

  final int totalPresences;
  final double weeklyPresences;

  final int lessonMinutes;

  // How the hours are paid for, as the pupil's record stores it; a
  // package's balance is not tracked yet.
  final String? homeworkTariff;

  const PupilMonthFiguresItem({
    required this.student,
    required this.totalPresences,
    required this.weeklyPresences,
    required this.lessonMinutes,
    this.homeworkTariff,
  });

  bool get hasPackage => homeworkTariff?.endsWith('_PACKAGE') ?? false;

  bool get isHourly => homeworkTariff?.endsWith('_HOURLY') ?? false;

  bool get isMonthly => homeworkTariff == 'PRIMARY_MONTHLY';

  factory PupilMonthFiguresItem.fromJson(Map<String, dynamic> json)
  {
    return PupilMonthFiguresItem(
      student: PersonOptionItem.fromJson(json['student'] as Map<String, dynamic>),
      totalPresences: json['total_presences'] as int,
      weeklyPresences: parseDouble(json['weekly_presences']),
      lessonMinutes: json['lesson_minutes'] as int,
      homeworkTariff: json['homework_tariff'] as String?,
    );
  }
}

class StudentMonthSummaryItem
{
  final PupilMonthFiguresItem figures;

  // A pupil somebody answers for reads a narrower card than one who books
  // for themselves.
  final bool hasParentalResponsibility;

  const StudentMonthSummaryItem({
    required this.figures,
    required this.hasParentalResponsibility,
  });

  factory StudentMonthSummaryItem.fromJson(Map<String, dynamic> json)
  {
    return StudentMonthSummaryItem(
      figures: PupilMonthFiguresItem.fromJson(json['figures'] as Map<String, dynamic>),
      hasParentalResponsibility: json['has_parental_responsibility'] as bool,
    );
  }
}

class ParentMonthSummaryItem
{
  final List<PupilMonthFiguresItem> children;

  const ParentMonthSummaryItem({required this.children});

  factory ParentMonthSummaryItem.fromJson(Map<String, dynamic> json)
  {
    return ParentMonthSummaryItem(
      children: parseList(json['children'], PupilMonthFiguresItem.fromJson),
    );
  }
}
