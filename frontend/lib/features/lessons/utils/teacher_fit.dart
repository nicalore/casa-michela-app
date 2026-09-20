import '../../people/models/person_item.dart';

// Fitting teachers first, then the rest, each in the order given: a nudge, not a divide.
// Fit: a competence covers a discipline for the pupil's programme, or any discipline with no programme.
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
