import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/week_range.dart';
import '../edit/homework_tariffs.dart';
import '../models/early_exit_schedule_item.dart';
import '../models/person_item.dart';
import '../widgets/teacher_rating_dots.dart';
import 'person_detail_widgets.dart';

// Backend convention: province 'EE' means born abroad, so the nation is shown.
const String _abroadProvinceCode = 'EE';

const String _otherOptionCode = 'OTHER';

const String _dsaOptionCode = 'DSA';

String _formatDate(DateTime? date)
{
  return date == null ? missingValue : DateFormat('dd/MM/yyyy').format(date);
}

// Accepts both the code and the label: endpoints are inconsistent.
String? _adminRoleLabel(String role)
{
  return switch (role)
  {
    'PRESIDENT' || 'Presidente' => 'Presidente',
    'VICE_PRESIDENT' || 'Vicepresidente' => 'Vicepresidente',
    'TREASURER' || 'Tesoriere' => 'Tesoriere',
    _ => null,
  };
}

String? _paymentMethodLabel(String method)
{
  return switch (method)
  {
    'CASH' => 'Contanti',
    'BANK_TRANSFER' => 'Bonifico bancario',
    _ => null,
  };
}

Set<String> _upperCaseRoles(PersonItem person)
{
  return person.roles.map((role) => role.toUpperCase()).toSet();
}

String _adminRoleText(PersonItem person)
{
  final role = person.adminRole;

  if (role == null)
  {
    return missingValue;
  }

  if (role == _otherOptionCode || role.toUpperCase() == 'ALTRO')
  {
    return orDash(person.adminOtherRole);
  }

  return _adminRoleLabel(role) ?? role;
}

int? _grossCompensationCents(PersonItem person)
{
  final String? raw = person.grossCompensation;

  return raw == null ? null : parseAmountCents(raw);
}

// Mirrors the wizard: only a parent who did not join is never asked how they pay.
bool _wasEverAskedToPay(PersonItem person)
{
  final Set<String> roles = _upperCaseRoles(person);
  final Set<String> active = roles.difference(const {'ASSOCIATO'});

  return !(active.length == 1 &&
      active.contains('GENITORE') &&
      !roles.contains('ASSOCIATO'));
}

String _paymentMethodText(PersonItem person)
{
  final method = person.paymentMethod;

  if (method == null)
  {
    return missingValue;
  }

  if (method == _otherOptionCode)
  {
    return orDash(person.paymentMethodOther);
  }

  return _paymentMethodLabel(method) ?? method;
}

const String _listSeparator = ' – ';

// Null when no certification is declared, so the row can be omitted.
String? _certificationText(PersonItem person)
{
  if (person.certificationTypes.isEmpty)
  {
    return null;
  }

  return person.certificationTypes
      .map((type) =>
          type == _otherOptionCode ? orDash(person.certificationOtherDetail) : type)
      .join(_listSeparator);
}

String _residenceAddress(PersonItem person)
{
  final joined =
      '${person.residenceType?.trim() ?? ''} ${person.address?.trim() ?? ''}'.trim();

  return joined.isEmpty ? missingValue : joined;
}

String _earlyExitPeriodText(PersonItem person)
{
  final DateTime? from = person.earlyExitStartDate;
  final DateTime? to = person.earlyExitEndDate;

  if (from == null || to == null)
  {
    return 'Tutto il periodo di iscrizione';
  }

  return 'Dal ${_formatDate(from)} al ${_formatDate(to)}';
}

// The days label the row; the time and the reason are its value.
List<DetailRowData> _earlyExitRows(PersonItem person)
{
  final bool? authorized = person.earlyExit;

  return [
    DetailRowData(
      'Autorizzata',
      authorized == null ? missingValue : (authorized ? 'Sì' : 'No'),
    ),
    if (authorized ?? false) ...[
      DetailRowData('Validità', _earlyExitPeriodText(person)),
      for (final schedule
          in person.earlyExitSchedules ?? const <EarlyExitScheduleItem>[])
        DetailRowData(
          (schedule.weekdays.toList()..sort()).map(weekdayShortName).join(', '),
          '${formatTimeOfDayShort(schedule.exitTime)}$_listSeparator${schedule.reason}',
        ),
    ],
  ];
}

