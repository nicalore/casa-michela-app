import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/language/app_language.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/week_range.dart';
import '../../psychologist/widgets/certifications_dialog.dart' show kCertificationLabels;
import '../models/early_exit_schedule_item.dart';
import '../models/person_item.dart';
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
String? _adminRoleLabel(String role, {required bool feminine})
{
  return switch (role)
  {
    'PRESIDENT' || 'Presidente' => tr('Presidente', 'President'),
    'VICE_PRESIDENT' || 'Vicepresidente' => tr('Vicepresidente', 'Vice president'),
    'TREASURER' || 'Tesoriere' => tr(feminine ? 'Tesoriera' : 'Tesoriere', 'Treasurer'),
    'IT_MANAGER' || 'Responsabile IT' => tr('Responsabile IT', 'IT manager'),
    _ => null,
  };
}

String? _paymentMethodLabel(String method)
{
  return switch (method)
  {
    'CASH' => tr('Contanti', 'Cash'),
    'BANK_TRANSFER' => tr('Bonifico bancario', 'Bank transfer'),
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

  return _adminRoleLabel(role, feminine: person.gender == 'F') ?? role;
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

  return person.certificationTypes.map((type) => switch (type)
  {
    _otherOptionCode => orDash(person.certificationOtherDetail),
    _dsaOptionCode => _dsaText(person),
    _ => kCertificationLabels[type] ?? type,
  }).join(_listSeparator);
}

// The disorder rides along on the same line: a hidden type next to a plain one hides nothing.
String _dsaText(PersonItem person)
{
  final String? detail = person.certificationDsaDetail;

  final String label = kCertificationLabels[_dsaOptionCode]!;

  return detail == null || detail.isEmpty ? label : '$label ($detail)';
}

// The server's own words; English shows its own.
String _collaborationTypeText(String? type) => switch (type)
{
  'Volontario' => tr('Volontario', 'Volunteer'),
  'Retribuito' => tr('Retribuito', 'Paid'),
  _ => orDash(type),
};

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
    return tr('Tutto il periodo di iscrizione', 'The whole enrolment period');
  }

  return tr('Dal ${_formatDate(from)} al ${_formatDate(to)}', 'From ${_formatDate(from)} to ${_formatDate(to)}');
}

