import '../../../core/utils/phone_number.dart';
import '../models/person_item.dart';
import 'person_edit_form.dart';
import 'person_edit_pages.dart';

// An issue carries the name of the card to jump to; names do not slide when the
// step order changes.

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

  // Validation runs over the whole form; per step only that step's cards count.
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
  form.firstNameCtrl.text = form.firstNameCtrl.text.trim();
  form.lastNameCtrl.text = form.lastNameCtrl.text.trim();
  form.cfCtrl.text = form.cfCtrl.text.trim().toUpperCase();
  form.birthDateCtrl.text = form.birthDateCtrl.text.trim();
  form.birthCityCtrl.text = form.birthCityCtrl.text.trim();
  form.birthProvinceCtrl.text = form.birthProvinceCtrl.text.trim().toUpperCase();
  form.birthNationCtrl.text = form.birthNationCtrl.text.trim();
  form.psychologicalSupportStartDateCtrl.text =
      form.psychologicalSupportStartDateCtrl.text.trim();

  form.streetTypeCtrl.text = form.streetTypeCtrl.text.trim();
  form.streetNameCtrl.text = form.streetNameCtrl.text.trim();
  form.streetNumberCtrl.text = form.streetNumberCtrl.text.trim();
  form.residenceCityCtrl.text = form.residenceCityCtrl.text.trim();
  form.residenceProvinceCtrl.text = form.residenceProvinceCtrl.text.trim().toUpperCase();
  form.postalCodeCtrl.text = form.postalCodeCtrl.text.trim();
  form.emailCtrl.text = form.emailCtrl.text.trim();
  form.phoneCtrl.text = formatPhoneNumber(form.phoneCtrl.text);

  form.certificateExpirationCtrl.text = form.certificateExpirationCtrl.text.trim();
  form.ibanCtrl.text = form.ibanCtrl.text.replaceAll(' ', '').toUpperCase();
  form.otherAdminRoleCtrl.text = form.otherAdminRoleCtrl.text.trim();
  form.studiScolasticiCtrl.text = form.studiScolasticiCtrl.text.trim();
  form.studiUniversitariCtrl.text = form.studiUniversitariCtrl.text.trim();
  form.otherPaymentMethodCtrl.text = form.otherPaymentMethodCtrl.text.trim();
  form.otherCertificationCtrl.text = form.otherCertificationCtrl.text.trim();
  form.dsaCertificationCtrl.text = form.dsaCertificationCtrl.text.trim();
  form.emergencyContactNameCtrl.text = form.emergencyContactNameCtrl.text.trim();
  form.emergencyContactPhoneCtrl.text = formatPhoneNumber(form.emergencyContactPhoneCtrl.text);
}

