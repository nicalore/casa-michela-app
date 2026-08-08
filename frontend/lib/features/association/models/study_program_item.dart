import 'ministry_subject_item.dart';

class StudyProgramItem
{
  final int id;
  final String name;

  // The sector the programme belongs to. Null where none exists, since primary
  // and middle school have no branches. It used to live inside the name, after a
  // vertical bar, and grouping the programmes meant reading the punctuation of
  // whoever had written them.
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

  // The full name, sector included. Needed wherever a programme is named
  // outside its own context — a school year, a competence — and the name alone
  // does not identify it.
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