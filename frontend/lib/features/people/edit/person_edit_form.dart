import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/phone_number.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/school_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../models/parental_relationship_draft.dart';
import '../models/person_item.dart';
import '../models/school_enrollment_item.dart';
import '../models/teacher_subject_item.dart';
import '../widgets/person_row_models.dart';

// Everything the person edit dialog holds: the fields, the choices, the rows
// that get added, and the way all of it becomes the request body.
//
// It lives outside the widgets for one decisive reason: the dialog calls four
// endpoints as soon as it opens and cannot be exercised in a test, whereas this
// class touches no network and can be built in a single line.

// The roles that can be ticked, in the order they are offered.
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

// The courses the association runs, as they read and as the server writes them.
// A two-value enum in the database, so there is no third course to type by hand.
// The server sends the label already translated and expects the code back, which
// is why the translation is written once: written twice, one of the two had
// already drifted.
const Map<String, String> kCourseTypes = {
  'Yoga': 'YOGA',
  'Pilates': 'PILATES',
};

// The other fixed-value choices, as they read and as the server writes them.
// They sit next to the courses for the same reason: each of these translations
// used to be written twice, once in the update payload and once in the create
// one — which is exactly the shape in which the course type broke.
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

// The label matching whatever the server sent, be it the code or the label
// itself. The server is not consistent with itself — some fields arrive
// translated and others as codes — so asking here rather than listing the two
// cases by hand is what makes seeding indifferent to which one turns up.
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

// The school years, as the Roman numerals they are written in, and the number
// each one stands for.
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

// The current school year: from September on it is the one starting.
int currentSchoolYearStart()
{
  final DateTime now = DateTime.now();

  return now.month < 9 ? now.year - 1 : now.year;
}

// The residence of whoever opened a dialog, offered to whoever is inside it. A
// parent is created from a minor's page and a minor from a parent's, and nine
// times out of ten they live together. Residence only: birth, contacts and
// everything else belong to each person.
class ResidenceOffer
{
  // What the checkbox calls it, which depends on who is offering it.
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

  // A residence that was never written cannot be offered: the checkbox would
  // fill six empty fields with six empty fields.
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
  // The person being edited. Null when one is being created: the only
  // substantial difference between the two dialogs, and the others follow from
  // it — the identity is written instead of read, the consents are asked for,
  // and there is no last-modified moment to respect.
  final PersonItem? person;

  bool get isCreation => person == null;

  // 0 = involved in the activities, 1 = member only, -1 neither.
  //
  // A new person starts with no answer, and without one there is no going on:
  // pre-ticking "involved" was an answer the user never gave, passing for
  // theirs because nobody had asked. Someone being edited always has an answer,
  // and parents and minors created on the fly have one because the question is
  // never put to them.
  int involvementType = -1;

  // Whether the parent joins as well. Null until they say so: a two-answer
  // question, and a pre-ticked "No" was one of them given by default.
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

  // Whether the residence was copied from whoever opened this dialog, and what
  // was written before copying it: unticking puts it back as it was instead of
  // leaving fields nobody chose to write.
  bool copiesResidence = false;
  ResidenceOffer? _residenceBeforeCopy;

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  final List<MembershipRowData> membershipRows = [];
  final List<SchoolEnrollmentRowData> schoolRows = [];

  final TextEditingController certificateExpirationCtrl = TextEditingController();
  final TextEditingController ibanCtrl = TextEditingController();
  String? collaborationTypeValue;
  String? adminRoleValue;
  final TextEditingController otherAdminRoleCtrl = TextEditingController();
  final TextEditingController studiScolasticiCtrl = TextEditingController();
  final TextEditingController studiUniversitariCtrl = TextEditingController();

  // False by default: a minor is collected by a parent unless said otherwise,
  // which is the server's starting value too.
  bool uscitaAnticipata = false;

  String? paymentMethodValue;
  final TextEditingController otherPaymentMethodCtrl = TextEditingController();

  // This dialog has no consents card: the certification type is read and
  // written back as it was, never asked for.
  String? certificationTypeValue = 'No';
  final TextEditingController otherCertificationCtrl = TextEditingController();
  bool? mandatoryPsychMeetingsAcknowledgedExisting;

