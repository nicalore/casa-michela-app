import 'package:flutter/widgets.dart';

import '../../../core/language/app_language.dart';
import '../../../core/utils/iban.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/text_case.dart';
import '../models/person_item.dart';
import '../utils/student_notes_strings.dart' show kHealthDataWithoutConsent;
import '../widgets/membership_edit_row.dart';
import '../widgets/person_row_models.dart';
import 'homework_tariffs.dart';
import 'person_edit_form.dart';
import 'person_edit_pages.dart';

class PersonEditIssue
{
  final String field;
  final String message;
  final PersonEditCardId card;

  const PersonEditIssue({
    required this.field,
    required this.message,
    required this.card,
  });
}

class PersonEditValidation
{
  final Map<String, String> errors;
  final List<PersonEditIssue> issues;

  final String? message;

  const PersonEditValidation({
    required this.errors,
    required this.issues,
    this.message,
  });

  bool get isValid => issues.isEmpty && message == null;

  PersonEditCardId? get firstCard => issues.isEmpty ? null : issues.first.card;

  List<PersonEditIssue> issuesOn(PersonEditStep step)
  {
    final Set<PersonEditCardId> here = {for (final card in step.cards) card.id};

    return issues.where((issue) => here.contains(issue.card)).toList();
  }
}

class _Collector
{
  final Map<String, String> errors = {};
  final List<PersonEditIssue> issues = [];

  void add(String field, String message, PersonEditCardId card)
  {
    errors[field] = message;
    issues.add(PersonEditIssue(field: field, message: message, card: card));
  }
}

void tidyForm(PersonEditForm form)
{
  form.firstNameCtrl.text = titleCase(form.firstNameCtrl.text.trim());
  form.lastNameCtrl.text = titleCase(form.lastNameCtrl.text.trim());
  form.cfCtrl.text = form.cfCtrl.text.trim().toUpperCase();
  form.birthDateCtrl.text = form.birthDateCtrl.text.trim();
  form.birthCityCtrl.text = titleCase(form.birthCityCtrl.text.trim());
  form.birthProvinceCtrl.text = form.birthProvinceCtrl.text.trim().toUpperCase();
  form.birthNationCtrl.text = titleCase(form.birthNationCtrl.text.trim());
  form.psychologicalSupportStartDateCtrl.text =
      form.psychologicalSupportStartDateCtrl.text.trim();

  form.streetTypeCtrl.text = titleCase(form.streetTypeCtrl.text.trim());
  form.streetNameCtrl.text = titleCase(form.streetNameCtrl.text.trim());
  form.streetNumberCtrl.text = form.streetNumberCtrl.text.trim().toUpperCase();
  form.residenceCityCtrl.text = titleCase(form.residenceCityCtrl.text.trim());
  form.residenceProvinceCtrl.text = form.residenceProvinceCtrl.text.trim().toUpperCase();
  form.postalCodeCtrl.text = form.postalCodeCtrl.text.trim();
  form.emailCtrl.text = form.emailCtrl.text.trim();
  form.phoneCtrl.text = formatPhoneNumber(form.phoneCtrl.text);

  form.certificateExpirationCtrl.text = form.certificateExpirationCtrl.text.trim();
  form.ibanCtrl.text = normalizedIban(form.ibanCtrl.text);
  form.otherAdminRoleCtrl.text = openingCapital(form.otherAdminRoleCtrl.text.trim());
  form.studiScolasticiCtrl.text = openingCapital(form.studiScolasticiCtrl.text.trim());
  form.studiUniversitariCtrl.text = openingCapital(form.studiUniversitariCtrl.text.trim());
  form.otherPaymentMethodCtrl.text = sentenceCase(form.otherPaymentMethodCtrl.text.trim());
  form.otherCertificationCtrl.text = openingCapital(form.otherCertificationCtrl.text.trim());
  form.dsaCertificationCtrl.text = openingCapital(form.dsaCertificationCtrl.text.trim());
  form.allergiesCtrl.text = openingCapital(form.allergiesCtrl.text.trim());
  form.medicationsCtrl.text = openingCapital(form.medicationsCtrl.text.trim());
  form.emergencyContactNameCtrl.text = titleCase(form.emergencyContactNameCtrl.text.trim());
  form.emergencyContactPhoneCtrl.text = formatPhoneNumber(form.emergencyContactPhoneCtrl.text);

  for (final row in form.earlyExitRows)
  {
    row.reasonCtrl.text = openingCapital(row.reasonCtrl.text.trim());
  }
}

