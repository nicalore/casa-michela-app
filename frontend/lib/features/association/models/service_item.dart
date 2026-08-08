// A service offered besides the subjects. The name is the key: there is no id,
// and renaming a service changes its identity, so whoever edits one has to keep
// the previous name to tell the server which row is being rewritten.
class ServiceItem
{
  final String name;
  final String? description;
  final DateTime createdAt;

  const ServiceItem({
    required this.name,
    this.description,
    required this.createdAt,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json)
  {
    return ServiceItem(
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
