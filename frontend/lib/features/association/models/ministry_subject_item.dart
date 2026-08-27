class MinistrySubjectItem
{
  final int id;
  final String name;
  final String level;
  final List<String> areas;
  final String? description;
  final DateTime createdAt;
  final List<AssociationSubjectOption> associationSubjects;

  const MinistrySubjectItem({
    required this.id,
    required this.name,
    required this.level,
    required this.areas,
    this.description,
    required this.createdAt,
    this.associationSubjects = const [],
  });
}

class AssociationSubjectOption
{
  final int id;
  final String name;

  final String? description;

  const AssociationSubjectOption({
    required this.id,
    required this.name,
    this.description,
  });

  factory AssociationSubjectOption.fromJson(Map<String, dynamic> json)
  {
    return AssociationSubjectOption(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}