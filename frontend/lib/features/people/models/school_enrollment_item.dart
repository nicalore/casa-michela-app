class SchoolEnrollmentItem 
{
  final int    startYear;
  final int    grade;
  final int    schoolId;
  final String schoolName;

  // Solo visualizzazione: la scuola potrebbe non avere un codice.
  final String? schoolMechanographicCode;

  final String studyProgramName;
  final int    studyProgramId;
  final String educationLevel;

  const SchoolEnrollmentItem({
    required this.startYear,
    required this.grade,
    required this.schoolId,
    required this.schoolName,
    this.schoolMechanographicCode,
    required this.studyProgramName,
    required this.studyProgramId,
    required this.educationLevel,
  });

  factory SchoolEnrollmentItem.fromJson(Map<String, dynamic> json) 
  {
    return SchoolEnrollmentItem(
      startYear:                json['start_year'] ?? 0,
      grade:                    json['grade'] ?? 0,
      schoolId:                 json['school_id'] ?? 0,
      schoolName:               json['school_name'] ?? '',
      schoolMechanographicCode: json['school_mechanographic_code'],
      studyProgramName:         json['study_program_name'] ?? '',
      studyProgramId:           json['study_program_id'] ?? 0,
      educationLevel:           json['education_level'] ?? '',
    );
  }
}