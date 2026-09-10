import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/course_item.dart';
import '../../association/models/school_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../models/early_exit_schedule_item.dart';
import '../models/parental_relationship_draft.dart';
import '../models/membership_item.dart';
import '../models/person_item.dart';
import '../models/school_enrollment_item.dart';
import '../models/teacher_subject_item.dart';
import '../widgets/person_row_models.dart';
import 'homework_tariffs.dart';

class PersonRoleOption
{
  final String id;
  final String label;
  final String description;

  const PersonRoleOption({
    required this.id,
    required this.label,
    required this.description,
  });
}

const Map<String, String> kCollaborationTypes = {
  'Volontario': 'VOLUNTEER',
  'Retribuito': 'PAID',
  'FSL (Ex PCTO)': 'PCTO',
  'Non pagato': 'UNPAID',
};

const Map<String, String> kAdminRoles = {
  'Presidente': 'PRESIDENT',
  'Vicepresidente': 'VICE_PRESIDENT',
  'Tesoriere': 'TREASURER',
  'Altro': 'OTHER',
};

const Map<String, String> kPaymentMethods = {
  'Contanti': 'CASH',
  'Bonifico bancario': 'BANK_TRANSFER',
  'Altro': 'OTHER',
};

const Map<String, String> kCertificationTypes = {
  'DSA': 'DSA',
  'BES': 'BES',
  'ADHD': 'ADHD',
  'Altro': 'OTHER',
};

// The server is inconsistent: some fields arrive as labels, others as codes.
String? labelForServerValue(Map<String, String> table, String? value)
{
  if (value == null)
  {
    return null;
  }

  if (table.containsKey(value))
  {
    return value;
  }

  for (final entry in table.entries)
  {
    if (entry.value == value)
    {
      return entry.key;
    }
  }

  return null;
}

const List<PersonRoleOption> kPersonRoleOptions = [
  PersonRoleOption(
    id: 'DOCENTE',
    label: 'Docente',
    description: 'Svolge attività di supporto didattico e ripetizioni.',
  ),
  PersonRoleOption(
    id: 'STUDENTE',
    label: 'Studente',
    description: 'Riceve supporto didattico e ripetizioni.',
  ),
  PersonRoleOption(
    id: 'AMMINISTRATORE',
    label: 'Amministratore',
    description:
        'Gestisce le attività amministrative, organizzative e operative dell\'Associazione.',
  ),
  PersonRoleOption(
    id: 'PSICOLOGO',
    label: 'Psicologo',
    description: 'Svolge colloqui psicologici e supporta gli studenti.',
  ),
  PersonRoleOption(
    id: 'CORSISTA',
    label: 'Corsista',
    description:
        'Partecipa ai corsi organizzati dall\'Associazione, come yoga o pilates.',
  ),
  PersonRoleOption(
    id: 'GENITORE',
    label: 'Genitore / Tutore',
    description: 'È il responsabile legale di uno o più iscritti all\'Associazione.',
  ),
];

const Map<String, int> kGradeNumbers = {
  'I': 1,
  'II': 2,
  'III': 3,
  'IV': 4,
  'V': 5,
  'VI': 6,
  'VII': 7,
  'VIII': 8,
};

// Duplicated in school_enrollment_edit_row.dart: the year turns over on 1 September.
int currentSchoolYearStart([DateTime? today])
{
  final DateTime now = today ?? DateTime.now();

  return now.month < 9 ? now.year - 1 : now.year;
}

class ResidenceOffer
{
  final String label;

  final String streetTypeValue;
  final String addressValue;
  final String streetNumberValue;
  final String cityValue;
  final String provinceCode;
  final String postalCodeValue;

  const ResidenceOffer({
    this.label = '',
    required this.streetTypeValue,
    required this.addressValue,
    required this.streetNumberValue,
    required this.cityValue,
    required this.provinceCode,
    required this.postalCodeValue,
  });

  bool get isEmpty =>
      streetTypeValue.trim().isEmpty &&
      addressValue.trim().isEmpty &&
      streetNumberValue.trim().isEmpty &&
      cityValue.trim().isEmpty &&
      provinceCode.trim().isEmpty &&
      postalCodeValue.trim().isEmpty;
}

class PersonEditForm
{
  final PersonItem? person;

  bool get isCreation => person == null;

  // Once on file the consent is settled for good, so the wizard stops asking.
  bool get asksSpecialCategoryDataConsent =>
      !(person?.specialCategoryDataConsent ?? false);

  // No longer enrolled: only personal and contact details show, and nothing else may be required or the form is unsaveable.
  bool get isPersonalDataOnly
  {
    final PersonItem? person = this.person;

    return person != null && !person.isEnrolled;
  }

  // Only a paid collaboration has an hourly rate; the wizard neither asks nor sends one otherwise.
  bool get isPaidCollaboration =>
      kCollaborationTypes[collaborationTypeValue] == 'PAID';

  // Payment is asked only of someone actually enrolled, and what is not asked cannot be required.
  bool get asksPayment => !isOnlyParentNotMember && !isPersonalDataOnly;

  // Enrolled by the typed rows: newest one, not revoked, still inside its renewal window — the register's own rule.
  bool get isEnrolledByRows
  {
    MembershipRowData? latest;
    int? latestYear;

    for (final row in membershipRows)
    {
      final int? year = int.tryParse(row.yearCtrl.text.trim());

      if (year != null && (latestYear == null || year > latestYear))
      {
        latestYear = year;
        latest = row;
      }
    }

    if (latest == null ||
        latestYear == null ||
        latest.revocation != MembershipItem.revocationNone)
    {
      return false;
    }

    // The wizard writes 31 December and the standard window on every row.
    return MembershipItem.isWithinRenewalWindow(
      DateTime(latestYear, 12, 31),
      MembershipItem.defaultRenewalPeriodDays,
    );
  }

