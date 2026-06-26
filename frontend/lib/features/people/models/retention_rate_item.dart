class RetentionRateItem 
{
  final int    year;
  final int?   month;
  final int    previousYearMembers;
  final int    retainedMembers;
  final double retentionRatePercentage;

  RetentionRateItem({
    required this.year,
    this.month,
    required this.previousYearMembers,
    required this.retainedMembers,
    required this.retentionRatePercentage,
  });

  factory RetentionRateItem.fromJson(Map<String, dynamic> json) 
  {
    return RetentionRateItem(
      year:                    json['year'],
      month:                   json['month'],
      previousYearMembers:     json['previous_year_members'],
      retainedMembers:         json['retained_members'],
      retentionRatePercentage: (json['retention_rate_percentage'] as num).toDouble(),
    );
  }
}