PersonEditValidation validatePersonEdit(PersonEditForm form)
{
  tidyForm(form);

  if (form.reEnrolling)
  {
    return _validateReEnrollment(form);
  }

  final _Collector collector = _Collector();
  final List<String> activeRoles = form.activeRoles;

  if (form.involvementType == 0 && activeRoles.isEmpty)
  {
    return PersonEditValidation(
      errors: const {},
      issues: [
        PersonEditIssue(
          field: 'roles',
          message: tr('Seleziona almeno un ruolo.', 'Select at least one role.'),
          card: PersonEditCardId.roleChoice,
        ),
      ],
      message: tr('Seleziona almeno un ruolo.', 'Select at least one role.'),
    );
  }

  final bool requiresAdult = form.selectedRoles.contains('GENITORE') ||
      form.selectedRoles.contains('PSICOLOGO') ||
      form.selectedRoles.contains('AMMINISTRATORE');

  if (requiresAdult && form.isMinor)
  {
    return PersonEditValidation(
      errors: const {},
      issues: [
        PersonEditIssue(
          field: 'roles',
          message: tr(
            'I ruoli Genitore, Psicologo e Amministratore richiedono la maggiore età.',
            'The Parent, Psychologist and Administrator roles require being of age.',
          ),
          card: PersonEditCardId.roleChoice,
        ),
      ],
      message: tr(
        'I ruoli Genitore, Psicologo e Amministratore richiedono la maggiore età.',
        'The Parent, Psychologist and Administrator roles require being of age.',
      ),
    );
  }

  final String? orphaned = _childLeftWithoutParents(form);

  if (orphaned != null)
  {
    return PersonEditValidation(
      errors: const {},
      issues: [
        PersonEditIssue(
          field: 'roles',
          message: tr('Genitore obbligatorio', 'Parent required'),
          card: PersonEditCardId.roleChoice,
        ),
      ],
      message: tr(
        'Impossibile rimuovere il ruolo Genitore: $orphaned rimarrebbe senza genitori.',
        'Cannot remove the Parent role: $orphaned would be left without parents.',
      ),
    );
  }

  if (form.isCreation)
  {
    if (form.firstNameCtrl.text.trim().isEmpty)
    {
      collector.add('nome', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.identity);
    }

    if (form.lastNameCtrl.text.trim().isEmpty)
    {
      collector.add('cognome', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.identity);
    }

    if (form.genderValue == null)
    {
      collector.add('sesso', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.identity);
    }

    final String cf = form.cfCtrl.text.trim().toUpperCase();

    if (cf.isEmpty)
    {
      collector.add('cf', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.identity);
    }
    else if (!PersonEditForm.isFiscalCodeValid(cf))
    {
      collector.add('cf', tr('Codice fiscale non valido', 'Invalid tax code'), PersonEditCardId.identity);
    }

    if (form.birthDateCtrl.text.trim().isEmpty)
    {
      collector.add('dataNascita', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.birthData);
    }
    else if (!PersonEditForm.isValidDate(form.birthDateCtrl.text.trim()))
    {
      collector.add('dataNascita', tr('Data non valida', 'Invalid date'), PersonEditCardId.birthData);
    }
    else if (cf.length == 16 &&
        form.genderValue != null &&
        !PersonEditForm.fiscalCodeMatchesData(
          cf,
          form.birthDateCtrl.text.trim(),
          form.genderValue!,
        ))
    {
      collector.add(
        'cf',
        tr('Non combacia con data di nascita e sesso', 'Does not match date of birth and sex'),
        PersonEditCardId.identity,
      );
    }

    if (cf.length == 16 &&
        !collector.errors.containsKey('cf') &&
        form.firstNameCtrl.text.trim().isNotEmpty &&
        form.lastNameCtrl.text.trim().isNotEmpty &&
        !PersonEditForm.fiscalCodeMatchesName(
          cf,
          form.firstNameCtrl.text.trim(),
          form.lastNameCtrl.text.trim(),
        ))
    {
      collector.add(
        'cf',
        tr('Non combacia con nome e cognome', 'Does not match first name and surname'),
        PersonEditCardId.identity,
      );
    }

    if (cf.length == 16 && !collector.errors.containsKey('cf') && form.isTaxCodeTaken(cf))
    {
      collector.add('cf', tr('Codice fiscale già presente', 'Tax code already registered'), PersonEditCardId.identity);
    }

    // Abroad the city may be unknown; the switch fills the province in.
    if (!form.bornAbroad && form.birthCityCtrl.text.trim().isEmpty)
    {
      collector.add('cittaNascita', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.birthData);
    }

    if (form.birthProvinceCtrl.text.trim().isEmpty)
    {
      collector.add('provNascita', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.birthData);
    }

    if (form.birthNationCtrl.text.trim().isEmpty)
    {
      collector.add('nazioneNascita', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.birthData);
    }
  }

  if (form.streetTypeCtrl.text.isEmpty)
  {
    collector.add('tipoVia', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.residence);
  }

  if (form.streetNameCtrl.text.isEmpty)
  {
    collector.add('indirizzo', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.residence);
  }

  if (form.streetNumberCtrl.text.isEmpty)
  {
    collector.add('civico', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.residence);
  }

  if (form.residenceCityCtrl.text.isEmpty)
  {
    collector.add('cittaResidenza', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.residence);
  }

  if (form.residenceProvinceCtrl.text.isEmpty)
  {
    collector.add('provResidenza', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.residence);
  }
  else if (!RegExp(r'^[A-Z]{2}$').hasMatch(form.residenceProvinceCtrl.text))
  {
    collector.add(
      'provResidenza',
      tr('Inserire 2 lettere (es. VI)', 'Enter 2 letters (e.g. VI)'),
      PersonEditCardId.residence,
    );
  }

  if (form.postalCodeCtrl.text.isEmpty)
  {
    collector.add('cap', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.residence);
  }
  else if (!RegExp(r'^\d{5}$').hasMatch(form.postalCodeCtrl.text))
  {
    collector.add(
      'cap',
      tr('Deve contenere esattamente 5 numeri', 'Must contain exactly 5 digits'),
      PersonEditCardId.residence,
    );
  }

  if (form.emailCtrl.text.isEmpty)
  {
    collector.add('email', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.contacts);
  }
  // Must match the database CHECK ck_people_email_format exactly.
  else if (!RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$")
      .hasMatch(form.emailCtrl.text))
  {
    collector.add('email', tr('Formato email non valido', 'Invalid email format'), PersonEditCardId.contacts);
  }

  if (form.phoneCtrl.text.isEmpty)
  {
    collector.add('telefono', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.contacts);
  }
  // Validates the bare digits, not the formatted text.
  else if (!RegExp(r'^\+?[0-9]+$').hasMatch(barePhoneNumber(form.phoneCtrl.text)))
  {
    collector.add('telefono', tr('Formato telefono non valido', 'Invalid phone format'), PersonEditCardId.contacts);
  }

  // Reduced to the personal details: nothing beyond them may be required.
  if (form.isPersonalDataOnly)
  {
    return _resultOf(collector, futureSchoolYear: false);
  }

  final bool onlyParent = form.isOnlyParentNotMember;
  final bool isStudent = activeRoles.contains('STUDENTE');
  final bool isCourseParticipant = activeRoles.contains('CORSISTA');
  bool futureSchoolYear = false;

  if (!onlyParent)
  {
    if (form.membershipRows.isEmpty)
    {
      collector.add(
        'enrollmentGeneral',
        tr('Aggiungi almeno un\'iscrizione', 'Add at least one enrolment'),
        PersonEditCardId.memberships,
      );
    }

    for (var i = 0; i < form.membershipRows.length; i++)
    {
      final row = form.membershipRows[i];
      final String year = row.yearCtrl.text.trim();
      final String date = row.dateCtrl.text.trim();
      bool yearValid = false;

      if (year.isEmpty)
      {
        collector.add('enrollmentYear_$i', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.memberships);
      }
      else if (!RegExp(r'^\d{4}$').hasMatch(year))
      {
        collector.add('enrollmentYear_$i', tr('Anno non valido', 'Invalid year'), PersonEditCardId.memberships);
      }
      else if (int.parse(year) > romeNow().year)
      {
        collector.add(
          'enrollmentYear_$i',
          tr('Anno non futuro', 'Year cannot be in the future'),
          PersonEditCardId.memberships,
        );
      }
      else if ((newestMembershipYear(form.person) ?? 9999) < int.parse(year))
      {
        collector.add('enrollmentYear_$i', kNewYearError, PersonEditCardId.memberships);
      }
      else
      {
        yearValid = true;
      }

      if (date.isEmpty)
      {
        collector.add('enrollmentDate_$i', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.memberships);
      }
      else if (yearValid && !PersonEditForm.isValidDayMonthYear(date, year))
      {
        collector.add('enrollmentDate_$i', tr('Data non valida', 'Invalid date'), PersonEditCardId.memberships);
      }
      else if (!yearValid && !RegExp(r'^\d{2}/\d{2}$').hasMatch(date))
      {
        collector.add('enrollmentDate_$i', tr('Formato gg/mm', 'Format dd/mm'), PersonEditCardId.memberships);
      }
      else if (yearValid)
      {
        final String? pastPayments = MembershipEditRow.startPastPayments(row.latestStart, date, year);

        if (pastPayments != null)
        {
          collector.add('enrollmentDate_$i', pastPayments, PersonEditCardId.memberships);
        }
      }
    }
  }

  _checkPayment(form, collector);

  if (activeRoles.contains('AMMINISTRATORE'))
  {
    if (form.adminRoleValue == null)
    {
      collector.add('ruoloAmministratore', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.admin);
    }
    else if (kAdminRoles[form.adminRoleValue] == 'OTHER' &&
        form.otherAdminRoleCtrl.text.isEmpty)
    {
      collector.add(
        'altroRuoloAmministratore',
        tr('Specificare il ruolo', 'Specify the role'),
        PersonEditCardId.admin,
      );
    }
  }

  if (isCourseParticipant)
  {
    // Optional: only what has been typed is checked.
    if (form.certificateExpirationCtrl.text.isNotEmpty &&
        !PersonEditForm.isValidDate(form.certificateExpirationCtrl.text))
    {
      collector.add(
        'scadenzaCertificato',
        tr('Formato data non valido', 'Invalid date format'),
        PersonEditCardId.courseParticipant,
      );
    }

    final bool courseMissing = form.courseTypeValue == null;

    if (courseMissing)
    {
      collector.add('tipoCorso', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.courseParticipant);
    }
  }

  if (isStudent)
  {
    if (form.isCreation)
    {
      _checkCertifications(form, collector);
    }

    if (form.isMinor && form.uscitaAnticipata)
    {
      _checkEarlyExit(form, collector);
    }

    futureSchoolYear = _checkSchoolRows(form, collector);
  }

  if (form.isCreation && !onlyParent)
  {
    if (!form.statuteAcknowledged)
    {
      collector.add('statutoAccettato', tr('Obbligatorio', 'Required'), PersonEditCardId.consents);
    }

    if (!form.regulationAcknowledged)
    {
      collector.add('regolamentoAccettato', tr('Obbligatorio', 'Required'), PersonEditCardId.consents);
    }

    if (!form.videoSurveillanceAcknowledged)
    {
      collector.add(
        'videosorveglianzaPresaVisione',
        tr('Obbligatorio', 'Required'),
        PersonEditCardId.consents,
      );
    }

    if (form.hasPsychologicalSupport)
    {
      final String start = form.psychologicalSupportStartDateCtrl.text.trim();

      if (start.isEmpty)
      {
        collector.add(
          'dataInizioSostegnoPsicologico',
          tr('Campo obbligatorio', 'Required field'),
          PersonEditCardId.psychologicalSupport,
        );
      }
      else if (!PersonEditForm.isValidDate(start))
      {
        collector.add(
          'dataInizioSostegnoPsicologico',
          tr('Formato data non valido', 'Invalid date format'),
          PersonEditCardId.psychologicalSupport,
        );
      }
    }
  }

  final bool isStaff = activeRoles.contains('AMMINISTRATORE') ||
      activeRoles.contains('DOCENTE') ||
      activeRoles.contains('PSICOLOGO');

  if (isStaff)
  {
    if (!form.ibanInCompensi && form.ibanCtrl.text.isNotEmpty && !isItalianIban(form.ibanCtrl.text))
    {
      collector.add('iban', kInvalidIban, PersonEditCardId.staff);
    }

    if (form.collaborationTypeValue == null && !form.collaborationInCompensi)
    {
      collector.add('tipoCollaborazione', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.staff);
    }

    final String compensation = form.grossCompensationCtrl.text.trim();

    if (form.isPaidCollaboration &&
        !form.collaborationInCompensi &&
        compensation.isNotEmpty &&
        parseAmountCents(compensation) == null)
    {
      collector.add('compensoLordo', tr('Importo non valido', 'Invalid amount'), PersonEditCardId.staff);
    }
  }

  if (form.isMinor && form.selectedParents.isEmpty)
  {
    collector.add(
      'parents',
      tr('Seleziona almeno un genitore', 'Select at least one parent'),
      PersonEditCardId.parents,
    );
  }

  if (form.asksSubjects &&
      !form.subjectToggles.values.any((selected) => selected))
  {
    collector.add(
      'subjects',
      tr('Seleziona almeno una disciplina', 'Select at least one discipline'),
      PersonEditCardId.subjects,
    );
  }

  // Mirrored by HEALTH_DATA_WITHOUT_CONSENT_ERROR in backend/app/schemas/person.py.
  if (!onlyParent &&
      !form.specialCategoryDataConsentValue &&
      !form.withdrawsSpecialCategoryDataConsent &&
      form.bringsHealthData)
  {
    collector.add(
      _healthWithoutConsent,
      kHealthDataWithoutConsent,
      PersonEditCardId.consents,
    );
  }

  return _resultOf(collector, futureSchoolYear: futureSchoolYear);
}

