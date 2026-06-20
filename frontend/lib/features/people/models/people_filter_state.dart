import 'package:flutter/material.dart';

class PeopleFilterState 
{
  final String?        selectedCategory;
  final List<String>   selectedRoles;
  final RangeValues?   ageRange;
  final String?        city;
  final String?        childrenCount;
  final bool?          isActiveCollaborator;
  final String?        enrollmentYear;
  final String?        educationLevel;
  final String?        schoolName;
  final String?        schoolClass;
  final String?        studyProgram;
  final bool?          earlyExit;
  final String?        collaborationType;
  final List<String>   taughtSubjects;
  final RangeValues?   taughtSubjectsCount;
  final String?        courseType;
  final bool?          isMedicalCertificateValid;

  const PeopleFilterState({
    this.selectedCategory,
    this.selectedRoles             = const [],
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
    this.taughtSubjects            = const [],
    this.taughtSubjectsCount,
    this.courseType,
    this.isMedicalCertificateValid,
  });

  PeopleFilterState copyWith({
    String?        selectedCategory,
    List<String>?  selectedRoles,
    RangeValues?   ageRange,
    String?        city,
    String?        childrenCount,
    bool?          isActiveCollaborator,
    String?        enrollmentYear,
    String?        educationLevel,
    String?        schoolName,
    String?        schoolClass,
    String?        studyProgram,
    bool?          earlyExit,
    String?        collaborationType,
    List<String>?  taughtSubjects,
    RangeValues?   taughtSubjectsCount,
    String?        courseType,
    bool?          isMedicalCertificateValid,
    bool           clearCategory            = false,
    bool           clearRoles               = false,
    bool           clearAgeRange            = false,
    bool           clearCity                = false,
    bool           clearChildrenCount       = false,
    bool           clearCollaborator        = false,
    bool           clearEnrollment          = false,
    bool           clearEducationLevel      = false,
    bool           clearSchoolName          = false,
    bool           clearSchoolClass         = false,
    bool           clearStudyProgram        = false,
    bool           clearEarlyExit           = false,
    bool           clearCollaborationType   = false,
    bool           clearTaughtSubjects      = false,
    bool           clearTaughtSubjectsCount = false,
    bool           clearCourseType          = false,
    bool           clearMedicalCert         = false,
  }) 
  {
    return PeopleFilterState(
      selectedCategory:          clearCategory            ? null : (selectedCategory          ?? this.selectedCategory),
      selectedRoles:             clearRoles               ? []   : (selectedRoles             ?? this.selectedRoles),
      ageRange:                  clearAgeRange            ? null : (ageRange                  ?? this.ageRange),
      city:                      clearCity                ? null : (city                      ?? this.city),
      childrenCount:             clearChildrenCount       ? null : (childrenCount             ?? this.childrenCount),
      isActiveCollaborator:      clearCollaborator        ? null : (isActiveCollaborator      ?? this.isActiveCollaborator),
      enrollmentYear:            clearEnrollment          ? null : (enrollmentYear            ?? this.enrollmentYear),
      educationLevel:            clearEducationLevel      ? null : (educationLevel            ?? this.educationLevel),
      schoolName:                clearSchoolName          ? null : (schoolName                ?? this.schoolName),
      schoolClass:               clearSchoolClass         ? null : (schoolClass               ?? this.schoolClass),
      studyProgram:              clearStudyProgram        ? null : (studyProgram              ?? this.studyProgram),
      earlyExit:                 clearEarlyExit           ? null : (earlyExit                 ?? this.earlyExit),
      collaborationType:         clearCollaborationType   ? null : (collaborationType         ?? this.collaborationType),
      taughtSubjects:            clearTaughtSubjects      ? []   : (taughtSubjects            ?? this.taughtSubjects),
      taughtSubjectsCount:       clearTaughtSubjectsCount ? null : (taughtSubjectsCount       ?? this.taughtSubjectsCount),
      courseType:                clearCourseType          ? null : (courseType                ?? this.courseType),
      isMedicalCertificateValid: clearMedicalCert         ? null : (isMedicalCertificateValid ?? this.isMedicalCertificateValid),
    );
  }

  bool get hasActiveFilters 
  {
    return activeFiltersCount > 0;
  }

  int get activeFiltersCount 
  {
    int count = 0;

    if (selectedCategory != null) count++;
    if (selectedRoles.isNotEmpty) count += selectedRoles.length;
    if (ageRange != null) count++;
    if (city != null && city!.trim().isNotEmpty) count++;
    if (childrenCount != null) count++;
    if (isActiveCollaborator != null) count++;
    if (enrollmentYear != null) count++;
    if (educationLevel != null) count++;
    if (schoolName != null && schoolName!.trim().isNotEmpty) count++;
    if (schoolClass != null) count++;
    if (studyProgram != null && studyProgram!.trim().isNotEmpty) count++;
    if (earlyExit != null) count++;
    if (collaborationType != null) count++;
    if (taughtSubjects.isNotEmpty) count += taughtSubjects.length;
    if (taughtSubjectsCount != null) count++;
    if (courseType != null && courseType!.trim().isNotEmpty) count++;
    if (isMedicalCertificateValid != null) count++;

    return count;
  }
}