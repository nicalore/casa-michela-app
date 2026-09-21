import 'package:flutter/material.dart';

import '../edit/person_edit_form.dart' show kBornInItalyNation;

class PeopleFilterState
{
  // Range filters count as active only once moved away from these bounds.
  static const RangeValues defaultAgeRange = RangeValues(5, 99);
  static const RangeValues defaultTaughtSubjectsCount = RangeValues(1, 15);

  // Sentinel chip value for "no certification"; not null, since chips are a set.
  static const String noCertification = 'NONE';

  // Birthplace chips: Italy is one nation, abroad is every other.
  static const String bornInItaly = 'ITALY';
  static const String bornAbroad = 'ABROAD';

  final String? selectedCategory;
  final List<String> selectedRoles;
  final RangeValues? ageRange;
  final String? birthPlace;

  // Named only when abroad: they narrow it to these nations.
  final List<String> birthNations;
  final String? birthCity;
  final String? city;
  final String? childrenCount;
  final bool? isActiveCollaborator;
  final String? enrollmentYear;
  final String? educationLevel;
  final String? schoolName;
  final String? schoolClass;
  final String? studyProgram;
  final bool? earlyExit;
  final String? collaborationType;
  final List<String> taughtSubjects;
  final RangeValues? taughtSubjectsCount;
  final String? courseType;
  final bool? isMedicalCertificateValid;

  final List<String> certifications;

  const PeopleFilterState({
    this.selectedCategory,
    this.selectedRoles = const [],
    this.ageRange,
    this.birthPlace,
    this.birthNations = const [],
    this.birthCity,
    this.city,
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
    this.taughtSubjectsCount,
    this.courseType,
    this.isMedicalCertificateValid,
    this.certifications = const [],
  });

  // Each field has a clear flag: null means "leave unchanged", not "reset".
  PeopleFilterState copyWith({
    String? selectedCategory,
    List<String>? selectedRoles,
    RangeValues? ageRange,
    String? birthPlace,
    List<String>? birthNations,
    String? birthCity,
    String? city,
    String? childrenCount,
    bool? isActiveCollaborator,
    String? enrollmentYear,
    String? educationLevel,
    String? schoolName,
    String? schoolClass,
    String? studyProgram,
    bool? earlyExit,
    String? collaborationType,
    List<String>? taughtSubjects,
    RangeValues? taughtSubjectsCount,
    String? courseType,
    bool? isMedicalCertificateValid,
    List<String>? certifications,
    bool clearCategory = false,
    bool clearRoles = false,
    bool clearAgeRange = false,
    bool clearBirthPlace = false,
    bool clearBirthNations = false,
    bool clearBirthCity = false,
    bool clearCity = false,
    bool clearChildrenCount = false,
    bool clearCollaborator = false,
    bool clearEnrollment = false,
    bool clearEducationLevel = false,
    bool clearSchoolName = false,
    bool clearSchoolClass = false,
    bool clearStudyProgram = false,
    bool clearEarlyExit = false,
    bool clearCollaborationType = false,
    bool clearTaughtSubjects = false,
    bool clearTaughtSubjectsCount = false,
    bool clearCourseType = false,
    bool clearMedicalCert = false,
    bool clearCertifications = false,
  })
  {
    return PeopleFilterState(
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedRoles: clearRoles ? [] : (selectedRoles ?? this.selectedRoles),
      ageRange: clearAgeRange ? null : (ageRange ?? this.ageRange),
      birthPlace: clearBirthPlace ? null : (birthPlace ?? this.birthPlace),
      birthNations: clearBirthNations ? [] : (birthNations ?? this.birthNations),
      birthCity: clearBirthCity ? null : (birthCity ?? this.birthCity),
      city: clearCity ? null : (city ?? this.city),
      childrenCount: clearChildrenCount ? null : (childrenCount ?? this.childrenCount),
      isActiveCollaborator: clearCollaborator ? null : (isActiveCollaborator ?? this.isActiveCollaborator),
      enrollmentYear: clearEnrollment ? null : (enrollmentYear ?? this.enrollmentYear),
      educationLevel: clearEducationLevel ? null : (educationLevel ?? this.educationLevel),
      schoolName: clearSchoolName ? null : (schoolName ?? this.schoolName),
      schoolClass: clearSchoolClass ? null : (schoolClass ?? this.schoolClass),
      studyProgram: clearStudyProgram ? null : (studyProgram ?? this.studyProgram),
      earlyExit: clearEarlyExit ? null : (earlyExit ?? this.earlyExit),
      collaborationType: clearCollaborationType ? null : (collaborationType ?? this.collaborationType),
      taughtSubjects: clearTaughtSubjects ? [] : (taughtSubjects ?? this.taughtSubjects),
      taughtSubjectsCount: clearTaughtSubjectsCount ? null : (taughtSubjectsCount ?? this.taughtSubjectsCount),
      courseType: clearCourseType ? null : (courseType ?? this.courseType),
      isMedicalCertificateValid: clearMedicalCert ? null : (isMedicalCertificateValid ?? this.isMedicalCertificateValid),
      certifications: clearCertifications ? [] : (certifications ?? this.certifications),
    );
  }

  // A certification filter narrows to students; holding none matches only
  // [noCertification].
  bool matchesCertification({
    required List<String> certificationTypes,
    required bool isStudent,
  })
  {
    if (certifications.isEmpty)
    {
      return true;
    }

    if (!isStudent)
    {
      return false;
    }

    if (certificationTypes.isEmpty)
    {
      return certifications.contains(noCertification);
    }

    return certificationTypes.any(certifications.contains);
  }

  bool matchesBirthNation(String? nation)
  {
    if (birthPlace == null)
    {
      return true;
    }

    final String? held = nation?.toLowerCase();
    final bool italian = held == kBornInItalyNation.toLowerCase();

    if (birthPlace == bornInItaly)
    {
      return italian;
    }

    if (birthNations.isEmpty)
    {
      return !italian;
    }

    return birthNations.any((wanted) => wanted.toLowerCase() == held);
  }

  bool get hasActiveFilters => activeFiltersCount > 0;

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  int get activeFiltersCount
  {
    final singleValueFilters = <bool>[
      selectedCategory != null,
      ageRange != null && ageRange != defaultAgeRange,
      birthPlace != null,
      _hasText(birthCity),
      _hasText(city),
      childrenCount != null,
      isActiveCollaborator != null,
      enrollmentYear != null,
      educationLevel != null,
      _hasText(schoolName),
      schoolClass != null,
      _hasText(studyProgram),
      earlyExit != null,
      collaborationType != null,
      taughtSubjectsCount != null && taughtSubjectsCount != defaultTaughtSubjectsCount,
      _hasText(courseType),
      isMedicalCertificateValid != null,
    ];

    // Multi value filters count one unit per selected entry.
    return singleValueFilters.where((isActive) => isActive).length +
        selectedRoles.length +
        birthNations.length +
        taughtSubjects.length +
        certifications.length;
  }
}