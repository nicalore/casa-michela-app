class AssociationSubjectItem
{
  final int id;
  final String name;
  final String area;
  final String? description;
  final DateTime createdAt;

  const AssociationSubjectItem({
    required this.id,
    required this.name,
    required this.area,
    this.description,
    required this.createdAt,
  });

  factory AssociationSubjectItem.fromJson(Map<String, dynamic> json)
  {
    return AssociationSubjectItem(
      id: json['id'] as int,
      name: json['name'] as String,
      area: json['area'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}