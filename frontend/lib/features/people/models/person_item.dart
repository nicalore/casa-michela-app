import '../../../core/utils/json_parsing.dart';

import 'child_item.dart';
import 'membership_item.dart';
import 'parent_item.dart';
import 'person_face.dart';
import 'school_enrollment_item.dart';
import 'teacher_subject_item.dart';

class PersonItem implements PersonFace
{
  final String fiscalCode;

  @override
  final String firstName;

  @override
  final String lastName;

  final List<String> roles;

  @override
  final String? profileImageUrl;

  final DateTime createdAt;

  final String? gender;
  final String? email;
  final String? phoneNumber;
  final String? birthCity;
  final String? birthNation;
  final String? birthProvince;
  final String? residenceType;
  final String? address;
  final String? addressNumber;
  final String? province;
  final String? zipCode;
  final String? city;
  final DateTime? birthDate;

  final int? childrenCount;
  final bool? isActiveCollaborator;
  final String? enrollmentYear;
  final String? educationLevel;
  final String? schoolName;
  final String? schoolClass;
  final String? studyProgram;
  final bool? earlyExit;
  final String? collaborationType;
  final List<String> taughtSubjects;
  final String? courseType;
  final bool? isMedicalCertificateValid;

  final String? certificationType;
  final String? certificationOtherDetail;
  final bool? mandatoryPsychMeetingsAcknowledged;

  final String? paymentMethod;
  final String? paymentMethodOther;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? allergiesNotes;
  final String? medicationsNotes;

  final String? iban;
  final String? adminRole;
  final String? adminOtherRole;
  final String? schoolEducation;
  final String? universityEducation;
  final DateTime? medicalCertificateExpiration;

  // Timestamps of the three aggregates under optimistic concurrency control
  // (RNF-IAM-REL-07). They travel back to the server as expected_updated_at on
  // the corresponding edit endpoints, so their exact instant is significant:
  // unlike the display-only dates above, these are compared for equality by the
  // backend.
  // The two consents that stay a choice: special category data and the
  // newsletters. The three declarations signed on joining are not here, because
  // they are never withdrawn.
  final bool? specialCategoryDataConsent;
  final bool? newsletterConsent;

  final DateTime? memberUpdatedAt;
  final DateTime? studentUpdatedAt;
  final DateTime? teacherUpdatedAt;

  final List<MembershipItem>? memberships;
  final List<SchoolEnrollmentItem>? schoolEnrollments;
  final List<ParentItem>? parents;
  final List<ChildItem>? children;
  final List<TeacherSubjectItem>? teacherSubjects;

  // The services the teacher can take on, by name. Kept apart from the
  // disciplines: a service has no programmes, and whoever shows them calls the
  // two by different names.
  final List<String>? teacherServices;

  const PersonItem({
    required this.fiscalCode,
    required this.firstName,
    required this.lastName,
    required this.roles,
    required this.createdAt,
    this.profileImageUrl,
    this.gender,
    this.email,
    this.phoneNumber,
    this.birthCity,
    this.birthNation,
    this.birthProvince,
    this.residenceType,
    this.address,
    this.addressNumber,
    this.province,
    this.zipCode,
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
    this.certificationType,
    this.certificationOtherDetail,
    this.mandatoryPsychMeetingsAcknowledged,
    this.paymentMethod,
    this.paymentMethodOther,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.allergiesNotes,
    this.medicationsNotes,
    this.iban,
    this.adminRole,
    this.adminOtherRole,
    this.schoolEducation,
    this.universityEducation,
    this.medicalCertificateExpiration,
    this.specialCategoryDataConsent,
    this.newsletterConsent,
    this.memberUpdatedAt,
    this.studentUpdatedAt,
    this.teacherUpdatedAt,
    this.memberships,
    this.schoolEnrollments,
    this.parents,
    this.children,
    this.teacherSubjects,
    this.teacherServices,
  });

