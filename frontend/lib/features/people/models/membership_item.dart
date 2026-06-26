class MembershipItem 
{
  final int      year;
  final DateTime startDate;
  final DateTime endDate;
  final int      renewalPeriodDays;
  final String   revocation; 

  MembershipItem({
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.renewalPeriodDays,
    required this.revocation,
  });

  factory MembershipItem.fromJson(Map<String, dynamic> json) 
  {
    return MembershipItem(
      year:              json['year'] as int,
      startDate:         DateTime.parse(json['start_date'] as String),
      endDate:           DateTime.parse(json['end_date'] as String),
      renewalPeriodDays: json['renewal_period_days'] as int,
      revocation:        json['revocation'] as String,
    );
  }
}