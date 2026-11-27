import 'dart:math' as math;

import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

class TeacherMonthFiguresItem
{
  final int totalAvailabilities;
  final double weeklyAvailabilities;

  final int workedMinutes;

  // Null without an hourly rate; a decimal string as the backend serialises it.
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

class TeacherWeekItem
{
  final int given;
  final int needed;

  const TeacherWeekItem({required this.given, required this.needed});

  bool get isShort => given < needed;

  factory TeacherWeekItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherWeekItem(
      given: json['given'] as int,
      needed: json['required'] as int,
    );
  }
}

class TeacherMonthSummaryItem extends TeacherMonthFiguresItem
{
  final bool isBelowMonthlyThreshold;

  // Weeks already over with fewer days than asked.
  final int shortWeekCount;

  // The week still being filled; null once no opening is left in it.
  final TeacherWeekItem? currentWeek;

  // Cut at the same day and hour, so the two compare like for like.
  final TeacherMonthFiguresItem lastMonth;

  const TeacherMonthSummaryItem({
    required super.totalAvailabilities,
    required super.weeklyAvailabilities,
    required super.workedMinutes,
    super.grossCompensation,
    required this.isBelowMonthlyThreshold,
    required this.shortWeekCount,
    this.currentWeek,
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
      shortWeekCount: json['short_week_count'] as int,
      currentWeek: json['current_week'] == null
          ? null
          : TeacherWeekItem.fromJson(json['current_week'] as Map<String, dynamic>),
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

  // HOURLY, PACKAGE or MONTHLY; null when there is none or a parent pays it.
  final String? tariffKind;

  // Null also while the initial set-up waits.
  final PupilPaymentFiguresItem? payment;

  const PupilMonthFiguresItem({
    required this.student,
    required this.totalPresences,
    required this.weeklyPresences,
    required this.bookedPresences,
    required this.lessonMinutes,
    this.tariffKind,
    this.payment,
  });

  bool get hasPackage => tariffKind == 'PACKAGE';

  bool get isHourly => tariffKind == 'HOURLY';

  bool get isMonthly => tariffKind == 'MONTHLY';

  factory PupilMonthFiguresItem.fromJson(Map<String, dynamic> json)
  {
    return PupilMonthFiguresItem(
      student: PersonOptionItem.fromJson(json['student'] as Map<String, dynamic>),
      totalPresences: json['total_presences'] as int,
      weeklyPresences: parseDouble(json['weekly_presences']),
      bookedPresences: json['booked_presences'] as int,
      lessonMinutes: json['lesson_minutes'] as int,
      tariffKind: json['tariff_kind'] as String?,
      payment: json['payment'] == null
          ? null
          : PupilPaymentFiguresItem.fromJson(json['payment'] as Map<String, dynamic>),
    );
  }
}

class PupilPaymentFiguresItem
{
  final String kind;

  // The package running, else the last one, else the tariff's; nothing used (null) before any was bought.
  final int? packageMinutes;
  final int? usedMinutes;

  final bool monthPaid;

  // Owed this month, not just unpaid.
  final bool monthDue;

  // This month's hours by the hour.
  final int paidMinutes;
  final int dueMinutes;

  const PupilPaymentFiguresItem({
    required this.kind,
    this.packageMinutes,
    this.usedMinutes,
    this.monthPaid = false,
    this.monthDue = false,
    this.paidMinutes = 0,
    this.dueMinutes = 0,
  });

  bool get isPackage => kind == 'PACKAGE';

  bool get isMonthly => kind == 'MONTHLY';

  // Null before any package was bought.
  int? get leftMinutes
  {
    final int? total = packageMinutes;
    final int? used = usedMinutes;

    return total == null || used == null ? null : math.max(total - used, 0);
  }

  factory PupilPaymentFiguresItem.fromJson(Map<String, dynamic> json)
  {
    return PupilPaymentFiguresItem(
      kind: json['kind'] as String,
      packageMinutes: json['package_minutes'] as int?,
      usedMinutes: json['used_minutes'] as int?,
      monthPaid: json['month_paid'] as bool? ?? false,
      monthDue: json['month_due'] as bool? ?? false,
      paidMinutes: json['paid_minutes'] as int? ?? 0,
      dueMinutes: json['due_minutes'] as int? ?? 0,
    );
  }
}

class StudentMonthSummaryItem
{
  final PupilMonthFiguresItem figures;

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
