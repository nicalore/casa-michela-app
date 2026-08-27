import 'package:flutter/material.dart';

class PeopleFilterState
{
  // A range filter counts as active only when moved away from these bounds, so
  // the dialog must initialise its sliders from here.
  static const RangeValues defaultAgeRange = RangeValues(5, 99);
  static const RangeValues defaultTaughtSubjectsCount = RangeValues(1, 15);

  final String? selectedCategory;
  final List<String> selectedRoles;
  final RangeValues? ageRange;
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

  const PeopleFilterState({
    this.selectedCategory,
    this.selectedRoles = const [],
    this.ageRange,
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
  });

  // Each field has a matching clear flag, because passing null cannot express
  // "reset this one": null already means "leave unchanged".
  PeopleFilterState copyWith({
    String? selectedCategory,
    List<String>? selectedRoles,
    RangeValues? ageRange,
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
    bool clearCategory = false,
    bool clearRoles = false,
    bool clearAgeRange = false,
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
  })
  {
    return PeopleFilterState(
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedRoles: clearRoles ? [] : (selectedRoles ?? this.selectedRoles),
      ageRange: clearAgeRange ? null : (ageRange ?? this.ageRange),
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
    );
  }

  bool get hasActiveFilters => activeFiltersCount > 0;

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  int get activeFiltersCount
  {
    final singleValueFilters = <bool>[
      selectedCategory != null,
      ageRange != null && ageRange != defaultAgeRange,
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

    // The two multi value filters contribute one unit per selected entry, so a
    // person filtered on three roles shows three active filters.
    return singleValueFilters.where((isActive) => isActive).length +
        selectedRoles.length +
        taughtSubjects.length;
  }
}