String _highSchoolStudentText(PersonItem person)
{
  final isHighSchoolStudent = person.isHighSchoolStudent;

  if (isHighSchoolStudent == null)
  {
    return missingValue;
  }

  return isHighSchoolStudent ? 'Sì' : 'No';
}

PersonDetailCard identityCard(PersonItem person, {Widget? leading})
{
  return PersonDetailCard(
    title: 'Identità',
    icon: Icons.badge_rounded,
    leading: leading,
    rows: [
      DetailRowData('Nome', person.firstName),
      DetailRowData('Cognome', person.lastName),
      DetailRowData('Sesso', orDash(person.gender)),
      DetailRowData('Codice fiscale', person.fiscalCode),
      null,
    ],
  );
}

PersonDetailCard residenceCard(PersonItem person)
{
  return PersonDetailCard(
    title: 'Residenza',
    icon: Icons.home_rounded,
    rows: [
      DetailRowData('Indirizzo', _residenceAddress(person)),
      DetailRowData('N°', orDash(person.addressNumber)),
      DetailRowData('Città', orDash(person.city)),
      DetailRowData('Provincia', orDash(person.province)),
      DetailRowData('CAP', orDash(person.zipCode)),
    ],
  );
}

PersonDetailCard birthCard(PersonItem person)
{
  final isBornAbroad = person.birthProvince == _abroadProvinceCode;

  return PersonDetailCard(
    title: 'Dati anagrafici',
    icon: Icons.cake_rounded,
    rows: [
      DetailRowData('Data di nascita', _formatDate(person.birthDate)),
      DetailRowData('Città di nascita', orDash(person.birthCity)),
      DetailRowData(
        isBornAbroad ? 'Nazione' : 'Provincia',
        orDash(isBornAbroad ? person.birthNation : person.birthProvince),
      ),
    ],
  );
}

PersonDetailCard contactsCard(PersonItem person)
{
  return PersonDetailCard(
    title: 'Contatti',
    icon: Icons.alternate_email_rounded,
    labelWidth: 110,
    rows: [
      DetailRowData('Email', orDash(person.email)),
      DetailRowData('Telefono', orDash(formatPhoneNumber(person.phoneNumber))),
      null,
    ],
  );
}

List<PersonDetailCard> personalDetailCards(PersonItem person)
{
  return [
    identityCard(person),
    birthCard(person),
    residenceCard(person),
    contactsCard(person),
  ];
}

// Null for a parent who did not join; shown even once the membership lapsed.
PersonDetailCard? paymentsCard(PersonItem person)
{
  if (!_wasEverAskedToPay(person))
  {
    return null;
  }

  final String? tariff = homeworkTariffLabel(person.homeworkTariff);

  return PersonDetailCard(
    title: 'Pagamenti',
    icon: Icons.payments_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [
      DetailRowData('Modalità', _paymentMethodText(person)),
      if (_upperCaseRoles(person).contains('STUDENTE'))
        DetailRowData('Tariffa', tariff ?? missingValue),
    ],
  );
}

PersonDetailCard collaborationCard(PersonItem person)
{
  final int? cents = _grossCompensationCents(person);

  return PersonDetailCard(
    title: 'Dettagli collaborazione',
    icon: Icons.account_balance_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [
      DetailRowData('Tipo collaborazione', orDash(person.collaborationType)),
      if (person.collaborationType == 'Retribuito') ...[
        DetailRowData(
          'Compenso orario lordo',
          cents == null ? missingValue : formatAmount(cents),
        ),
        DetailRowData(
          'Compenso orario netto',
          cents == null ? missingValue : formatAmount(netOfCents(cents)),
        ),
      ],
      DetailRowData('IBAN', orDash(person.iban), isSensitive: true),
    ],
  );
}