  // Only a pupil has a rate; with no level to read, what is on file stands rather than being wiped.
  String? get homeworkTariffCode
  {
    if (!activeRoles.contains('STUDENTE'))
    {
      return null;
    }

    return homeworkTariffCodeOf(
          level: currentSchoolLevel,
          choice: homeworkTariffValue,
        ) ??
        person?.homeworkTariff;
  }

  // Level the Aiuto Compiti rate hangs on: the year under way when recorded, else the most recent earlier one.
  String? get currentSchoolLevel
  {
    final int current = currentSchoolYearStart();

    String? fallbackLevel;
    int? fallbackYear;

    for (final row in schoolRows)
    {
      final int? year = int.tryParse(row.yearCtrl.text.trim());
      final String? level = row.program?.level;

      if (year == null || level == null)
      {
        continue;
      }

      if (year == current)
      {
        return level;
      }

      if (year < current && (fallbackYear == null || year > fallbackYear))
      {
        fallbackYear = year;
        fallbackLevel = level;
      }
    }

    return fallbackLevel;
  }

  // 0 = involved in the activities, 1 = member only, -1 = unanswered.
  int involvementType = -1;

  // Whether the parent joins as well; null until answered.
  bool? parentIsMember;

  bool wasMember = false;

  final Set<String> selectedRoles = {};

  Uint8List? fotoProfilo;

  final TextEditingController firstNameCtrl = TextEditingController();
  final TextEditingController lastNameCtrl = TextEditingController();
  String? genderValue;
  final TextEditingController cfCtrl = TextEditingController();
  final TextEditingController birthDateCtrl = TextEditingController();
  final TextEditingController birthCityCtrl = TextEditingController();
  final TextEditingController birthProvinceCtrl = TextEditingController();
  final TextEditingController birthNationCtrl = TextEditingController();

  final TextEditingController streetTypeCtrl = TextEditingController();
  final TextEditingController streetNameCtrl = TextEditingController();
  final TextEditingController streetNumberCtrl = TextEditingController();
  final TextEditingController residenceCityCtrl = TextEditingController();
  final TextEditingController residenceProvinceCtrl = TextEditingController();
  final TextEditingController postalCodeCtrl = TextEditingController();

  bool copiesResidence = false;
  ResidenceOffer? _residenceBeforeCopy;

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  final List<MembershipRowData> membershipRows = [];
  final List<SchoolEnrollmentRowData> schoolRows = [];

  final TextEditingController certificateExpirationCtrl = TextEditingController();
  final TextEditingController ibanCtrl = TextEditingController();
  final TextEditingController grossCompensationCtrl = TextEditingController();
  String? collaborationTypeValue;
  String? adminRoleValue;
  final TextEditingController otherAdminRoleCtrl = TextEditingController();
  final TextEditingController studiScolasticiCtrl = TextEditingController();
  final TextEditingController studiUniversitariCtrl = TextEditingController();

  // True hides university studies instead of clearing them.
  bool isHighSchoolStudent = false;

  // Null for non-admin viewers and on creation; omitted from the payload.
  double? teacherRating;

  bool uscitaAnticipata = false;

  // False means the authorisation lasts as long as the membership, with both dates left empty.
  bool uscitaAnticipataPeriodoLimitato = false;
  final TextEditingController uscitaAnticipataDalCtrl = TextEditingController();
  final TextEditingController uscitaAnticipataAlCtrl = TextEditingController();

  // The paper form has room for two lines, and so has the register.
  static const int maxEarlyExitRows = 2;
  final List<EarlyExitRowData> earlyExitRows = [];

  String? paymentMethodValue;

  // Shown to whoever fills the form in, and deliberately not sent anywhere.
  String? homeworkTariffValue;
  final TextEditingController otherPaymentMethodCtrl = TextEditingController();

  // Certification labels; empty means none held.
  final Set<String> certificationValues = {};
  final TextEditingController otherCertificationCtrl = TextEditingController();
  // Required for a DSA certification; the server rejects it without this.
  final TextEditingController dsaCertificationCtrl = TextEditingController();
  bool? mandatoryPsychMeetingsAcknowledgedExisting;

  final TextEditingController emergencyContactNameCtrl = TextEditingController();
  final TextEditingController emergencyContactPhoneCtrl = TextEditingController();
  final TextEditingController allergiesCtrl = TextEditingController();
  final TextEditingController medicationsCtrl = TextEditingController();

  bool statuteAcknowledged = false;
  bool regulationAcknowledged = false;
  bool videoSurveillanceAcknowledged = false;
  bool specialCategoryDataConsentValue = false;
  bool newsletterConsentValue = false;

  bool hasPsychologicalSupport = false;
  final TextEditingController psychologicalSupportStartDateCtrl = TextEditingController();
  bool psychMeetingsAcknowledgedValue = false;

  String? courseTypeValue;

  // People created inside this dialog; they must reach the server first.
  final List<Map<String, dynamic>> pendingPeople = [];

  final Map<String, ParentalRelationshipDraft> selectedParents = {};
  final Map<String, ParentalRelationshipDraft> selectedMinors = {};

  final Map<int, bool> subjectToggles = {};
  final Map<int, Set<int>> selectedProgramsForSubject = {};

  final Set<String> selectedServices = {};

  List<SchoolItem> allSchools = [];
  List<StudyProgramItem> allPrograms = [];
  List<AssociationSubjectItem> allSubjects = [];
  List<ServiceItem> allServices = [];
  List<CourseItem> allCourses = [];
  List<PersonItem> allAdults = [];
  List<PersonItem> allMinors = [];

  final Map<int, List<StudyProgramItem>> programsBySubjectId = {};

  PersonEditForm._(this.person);

  factory PersonEditForm.fromPerson(PersonItem person)
  {
    final PersonEditForm form = PersonEditForm._(person);
    form._loadExisting();

    return form;
  }

