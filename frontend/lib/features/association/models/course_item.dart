// The name is the key: no id, so an edit must send the previous name.
class CourseItem
{
  final String name;
  final String? description;

  // Free text, not a number: it carries the period too ("45€ al mese").
  final String? cost;

  final DateTime createdAt;

  const CourseItem({
    required this.name,
    this.description,
    this.cost,
    required this.createdAt,
  });

  factory CourseItem.fromJson(Map<String, dynamic> json)
  {
    return CourseItem(
      name: json['name'] as String,
      description: json['description'] as String?,
      cost: json['cost'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
