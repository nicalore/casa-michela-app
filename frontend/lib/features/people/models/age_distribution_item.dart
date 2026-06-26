class AgeDistributionItem 
{
  final String ageGroup;
  final int    count;

  AgeDistributionItem({required this.ageGroup, required this.count});

  factory AgeDistributionItem.fromJson(Map<String, dynamic> json) 
  {
    return AgeDistributionItem(
      ageGroup: json['age_group'],
      count:    json['count'],
    );
  }
}