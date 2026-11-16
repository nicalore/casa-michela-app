import '../../../core/utils/money.dart';
import '../../accounting/models/volunteering_rule.dart';

// Hours as the server writes them, "15:00:00": only the minutes are ever shown.
String _shortTime(String time) => time.substring(0, 5);

class CompensationSpan
{
  final String start;
  final String end;

  // Volunteering is always in person.
  final bool online;

  const CompensationSpan({required this.start, required this.end, this.online = false});

  factory CompensationSpan.fromJson(Map<String, dynamic> json)
  {
    return CompensationSpan(
      start: _shortTime(json['start_time'] as String),
      end: _shortTime(json['end_time'] as String),
      online: json['mode'] == 'online',
    );
  }
}

List<CompensationSpan> _spans(Object? json)
{
  return [
    for (final span in json as List<dynamic>)
      CompensationSpan.fromJson(span as Map<String, dynamic>),
  ];
}

int? _cents(Object? json) => json == null ? null : parseAmountCents(json.toString());

class CompensationDay
{
  final DateTime date;
  final List<CompensationSpan> worked;
  final List<CompensationSpan> volunteer;
  final int workedMinutes;
  final int volunteerMinutes;
  final int? gross;
  final int? net;

  const CompensationDay({
    required this.date,
    required this.worked,
    required this.volunteer,
    required this.workedMinutes,
    required this.volunteerMinutes,
    required this.gross,
    required this.net,
  });

  factory CompensationDay.fromJson(Map<String, dynamic> json)
  {
    return CompensationDay(
      date: DateTime.parse(json['date'] as String),
      worked: _spans(json['worked']),
      volunteer: _spans(json['volunteer']),
      workedMinutes: json['worked_minutes'] as int,
      volunteerMinutes: json['volunteer_minutes'] as int,
      gross: _cents(json['gross']),
      net: _cents(json['net']),
    );
  }
}

class CompensationMonth
{
  final String collaborationType;
  final int? grossRate;
  final int? netRate;
  final int? gross;
  final int? net;
  final int workedMinutes;
  final int volunteerMinutes;
  final int paidMinutes;
  final List<CompensationDay> days;
  final bool canEdit;

  // How the month counts the unpaid hour; month only when the monthly summary
  // chose it for this month alone.
  final VolunteeringRule volunteering;
  final bool volunteeringMonthOnly;

  // Months with their own choice that a rule from this month would replace.
  final List<DateTime> volunteeringReplaced;

  // The month under each rule, were it the teacher's from here: null unless paid.
  final Map<VolunteeringRule, RuleFigures>? volunteeringPreviews;

  // The first day the app works pay out; the initial set-up says the pay before it.
  final DateTime? moneyFrom;

  // That pay, when it falls in this month: inside gross and net.
  final int? openingGross;
  final int? openingNet;

  // The month's set-up is still to do: no money yet.
  final bool openingPending;

  const CompensationMonth({
    required this.collaborationType,
    required this.grossRate,
    required this.netRate,
    required this.gross,
    required this.net,
    required this.workedMinutes,
    required this.volunteerMinutes,
    required this.paidMinutes,
    required this.days,
    required this.canEdit,
    this.volunteering = VolunteeringRule.weekly,
    this.volunteeringMonthOnly = false,
    this.volunteeringReplaced = const [],
    this.volunteeringPreviews,
    this.moneyFrom,
    this.openingGross,
    this.openingNet,
    this.openingPending = false,
  });

  bool get isPaid => collaborationType == 'PAID';

  // The day the initial set-up describes.
  DateTime? get openingDay => moneyFrom?.subtract(const Duration(days: 1));

  factory CompensationMonth.fromJson(Map<String, dynamic> json)
  {
    return CompensationMonth(
      collaborationType: json['collaboration_type'] as String,
      grossRate: _cents(json['gross_rate']),
      netRate: _cents(json['net_rate']),
      gross: _cents(json['gross']),
      net: _cents(json['net']),
      workedMinutes: json['worked_minutes'] as int,
      volunteerMinutes: json['volunteer_minutes'] as int,
      paidMinutes: json['paid_minutes'] as int,
      days: [
        for (final day in json['days'] as List<dynamic>)
          CompensationDay.fromJson(day as Map<String, dynamic>),
      ],
      canEdit: json['can_edit'] as bool,
      volunteering: VolunteeringRule.fromJson(json['volunteering']),
      volunteeringMonthOnly: json['volunteering_month_only'] as bool,
      volunteeringReplaced: [
        for (final month in json['volunteering_replaced'] as List<dynamic>) DateTime.parse(month as String),
      ],
      volunteeringPreviews: ruleFiguresOf(json['volunteering_previews']),
      moneyFrom: json['money_from'] == null ? null : DateTime.parse(json['money_from'] as String),
      openingGross: _cents(json['opening_gross']),
      openingNet: _cents(json['opening_net']),
      openingPending: json['opening_pending'] as bool? ?? false,
    );
  }
}
