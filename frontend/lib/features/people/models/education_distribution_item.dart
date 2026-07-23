class EducationDistributionItem
{
  final String label;
  final int count;

  const EducationDistributionItem({required this.label, required this.count});

  factory EducationDistributionItem.fromJson(Map<String, dynamic> json)
  {
    return EducationDistributionItem(
      label: json['label'],
      count: json['count'],
    );
  }
}