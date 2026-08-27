import 'ministry_subject_item.dart';

class StudyProgramItem
{
  final int id;
  final String name;

  // Null where none exists: primary and middle school have no branches.
  final String? sector;

  final String description;
  final String level;
  final int minYear;
  final int maxYear;
  final DateTime createdAt;
  final List<MinistrySubjectOption> ministrySubjects;

  const StudyProgramItem({
    required this.id,
    required this.name,
    required this.description,
    this.sector,
    required this.level,
    required this.minYear,
    required this.maxYear,
    required this.createdAt,
    this.ministrySubjects = const [],
  });

  String get fullName => sector == null ? name : '$sector | $name';
}

class MinistrySubjectOption
{
  final int id;
  final String name;
  final List<AssociationSubjectOption> associationSubjects;

  const MinistrySubjectOption({
    required this.id,
    required this.name,
    this.associationSubjects = const [],
  });
}