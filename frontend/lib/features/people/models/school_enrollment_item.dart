class SchoolEnrollmentItem 
{
  final int    startYear;
  final int    grade;
  final String schoolName;
  final String schoolMechanographicCode;
  final String studyProgramName;
  final int    studyProgramId;
  final String educationLevel;

  const SchoolEnrollmentItem({
    required this.startYear,
    required this.grade,
    required this.schoolName,
    required this.schoolMechanographicCode,
    required this.studyProgramName,
    required this.studyProgramId,
    required this.educationLevel,
  });

  factory SchoolEnrollmentItem.fromJson(Map<String, dynamic> json) 
  {
    return SchoolEnrollmentItem(
      startYear:                json['start_year'] ?? 0,
      grade:                    json['grade'] ?? 0,
      schoolName:               json['school_name'] ?? '',
      schoolMechanographicCode: json['school_mechanographic_code'] ?? '',
      studyProgramName:         json['study_program_name'] ?? '',
      studyProgramId:           json['study_program_id'] ?? 0,
      educationLevel:           json['education_level'] ?? '',
    );
  }
}