// No field shows it: the refusal reads only as the snackbar.
const String _healthWithoutConsent = 'datiSanitariSenzaConsenso';

// True when a year after the one in course was typed.
bool _checkSchoolRows(PersonEditForm form, _Collector collector)
{
  bool future = false;

  if (form.schoolRows.isEmpty)
  {
    collector.add(
      'schoolGeneral',
      tr('Aggiungi almeno un anno scolastico', 'Add at least one school year'),
      PersonEditCardId.schoolEnrollments,
    );
  }

  final Set<int> seenYears = {};

  for (var i = 0; i < form.schoolRows.length; i++)
  {
    final row = form.schoolRows[i];
    final String year = row.yearCtrl.text.trim();

    if (year.isEmpty)
    {
      collector.add('schoolYear_$i', tr('Obbligatorio', 'Required'), PersonEditCardId.schoolEnrollments);
    }
    else if (!RegExp(r'^\d{4}$').hasMatch(year))
    {
      collector.add('schoolYear_$i', tr('Anno non valido', 'Invalid year'), PersonEditCardId.schoolEnrollments);
    }
    else
    {
      final int parsed = int.parse(year);

      if (parsed > currentSchoolYearStart())
      {
        future = true;
        collector.add(
          'schoolYear_$i',
          tr('Anno futuro non permesso', 'Future year not allowed'),
          PersonEditCardId.schoolEnrollments,
        );
      }
      else if (!seenYears.add(parsed))
      {
        collector.add('schoolYear_$i', tr('Duplicato', 'Duplicate'), PersonEditCardId.schoolEnrollments);
      }
    }

    if (!row.hasSchool)
    {
      collector.add('school_$i', tr('Obbligatorio', 'Required'), PersonEditCardId.schoolEnrollments);
    }

    if (row.program == null)
    {
      collector.add('program_$i', tr('Obbligatorio', 'Required'), PersonEditCardId.schoolEnrollments);
    }

    if (row.grade == null)
    {
      collector.add('grade_$i', tr('Obbligatorio', 'Required'), PersonEditCardId.schoolEnrollments);
    }
  }

  return future;
}

