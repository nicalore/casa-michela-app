import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/phone_number.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/teacher_rating_dots.dart';

const int _adultAge = 18;

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

  bool get _isAdult => person.age != null && person.age! >= _adultAge;

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

  String get _earlyExitText
  {
    if (_isAdult)
    {
      return 'Autorizzata';
    }

    final earlyExit = person.earlyExit;

    if (earlyExit == null)
    {
      return missingValue;
    }

    return earlyExit ? 'Autorizzata' : 'Non autorizzata';
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

    if (roles.contains('STUDENTE') || roles.contains('CORSISTA'))
    {
      cards.add(PersonDetailCard(
        title: 'Modalità di pagamento',
        icon: Icons.payments_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: [DetailRowData('Modalità', _paymentMethodText)],
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

      cards.add(PersonDetailCard(
        title: 'Dettagli studente',
        icon: Icons.menu_book_outlined,
        labelWidth: kPersonWideCardLabelWidth,
        rows: [
          DetailRowData('Uscita anticipata', _earlyExitText),
          if (certification != null)
            DetailRowData('Certificazione', certification, isSensitive: true),
          if (person.certificationTypes.contains(_dsaOptionCode))
            DetailRowData(
              'Tipo di DSA',
              orDash(person.certificationDsaDetail),
              isSensitive: true,
            ),
        ],
      ));
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

    if (!_isAdult)
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