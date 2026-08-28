import 'ministry_subject_item.dart';
import 'subject_taxonomy.dart';

class StudyProgramItem
{
  final int id;
  final String name;

  // Null where none exists: primary and middle school have no branches.
  final String? sector;

  final String description;
  final String level;

  // Null where none exists: only high school is split into cycles.
  final String? highSchoolTrack;

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
    this.highSchoolTrack,
    required this.minYear,
    required this.maxYear,
    required this.createdAt,
    this.ministrySubjects = const [],
  });

  // The line shown above the name: sector and cycle, whichever exist. Mirrors
  // StudyProgram.scope_line on the backend.
  String? get scopeLine
  {
    final HighSchoolTrack? cycle = highSchoolTrackOf(highSchoolTrack);

    final List<String> parts = [
      ?sector,
      if (cycle != null) cycle.shortLabel,
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }

  // Must stay identical to display_name on the backend: it is the key the
  // enrolment form matches a school's programmes against the catalogue with.
  String get fullName => scopeLine == null ? name : '${scopeLine!} | $name';

  // Biennio/triennio/quadriennale where there is one; the range elsewhere.
  String get yearsLabel => highSchoolTrackOf(highSchoolTrack)?.label ?? '$minYear - $maxYear';

  String get yearsFieldLabel => highSchoolTrack == null ? 'Anni di corso' : 'Articolazione';
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