void _checkPayment(PersonEditForm form, _Collector collector)
{
  final bool asksPayment = form.asksPaymentStep;

  if (asksPayment && form.paymentMethodValue == null)
  {
    collector.add('modalitaPagamento', tr('Obbligatorio', 'Required'), PersonEditCardId.payment);
  }

  if (form.asksTariff)
  {
    _validateTariff(form, collector);
  }

  if (form.asksFees)
  {
    _validateFee(form.membershipFeeCtrl, 'quotaIscrizione', collector);
    _validateFee(form.insuranceFeeCtrl, 'quotaAssicurazione', collector);
  }

  if (asksPayment &&
      kPaymentMethods[form.paymentMethodValue] == 'OTHER' &&
      form.otherPaymentMethodCtrl.text.isEmpty)
  {
    collector.add(
      'altraModalitaPagamento',
      tr('Specificare la modalità', 'Specify the method'),
      PersonEditCardId.payment,
    );
  }
}

// The re-enrollment asks only its own steps: what else is on file is not its business.
PersonEditValidation _validateReEnrollment(PersonEditForm form)
{
  final _Collector collector = _Collector();
  final String start = form.reEnrollStartCtrl.text.trim();

  if (start.isEmpty)
  {
    collector.add('reEnrollStart', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.reEnrollment);
  }
  else if (!PersonEditForm.isValidDayMonthYear(start, form.reEnrollYearCtrl.text))
  {
    collector.add('reEnrollStart', tr('Data non valida', 'Invalid date'), PersonEditCardId.reEnrollment);
  }

  bool futureSchoolYear = false;

  if (form.asksSchoolYear)
  {
    futureSchoolYear = _checkSchoolRows(form, collector);

    final bool hasCurrent = form.schoolRows.any(
      (row) => int.tryParse(row.yearCtrl.text.trim()) == currentSchoolYearStart(),
    );

    if (!hasCurrent && form.schoolRows.isNotEmpty)
    {
      collector.add(
        'schoolGeneral',
        tr('Aggiungi l\'anno scolastico in corso', 'Add the current school year'),
        PersonEditCardId.schoolEnrollments,
      );
    }
  }

  _checkPayment(form, collector);

  return _resultOf(collector, futureSchoolYear: futureSchoolYear);
}

