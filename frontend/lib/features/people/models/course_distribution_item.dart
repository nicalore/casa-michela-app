class CourseDistributionItem
{
  final String label;
  final int count;

  const CourseDistributionItem({required this.label, required this.count});

  factory CourseDistributionItem.fromJson(Map<String, dynamic> json)
  {
    return CourseDistributionItem(
      label: json['label'],
      count: json['count'],
    );
  }
}