  factory PersonEditForm.blank({
    Set<String> roles = const {},
    int involvement = -1,
  })
  {
    final PersonEditForm form = PersonEditForm._(null);
    final DateTime now = DateTime.now();

    form.involvementType = involvement;
    form.selectedRoles.addAll(roles);

    form.membershipRows.add(MembershipRowData.empty(
      year: now.year.toString(),
      date: DateFormat('dd/MM').format(now),
    ));

    return form;
  }

  void _loadExisting()
  {
    final PersonItem person = this.person!;

    firstNameCtrl.text = person.firstName;
    lastNameCtrl.text = person.lastName;
    genderValue = person.gender;
    cfCtrl.text = person.fiscalCode;

    if (person.birthDate != null)
    {
      birthDateCtrl.text = DateFormat('dd/MM/yyyy').format(person.birthDate!);
    }

    birthCityCtrl.text = person.birthCity ?? '';
    birthProvinceCtrl.text = person.birthProvince ?? '';
    birthNationCtrl.text = person.birthNation ?? '';

    streetTypeCtrl.text = person.residenceType ?? '';
    streetNameCtrl.text = person.address ?? '';
    streetNumberCtrl.text = person.addressNumber ?? '';
    residenceCityCtrl.text = person.city ?? '';
    residenceProvinceCtrl.text = person.province ?? '';
    postalCodeCtrl.text = person.zipCode ?? '';

    emailCtrl.text = person.email ?? '';
    phoneCtrl.text = formatPhoneNumber(person.phoneNumber);

    final Set<String> roles = person.roles.map((role) => role.toUpperCase()).toSet();
    selectedRoles
      ..clear()
      ..addAll(roles);

    wasMember = roles.contains('ASSOCIATO') || roles.any((role) => role != 'GENITORE');
    involvementType = roles.length == 1 && roles.contains('ASSOCIATO') ? 1 : 0;
    parentIsMember = roles.contains('GENITORE') && roles.contains('ASSOCIATO');

    // MembershipItem carries no id; the server rebuilds the whole list.
    for (final membership in person.memberships ?? const [])
    {
      membershipRows.add(MembershipRowData.empty(
        year: membership.year.toString(),
        date: DateFormat('dd/MM').format(membership.startDate),
        revocation: membership.revocation,
      ));
    }

    if (membershipRows.isEmpty)
    {
      final DateTime now = DateTime.now();
      membershipRows.add(MembershipRowData.empty(
        year: now.year.toString(),
        date: DateFormat('dd/MM').format(now),
      ));
    }

    certificateExpirationCtrl.text = person.medicalCertificateExpiration != null
        ? DateFormat('dd/MM/yyyy').format(person.medicalCertificateExpiration!)
        : '';
    courseTypeValue = person.courseType;
    ibanCtrl.text = person.iban ?? '';
    grossCompensationCtrl.text = formatAmountText(person.grossCompensation) ?? '';

    collaborationTypeValue =
        labelForServerValue(kCollaborationTypes, person.collaborationType);

    final String? adminRole = person.adminRole;

    if (adminRole != null)
    {
      adminRoleValue = labelForServerValue(kAdminRoles, adminRole) ?? 'Altro';

      if (adminRoleValue == 'Altro')
      {
        otherAdminRoleCtrl.text = person.adminOtherRole ?? adminRole;
      }
    }

    isHighSchoolStudent = person.isHighSchoolStudent ?? false;
    teacherRating = person.teacherRating;
    studiScolasticiCtrl.text = person.schoolEducation ?? '';
    studiUniversitariCtrl.text = person.universityEducation ?? '';

    if (person.earlyExit != null)
    {
      uscitaAnticipata = person.earlyExit!;
    }

    if (person.earlyExitStartDate != null && person.earlyExitEndDate != null)
    {
      uscitaAnticipataPeriodoLimitato = true;
      uscitaAnticipataDalCtrl.text =
          DateFormat('dd/MM/yyyy').format(person.earlyExitStartDate!);
      uscitaAnticipataAlCtrl.text =
          DateFormat('dd/MM/yyyy').format(person.earlyExitEndDate!);
    }

    for (final schedule in person.earlyExitSchedules ?? const <EarlyExitScheduleItem>[])
    {
      earlyExitRows.add(EarlyExitRowData.empty(
        weekdays: schedule.weekdays.toSet(),
        time: formatTimeOfDayShort(schedule.exitTime),
        reason: schedule.reason,
      ));
    }

    paymentMethodValue = labelForServerValue(kPaymentMethods, person.paymentMethod);

    if (paymentMethodValue == 'Altro')
    {
      otherPaymentMethodCtrl.text = person.paymentMethodOther ?? '';
    }

    certificationValues
      ..clear()
      ..addAll(person.certificationTypes
          .map((code) => labelForServerValue(kCertificationTypes, code))
          .whereType<String>());

    if (certificationValues.contains('Altro'))
    {
      otherCertificationCtrl.text = person.certificationOtherDetail ?? '';
    }

    if (certificationValues.contains('DSA'))
    {
      dsaCertificationCtrl.text = person.certificationDsaDetail ?? '';
    }

    mandatoryPsychMeetingsAcknowledgedExisting = person.mandatoryPsychMeetingsAcknowledged;
    homeworkTariffValue = homeworkTariffChoiceOf(person.homeworkTariff);
    specialCategoryDataConsentValue = person.specialCategoryDataConsent ?? false;
    newsletterConsentValue = person.newsletterConsent ?? false;
    psychMeetingsAcknowledgedValue = person.mandatoryPsychMeetingsAcknowledged ?? false;

    emergencyContactNameCtrl.text = person.emergencyContactName ?? '';
    emergencyContactPhoneCtrl.text = formatPhoneNumber(person.emergencyContactPhone);
    allergiesCtrl.text = person.allergiesNotes ?? '';
    medicationsCtrl.text = person.medicationsNotes ?? '';

    for (final parent in person.parents ?? const [])
    {
      selectedParents[parent.fiscalCode] = ParentalRelationshipDraft(
        taxCode: parent.fiscalCode,
        authorizedPickup: parent.authorizedPickup,
        restrictionReason: parent.pickupRestrictionReason,
      );
    }

    for (final child in person.children ?? const [])
    {
      selectedMinors[child.fiscalCode] = ParentalRelationshipDraft(
        taxCode: child.fiscalCode,
        authorizedPickup: child.authorizedPickup,
        restrictionReason: child.pickupRestrictionReason,
      );
    }

    for (final competence in person.teacherSubjects ?? const <TeacherSubjectItem>[])
    {
      subjectToggles[competence.subjectId] = true;
      selectedProgramsForSubject[competence.subjectId] = competence.studyProgramIds.toSet();
    }

    selectedServices.addAll(person.teacherServices ?? const <String>[]);
  }