PersonEditValidation _resultOf(
  _Collector collector, {
  required bool futureSchoolYear,
})
{
  if (collector.issues.isEmpty)
  {
    return PersonEditValidation(errors: collector.errors, issues: collector.issues);
  }

  return PersonEditValidation(
    errors: collector.errors,
    issues: collector.issues,
    message: _messageFor(collector.issues.first, futureSchoolYear),
  );
}

String _messageFor(PersonEditIssue issue, bool futureSchoolYear)
{
  if (issue.field == _healthWithoutConsent)
  {
    return issue.message;
  }

  if (futureSchoolYear && issue.card == PersonEditCardId.schoolEnrollments)
  {
    return tr('Non è possibile inserire anni scolastici futuri.', 'Future school years cannot be entered.');
  }

  return switch (issue.card)
  {
    PersonEditCardId.identity ||
    PersonEditCardId.birthData ||
    PersonEditCardId.residence ||
    PersonEditCardId.contacts =>
      tr(
        'Ci sono errori nei dati inseriti. Correggi i campi.',
        'There are errors in the details entered. Correct the fields.',
      ),
    PersonEditCardId.payment => tr('Completa i dati sul pagamento.', 'Complete the payment details.'),
    PersonEditCardId.consents => tr(
      'Statuto, regolamento e videosorveglianza sono obbligatori.',
      'The statute, the rules and the video surveillance notice are required.',
    ),
    PersonEditCardId.parents => tr(
      'Seleziona almeno un genitore o tutore legale.',
      'Select at least one parent or legal guardian.',
    ),
    PersonEditCardId.subjects => tr('Seleziona almeno una disciplina.', 'Select at least one discipline.'),
    _ => tr(
      'Ci sono errori nelle informazioni associative. Correggi i campi.',
      'There are errors in the membership details. Correct the fields.',
    ),
  };
}

