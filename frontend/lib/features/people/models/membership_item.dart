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

  const MembershipItem({
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.renewalPeriodDays,
    required this.revocation,
  });

  bool get isRevoked => revocation != revocationNone;

  // A membership ends on 31 December and still counts for 31 more days, so renewal is open until 31 January.
  static const int defaultRenewalPeriodDays = 31;

  static bool isWithinRenewalWindow(DateTime endDate, int renewalPeriodDays) =>
      DateTime.now().isBefore(endDate.add(Duration(days: renewalPeriodDays)));

  factory MembershipItem.fromJson(Map<String, dynamic> json)
  {
    return MembershipItem(
      year: json['year'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      renewalPeriodDays: json['renewal_period_days'] as int,
      revocation: json['revocation'] as String,
    );
  }
}
