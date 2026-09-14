import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

// A month so far, up to a day and hour: days already lived, hours already
// held.
class TeacherMonthFiguresItem
{
  final int totalAvailabilities;
  final double weeklyAvailabilities;

  final int workedMinutes;

  // Null for a teacher with no hourly rate; the amount as the backend
  // serialises its decimal.
  final String? grossCompensation;

  const TeacherMonthFiguresItem({
    required this.totalAvailabilities,
    required this.weeklyAvailabilities,
    required this.workedMinutes,
    this.grossCompensation,
  });

  factory TeacherMonthFiguresItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherMonthFiguresItem(
      totalAvailabilities: json['total_availabilities'] as int,
      weeklyAvailabilities: parseDouble(json['weekly_availabilities']),
      workedMinutes: json['worked_minutes'] as int,
      grossCompensation: json['gross_compensation']?.toString(),
    );
  }
}

class TeacherMonthSummaryItem extends TeacherMonthFiguresItem
{
  final bool isBelowMonthlyThreshold;
  final bool isBelowWeeklyThreshold;

  // The month before, lived up to the same day and hour, so the two
  // compare like for like.
  final TeacherMonthFiguresItem lastMonth;

  const TeacherMonthSummaryItem({
    required super.totalAvailabilities,
    required super.weeklyAvailabilities,
    required super.workedMinutes,
    super.grossCompensation,
    required this.isBelowMonthlyThreshold,
    required this.isBelowWeeklyThreshold,
    required this.lastMonth,
  });

  factory TeacherMonthSummaryItem.fromJson(Map<String, dynamic> json)
  {
    final TeacherMonthFiguresItem now = TeacherMonthFiguresItem.fromJson(json);

    return TeacherMonthSummaryItem(
      totalAvailabilities: now.totalAvailabilities,
      weeklyAvailabilities: now.weeklyAvailabilities,
      workedMinutes: now.workedMinutes,
      grossCompensation: now.grossCompensation,
      isBelowMonthlyThreshold: json['is_below_monthly_threshold'] as bool,
      isBelowWeeklyThreshold: json['is_below_weekly_threshold'] as bool,
      lastMonth: TeacherMonthFiguresItem.fromJson(json['last_month'] as Map<String, dynamic>),
    );
  }
}

class PupilMonthFiguresItem
{
  final PersonOptionItem student;

  final int totalPresences;
  final double weeklyPresences;

  // Days booked from tomorrow to the end of the month.
  final int bookedPresences;

  final int lessonMinutes;

  // How the hours are paid for, as the pupil's record stores it; a
  // package's balance is not tracked yet.
  final String? homeworkTariff;

  const PupilMonthFiguresItem({
    required this.student,
    required this.totalPresences,
    required this.weeklyPresences,
    required this.bookedPresences,
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
      bookedPresences: json['booked_presences'] as int,
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
