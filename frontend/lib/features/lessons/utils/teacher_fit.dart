import '../../people/models/person_item.dart';

// The teachers who could take the lesson come first, in the order given, and
// the rest follow in theirs: a nudge, not a divide, so nothing marks the seam.
// A teacher fits when a competence covers one of the disciplines for the
// pupil's programme; with no programme on record, the discipline alone will do.
List<PersonItem> teachersFitFirst(
  List<PersonItem> teachers, {
  required Set<int> disciplineIds,
  required int? studyProgramId,
})
{
  if (disciplineIds.isEmpty)
  {
    return teachers;
  }

  bool fits(PersonItem teacher)
  {
    for (final subject in teacher.teacherSubjects ?? const [])
    {
      if (!disciplineIds.contains(subject.subjectId))
      {
        continue;
      }

      if (studyProgramId == null ||
          subject.studyPrograms.any((programme) => programme.id == studyProgramId))
      {
        return true;
      }
    }

    return false;
  }

  return [
    ...teachers.where(fits),
    ...teachers.where((teacher) => !fits(teacher)),
  ];
}