  void applyCatalogues({
    required List<StudyProgramItem> programs,
    required List<SchoolItem> schools,
    required List<AssociationSubjectItem> subjects,
    required List<ServiceItem> services,
    required List<CourseItem> courses,
    required List<PersonItem> people,
  })
  {
    allPrograms = programs;
    allSchools = schools;
    allSubjects = subjects;
    allServices = services;
    allCourses = courses;

    allMinors = people
        .where((candidate) =>
            ((candidate.age != null && candidate.age! < 18) ||
                (person?.children?.any((child) => child.fiscalCode == candidate.fiscalCode) ??
                    false)) &&
            candidate.fiscalCode != person?.fiscalCode)
        .toList();

    allAdults = people
        .where((candidate) =>
            (candidate.age == null || candidate.age! >= 18) &&
            candidate.roles.any((role) => role.toUpperCase() == 'GENITORE') &&
            candidate.fiscalCode != person?.fiscalCode)
        .toList();

    programsBySubjectId.clear();

    for (final subject in allSubjects)
    {
      programsBySubjectId[subject.id] = _findProgramsFor(subject);
    }

    if (schoolRows.isEmpty &&
        (person?.roles.any((role) => role.toUpperCase() == 'STUDENTE') ?? false))
    {
      _hydrateSchoolRows();
    }
  }

  void _hydrateSchoolRows()
  {
    final PersonItem person = this.person!;
    final List<SchoolEnrollmentItem> enrollments = person.schoolEnrollments ?? [];

    if (enrollments.isNotEmpty)
    {
      final List<SchoolEnrollmentItem> sorted = List<SchoolEnrollmentItem>.from(enrollments)
        ..sort((a, b) => b.startYear.compareTo(a.startYear));

      for (final enrollment in sorted)
      {
        final SchoolItem? school =
            allSchools.where((item) => item.id == enrollment.schoolId).firstOrNull;
        final StudyProgramItem? program =
            allPrograms.where((item) => item.id == enrollment.studyProgramId).firstOrNull;

        schoolRows.add(SchoolEnrollmentRowData.empty(
          year: enrollment.startYear.toString(),
          school: school,
          program: program,
          grade: program == null ? null : _gradeLabel(enrollment.grade),
        ));
      }

      return;
    }

    SchoolItem? matchedSchool;
    StudyProgramItem? matchedProgram;

    // School names are not unique; with multiple matches the field is left empty.
    final List<SchoolItem> byName =
        allSchools.where((school) => school.name == person.schoolName).toList();

    if (byName.length == 1)
    {
      matchedSchool = byName.first;
    }

    matchedProgram =
        allPrograms.where((program) => program.fullName == person.studyProgram).firstOrNull;

    schoolRows.add(SchoolEnrollmentRowData.empty(
      year: person.enrollmentYear ?? currentSchoolYearStart().toString(),
      school: matchedSchool,
      program: matchedProgram,
      grade: person.schoolClass,
    ));
  }

  String? _gradeLabel(int grade)
  {
    for (final entry in kGradeNumbers.entries)
    {
      if (entry.value == grade)
      {
        return entry.key;
      }
    }

    return null;
  }

  List<StudyProgramItem> _findProgramsFor(AssociationSubjectItem subject)
  {
    return allPrograms
        .where((program) => program.ministrySubjects.any(
              (ministry) => ministry.associationSubjects.any((assoc) => assoc.id == subject.id),
            ))
        .toList();
  }

  List<StudyProgramItem> programsFor(int subjectId) =>
      programsBySubjectId[subjectId] ?? const [];

