class MembershipItem
{
  // The values of [revocation] as the server writes them. They travel unchanged
  // in the update payload, so they cannot be translated in place.
  //
  // Here and not in the page showing them, because that page is no longer the
  // only one asking: two places writing 'NO' by hand are two places that can
  // stop agreeing.
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

  // Espulsa o dimessa.
  bool get isRevoked => revocation != revocationNone;

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
