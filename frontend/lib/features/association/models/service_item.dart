// The name is the key: no id, so an edit must send the previous name.
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
