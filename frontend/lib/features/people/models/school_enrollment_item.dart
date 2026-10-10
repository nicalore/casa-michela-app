class SchoolEnrollmentItem
{
  final int startYear;
  final int grade;

  // Null under homeschooling; the server then sends its label as the name.
  final int? schoolId;
  final bool homeschooling;
  final String schoolName;

  // Display only: the mechanographic code is optional on the school record.
  final String? schoolMechanographicCode;

  // Server-composed: sector and track joined by a middle dot, then " | " and the name.
  final String studyProgramName;
  final int studyProgramId;
  final String educationLevel;

  const SchoolEnrollmentItem({
    required this.startYear,
    required this.grade,
    required this.schoolId,
    this.homeschooling = false,
    required this.schoolName,
    this.schoolMechanographicCode,
    required this.studyProgramName,
    required this.studyProgramId,
    required this.educationLevel,
  });

  String get studyProgramNameOnly => studyProgramNameOnlyOf(studyProgramName);

  factory SchoolEnrollmentItem.fromJson(Map<String, dynamic> json)
  {
    return SchoolEnrollmentItem(
      startYear: json['start_year'] ?? 0,
      grade: json['grade'] ?? 0,
      schoolId: json['school_id'],
      homeschooling: json['homeschooling'] ?? false,
      schoolName: json['school_name'] ?? '',
      schoolMechanographicCode: json['school_mechanographic_code'],
      studyProgramName: json['study_program_name'] ?? '',
      studyProgramId: json['study_program_id'] ?? 0,
      educationLevel: json['education_level'] ?? '',
    );
  }
}

// A repeat is the same grade at the same education level as the previous year.
bool isRepeatingYear(SchoolEnrollmentItem current, List<SchoolEnrollmentItem> all)
{
  final previous =
      all.where((item) => item.startYear == current.startYear - 1).firstOrNull;

  if (previous == null)
  {
    return false;
  }

  return current.grade == previous.grade &&
      current.educationLevel == previous.educationLevel;
}

// What follows the '|', or the whole name when there is none.
String studyProgramNameOnlyOf(String displayName)
{
  final bar = displayName.lastIndexOf('|');

  return bar < 0 ? displayName.trim() : displayName.substring(bar + 1).trim();
}
