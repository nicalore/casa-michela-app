import '../../association/models/study_program_item.dart';
import '../../people/models/person_item.dart';
import '../../people/models/school_enrollment_item.dart';

// Mirrors the backend's tie-break (api/people.py _latest_enrollment):
// highest start_year wins, so results match PersonItem's flat fields.
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

// "Scuola - percorso di studi"; falls back to PersonItem's flat fields when
// the enrollment list isn't populated, null with no school data at all.
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
