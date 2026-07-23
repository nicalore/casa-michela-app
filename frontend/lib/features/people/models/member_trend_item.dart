class MemberTrendItem
{
  final int year;

  // Null on the yearly aggregates, set on the monthly ones: the same endpoint
  // returns both granularities.
  final int? month;

  final int totalMembers;

  const MemberTrendItem({
    required this.year,
    this.month,
    required this.totalMembers,
  });

  factory MemberTrendItem.fromJson(Map<String, dynamic> json)
  {
    return MemberTrendItem(
      year: json['year'],
      month: json['month'],
      totalMembers: json['total_members'],
    );
  }
}