  factory PersonItem.fromJson(Map<String, dynamic> json)
  {
    return PersonItem(
      fiscalCode: json['fiscal_code'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      roles: parseStringList(json['roles']),
      createdAt: DateTime.parse(json['created_at']),
      profileImageUrl: json['profile_image_url'],
      gender: json['gender'],
      email: json['email'],
      phoneNumber: json['phone'],
      birthCity: json['birth_city'],
      birthNation: json['birth_nation'],
      birthProvince: json['birth_province'],
      residenceType: json['residence_type'],
      address: json['residence_address'],
      addressNumber: json['residence_street_number'],
      province: json['residence_province'],
      zipCode: json['postal_code'],
      // Two keys are accepted because the endpoints are not consistent on this
      // field: the prefixed one wins when both are present.
      city: json['residence_city'] ?? json['city'],
      birthDate: parseDate(json['birth_date']),
      childrenCount: json['children_count'],
      isActiveCollaborator: json['is_active_collaborator'],
      enrollmentYear: json['enrollment_year']?.toString(),
      educationLevel: json['education_level'],
      schoolName: json['school_name'],
      schoolClass: json['school_class'],
      studyProgram: json['study_program'],
      earlyExit: json['early_exit'],
      collaborationType: json['collaboration_type'],
      taughtSubjects: parseStringList(json['taught_subjects']),
      courseType: json['course_type'],
      isMedicalCertificateValid: json['is_medical_certificate_valid'],
      certificationType: json['certification_type'],
      certificationOtherDetail: json['certification_other_detail'],
      mandatoryPsychMeetingsAcknowledged: json['mandatory_psych_meetings_acknowledged'],
      paymentMethod: json['payment_method'],
      paymentMethodOther: json['payment_method_other'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      allergiesNotes: json['allergies_notes'],
      medicationsNotes: json['medications_notes'],
      iban: json['iban'],
      adminRole: json['admin_role'],
      adminOtherRole: json['admin_other_role'],
      schoolEducation: json['school_education'],
      universityEducation: json['university_education'],
      medicalCertificateExpiration: parseDate(json['medical_certificate_expiration']),
      specialCategoryDataConsent: json['special_category_data_consent'] as bool?,
      newsletterConsent: json['newsletter_consent'] as bool?,
      memberUpdatedAt: parseInstant(json['member_updated_at']),
      studentUpdatedAt: parseInstant(json['student_updated_at']),
      teacherUpdatedAt: parseInstant(json['teacher_updated_at']),
      memberships: parseOptionalList(json['memberships'], MembershipItem.fromJson),
      schoolEnrollments: parseOptionalList(json['school_enrollments'], SchoolEnrollmentItem.fromJson),
      parents: parseOptionalList(json['parents'], ParentItem.fromJson),
      children: parseOptionalList(json['children'], ChildItem.fromJson),
      teacherSubjects: parseOptionalList(json['teacher_subjects'], TeacherSubjectItem.fromJson),
      teacherServices: json['teacher_services'] == null
          ? null
          : parseStringList(json['teacher_services']),
    );
  }

  // The most recent membership, the only one that can be the current one: the
  // others are history either way.
  MembershipItem? get latestMembership
  {
    final List<MembershipItem> all = [...?memberships];

    if (all.isEmpty)
    {
      return null;
    }

    all.sort((a, b) => b.year.compareTo(a.year));

    return all.first;
  }

  // Expelled or resigned: their last membership was revoked, and with it
  // everything that depended on being part of the association.
  bool get isMembershipRevoked => latestMembership?.isRevoked ?? false;

  int? get age
  {
    final birth = birthDate;

    if (birth == null)
    {
      return null;
    }

    final today = DateTime.now();
    var years = today.year - birth.year;

    // The birthday has not occurred yet this year, so one year is taken back.
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day))
    {
      years--;
    }

    return years;
  }
}

// Who can still be picked: only those actively collaborating. It holds wherever
// somebody is named for something still to happen — the teacher offering an
// availability, the one preferred or not preferred on a lesson, the pupil booked
// for — because whoever has stopped will not be there that day, and offering
// them is offering a choice nobody can honour.
//
// Expelled or resigned counts as not collaborating: collaborating holds while
// the membership runs, and whoever is no longer part of the association does not
// spend the day inside it.
//
// It does not apply to what has already happened: the availability a former
// collaborator gave still carries their name, and writing it needs the whole
// list.
List<PersonItem> activeCollaborators(List<PersonItem> people)
{
  return people
      .where((person) =>
          (person.isActiveCollaborator ?? false) && !person.isMembershipRevoked)
      .toList();
}
