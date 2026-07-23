import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/person_item.dart';
import '../person_wizard_components.dart';
import '../widgets/person_detail_widgets.dart';

const int _adultAge = 18;

// Convention of the backend: an empty birth province means born abroad, and the
// nation is shown in its place.
const String _abroadProvinceCode = 'EE';

const String _otherOptionCode = 'OTHER';

String _formatDate(DateTime? date)
{
  return date == null ? missingValue : DateFormat('dd/MM/yyyy').format(date);
}

// Both the backend code and the already translated label are accepted, because
// the two forms are not consistent across endpoints.
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

  const PersonInfoTab({
    super.key,
    required this.person,
    required this.onEdit,
  });

  bool get _isAdult => person.age != null && person.age! >= _adultAge;

  Set<String> get _upperCaseRoles => person.roles.map((role) => role.toUpperCase()).toSet();

  // When the value is "other" the free text is shown directly, without the word
  // "Altro" in front of it.
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

  // Null when no certification is declared, so the row can be omitted entirely
  // rather than shown as a dash.
  String? get _certificationText
  {
    final type = person.certificationType;

    if (type == null)
    {
      return null;
    }

    return type == _otherOptionCode ? orDash(person.certificationOtherDetail) : type;
  }

  // Type and street name are stored apart but read as one line.
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
          DetailRowData('Telefono', orDash(person.phoneNumber)),
          null,
        ],
      ),
    );
  }

  Widget _buildFullWidthCard(PersonDetailCard card)
  {
    return SizedBox(width: double.infinity, child: card);
  }

  // Cards that only make sense for some roles or ages. Each entry is built lazily
  // by the caller and null ones are dropped, so the spacing between them stays
  // consistent whatever combination applies.
  List<Widget> _buildRoleSpecificCards()
  {
    final roles = _upperCaseRoles;
    final cards = <PersonDetailCard>[];

    if (roles.contains('STUDENTE') || roles.contains('CORSISTA'))
    {
      cards.add(PersonDetailCard(
        title: 'Modalità di Pagamento',
        icon: Icons.payments_outlined,
        labelWidth: 205,
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
        labelWidth: 205,
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
        labelWidth: 205,
        rows: [DetailRowData('Ruolo', _adminRoleText)],
      ));
    }

    if (roles.contains('DOCENTE'))
    {
      cards.add(PersonDetailCard(
        title: 'Dettagli docente',
        icon: Icons.school_outlined,
        labelWidth: 205,
        rows: [
          DetailRowData('Studi scolastici', orDash(person.schoolEducation)),
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
        labelWidth: 205,
        rows: [
          DetailRowData('Uscita anticipata', _earlyExitText),
          if (certification != null)
            DetailRowData('Certificazione', certification, isSensitive: true),
        ],
      ));
    }

    if (roles.contains('CORSISTA'))
    {
      cards.add(PersonDetailCard(
        title: 'Dettagli corsista',
        icon: Icons.self_improvement_rounded,
        labelWidth: 205,
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
        title: 'Sicurezza del Minore',
        icon: Icons.health_and_safety_outlined,
        labelWidth: 205,
        rows: [
          DetailRowData('Contatto emergenza', orDash(person.emergencyContactName)),
          DetailRowData('Telefono emergenza', orDash(person.emergencyContactPhone)),
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
            children: [
              _buildIdentityAndResidence(),
              const SizedBox(height: 24),
              _buildBirthAndContacts(),
              ..._buildRoleSpecificCards(),
              const SizedBox(height: 48),
              Center(
                child: SizedBox(
                  width: 255,
                  child: WizardAnimatedActionButton(
                    text: 'MODIFICA ANAGRAFICA',
                    icon: Icons.edit_rounded,
                    baseColor: AppTheme.primary,
                    hoverColor: AppTheme.primaryHover,
                    onPressed: onEdit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}