PersonDetailCard adminDetailsCard(PersonItem person)
{
  return PersonDetailCard(
    title: 'Dettagli amministratore',
    icon: Icons.computer_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [DetailRowData('Ruolo', _adminRoleText(person))],
  );
}

// forOwner hides rating and high-school rows; the server sends the rating to admins only.
PersonDetailCard teacherDetailsCard(PersonItem person, {bool forOwner = false})
{
  return PersonDetailCard(
    title: 'Dettagli docente',
    icon: Icons.school_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [
      if (!forOwner && person.teacherRating != null)
        DetailRowData.drawn(
          'Valutazione',
          TeacherRatingDots(value: person.teacherRating!),
        ),
      if (!forOwner)
        DetailRowData('Studente delle superiori', _highSchoolStudentText(person)),
      DetailRowData('Studi scolastici', orDash(person.schoolEducation)),
      if (person.isHighSchoolStudent != true)
        DetailRowData('Studi universitari', orDash(person.universityEducation)),
    ],
  );
}

List<PersonDetailCard> roleDetailCards(
  PersonItem person, {
  bool includeTeacherDetails = true,
})
{
  final roles = _upperCaseRoles(person);
  final cards = <PersonDetailCard>[];

  if (paymentsCard(person) case final PersonDetailCard payments)
  {
    cards.add(payments);
  }

  final isStaff = roles.contains('AMMINISTRATORE') ||
      roles.contains('DOCENTE') ||
      roles.contains('PSICOLOGO');

  if (isStaff)
  {
    cards.add(collaborationCard(person));
  }

  if (roles.contains('AMMINISTRATORE'))
  {
    cards.add(adminDetailsCard(person));
  }

  if (roles.contains('DOCENTE') && includeTeacherDetails)
  {
    cards.add(teacherDetailsCard(person));
  }

  if (roles.contains('STUDENTE'))
  {
    cards.addAll(pupilDetailCards(person));
  }

  if (roles.contains('CORSISTA'))
  {
    cards.add(PersonDetailCard(
      title: 'Dettagli corsista',
      icon: Icons.self_improvement_rounded,
      labelWidth: kPersonWideCardLabelWidth,
      rows: [
        DetailRowData('Tipo corso', orDash(person.courseType)),
        DetailRowData(
          'Scadenza certificato',
          _formatDate(person.medicalCertificateExpiration),
        ),
      ],
    ));
  }

  if (!person.isAdult)
  {
    cards.add(minorSafetyCard(person));
  }

  return cards;
}

List<PersonDetailCard> pupilDetailCards(PersonItem person)
{
  final certification = _certificationText(person);

  final List<DetailRowData> certificationRows = [
    if (certification != null)
      DetailRowData('Tipologia', certification, isSensitive: true, hidesLength: true),
    if (person.certificationTypes.contains(_dsaOptionCode))
      DetailRowData(
        'Tipo di DSA',
        orDash(person.certificationDsaDetail),
        isSensitive: true,
        hidesLength: true,
      ),
  ];

  return [
    if (certificationRows.isNotEmpty)
      PersonDetailCard(
        title: 'Certificazioni',
        icon: Icons.assignment_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: certificationRows,
      ),
    if (!person.isAdult)
      PersonDetailCard(
        title: 'Uscita anticipata',
        icon: Icons.logout_rounded,
        labelWidth: kPersonWideCardLabelWidth,
        rows: _earlyExitRows(person),
      ),
  ];
}

PersonDetailCard minorSafetyCard(PersonItem person)
{
  return PersonDetailCard(
    title: 'Sicurezza del minore',
    icon: Icons.health_and_safety_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [
      DetailRowData('Contatto emergenza', orDash(person.emergencyContactName)),
      DetailRowData('Telefono emergenza', orDash(formatPhoneNumber(person.emergencyContactPhone))),
      DetailRowData('Allergie / intolleranze', orDash(person.allergiesNotes)),
      DetailRowData('Farmaci / note', orDash(person.medicationsNotes)),
    ],
  );
}
