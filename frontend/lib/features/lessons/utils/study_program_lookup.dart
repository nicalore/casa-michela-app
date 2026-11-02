import '../../association/models/study_program_item.dart';
import '../../people/models/person_item.dart';
import '../../people/models/school_enrollment_item.dart';

// Mirrors api/people.py _latest_enrollment (highest start_year wins) to match PersonItem's flat fields.
SchoolEnrollmentItem? _latestEnrollment(PersonItem student)
{
  final enrollments = student.schoolEnrollments;

  if (enrollments == null || enrollments.isEmpty)
  {
    return null;
  }

  return enrollments.reduce((a, b) => a.startYear >= b.startYear ? a : b);
}

int? currentStudyProgramId(PersonItem student) => _latestEnrollment(student)?.studyProgramId;

// Empty when the student has no enrollment or the program isn't loaded.
Set<int> allowedMinistrySubjectIds(PersonItem student, List<StudyProgramItem> studyPrograms)
{
  final programId = currentStudyProgramId(student);

  if (programId == null)
  {
    return {};
  }

  for (final program in studyPrograms)
  {
    if (program.id == programId)
    {
      return program.ministrySubjects.map((subject) => subject.id).toSet();
    }
  }

  return {};
}