// The child who would be left without parents if the role were removed.
String? _childLeftWithoutParents(PersonEditForm form)
{
  final PersonItem? person = form.person;

  final bool wasParent =
      person?.roles.any((role) => role.toUpperCase() == 'GENITORE') ?? false;

  if (!wasParent || form.selectedRoles.contains('GENITORE'))
  {
    return null;
  }

  for (final child in person!.children ?? const [])
  {
    final minor =
        form.allMinors.where((item) => item.fiscalCode == child.fiscalCode).firstOrNull;

    if (minor?.parents == null)
    {
      continue;
    }

    final others = minor!.parents!
        .where((parent) => parent.fiscalCode != person.fiscalCode)
        .toList();

    if (others.isEmpty)
    {
      return '${minor.firstName} ${minor.lastName}';
    }
  }

  return null;
}

// The activity day ends at 19:00; leaving then is not leaving early.
const int _closingHour = 19;

DateTime? _italianDate(String value)
{
  if (!PersonEditForm.isValidDate(value))
  {
    return null;
  }

  final List<String> parts = value.split('/');

  return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
}

// "hh:mm" as the mask writes it; anything else is refused.
int? _minutesOfDay(String value)
{
  final RegExpMatch? match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);

  if (match == null)
  {
    return null;
  }

  final int hour = int.parse(match.group(1)!);
  final int minute = int.parse(match.group(2)!);

  if (hour > 23 || minute > 59)
  {
    return null;
  }

  return hour * 60 + minute;
}