  final TextEditingController emergencyContactNameCtrl = TextEditingController();
  final TextEditingController emergencyContactPhoneCtrl = TextEditingController();
  final TextEditingController allergiesCtrl = TextEditingController();
  final TextEditingController medicationsCtrl = TextEditingController();

  // What is asked only of someone not yet on the books: the consents are signed
  // once, on joining.
  bool statuteAcknowledged = false;
  bool regulationAcknowledged = false;
  bool videoSurveillanceAcknowledged = false;
  bool specialCategoryDataConsentValue = false;
  bool newsletterConsentValue = false;

  bool hasPsychologicalSupport = false;
  final TextEditingController psychologicalSupportStartDateCtrl = TextEditingController();
  bool psychMeetingsAcknowledgedValue = false;

  // The course the participant attends, picked from the ones the association
  // runs. Free text when editing, because older courses are no longer on that
  // list.
  String? courseTypeValue;

  // The people created inside this dialog — a parent, a minor — which have to
  // reach the server before the one being created, because it is to them that it
  // will be tied.
  final List<Map<String, dynamic>> pendingPeople = [];

  final Map<String, ParentalRelationshipDraft> selectedParents = {};
  final Map<String, ParentalRelationshipDraft> selectedMinors = {};

  final Map<int, bool> subjectToggles = {};
  final Map<int, Set<int>> selectedProgramsForSubject = {};

  // The services the teacher can take on, by name: a service has no programmes
  // to narrow it down, so the set of chosen ones is enough.
  final Set<String> selectedServices = {};

  // The catalogues, which arrive later over the network.
  List<SchoolItem> allSchools = [];
  List<StudyProgramItem> allPrograms = [];
  List<AssociationSubjectItem> allSubjects = [];
  List<ServiceItem> allServices = [];
  List<PersonItem> allAdults = [];
  List<PersonItem> allMinors = [];

  // The programmes each discipline is taught in, computed once when the
  // catalogues arrive.
  final Map<int, List<StudyProgramItem>> programsBySubjectId = {};

  PersonEditForm._(this.person);

  // Fills the form with what the person is right now.
  factory PersonEditForm.fromPerson(PersonItem person)
  {
    final PersonEditForm form = PersonEditForm._(person);
    form._loadExisting();

    return form;
  }

