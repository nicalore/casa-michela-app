class MinistrySubjectItem 
{
  final int id;
  final String name;
  final String level;
  final String area;
  final String? description;
  final DateTime createdAt;
  final List<AssociationSubjectOption> associationSubjects;

  const MinistrySubjectItem({
    required this.id,
    required this.name,
    required this.level,
    required this.area,
    this.description,
    required this.createdAt,
    this.associationSubjects = const [],
  });
}

class AssociationSubjectOption 
{
  final int id;
  final String name;

  const AssociationSubjectOption({
    required this.id,
    required this.name,
  });
}