  bool get isMinor
  {
    if (!isValidDate(birthDateCtrl.text))
    {
      return false;
    }

    final List<String> parts = birthDateCtrl.text.split('/');
    final DateTime birth =
        DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    final DateTime now = DateTime.now();

    int age = now.year - birth.year;

    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day))
    {
      age--;
    }

    return age < 18;
  }

  List<String> get activeRoles => selectedRoles.where((role) => role != 'ASSOCIATO').toList();

  bool get isOnlyParentNotMember =>
      activeRoles.length == 1 &&
      activeRoles.contains('GENITORE') &&
      parentIsMember != true;

  // President, vice president and treasurer cannot be paid.
  bool get collaborationForcedUnpaid
  {
    return selectedRoles.contains('AMMINISTRATORE') &&
        (adminRoleValue == 'Presidente' ||
            adminRoleValue == 'Vicepresidente' ||
            adminRoleValue == 'Tesoriere');
  }

  void syncCollaborationWithAdminRole()
  {
    if (collaborationForcedUnpaid)
    {
      collaborationTypeValue = 'Non pagato';
    }
    else if (collaborationTypeValue == 'Non pagato')
    {
      collaborationTypeValue = null;
    }
  }

  bool get asksAssociationQuestion =>
      involvementType == 0 &&
      activeRoles.length == 1 &&
      activeRoles.contains('GENITORE') &&
      !wasMember;

  // Must be called on every role change; a question never shown counts as yes.
  void normaliseAssociationAnswer()
  {
    if (involvementType != 0)
    {
      return;
    }

    if (!asksAssociationQuestion)
    {
      parentIsMember = true;
    }
    else if (isCreation)
    {
      parentIsMember = null;
    }
  }

  void chooseInvolvement(int type)
  {
    involvementType = type;

    if (type == 1)
    {
      selectedRoles.clear();
    }

    normaliseAssociationAnswer();
  }

  void toggleRole(String roleId, bool selected)
  {
    if (selected)
    {
      selectedRoles.add(roleId);
    }
    else
    {
      selectedRoles.remove(roleId);
    }

    normaliseAssociationAnswer();
    syncCollaborationWithAdminRole();
  }

  ResidenceOffer residenceOffer({String label = ''}) => ResidenceOffer(
        label: label,
        streetTypeValue: streetTypeCtrl.text,
        addressValue: streetNameCtrl.text,
        streetNumberValue: streetNumberCtrl.text,
        cityValue: residenceCityCtrl.text,
        provinceCode: residenceProvinceCtrl.text,
        postalCodeValue: postalCodeCtrl.text,
      );

  void _writeResidence(ResidenceOffer residence)
  {
    streetTypeCtrl.text = residence.streetTypeValue;
    streetNameCtrl.text = residence.addressValue;
    streetNumberCtrl.text = residence.streetNumberValue;
    residenceCityCtrl.text = residence.cityValue;
    residenceProvinceCtrl.text = residence.provinceCode;
    postalCodeCtrl.text = residence.postalCodeValue;
  }

  void takeResidence(ResidenceOffer offered)
  {
    _residenceBeforeCopy = residenceOffer();
    _writeResidence(offered);
    copiesResidence = true;
  }

  void giveBackResidence()
  {
    final ResidenceOffer? before = _residenceBeforeCopy;

    if (before != null)
    {
      _writeResidence(before);
    }

    _residenceBeforeCopy = null;
    copiesResidence = false;
  }

  void residenceEditedByHand()
  {
    _residenceBeforeCopy = null;
    copiesResidence = false;
  }

  // Shared by both payloads: the same fields travel on create and on update.
  Map<String, dynamic> earlyExitPayload({required bool authorized})
  {
    final bool limited = authorized && uscitaAnticipataPeriodoLimitato;

    return {
      'early_exit_start_date':
          limited ? toIsoDate(uscitaAnticipataDalCtrl.text.trim()) : null,
      'early_exit_end_date':
          limited ? toIsoDate(uscitaAnticipataAlCtrl.text.trim()) : null,
      'early_exit_schedules': authorized
          ? [
              for (final row in earlyExitRows)
                if (!row.isBlank)
                  {
                    'weekdays': row.weekdays.toList()..sort(),
                    'exit_time': '${row.timeCtrl.text.trim()}:00',
                    'reason': row.reasonCtrl.text.trim(),
                  },
            ]
          : const <Map<String, dynamic>>[],
    };
  }

  static String? toIsoDate(String? itaDate)
  {
    if (itaDate == null || itaDate.isEmpty)
    {
      return null;
    }

    final List<String> parts = itaDate.split('/');

    if (parts.length != 3)
    {
      return null;
    }

    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  static bool isValidDate(String dateStr)
  {
    try
    {
      final List<String> parts = dateStr.split('/');

      if (parts.length != 3)
      {
        return false;
      }

      final int day = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int year = int.parse(parts[2]);
      final DateTime date = DateTime(year, month, day);

      return date.year == year && date.month == month && date.day == day;
    }
    catch (_)
    {
      return false;
    }
  }

  static bool isValidDayMonthYear(String dayMonth, String yearStr)
  {
    try
    {
      final List<String> parts = dayMonth.split('/');

      if (parts.length != 2)
      {
        return false;
      }

      final int day = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int year = int.parse(yearStr);
      final DateTime date = DateTime(year, month, day);

      return date.year == year && date.month == month && date.day == day;
    }
    catch (_)
    {
      return false;
    }
  }

  static int romanToNumeric(String roman) => kGradeNumbers[roman] ?? 1;

  // `expected_updated_at` keys are omitted (not null) when unknown; absent keys are left untouched.
  Map<String, dynamic> buildPayload()
  {
    final Set<String> finalRolesSet = selectedRoles.where((role) => role != 'ASSOCIATO').toSet();

    if (involvementType == 1)
    {
      finalRolesSet
        ..clear()
        ..add('ASSOCIATO');
    }
    else if (finalRolesSet.any((role) => role != 'GENITORE') || parentIsMember == true)
    {
      finalRolesSet.add('ASSOCIATO');
    }

    final List<String> finalRoles = finalRolesSet.toList();
    final bool onlyParentNotMember =
        finalRoles.length == 1 &&
            finalRoles.contains('GENITORE') &&
            parentIsMember != true;

    final List<Map<String, dynamic>> membershipsData = [];

    if (!onlyParentNotMember)
    {
      for (final row in membershipRows)
      {
        final List<String> parts = row.dateCtrl.text.trim().split('/');
        final String year = row.yearCtrl.text.trim();

        membershipsData.add({
          'year': int.parse(year),
          'start_date': '$year-${parts[1]}-${parts[0]}',
          'end_date': '$year-12-31',
          'renewal_period_days': MembershipItem.defaultRenewalPeriodDays,
          // Preserved as-is: hard-coding 'NO' silently readmitted expelled people.
          'revocation': row.revocation,
          if (row.id != null) 'id': row.id,
        });
      }
    }

    // Joining declarations are omitted entirely: absent keys keep their value.
    Map<String, dynamic>? memberData;

    if (!onlyParentNotMember && membershipsData.isNotEmpty)
    {
      final String? paymentMethod = kPaymentMethods[paymentMethodValue];

      final bool minor = isMinor;

      memberData = {
        'collaborating_active': involvementType == 0,
        'memberships': membershipsData,
        'payment_method': paymentMethod,
        'payment_method_other':
            paymentMethod == 'OTHER' ? otherPaymentMethodCtrl.text.trim() : null,
        'emergency_contact_name': minor && emergencyContactNameCtrl.text.isNotEmpty
            ? emergencyContactNameCtrl.text.trim()
            : null,
        'emergency_contact_phone': minor && emergencyContactPhoneCtrl.text.isNotEmpty
            ? barePhoneNumber(emergencyContactPhoneCtrl.text)
            : null,
        'allergies_notes':
            minor && allergiesCtrl.text.isNotEmpty ? allergiesCtrl.text.trim() : null,
        'medications_notes':
            minor && medicationsCtrl.text.isNotEmpty ? medicationsCtrl.text.trim() : null,
        'special_category_data_consent': specialCategoryDataConsentValue,
        'newsletter_consent': newsletterConsentValue,
        if (person?.memberUpdatedAt != null)
          'expected_updated_at': person!.memberUpdatedAt!.toIso8601String(),
      };
    }

    Map<String, dynamic>? staffData;
    Map<String, dynamic>? adminData;
    Map<String, dynamic>? teacherData;
    Map<String, dynamic>? courseParticipantData;
    Map<String, dynamic>? studentData;

    final bool isStaff = finalRoles.contains('AMMINISTRATORE') ||
        finalRoles.contains('DOCENTE') ||
        finalRoles.contains('PSICOLOGO');

    if (isStaff)
    {
      staffData = {
        'collaboration_type': kCollaborationTypes[collaborationTypeValue] ?? 'VOLUNTEER',
        'iban': ibanCtrl.text.isNotEmpty ? ibanCtrl.text.trim().toUpperCase() : null,
        'gross_compensation':
            isPaidCollaboration ? amountPayloadOf(grossCompensationCtrl.text) : null,
      };
    }

    if (finalRoles.contains('AMMINISTRATORE'))
    {
      final String adminRole = kAdminRoles[adminRoleValue] ?? 'OTHER';

      adminData = {
        'role': adminRole,
        'other_role': adminRole == 'OTHER' ? otherAdminRoleCtrl.text.trim() : null,
      };
    }

    if (finalRoles.contains('DOCENTE'))
    {
      teacherData = {
        'is_high_school_student': isHighSchoolStudent,
        'school_education':
            studiScolasticiCtrl.text.isNotEmpty ? studiScolasticiCtrl.text.trim() : null,
        // The server rejects university education for a high-school student.
        'university_education': !isHighSchoolStudent && studiUniversitariCtrl.text.isNotEmpty
            ? studiUniversitariCtrl.text.trim()
            : null,
        'competences': subjectToggles.entries
            .where((entry) => entry.value)
            .map((entry) => {
                  'subject_id': entry.key,
                  'study_program_ids': selectedProgramsForSubject[entry.key]?.toList() ?? [],
                })
            .toList(),
        'service_names': selectedServices.toList(),
        // Omitted when null; the server rejects a rating from non-admins.
        if (teacherRating != null) 'rating': teacherRating,
        if (person?.teacherUpdatedAt != null)
          'expected_updated_at': person!.teacherUpdatedAt!.toIso8601String(),
      };
    }

    if (finalRoles.contains('CORSISTA'))
    {
      courseParticipantData = {
        'medical_certificate_expiration': certificateExpirationCtrl.text.isNotEmpty
            ? certificateExpirationCtrl.text.trim().split('/').reversed.join('-')
            : null,
        'course_type': courseTypeValue,
      };
    }

    if (finalRoles.contains('STUDENTE'))
    {
      final List<String> certificationTypes = certificationValues
          .map((label) => kCertificationTypes[label])
          .whereType<String>()
          .toList();

      // Enrollments go in the same body: one transaction, one concurrency check.
      // Only a minor is authorised to leave early: an adult just leaves.
      final bool earlyExitAuthorized = isMinor && uscitaAnticipata;

      studentData = {
        'authorized_early_exit': earlyExitAuthorized,
        ...earlyExitPayload(authorized: earlyExitAuthorized),
        'certification_types': certificationTypes,
        'certification_other_detail': certificationTypes.contains('OTHER')
            ? otherCertificationCtrl.text.trim()
            : null,
        'certification_dsa_detail': certificationTypes.contains('DSA')
            ? dsaCertificationCtrl.text.trim()
            : null,
        'mandatory_psych_meetings_acknowledged': psychMeetingsAcknowledgedValue,
        'homework_tariff': homeworkTariffCode,
        'school_enrollments': schoolRows
            .map((row) => {
                  'start_year': int.parse(row.yearCtrl.text.trim()),
                  'school_id': row.school!.id,
                  'study_program_id': row.program!.id,
                  'grade': romanToNumeric(row.grade!),
                })
            .toList(),
        if (person?.studentUpdatedAt != null)
          'expected_updated_at': person!.studentUpdatedAt!.toIso8601String(),
      };
    }

    return {
      'general_data': {
        'first_name': firstNameCtrl.text.trim(),
        'last_name': lastNameCtrl.text.trim(),
        'tax_code': cfCtrl.text.trim().toUpperCase(),
        'gender': genderValue,
        'birth_date': toIsoDate(birthDateCtrl.text.trim()),
        'birth_city': birthCityCtrl.text.trim(),
        'birth_province': birthProvinceCtrl.text.trim().toUpperCase(),
        'birth_nation': birthNationCtrl.text.trim(),
        'residence_type': streetTypeCtrl.text.trim(),
        'residence_address': streetNameCtrl.text.trim(),
        'residence_street_number': streetNumberCtrl.text.trim(),
        'residence_city': residenceCityCtrl.text.trim(),
        'residence_province': residenceProvinceCtrl.text.trim().toUpperCase(),
        'postal_code': postalCodeCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'phone': barePhoneNumber(phoneCtrl.text),
      },
      'roles': finalRoles,
      'member_data': memberData,
      'staff_data': staffData,
      'admin_data': adminData,
      'teacher_data': teacherData,
      'course_participant_data': courseParticipantData,
      'student_data': studentData,
      'relationships': {
        'minors_tax_codes': selectedMinors.values.map((draft) => draft.toJson()).toList(),
        'parents_tax_codes': selectedParents.values.map((draft) => draft.toJson()).toList(),
      },
    };
  }

  // Differs from the update payload: consents signed now, Roman-numeral grade, no expected_updated_at.
  Map<String, dynamic> buildCreatePayload()
  {
    final Set<String> finalRolesSet = selectedRoles.where((role) => role != 'ASSOCIATO').toSet();

    if (involvementType == 1)
    {
      finalRolesSet
        ..clear()
        ..add('ASSOCIATO');
    }
    else if (finalRolesSet.any((role) => role != 'GENITORE') || parentIsMember == true)
    {
      finalRolesSet.add('ASSOCIATO');
    }

    final List<String> finalRoles = finalRolesSet.toList();
    final bool onlyParentNotMember =
        finalRoles.length == 1 &&
            finalRoles.contains('GENITORE') &&
            parentIsMember != true;

    final List<Map<String, dynamic>> membershipsData = [];

    if (!onlyParentNotMember)
    {
      for (final row in membershipRows)
      {
        final List<String> parts = row.dateCtrl.text.trim().split('/');
        final String year = row.yearCtrl.text.trim();

        membershipsData.add({
          'year': int.parse(year),
          'start_date': '$year-${parts[1]}-${parts[0]}',
          'end_date': '$year-12-31',
          'renewal_period_days': MembershipItem.defaultRenewalPeriodDays,
          'revocation': 'NO',
        });
      }
    }

    Map<String, dynamic>? memberData;

    if (!onlyParentNotMember && membershipsData.isNotEmpty)
    {
      final String? paymentMethod = kPaymentMethods[paymentMethodValue];

      memberData = {
        'memberships': membershipsData,
        'payment_method': paymentMethod,
        'payment_method_other':
            paymentMethod == 'OTHER' ? otherPaymentMethodCtrl.text.trim() : null,
        'statute_acknowledged': statuteAcknowledged,
        'regulation_acknowledged': regulationAcknowledged,
        'video_surveillance_acknowledged': videoSurveillanceAcknowledged,
        'special_category_data_consent': specialCategoryDataConsentValue,
        'newsletter_consent': newsletterConsentValue,
        'consents_signed_at': DateTime.now().toIso8601String().split('T').first,
        'emergency_contact_name': emergencyContactNameCtrl.text.isNotEmpty
            ? emergencyContactNameCtrl.text.trim()
            : null,
        'emergency_contact_phone': emergencyContactPhoneCtrl.text.isNotEmpty
            ? barePhoneNumber(emergencyContactPhoneCtrl.text)
            : null,
        'allergies_notes': allergiesCtrl.text.isNotEmpty ? allergiesCtrl.text.trim() : null,
        'medications_notes': medicationsCtrl.text.isNotEmpty ? medicationsCtrl.text.trim() : null,
      };
    }

    Map<String, dynamic>? staffData;
    Map<String, dynamic>? adminData;
    Map<String, dynamic>? teacherData;
    Map<String, dynamic>? courseParticipantData;
    Map<String, dynamic>? psychologicalSupportData;
    Map<String, dynamic>? studentData;

    final bool isStaff = finalRoles.contains('AMMINISTRATORE') ||
        finalRoles.contains('DOCENTE') ||
        finalRoles.contains('PSICOLOGO');

    if (isStaff)
    {
      staffData = {
        'collaboration_type': kCollaborationTypes[collaborationTypeValue] ?? 'VOLUNTEER',
        'iban': ibanCtrl.text.isNotEmpty ? ibanCtrl.text.trim().toUpperCase() : null,
        'gross_compensation':
            isPaidCollaboration ? amountPayloadOf(grossCompensationCtrl.text) : null,
      };
    }

    if (finalRoles.contains('AMMINISTRATORE'))
    {
      final String adminRole = kAdminRoles[adminRoleValue] ?? 'OTHER';

      adminData = {
        'role': adminRole,
        'other_role': adminRole == 'OTHER' ? otherAdminRoleCtrl.text.trim() : null,
      };
    }

    if (finalRoles.contains('DOCENTE'))
    {
      teacherData = {
        'is_high_school_student': isHighSchoolStudent,
        'school_education':
            studiScolasticiCtrl.text.isNotEmpty ? studiScolasticiCtrl.text.trim() : null,
        // The server rejects university education for a high-school student.
        'university_education': !isHighSchoolStudent && studiUniversitariCtrl.text.isNotEmpty
            ? studiUniversitariCtrl.text.trim()
            : null,
        'competences': subjectToggles.entries
            .where((entry) => entry.value)
            .map((entry) => {
                  'subject_id': entry.key,
                  'study_program_ids': selectedProgramsForSubject[entry.key]?.toList() ?? [],
                })
            .toList(),
        'service_names': selectedServices.toList(),
      };
    }

    if (finalRoles.contains('CORSISTA'))
    {
      courseParticipantData = {
        'medical_certificate_expiration': certificateExpirationCtrl.text.isNotEmpty
            ? certificateExpirationCtrl.text.trim().split('/').reversed.join('-')
            : null,
        'course_type': courseTypeValue,
      };
    }

    // Open to any member except psychologists themselves.
    if (!onlyParentNotMember &&
        !finalRoles.contains('PSICOLOGO') &&
        hasPsychologicalSupport)
    {
      psychologicalSupportData = {
        'start_date':
            psychologicalSupportStartDateCtrl.text.trim().split('/').reversed.join('-'),
      };
    }

    if (finalRoles.contains('STUDENTE'))
    {
      final List<String> certificationTypes = certificationValues
          .map((label) => kCertificationTypes[label])
          .whereType<String>()
          .toList();

      // Only a minor is authorised to leave early: an adult just leaves.
      final bool earlyExitAuthorized = isMinor && uscitaAnticipata;

      studentData = {
        'authorized_early_exit': earlyExitAuthorized,
        ...earlyExitPayload(authorized: earlyExitAuthorized),
        'certification_types': certificationTypes,
        'certification_other_detail': certificationTypes.contains('OTHER')
            ? otherCertificationCtrl.text.trim()
            : null,
        'certification_dsa_detail': certificationTypes.contains('DSA')
            ? dsaCertificationCtrl.text.trim()
            : null,
        'mandatory_psych_meetings_acknowledged':
            certificationTypes.isNotEmpty ? psychMeetingsAcknowledgedValue : false,
        'homework_tariff': homeworkTariffCode,
        'school_enrollments': schoolRows
            .map((row) => {
                  'start_year': int.parse(row.yearCtrl.text.trim()),
                  'school_id': row.school!.id,
                  'study_program_id': row.program!.id,
                  'school_class': row.grade!,
                })
            .toList(),
      };
    }

    return {
      'general_data': {
        'first_name': firstNameCtrl.text.trim(),
        'last_name': lastNameCtrl.text.trim(),
        'tax_code': cfCtrl.text.trim().toUpperCase(),
        'gender': genderValue,
        'birth_date': toIsoDate(birthDateCtrl.text.trim()),
        'birth_city': birthCityCtrl.text.trim(),
        'birth_nation': birthNationCtrl.text.trim(),
        'birth_province': birthProvinceCtrl.text.trim().toUpperCase(),
        'residence_type': streetTypeCtrl.text.trim(),
        'residence_address': streetNameCtrl.text.trim(),
        'residence_street_number': streetNumberCtrl.text.trim(),
        'residence_city': residenceCityCtrl.text.trim(),
        'residence_province': residenceProvinceCtrl.text.trim().toUpperCase(),
        'postal_code': postalCodeCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'phone': barePhoneNumber(phoneCtrl.text),
      },
      'roles': finalRoles,
      'member_data': memberData,
      'staff_data': staffData,
      'admin_data': adminData,
      'teacher_data': teacherData,
      'course_participant_data': courseParticipantData,
      'psychological_support_data': psychologicalSupportData,
      'student_data': studentData,
      'relationships': {
        'minors_tax_codes': selectedMinors.values.map((draft) => draft.toJson()).toList(),
        'parents_tax_codes': selectedParents.values.map((draft) => draft.toJson()).toList(),
      },
    };
  }

  static bool isFiscalCodeValid(String cf)
  {
    if (!RegExp(r'^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$').hasMatch(cf))
    {
      return false;
    }

    const Map<String, int> odd = {
      '0': 1, '1': 0, '2': 5, '3': 7, '4': 9, '5': 13, '6': 15, '7': 17, '8': 19, '9': 21,
      'A': 1, 'B': 0, 'C': 5, 'D': 7, 'E': 9, 'F': 13, 'G': 15, 'H': 17, 'I': 19, 'J': 21,
      'K': 2, 'L': 4, 'M': 18, 'N': 20, 'O': 11, 'P': 3, 'Q': 6, 'R': 8, 'S': 12, 'T': 14,
      'U': 16, 'V': 10, 'W': 22, 'X': 25, 'Y': 24, 'Z': 23,
    };

    const Map<String, int> even = {
      '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
      'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'F': 5, 'G': 6, 'H': 7, 'I': 8, 'J': 9,
      'K': 10, 'L': 11, 'M': 12, 'N': 13, 'O': 14, 'P': 15, 'Q': 16, 'R': 17, 'S': 18, 'T': 19,
      'U': 20, 'V': 21, 'W': 22, 'X': 23, 'Y': 24, 'Z': 25,
    };

    int sum = 0;

    for (var i = 0; i < 15; i++)
    {
      final String char = cf[i];
      sum += (i + 1) % 2 != 0 ? odd[char]! : even[char]!;
    }

    return cf[15] == String.fromCharCode((sum % 26) + 65);
  }

  // The tax code encodes year, month letter, and day, with 40 added for women.
  static bool fiscalCodeMatchesData(String cf, String dateStr, String gender)
  {
    if (cf.length != 16)
    {
      return false;
    }

    final List<String> parts = dateStr.split('/');

    if (parts.length != 3)
    {
      return false;
    }

    if (cf.substring(6, 8) != parts[2].substring(2, 4))
    {
      return false;
    }

    const Map<String, String> monthCodes = {
      '01': 'A', '02': 'B', '03': 'C', '04': 'D', '05': 'E', '06': 'H',
      '07': 'L', '08': 'M', '09': 'P', '10': 'R', '11': 'S', '12': 'T',
    };

    if (cf.substring(8, 9) != monthCodes[parts[1]])
    {
      return false;
    }

    final int day = int.parse(parts[0]) + (gender == 'F' ? 40 : 0);

    return cf.substring(9, 11) == day.toString().padLeft(2, '0');
  }

  void dispose()
  {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    cfCtrl.dispose();
    birthDateCtrl.dispose();
    birthCityCtrl.dispose();
    birthProvinceCtrl.dispose();
    birthNationCtrl.dispose();
    streetTypeCtrl.dispose();
    streetNameCtrl.dispose();
    streetNumberCtrl.dispose();
    residenceCityCtrl.dispose();
    residenceProvinceCtrl.dispose();
    postalCodeCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    certificateExpirationCtrl.dispose();
    ibanCtrl.dispose();
    grossCompensationCtrl.dispose();
    otherAdminRoleCtrl.dispose();
    studiScolasticiCtrl.dispose();
    studiUniversitariCtrl.dispose();
    otherPaymentMethodCtrl.dispose();
    otherCertificationCtrl.dispose();
    dsaCertificationCtrl.dispose();
    psychologicalSupportStartDateCtrl.dispose();
    emergencyContactNameCtrl.dispose();
    emergencyContactPhoneCtrl.dispose();
    allergiesCtrl.dispose();
    medicationsCtrl.dispose();
    uscitaAnticipataDalCtrl.dispose();
    uscitaAnticipataAlCtrl.dispose();

    for (final row in membershipRows)
    {
      row.dispose();
    }

    for (final row in schoolRows)
    {
      row.dispose();
    }

    for (final row in earlyExitRows)
    {
      row.dispose();
    }
  }
}
