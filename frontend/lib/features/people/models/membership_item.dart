import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';

class MembershipItem
{
  // Revocation codes as the server writes them; they travel unchanged in the update payload.
  static const String revocationNone = 'NO';
  static const String revocationExpulsion = 'EXPULSION';
  static const String revocationResignation = 'RESIGNATION';

  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final int renewalPeriodDays;
  final String revocation;

  // Administrators only: payments hold the year (no removal, no other year
  // number), and its start may not pass latestStart.
  final bool locked;
  final DateTime? latestStart;

  const MembershipItem({
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.renewalPeriodDays,
    required this.revocation,
    this.locked = false,
    this.latestStart,
  });

  bool get isRevoked => revocation != revocationNone;

  // Memberships end 31 December and count 31 more days: renewal stays open until 31 January.
  static const int defaultRenewalPeriodDays = 31;

  // The day renewal closes, counted on the calendar: 24-hour days would skew it across a clock change.
  static DateTime renewalDeadlineOf(DateTime endDate, int renewalPeriodDays) => addDays(endDate, renewalPeriodDays);

  DateTime get renewalDeadline => renewalDeadlineOf(endDate, renewalPeriodDays);

  static bool isWithinRenewalWindow(DateTime endDate, int renewalPeriodDays) =>
      romeNow().isBefore(renewalDeadlineOf(endDate, renewalPeriodDays));

  factory MembershipItem.fromJson(Map<String, dynamic> json)
  {
    return MembershipItem(
      year: json['year'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      renewalPeriodDays: json['renewal_period_days'] as int,
      revocation: json['revocation'] as String,
      locked: json['locked'] as bool? ?? false,
      latestStart: json['latest_start'] == null
          ? null
          : DateTime.parse(json['latest_start'] as String),
    );
  }
}
