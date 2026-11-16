import '../../../core/utils/money.dart';

// How a paid teacher's unpaid hour is counted; the names are the server's.
enum VolunteeringRule
{
  weekly,
  daily,
  none;

  static VolunteeringRule fromJson(Object? json) => VolunteeringRule.values.byName(json as String);
}

int? _cents(Object? json) => json == null ? null : parseAmountCents(json.toString());

// A paid teacher's unpaid hour and pay under one rule.
class RuleFigures
{
  final int volunteerMinutes;
  final int paidMinutes;
  final int? gross;
  final int? net;

  const RuleFigures({required this.volunteerMinutes, required this.paidMinutes, required this.gross, required this.net});

  factory RuleFigures.fromJson(Map<String, dynamic> json)
  {
    return RuleFigures(
      volunteerMinutes: json['volunteer_minutes'] as int,
      paidMinutes: json['paid_minutes'] as int,
      gross: _cents(json['gross']),
      net: _cents(json['net']),
    );
  }
}

// Null where nothing is paid.
Map<VolunteeringRule, RuleFigures>? ruleFiguresOf(Object? json)
{
  if (json == null)
  {
    return null;
  }

  return {
    for (final entry in (json as Map<String, dynamic>).entries)
      VolunteeringRule.fromJson(entry.key): RuleFigures.fromJson(entry.value as Map<String, dynamic>),
  };
}
