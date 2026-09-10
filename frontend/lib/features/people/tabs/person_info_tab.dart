import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../models/early_exit_schedule_item.dart';
import '../edit/homework_tariffs.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/teacher_rating_dots.dart';

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

class PersonInfoTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onEdit;

  // Null when the person has no enrollment form to generate.
  final VoidCallback? onGenerateForm;

  final bool isGeneratingForm;

  const PersonInfoTab({
    super.key,
    required this.person,
    required this.onEdit,
    this.onGenerateForm,
    this.isGeneratingForm = false,
  });

  Set<String> get _upperCaseRoles => person.roles.map((role) => role.toUpperCase()).toSet();

  String get _adminRoleText
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

  int? get _grossCompensationCents
  {
    final String? raw = person.grossCompensation;

    return raw == null ? null : parseAmountCents(raw);
  }

  String get _grossCompensationText
  {
    final int? cents = _grossCompensationCents;

    return cents == null ? missingValue : formatAmount(cents);
  }

  // Not stored: a fifth off the gross, worked out for whoever is reading.
  String get _netCompensationText
  {
    final int? cents = _grossCompensationCents;

    return cents == null ? missingValue : formatAmount(netOfCents(cents));
  }

  // Mirrors the wizard: only a parent who did not join is never asked how they pay.
  bool get _wasEverAskedToPay
  {
    final Set<String> roles = _upperCaseRoles;
    final Set<String> active = roles.difference(const {'ASSOCIATO'});

    return !(active.length == 1 &&
        active.contains('GENITORE') &&
        !roles.contains('ASSOCIATO'));
  }

  String get _paymentMethodText
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

  // Null when no certification is declared, so the row can be omitted.
  String? get _certificationText
  {
    if (person.certificationTypes.isEmpty)
    {
      return null;
    }

    return person.certificationTypes
        .map((type) =>
            type == _otherOptionCode ? orDash(person.certificationOtherDetail) : type)
        .join(', ');
  }

  String get _residenceAddress
  {
    final joined =
        '${person.residenceType?.trim() ?? ''} ${person.address?.trim() ?? ''}'.trim();

    return joined.isEmpty ? missingValue : joined;
  }

  String get _earlyExitPeriodText
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
  List<DetailRowData> get _earlyExitRows
  {
    final bool? authorized = person.earlyExit;

    return [
      DetailRowData(
        'Autorizzata',
        authorized == null ? missingValue : (authorized ? 'Sì' : 'No'),
      ),
      if (authorized ?? false) ...[
        DetailRowData('Validità', _earlyExitPeriodText),
        for (final schedule
            in person.earlyExitSchedules ?? const <EarlyExitScheduleItem>[])
          DetailRowData(
            (schedule.weekdays.toList()..sort()).map(weekdayShortName).join(', '),
            '${formatTimeOfDayShort(schedule.exitTime)} · ${schedule.reason}',
          ),
      ],
    ];
  }

  String get _highSchoolStudentText
  {
    final isHighSchoolStudent = person.isHighSchoolStudent;

    if (isHighSchoolStudent == null)
    {
      return missingValue;
    }

    return isHighSchoolStudent ? 'Sì' : 'No';
  }

  Widget _buildIdentityAndResidence()
  {
    return PersonDetailCardPair(
      first: PersonDetailCard(
        title: 'Identità',
        icon: Icons.badge_rounded,
        rows: [
          DetailRowData('Nome', person.firstName),
          DetailRowData('Cognome', person.lastName),
          DetailRowData('Sesso', orDash(person.gender)),
          DetailRowData('Codice fiscale', person.fiscalCode),
          null,
        ],
      ),
      second: PersonDetailCard(
        title: 'Residenza',
        icon: Icons.home_rounded,
        rows: [
          DetailRowData('Indirizzo', _residenceAddress),
          DetailRowData('N°', orDash(person.addressNumber)),
          DetailRowData('Città', orDash(person.city)),
          DetailRowData('Provincia', orDash(person.province)),
          DetailRowData('CAP', orDash(person.zipCode)),
        ],
      ),
    );
  }

  Widget _buildBirthAndContacts()
  {
    final isBornAbroad = person.birthProvince == _abroadProvinceCode;

    return PersonDetailCardPair(
      first: PersonDetailCard(
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
      ),
      second: PersonDetailCard(
        title: 'Contatti',
        icon: Icons.alternate_email_rounded,
        labelWidth: 110,
        rows: [
          DetailRowData('Email', orDash(person.email)),
          DetailRowData('Telefono', orDash(formatPhoneNumber(person.phoneNumber))),
          null,
        ],
      ),
    );
  }

  Widget _buildFullWidthCard(PersonDetailCard card)
  {
    return SizedBox(width: double.infinity, child: card);
  }

  List<Widget> _buildRoleSpecificCards()
  {
    final roles = _upperCaseRoles;
    final cards = <PersonDetailCard>[];

    // Shown whether or not the membership still stands, even once the wizard stops asking.
    if (_wasEverAskedToPay)
    {
      final String? tariff = homeworkTariffLabel(person.homeworkTariff);

      cards.add(PersonDetailCard(
        title: 'Pagamenti',
        icon: Icons.payments_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: [
          DetailRowData('Modalità', _paymentMethodText),
          if (roles.contains('STUDENTE'))
            DetailRowData('Tariffa', tariff ?? missingValue),
        ],
      ));
    }

    final isStaff = roles.contains('AMMINISTRATORE') ||
        roles.contains('DOCENTE') ||
        roles.contains('PSICOLOGO');

    if (isStaff)
    {
      cards.add(PersonDetailCard(
        title: 'Dettagli collaborazione',
        icon: Icons.account_balance_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: [
          DetailRowData('Tipo collaborazione', orDash(person.collaborationType)),
          // Only a paid collaboration has a compensation.
          if (person.collaborationType == 'Retribuito') ...[
            DetailRowData('Compenso orario lordo', _grossCompensationText),
            DetailRowData('Compenso orario netto', _netCompensationText),
          ],
          DetailRowData('IBAN', orDash(person.iban), isSensitive: true),
        ],
      ));
    }

    if (roles.contains('AMMINISTRATORE'))
    {
      cards.add(PersonDetailCard(
        title: 'Dettagli amministratore',
        icon: Icons.computer_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: [DetailRowData('Ruolo', _adminRoleText)],
      ));
    }

    if (roles.contains('DOCENTE'))
    {
      cards.add(PersonDetailCard(
        title: 'Dettagli docente',
        icon: Icons.school_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: [
          // Only admins receive the rating from the server.
          if (person.teacherRating != null)
            DetailRowData.drawn(
              'Valutazione',
              TeacherRatingDots(value: person.teacherRating!),
            ),
          DetailRowData('Studente delle superiori', _highSchoolStudentText),
          DetailRowData('Studi scolastici', orDash(person.schoolEducation)),
          if (person.isHighSchoolStudent != true)
            DetailRowData('Studi universitari', orDash(person.universityEducation)),
        ],
      ));
    }

    if (roles.contains('STUDENTE'))
    {
      final certification = _certificationText;

      final List<DetailRowData> certificationRows = [
        if (certification != null)
          DetailRowData('Tipologia', certification, isSensitive: true),
        if (person.certificationTypes.contains(_dsaOptionCode))
          DetailRowData(
            'Tipo di DSA',
            orDash(person.certificationDsaDetail),
            isSensitive: true,
          ),
      ];

      // A heading over an empty card reads as something that failed to load.
      if (certificationRows.isNotEmpty)
      {
        cards.add(PersonDetailCard(
          title: 'Certificazioni',
          icon: Icons.assignment_outlined,
          labelWidth: kPersonWideCardLabelWidth,
          rows: certificationRows,
        ));
      }

      // Leaving before the end of the day needs no permission once of age.
      if (!person.isAdult)
      {
        cards.add(PersonDetailCard(
          title: 'Uscita anticipata',
          icon: Icons.logout_rounded,
          labelWidth: kPersonWideCardLabelWidth,
          rows: _earlyExitRows,
        ));
      }
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
      cards.add(PersonDetailCard(
        title: 'Sicurezza del minore',
        icon: Icons.health_and_safety_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: [
          DetailRowData('Contatto emergenza', orDash(person.emergencyContactName)),
          DetailRowData('Telefono emergenza', orDash(formatPhoneNumber(person.emergencyContactPhone))),
          DetailRowData('Allergie / intolleranze', orDash(person.allergiesNotes)),
          DetailRowData('Farmaci / note', orDash(person.medicationsNotes)),
        ],
      ));
    }

    return [
      for (final card in cards) ...[
        const SizedBox(height: 24),
        _buildFullWidthCard(card),
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pageTransitionBlocks([
              _buildIdentityAndResidence(),
              const SizedBox(height: 24),
              _buildBirthAndContacts(),
              ..._buildRoleSpecificCards(),
              const SizedBox(height: 48),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    AppGradientButton(
                      label: 'MODIFICA ANAGRAFICA',
                      icon: Icons.edit_rounded,
                      onPressed: onEdit,
                    ),
                    if (onGenerateForm case final VoidCallback generate)
                      AppGradientButton(
                        label: 'GENERA DOCUMENTI DI ISCRIZIONE',
                        icon: Icons.picture_as_pdf_outlined,
                        busy: isGeneratingForm,
                        onPressed: generate,
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}