PersonEditValidation validatePersonEdit(PersonEditForm form)
{
  tidyForm(form);

  final _Collector collector = _Collector();
  final List<String> activeRoles = form.activeRoles;

  if (form.involvementType == 0 && activeRoles.isEmpty)
  {
    return const PersonEditValidation(
      errors: {},
      issues: [
        PersonEditIssue(
          field: 'roles',
          message: 'Seleziona almeno un ruolo.',
          card: PersonEditCardId.roleChoice,
        ),
      ],
      message: 'Seleziona almeno un ruolo.',
    );
  }

  final bool requiresAdult = form.selectedRoles.contains('GENITORE') ||
      form.selectedRoles.contains('PSICOLOGO') ||
      form.selectedRoles.contains('AMMINISTRATORE');

  if (requiresAdult && form.isMinor)
  {
    return const PersonEditValidation(
      errors: {},
      issues: [
        PersonEditIssue(
          field: 'roles',
          message: 'I ruoli Genitore, Psicologo e Amministratore richiedono la maggiore età.',
          card: PersonEditCardId.roleChoice,
        ),
      ],
      message: 'I ruoli Genitore, Psicologo e Amministratore richiedono la maggiore età.',
    );
  }

  final String? orphaned = _childLeftWithoutParents(form);

  if (orphaned != null)
  {
    return PersonEditValidation(
      errors: const {},
      issues: const [
        PersonEditIssue(
          field: 'roles',
          message: 'Genitore obbligatorio',
          card: PersonEditCardId.roleChoice,
        ),
      ],
      message: 'Impossibile rimuovere il ruolo Genitore: $orphaned rimarrebbe senza genitori.',
    );
  }

  if (form.isCreation)
  {
    if (form.firstNameCtrl.text.trim().isEmpty)
    {
      collector.add('nome', 'Campo obbligatorio', PersonEditCardId.identity);
    }

    if (form.lastNameCtrl.text.trim().isEmpty)
    {
      collector.add('cognome', 'Campo obbligatorio', PersonEditCardId.identity);
    }

    if (form.genderValue == null)
    {
      collector.add('sesso', 'Campo obbligatorio', PersonEditCardId.identity);
    }

    final String cf = form.cfCtrl.text.trim().toUpperCase();

    if (cf.isEmpty)
    {
      collector.add('cf', 'Campo obbligatorio', PersonEditCardId.identity);
    }
    else if (!PersonEditForm.isFiscalCodeValid(cf))
    {
      collector.add('cf', 'Codice fiscale non valido', PersonEditCardId.identity);
    }

    if (form.birthDateCtrl.text.trim().isEmpty)
    {
      collector.add('dataNascita', 'Campo obbligatorio', PersonEditCardId.birthData);
    }
    else if (!PersonEditForm.isValidDate(form.birthDateCtrl.text.trim()))
    {
      collector.add('dataNascita', 'Data non valida', PersonEditCardId.birthData);
    }
    else if (cf.length == 16 &&
        form.genderValue != null &&
        !PersonEditForm.fiscalCodeMatchesData(
          cf,
          form.birthDateCtrl.text.trim(),
          form.genderValue!,
        ))
    {
      // The tax code encodes birth date and gender; a mismatch means one is wrong.
      collector.add(
        'cf',
        'Non combacia con data di nascita e sesso',
        PersonEditCardId.identity,
      );
    }

    if (form.birthCityCtrl.text.trim().isEmpty)
    {
      collector.add('cittaNascita', 'Campo obbligatorio', PersonEditCardId.birthData);
    }

    if (form.birthProvinceCtrl.text.trim().isEmpty)
    {
      collector.add('provNascita', 'Campo obbligatorio', PersonEditCardId.birthData);
    }

    if (form.birthNationCtrl.text.trim().isEmpty)
    {
      collector.add('nazioneNascita', 'Campo obbligatorio', PersonEditCardId.birthData);
    }
  }

  if (form.streetTypeCtrl.text.isEmpty)
  {
    collector.add('tipoVia', 'Campo obbligatorio', PersonEditCardId.residence);
  }

  if (form.streetNameCtrl.text.isEmpty)
  {
    collector.add('indirizzo', 'Campo obbligatorio', PersonEditCardId.residence);
  }

  if (form.streetNumberCtrl.text.isEmpty)
  {
    collector.add('civico', 'Campo obbligatorio', PersonEditCardId.residence);
  }

  if (form.residenceCityCtrl.text.isEmpty)
  {
    collector.add('cittaResidenza', 'Campo obbligatorio', PersonEditCardId.residence);
  }

  if (form.residenceProvinceCtrl.text.isEmpty)
  {
    collector.add('provResidenza', 'Campo obbligatorio', PersonEditCardId.residence);
  }
  else if (!RegExp(r'^[A-Z]{2}$').hasMatch(form.residenceProvinceCtrl.text))
  {
    collector.add('provResidenza', 'Inserire 2 lettere (es. VI)', PersonEditCardId.residence);
  }

  if (form.postalCodeCtrl.text.isEmpty)
  {
    collector.add('cap', 'Campo obbligatorio', PersonEditCardId.residence);
  }
  else if (!RegExp(r'^\d{5}$').hasMatch(form.postalCodeCtrl.text))
  {
    collector.add('cap', 'Deve contenere esattamente 5 numeri', PersonEditCardId.residence);
  }

  if (form.emailCtrl.text.isEmpty)
  {
    collector.add('email', 'Campo obbligatorio', PersonEditCardId.contacts);
  }
  // Must stay exactly as wide as the database CHECK ck_people_email_format, so
  // nothing passes here and is rejected there.
  else if (!RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$")
      .hasMatch(form.emailCtrl.text))
  {
    collector.add('email', 'Formato email non valido', PersonEditCardId.contacts);
  }

  if (form.phoneCtrl.text.isEmpty)
  {
    collector.add('telefono', 'Campo obbligatorio', PersonEditCardId.contacts);
  }
  // Validates the bare digits, not the formatted text.
  else if (!RegExp(r'^\+?[0-9]+$').hasMatch(barePhoneNumber(form.phoneCtrl.text)))
  {
    collector.add('telefono', 'Formato telefono non valido', PersonEditCardId.contacts);
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
        'Aggiungi almeno un\'iscrizione',
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
        collector.add('enrollmentYear_$i', 'Campo obbligatorio', PersonEditCardId.memberships);
      }
      else if (!RegExp(r'^\d{4}$').hasMatch(year))
      {
        collector.add('enrollmentYear_$i', 'Anno non valido', PersonEditCardId.memberships);
      }
      else if (int.parse(year) > DateTime.now().year)
      {
        collector.add('enrollmentYear_$i', 'Anno non futuro', PersonEditCardId.memberships);
      }
      else
      {
        yearValid = true;
      }

      if (date.isEmpty)
      {
        collector.add('enrollmentDate_$i', 'Campo obbligatorio', PersonEditCardId.memberships);
      }
      else if (yearValid && !PersonEditForm.isValidDayMonthYear(date, year))
      {
        collector.add('enrollmentDate_$i', 'Data non valida', PersonEditCardId.memberships);
      }
      else if (!yearValid && !RegExp(r'^\d{2}/\d{2}$').hasMatch(date))
      {
        collector.add('enrollmentDate_$i', 'Formato gg/mm', PersonEditCardId.memberships);
      }
    }
  }

  if (!onlyParent &&
      (isStudent || isCourseParticipant) &&
      form.paymentMethodValue == 'Altro' &&
      form.otherPaymentMethodCtrl.text.isEmpty)
  {
    collector.add(
      'altraModalitaPagamento',
      'Specificare la modalità',
      PersonEditCardId.payment,
    );
  }

  if (activeRoles.contains('AMMINISTRATORE'))
  {
    if (form.adminRoleValue == null)
    {
      collector.add('ruoloAmministratore', 'Campo obbligatorio', PersonEditCardId.admin);
    }
    else if (form.adminRoleValue == 'Altro' &&
        form.otherAdminRoleCtrl.text.isEmpty)
    {
      collector.add(
        'altroRuoloAmministratore',
        'Specificare il ruolo',
        PersonEditCardId.admin,
      );
    }
  }

  if (isCourseParticipant)
  {
    if (form.certificateExpirationCtrl.text.isEmpty)
    {
      collector.add(
        'scadenzaCertificato',
        'Campo obbligatorio',
        PersonEditCardId.courseParticipant,
      );
    }
    else if (!PersonEditForm.isValidDate(form.certificateExpirationCtrl.text))
    {
      collector.add(
        'scadenzaCertificato',
        'Formato data non valido',
        PersonEditCardId.courseParticipant,
      );
    }

    final bool courseMissing = form.courseTypeValue == null;

    if (courseMissing)
    {
      collector.add('tipoCorso', 'Campo obbligatorio', PersonEditCardId.courseParticipant);
    }
  }

  if (isStudent)
  {
    if (form.certificationTypeValue == 'Altro' && form.otherCertificationCtrl.text.isEmpty)
    {
      collector.add('altraCertificazione', 'Specificare il tipo', PersonEditCardId.student);
    }

    if (form.certificationTypeValue == 'DSA' && form.dsaCertificationCtrl.text.isEmpty)
    {
      collector.add('tipoDsa', 'Specificare il disturbo', PersonEditCardId.student);
    }

    if (form.certificationTypeValue != null &&
        form.certificationTypeValue != 'No' &&
        !form.psychMeetingsAcknowledgedValue)
    {
      collector.add(
        'presaVisioneIncontri',
        'Presa visione obbligatoria',
        PersonEditCardId.student,
      );
    }

    if (form.schoolRows.isEmpty)
    {
      collector.add(
        'schoolGeneral',
        'Aggiungi almeno un anno scolastico',
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
        collector.add('schoolYear_$i', 'Obbligatorio', PersonEditCardId.schoolEnrollments);
      }
      else if (!RegExp(r'^\d{4}$').hasMatch(year))
      {
        collector.add('schoolYear_$i', 'Anno non valido', PersonEditCardId.schoolEnrollments);
      }
      else
      {
        final int parsed = int.parse(year);

        if (parsed > currentSchoolYearStart())
        {
          futureSchoolYear = true;
          collector.add(
            'schoolYear_$i',
            'Anno futuro non permesso',
            PersonEditCardId.schoolEnrollments,
          );
        }
        else if (!seenYears.add(parsed))
        {
          collector.add('schoolYear_$i', 'Duplicato', PersonEditCardId.schoolEnrollments);
        }
      }

      if (row.school == null)
      {
        collector.add('school_$i', 'Obbligatorio', PersonEditCardId.schoolEnrollments);
      }

      if (row.program == null)
      {
        collector.add('program_$i', 'Obbligatorio', PersonEditCardId.schoolEnrollments);
      }

      if (row.grade == null)
      {
        collector.add('grade_$i', 'Obbligatorio', PersonEditCardId.schoolEnrollments);
      }
    }
  }

  if (form.isCreation && !onlyParent)
  {
    if (!form.statuteAcknowledged)
    {
      collector.add('statutoAccettato', 'Obbligatorio', PersonEditCardId.consents);
    }

    if (!form.regulationAcknowledged)
    {
      collector.add('regolamentoAccettato', 'Obbligatorio', PersonEditCardId.consents);
    }

    if (!form.videoSurveillanceAcknowledged)
    {
      collector.add(
        'videosorveglianzaPresaVisione',
        'Obbligatorio',
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
          'Campo obbligatorio',
          PersonEditCardId.psychologicalSupport,
        );
      }
      else if (!PersonEditForm.isValidDate(start))
      {
        collector.add(
          'dataInizioSostegnoPsicologico',
          'Formato data non valido',
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
    if (form.ibanCtrl.text.isNotEmpty &&
        !RegExp(r'^IT\d{2}[A-Z]\d{10}[A-Z0-9]{12}$').hasMatch(form.ibanCtrl.text))
    {
      collector.add('iban', 'Formato IBAN italiano non valido', PersonEditCardId.staff);
    }

    if (form.collaborationTypeValue == null)
    {
      collector.add('tipoCollaborazione', 'Campo obbligatorio', PersonEditCardId.staff);
    }
  }

  if (form.isMinor && form.selectedParents.isEmpty)
  {
    collector.add(
      'parents',
      'Seleziona almeno un genitore',
      PersonEditCardId.parents,
    );
  }

  if (form.selectedRoles.contains('DOCENTE') &&
      !form.subjectToggles.values.any((selected) => selected))
  {
    collector.add(
      'subjects',
      'Seleziona almeno una disciplina',
      PersonEditCardId.subjects,
    );
  }

  if (collector.issues.isEmpty)
  {
    return PersonEditValidation(errors: collector.errors, issues: collector.issues);
  }

  return PersonEditValidation(
    errors: collector.errors,
    issues: collector.issues,
    message: _messageFor(collector.issues.first.card, futureSchoolYear),
  );
}

String _messageFor(PersonEditCardId card, bool futureSchoolYear)
{
  if (futureSchoolYear && card == PersonEditCardId.schoolEnrollments)
  {
    return 'Non è possibile inserire anni scolastici futuri.';
  }

  return switch (card)
  {
    PersonEditCardId.identity ||
    PersonEditCardId.birthData ||
    PersonEditCardId.residence ||
    PersonEditCardId.contacts =>
      'Ci sono errori nei dati inseriti. Correggi i campi.',
    PersonEditCardId.consents => 'Statuto, regolamento e videosorveglianza sono obbligatori.',
    PersonEditCardId.parents => 'Seleziona almeno un genitore o tutore legale.',
    PersonEditCardId.subjects => 'Seleziona almeno una disciplina.',
    _ => 'Ci sono errori nelle informazioni associative. Correggi i campi.',
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
