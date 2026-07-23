import 'ministry_subject_item.dart';

class StudyProgramItem
{
  final int id;
  final String name;
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
    required this.level,
    required this.minYear,
    required this.maxYear,
    required this.createdAt,
    this.ministrySubjects = const [],
  });
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