void _checkCertifications(PersonEditForm form, _Collector collector)
{
  if (form.certificationValues.any((value) => kCertificationTypes[value] == 'OTHER') &&
      form.otherCertificationCtrl.text.isEmpty)
  {
    collector.add(
      'altraCertificazione',
      tr('Specificare il tipo', 'Specify the type'),
      PersonEditCardId.certifications,
    );
  }

  if (form.certificationValues.any((value) => kCertificationTypes[value] == 'DSA') && form.dsaCertificationCtrl.text.isEmpty)
  {
    collector.add('tipoDsa', tr('Specificare il disturbo', 'Specify the disorder'), PersonEditCardId.certifications);
  }

  if (form.certificationValues.isNotEmpty && !form.psychMeetingsAcknowledgedValue)
  {
    collector.add(
      'presaVisioneIncontri',
      tr('Presa visione obbligatoria', 'Acknowledgement required'),
      PersonEditCardId.certifications,
    );
  }
}

void _checkEarlyExitPeriod(PersonEditForm form, _Collector collector)
{
  final String from = form.uscitaAnticipataDalCtrl.text.trim();
  final String to = form.uscitaAnticipataAlCtrl.text.trim();

  if (from.isEmpty)
  {
    collector.add('uscitaAnticipataDal', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.earlyExit);
  }
  else if (!PersonEditForm.isValidDate(from))
  {
    collector.add('uscitaAnticipataDal', tr('Data non valida', 'Invalid date'), PersonEditCardId.earlyExit);
  }

  if (to.isEmpty)
  {
    collector.add('uscitaAnticipataAl', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.earlyExit);

    return;
  }

  if (!PersonEditForm.isValidDate(to))
  {
    collector.add('uscitaAnticipataAl', tr('Data non valida', 'Invalid date'), PersonEditCardId.earlyExit);

    return;
  }

  final DateTime? start = _italianDate(from);
  final DateTime? end = _italianDate(to);

  if (start != null && end != null && end.isBefore(start))
  {
    collector.add(
      'uscitaAnticipataAl',
      tr('Non può precedere l\'inizio', 'Cannot be before the start'),
      PersonEditCardId.earlyExit,
    );
  }
}