// The days label the row; the time and the reason are its value.
List<DetailRowData> _earlyExitRows(PersonItem person)
{
  final bool? authorized = person.earlyExit;

  return [
    DetailRowData(
      tr('Autorizzata', 'Authorised'),
      authorized == null ? missingValue : (authorized ? tr('Sì', 'Yes') : 'No'),
    ),
    if (authorized ?? false) ...[
      DetailRowData(tr('Validità', 'Validity'), _earlyExitPeriodText(person)),
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

  return isHighSchoolStudent ? tr('Sì', 'Yes') : 'No';
}

PersonDetailCard identityCard(PersonItem person, {Widget? leading})
{
  return PersonDetailCard(
    title: tr('Identità', 'Identity'),
    icon: Icons.badge_rounded,
    leading: leading,
    rows: [
      DetailRowData(tr('Nome', 'First name'), person.firstName),
      DetailRowData(tr('Cognome', 'Last name'), person.lastName),
      DetailRowData(tr('Sesso', 'Sex'), orDash(person.gender)),
      DetailRowData(tr('Codice fiscale', 'Tax code'), person.fiscalCode),
      null,
    ],
  );
}

PersonDetailCard residenceCard(PersonItem person)
{
  return PersonDetailCard(
    title: tr('Residenza', 'Residence'),
    icon: Icons.home_rounded,
    rows: [
      DetailRowData(tr('Indirizzo', 'Address'), _residenceAddress(person)),
      DetailRowData(tr('N°', 'No.'), orDash(person.addressNumber)),
      DetailRowData(tr('Città', 'City'), orDash(person.city)),
      DetailRowData(tr('Provincia', 'Province'), orDash(person.province)),
      DetailRowData(tr('CAP', 'Postcode'), orDash(person.zipCode)),
    ],
  );
}

PersonDetailCard birthCard(PersonItem person)
{
  final isBornAbroad = person.birthProvince == _abroadProvinceCode;

  return PersonDetailCard(
    title: tr('Dati anagrafici', 'Birth details'),
    icon: Icons.cake_rounded,
    rows: [
      DetailRowData(tr('Data di nascita', 'Date of birth'), _formatDate(person.birthDate)),
      DetailRowData(tr('Città di nascita', 'City of birth'), orDash(person.birthCity)),
      DetailRowData(
        isBornAbroad ? tr('Nazione', 'Country') : tr('Provincia', 'Province'),
        orDash(isBornAbroad ? person.birthNation : person.birthProvince),
      ),
    ],
  );
}

PersonDetailCard contactsCard(PersonItem person)
{
  return PersonDetailCard(
    title: tr('Contatti', 'Contacts'),
    icon: Icons.alternate_email_rounded,
    labelWidth: 110,
    rows: [
      DetailRowData('Email', orDash(person.email)),
      DetailRowData(tr('Telefono', 'Phone'), orDash(formatPhoneNumber(person.phoneNumber))),
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

// Null for a parent who did not join, and for a pupil, whose «Pagamenti» tab says it;
// shown even once the membership lapsed.
PersonDetailCard? paymentsCard(PersonItem person)
{
  if (!_wasEverAskedToPay(person) || _upperCaseRoles(person).contains('STUDENTE'))
  {
    return null;
  }

  return PersonDetailCard(
    title: tr('Pagamenti', 'Payments'),
    icon: Icons.payments_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [
      DetailRowData(tr('Modalità', 'Method'), _paymentMethodText(person)),
    ],
  );
}

PersonDetailCard collaborationCard(PersonItem person)
{
  final int? cents = _grossCompensationCents(person);
  final String iban = orDash(person.iban);

  return PersonDetailCard(
    title: tr('Dettagli collaborazione', 'Collaboration details'),
    icon: Icons.account_balance_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [
      DetailRowData(tr('Tipo collaborazione', 'Collaboration type'), _collaborationTypeText(person.collaborationType)),
      if (person.collaborationType == 'Retribuito') ...[
        DetailRowData(
          tr('Compenso orario lordo', 'Gross hourly pay'),
          cents == null ? missingValue : formatAmount(cents),
        ),
        DetailRowData(
          tr('Compenso orario netto', 'Net hourly pay'),
          cents == null ? missingValue : formatAmount(netOfCents(cents)),
        ),
      ],
      DetailRowData('IBAN', iban, isSensitive: iban != missingValue),
    ],
  );
}

PersonDetailCard adminDetailsCard(PersonItem person)
{
  return PersonDetailCard(
    title: tr(person.gender == 'F' ? 'Dettagli amministratrice' : 'Dettagli amministratore', 'Administrator details'),
    icon: Icons.computer_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [DetailRowData(tr('Ruolo', 'Role'), _adminRoleText(person))],
  );
}

// forOwner hides the high-school row.
PersonDetailCard teacherDetailsCard(PersonItem person, {bool forOwner = false})
{
  return PersonDetailCard(
    title: tr('Dettagli docente', 'Teacher details'),
    icon: Icons.school_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [
      if (!forOwner)
        DetailRowData(
          tr(
            person.gender == 'F' ? 'Studentessa delle superiori' : 'Studente delle superiori',
            'Upper secondary student',
          ),
          _highSchoolStudentText(person),
        ),
      DetailRowData(tr('Studi scolastici', 'School education'), orDash(person.schoolEducation)),
      if (person.isHighSchoolStudent != true)
        DetailRowData(tr('Studi universitari', 'University education'), orDash(person.universityEducation)),
    ],
  );
}

// [withCertifications]: false for the administrators, who have them in «Osservazioni».
// [inCompensi]: true where the Compensi tab, which a psychologist alone has not, says the collaboration.
// [withPayments]: false for the administrators, who have the way of paying in «Pagamenti».
List<PersonDetailCard> roleDetailCards(
  PersonItem person, {
  bool includeTeacherDetails = true,
  bool forOwner = false,
  bool withCertifications = true,
  bool inCompensi = false,
  bool withPayments = true,
})
{
  final roles = _upperCaseRoles(person);
  final cards = <PersonDetailCard>[];

  if (paymentsCard(person) case final PersonDetailCard payments when withPayments)
  {
    cards.add(payments);
  }

  final isStaff = roles.contains('AMMINISTRATORE') ||
      roles.contains('DOCENTE') ||
      roles.contains('PSICOLOGO');

  if (isStaff && !(inCompensi && (roles.contains('AMMINISTRATORE') || roles.contains('DOCENTE'))))
  {
    cards.add(collaborationCard(person));
  }

  if (roles.contains('AMMINISTRATORE'))
  {
    cards.add(adminDetailsCard(person));
  }

  if (roles.contains('DOCENTE') && includeTeacherDetails)
  {
    cards.add(teacherDetailsCard(person, forOwner: forOwner));
  }

  if (roles.contains('STUDENTE'))
  {
    cards.addAll(pupilDetailCards(person, forOwner: forOwner, withCertifications: withCertifications));
  }

  if (roles.contains('CORSISTA'))
  {
    cards.add(PersonDetailCard(
      title: tr('Dettagli corsista', 'Course participant details'),
      icon: Icons.self_improvement_rounded,
      labelWidth: kPersonWideCardLabelWidth,
      rows: [
        DetailRowData(tr('Tipo corso', 'Course type'), orDash(person.courseType)),
        DetailRowData(
          tr('Scadenza certificato', 'Certificate expiry'),
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

// [forOwner]: pupils are never shown their own certifications.
List<PersonDetailCard> pupilDetailCards(PersonItem person, {bool forOwner = false, bool withCertifications = true})
{
  final certification = forOwner || !withCertifications ? null : _certificationText(person);

  final List<DetailRowData> certificationRows = [
    if (certification != null)
      DetailRowData(tr('Tipologia', 'Type'), certification, isSensitive: true, hidesLength: true),
  ];

  return [
    if (certificationRows.isNotEmpty)
      PersonDetailCard(
        title: tr('Certificazioni', 'Certifications'),
        icon: Icons.assignment_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: certificationRows,
      ),
    if (!person.isAdult)
      PersonDetailCard(
        title: tr('Uscita anticipata', 'Early departure'),
        icon: Icons.logout_rounded,
        labelWidth: kPersonWideCardLabelWidth,
        rows: _earlyExitRows(person),
      ),
  ];
}

PersonDetailCard minorSafetyCard(PersonItem person)
{
  return PersonDetailCard(
    title: tr(person.gender == 'F' ? 'Sicurezza della minore' : 'Sicurezza del minore', 'Safety of the minor'),
    icon: Icons.health_and_safety_outlined,
    labelWidth: kPersonWideCardLabelWidth,
    rows: [
      DetailRowData(tr('Contatto emergenza', 'Emergency contact'), orDash(person.emergencyContactName)),
      DetailRowData(tr('Telefono emergenza', 'Emergency phone'), orDash(formatPhoneNumber(person.emergencyContactPhone))),
      DetailRowData(tr('Allergie / intolleranze', 'Allergies / intolerances'), orDash(person.allergiesNotes)),
      DetailRowData(tr('Farmaci / note', 'Medicines / notes'), orDash(person.medicationsNotes)),
    ],
  );
}