  // An empty form, for a person not yet on the books.
  //
  // The roles can already be decided by whoever opens the dialog: a parent
  // created on the fly while registering their child is a parent, and there is
  // nothing to ask. [involvement] is the answer to the first step, where it is
  // already given — the dialog one arrives from is saying it — so it cannot be
  // left unanswered either.
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
    form.schoolRows.add(SchoolEnrollmentRowData.empty(
      year: currentSchoolYearStart().toString(),
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
    // Spaced on the way in, the way it is read everywhere else. What is sent
    // back is the run of digits: see [barePhoneNumber] at the payloads below.
    phoneCtrl.text = formatPhoneNumber(person.phoneNumber);

    final Set<String> roles = person.roles.map((role) => role.toUpperCase()).toSet();
    selectedRoles
      ..clear()
      ..addAll(roles);

    wasMember = roles.contains('ASSOCIATO') || roles.any((role) => role != 'GENITORE');
    involvementType = roles.length == 1 && roles.contains('ASSOCIATO') ? 1 : 0;
    parentIsMember = roles.contains('GENITORE') && roles.contains('ASSOCIATO');

    // The memberships already paid. MembershipItem carries no id: the "id" key
    // has never left this dialog and still does not — the server rebuilds the
    // whole list.
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
    // What the server sends is already the label, and that is what the chips
    // show.
    courseTypeValue = person.courseType;
    ibanCtrl.text = person.iban ?? '';

    collaborationTypeValue =
        labelForServerValue(kCollaborationTypes, person.collaborationType);

    final String? adminRole = person.adminRole;

    if (adminRole != null)
    {
      // A role the table does not know is necessarily "Altro": the field next
      // to it holds how it is spelled out, which is the only place that name
      // exists.
      adminRoleValue = labelForServerValue(kAdminRoles, adminRole) ?? 'Altro';

      if (adminRoleValue == 'Altro')
      {
        otherAdminRoleCtrl.text = person.adminOtherRole ?? adminRole;
      }
    }

    studiScolasticiCtrl.text = person.schoolEducation ?? '';
    studiUniversitariCtrl.text = person.universityEducation ?? '';

    if (person.earlyExit != null)
    {
      uscitaAnticipata = person.earlyExit!;
    }

    paymentMethodValue = labelForServerValue(kPaymentMethods, person.paymentMethod);

    if (paymentMethodValue == 'Altro')
    {
      otherPaymentMethodCtrl.text = person.paymentMethodOther ?? '';
    }

    // The starting value is "No", and a person without a certification has
    // nothing to send: whatever the table does not recognise is left as it is.
    certificationTypeValue =
        labelForServerValue(kCertificationTypes, person.certificationType) ??
            certificationTypeValue;

    if (certificationTypeValue == 'Altro')
    {
      otherCertificationCtrl.text = person.certificationOtherDetail ?? '';
    }

    mandatoryPsychMeetingsAcknowledgedExisting = person.mandatoryPsychMeetingsAcknowledged;
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

  // What arrives over the network: the catalogues, the people to choose from,
  // and the school years, which can only be composed once schools and
  // programmes have a name.
  void applyCatalogues({
    required List<StudyProgramItem> programs,
    required List<SchoolItem> schools,
    required List<AssociationSubjectItem> subjects,
    required List<ServiceItem> services,
    required List<PersonItem> people,
  })
  {
    allPrograms = programs;
    allSchools = schools;
    allSubjects = subjects;
    allServices = services;

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

    // The name alone no longer identifies a school, now that two schools of
    // the same name in different cities are allowed. Only the denormalised name
    // is here: when more than one matches, nothing is guessed and the field is
    // left empty.
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

  // ---------------------------------------------------------------- questions

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

  // The roles that count: member is not an answer, it is a consequence.
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

  // The membership question is only put to someone who is a parent and nothing
  // else and was not already a member: a parent can enrol their child without
  // joining themselves.
  bool get asksAssociationQuestion =>
      involvementType == 0 &&
      activeRoles.length == 1 &&
      activeRoles.contains('GENITORE') &&
      !wasMember;

  // Skipping the question counts as answering yes. Now that the steps are a
  // computed list this has to be called every time the roles change, or a
  // removed role would leave the previous answer lying around.
  //
  // If the question comes back, on creation it comes back unanswered: that
  // "yes" was nobody's, it was the consequence of a role that is no longer
  // there, and leaving it ticked is the default answer removed from the rest of
  // the form.
  //
  // Not when editing: there an answer already exists, it is the one the person
  // is written with, and dropping it because a role was ticked and unticked
  // would mean asking again about something nobody meant to change.
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

  // «Coinvolto nelle attività» o «Solo socio». Scegliere il secondo lascia
  // cadere i ruoli, come faceva il vecchio AVANTI del primo passaggio.
  void chooseInvolvement(int type)
  {
    involvementType = type;

    if (type == 1)
    {
      selectedRoles.clear();
    }

    normaliseAssociationAnswer();
  }

  // Spunta o toglie un ruolo, tenendo dietro le conseguenze.
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

  // --------------------------------------------------------------- residence

  // The residence written here, to offer to a dialog opened from this one.
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

  // The box ticked: what was there is set aside and the offered one is
  // written.
  void takeResidence(ResidenceOffer offered)
  {
    _residenceBeforeCopy = residenceOffer();
    _writeResidence(offered);
    copiesResidence = true;
  }

  // The box unticked: what was there before ticking it comes back.
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

  // A residence field typed by hand while the box is ticked: it is no longer
  // the same residence, so the tick goes. What is written stays — this is a
  // deliberate change, not a step back.
  void residenceEditedByHand()
  {
    _residenceBeforeCopy = null;
    copiesResidence = false;
  }

  // ---------------------------------------------------------------- helpers

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

  // ------------------------------------------------------------------ saving

  // The request body, identical to the one this dialog has always sent. The
  // `expected_updated_at` keys appear only when the moment is known: absent,
  // not null — the server leaves alone what it is not told.
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
          'renewal_period_days': 30,
          // As it was. Hard-coded back to 'NO', editing the details of an
          // expelled person used to readmit them without anyone asking — and,
          // since a revoked person's dialog shows the details alone, without
          // even showing the membership it was reopening.
          'revocation': row.revocation,
          if (row.id != null) 'id': row.id,
        });
      }
    }

    // The three declarations signed on joining — statute, regulation, video
    // surveillance — are not sent at all: absent rather than null, because the
    // server leaves as-is whatever it does not find in the JSON and those are
    // never withdrawn. The two real consents can be changed.
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
        'school_education':
            studiScolasticiCtrl.text.isNotEmpty ? studiScolasticiCtrl.text.trim() : null,
        'university_education':
            studiUniversitariCtrl.text.isNotEmpty ? studiUniversitariCtrl.text.trim() : null,
        'competences': subjectToggles.entries
            .where((entry) => entry.value)
            .map((entry) => {
                  'subject_id': entry.key,
                  'study_program_ids': selectedProgramsForSubject[entry.key]?.toList() ?? [],
                })
            .toList(),
        'service_names': selectedServices.toList(),
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
        'course_type': kCourseTypes[courseTypeValue],
      };
    }

    if (finalRoles.contains('STUDENTE'))
    {
      final String? certificationType = kCertificationTypes[certificationTypeValue];

      // The whole school history goes in the same body rather than in a call
      // of its own: the server rebuilds the years in one go inside the same
      // transaction, with a single concurrency check.
      studentData = {
        'authorized_early_exit': isMinor ? uscitaAnticipata : true,
        'certification_type': certificationType,
        'certification_other_detail':
            certificationType == 'OTHER' ? otherCertificationCtrl.text.trim() : null,
        // Editable from here now: it starts from what the person had and goes
        // back with whatever was ticked.
        'mandatory_psych_meetings_acknowledged': psychMeetingsAcknowledgedValue,
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

  // The body a person is created with. It resembles the update one but is not
  // the same, and every difference is substantial: the consents are signed now,
  // psychological support is asked for only on joining, the school year starts
  // as a Roman numeral rather than a number, and there is no last-modified
  // moment to respect because there is nothing to overwrite yet.
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
          'renewal_period_days': 30,
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
        'school_education':
            studiScolasticiCtrl.text.isNotEmpty ? studiScolasticiCtrl.text.trim() : null,
        'university_education':
            studiUniversitariCtrl.text.isNotEmpty ? studiUniversitariCtrl.text.trim() : null,
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
        'course_type': kCourseTypes[courseTypeValue],
      };
    }

    // Aperto a chiunque sia socio, tranne agli psicologi stessi.
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
      final String? certificationType = kCertificationTypes[certificationTypeValue];

      studentData = {
        'authorized_early_exit': isMinor ? uscitaAnticipata : true,
        'certification_type': certificationType,
        'certification_other_detail':
            certificationType == 'OTHER' ? otherCertificationCtrl.text.trim() : null,
        'mandatory_psych_meetings_acknowledged':
            certificationType != null ? psychMeetingsAcknowledgedValue : false,
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

  // -------------------------------------------------------------- tax code

  // True when the tax code is well formed and its check character adds up.
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

  // True when birth date and gender are the ones the tax code declares: the
  // code carries the year, the month as a letter and the day, with forty added
  // for a woman.
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
    otherAdminRoleCtrl.dispose();
    studiScolasticiCtrl.dispose();
    studiUniversitariCtrl.dispose();
    otherPaymentMethodCtrl.dispose();
    otherCertificationCtrl.dispose();
    psychologicalSupportStartDateCtrl.dispose();
    emergencyContactNameCtrl.dispose();
    emergencyContactPhoneCtrl.dispose();
    allergiesCtrl.dispose();
    medicationsCtrl.dispose();

    for (final row in membershipRows)
    {
      row.dispose();
    }

    for (final row in schoolRows)
    {
      row.dispose();
    }
  }
}
