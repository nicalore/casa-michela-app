import '../../association/models/study_program_item.dart';
import '../../people/models/person_item.dart';
import '../../people/models/school_enrollment_item.dart';

// Mirrors the backend's own tie-break for a student's "current" school
// enrollment (api/people.py's _latest_enrollment): the one with the highest
// start_year, so the study program resolved here always matches the one
// shown elsewhere for the same student (school_name/study_program on
// PersonItem).
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

// The ministry subject ids taught under the student's current study program,
// used to narrow the booking form down to subjects actually relevant to that
// student instead of the association's whole catalog. Empty when the
// student has no enrollment or the matching study program isn't loaded.
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

// "Scuola - percorso di studi" for the student's current enrollment, shown
// instead of the fiscal code in student pickers. Falls back to the flat,
// precomputed fields on PersonItem (same data, reached a different way) when
// the enrollment list itself isn't populated, and to null when the student
// has no school data at all.
String? currentSchoolAndProgramLabel(PersonItem student)
{
  final latest = _latestEnrollment(student);

  if (latest != null)
  {
    return '${latest.schoolName} - ${latest.studyProgramName}';
  }

  final schoolName = student.schoolName;
  final studyProgram = student.studyProgram;

  if (schoolName != null && schoolName.isNotEmpty && studyProgram != null && studyProgram.isNotEmpty)
  {
    return '$schoolName - $studyProgram';
  }

  return null;
}
