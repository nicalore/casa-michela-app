import '../../../core/utils/json_parsing.dart';

class RetentionRateItem
{
  final int year;

  // Null on the yearly aggregates, set on the monthly ones: the same endpoint
  // returns both granularities.
  final int? month;

  final int previousYearMembers;
  final int retainedMembers;
  final double retentionRatePercentage;

  const RetentionRateItem({
    required this.year,
    this.month,
    required this.previousYearMembers,
    required this.retainedMembers,
    required this.retentionRatePercentage,
  });

  factory RetentionRateItem.fromJson(Map<String, dynamic> json)
  {
    return RetentionRateItem(
      year: json['year'],
      month: json['month'],
      previousYearMembers: json['previous_year_members'],
      retainedMembers: json['retained_members'],
      retentionRatePercentage: parseDouble(json['retention_rate_percentage']),
    );
  }
}