void _checkEarlyExit(PersonEditForm form, _Collector collector)
{
  if (form.uscitaAnticipataPeriodoLimitato)
  {
    _checkEarlyExitPeriod(form, collector);
  }

  final Set<int> takenDays = {};

  for (var i = 0; i < form.earlyExitRows.length; i++)
  {
    final EarlyExitRowData row = form.earlyExitRows[i];

    if (row.weekdays.isEmpty)
    {
      collector.add(
        'earlyExitDays_$i',
        tr('Scegli almeno un giorno', 'Choose at least one day'),
        PersonEditCardId.earlyExit,
      );
    }
    else if (row.weekdays.any(takenDays.contains))
    {
      collector.add(
        'earlyExitDays_$i',
        tr('Giorno già indicato in un\'altra uscita', 'Day already set in another departure'),
        PersonEditCardId.earlyExit,
      );
    }

    takenDays.addAll(row.weekdays);

    final String time = row.timeCtrl.text.trim();
    final int? minutes = _minutesOfDay(time);

    if (time.isEmpty)
    {
      collector.add('earlyExitTime_$i', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.earlyExit);
    }
    else if (minutes == null)
    {
      collector.add('earlyExitTime_$i', tr('Orario non valido', 'Invalid time'), PersonEditCardId.earlyExit);
    }
    else if (minutes >= _closingHour * 60)
    {
      collector.add(
        'earlyExitTime_$i',
        tr('Deve precedere le 19:00', 'Must be before 19:00'),
        PersonEditCardId.earlyExit,
      );
    }

    if (row.reasonCtrl.text.trim().isEmpty)
    {
      collector.add('earlyExitReason_$i', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.earlyExit);
    }
  }
}

void _validateFee(TextEditingController controller, String key, _Collector collector)
{
  final String amount = controller.text.trim();
  final int? cents = parseAmountCents(amount);

  if (amount.isEmpty)
  {
    collector.add(key, tr('Campo obbligatorio', 'Required field'), PersonEditCardId.payment);
  }
  else if (cents == null || cents == 0)
  {
    collector.add(key, tr('Importo non valido', 'Invalid amount'), PersonEditCardId.payment);
  }
}

void _validateTariff(PersonEditForm form, _Collector collector)
{
  final String? choice = form.tariffKindValue;

  if (choice == null)
  {
    collector.add('tariffaAiutoCompiti', tr('Obbligatoria', 'Required'), PersonEditCardId.payment);

    return;
  }

  final String amount = form.tariffAmountCtrl(choice).text.trim();
  final int? cents = parseAmountCents(amount);

  if (amount.isEmpty)
  {
    collector.add('tariffaCosto', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.payment);
  }
  else if (cents == null || cents == 0)
  {
    collector.add('tariffaCosto', tr('Importo non valido', 'Invalid amount'), PersonEditCardId.payment);
  }

  if (choice != kPackageTariff)
  {
    return;
  }

  final String hours = form.tariffPackageHoursCtrl.text.trim();

  if (hours.isEmpty)
  {
    collector.add('tariffaOre', tr('Campo obbligatorio', 'Required field'), PersonEditCardId.payment);
  }
  else if ((int.tryParse(hours) ?? 0) == 0)
  {
    collector.add('tariffaOre', tr('Numero non valido', 'Invalid number'), PersonEditCardId.payment);
  }
}
