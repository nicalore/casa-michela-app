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

  // What the discipline is, where somebody wrote it. It sits under the name in
  // the lists it is picked from: the name says what it is called, the
  // description says what is done in it.
  final String? description;

  const AssociationSubjectOption({
    required this.id,
    required this.name,
    this.description,
  });

  // One parser for every place the server names a discipline. There used to be
  // six hand-written copies, and the description would have reached five.
  factory AssociationSubjectOption.fromJson(Map<String, dynamic> json)
  {
    return AssociationSubjectOption(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}