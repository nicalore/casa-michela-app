class PersonItem 
{
  final String       fiscalCode;
  final String       firstName;
  final String       lastName;
  final List<String> roles;
  final String?      profileImageUrl;
  final DateTime     createdAt;

  // Campi per i filtri avanzati
  final String?      city;
  final DateTime?    birthDate;
  final int?         childrenCount;
  final bool?        isActiveCollaborator;
  final String?      enrollmentYear;
  final String?      educationLevel;
  final String?      schoolName;
  final String?      schoolClass;
  final String?      studyProgram;
  final bool?        earlyExit;
  final String?      collaborationType;
  final List<String> taughtSubjects;
  final String?      courseType;
  final bool?        isMedicalCertificateValid;

  const PersonItem({
    required this.fiscalCode,
    required this.firstName,
    required this.lastName,
    required this.roles,
    required this.createdAt,
    this.profileImageUrl,
    this.city,
    this.birthDate,
    this.childrenCount,
    this.isActiveCollaborator,
    this.enrollmentYear,
    this.educationLevel,
    this.schoolName,
    this.schoolClass,
    this.studyProgram,
    this.earlyExit,
    this.collaborationType,
    this.taughtSubjects = const [],
    this.courseType,
    this.isMedicalCertificateValid,
  });

  factory PersonItem.fromJson(Map<String, dynamic> json) 
  {
    return PersonItem(
      fiscalCode:                json['fiscal_code'] ?? '',
      firstName:                 json['first_name'] ?? '',
      lastName:                  json['last_name'] ?? '',
      roles:                     (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt:                 DateTime.parse(json['created_at']),
      profileImageUrl:           json['profile_image_url'], 
      city:                      json['city'],
      birthDate:                 json['birth_date'] != null ? DateTime.parse(json['birth_date']) : null,
      childrenCount:             json['children_count'],
      isActiveCollaborator:      json['is_active_collaborator'],
      enrollmentYear:            json['enrollment_year']?.toString(),
      educationLevel:            json['education_level'],
      schoolName:                json['school_name'],
      schoolClass:               json['school_class'],
      studyProgram:              json['study_program'],
      earlyExit:                 json['early_exit'],
      collaborationType:         json['collaboration_type'],
      taughtSubjects:            (json['taught_subjects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      courseType:                json['course_type'],
      isMedicalCertificateValid: json['is_medical_certificate_valid'],
    );
  }

  int? get age 
  {
    if (birthDate == null) return null;
    
    final today = DateTime.now();
    int age = today.year - birthDate!.year;
    
    if (today.month < birthDate!.month || (today.month == birthDate!.month && today.day < birthDate!.day)) 
    {
      age--;
    }
    
    return age;
  }
}