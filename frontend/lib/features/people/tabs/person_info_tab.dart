import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/person_item.dart';
import '../person_wizard_components.dart';

//BelowThisWidth_TheTwoSideBySideCardsStackVertically_InsteadOfBeingSqueezedNarrow
const double _kCardPairBreakpoint = 820.0;

class PersonInfoTab extends StatelessWidget 
{
  final PersonItem   person;
  final VoidCallback onEdit;

  const PersonInfoTab({
    super.key,
    required this.person,
    required this.onEdit,
  });

  String _getAdminRoleText(PersonItem person) 
  {
    final role = person.adminRole;
    
    if (role == null) 
    {
      return '-';
    }
    
    if (role == 'OTHER' || role.toUpperCase() == 'ALTRO') 
    {
      return person.adminOtherRole ?? '-';
    }
    
    if (role == 'PRESIDENT' || role == 'Presidente') 
    {
      return 'Presidente';
    }
    
    if (role == 'VICE_PRESIDENT' || role == 'Vicepresidente') 
    {
      return 'Vicepresidente';
    }
    
    if (role == 'TREASURER' || role == 'Tesoriere') 
    {
      return 'Tesoriere';
    }
    
    return role;
  }

  bool _isAdult(DateTime? birthDate)
  {
    if (birthDate == null) 
    {
      return false;
    }
    
    final now = DateTime.now();
    int   age = now.year - birthDate.year;
    
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) 
    {
      age--;
    }
    
    return age >= 18;
  }

  @override
  Widget build(BuildContext context) 
  {
    final String nome           = person.firstName;
    final String cognome        = person.lastName;
    final String sesso          = person.gender ?? '-';
    final String email          = person.email ?? '-';
    final String telefono       = person.phoneNumber ?? '-';
    final String dataNascita    = person.birthDate != null ? DateFormat('dd/MM/yyyy').format(person.birthDate!) : '-';
    final String cittaNascita   = person.birthCity ?? '-';
    final String provNascita    = person.birthProvince ?? '-';
    
    final String tipoVia        = person.residenceType?.trim() ?? '';
    final String nomeVia        = person.address?.trim() ?? '';
    final String indirizzo      = '$tipoVia $nomeVia'.trim().isNotEmpty ? '$tipoVia $nomeVia'.trim() : '-';
    final String civico         = person.addressNumber ?? '-';
    final String cittaResidenza = person.city ?? '-';
    final String provResidenza  = person.province ?? '-';
    final String cap            = person.zipCode ?? '-';

    final Set<String> roles       = person.roles.map((r) => r.toUpperCase()).toSet();
    final bool        isStaff     = roles.contains('AMMINISTRATORE') || roles.contains('DOCENTE') || roles.contains('PSICOLOGO');
    final bool        maggiorenne = _isAdult(person.birthDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top:    16,
        left:   0,
        right:  0,
        bottom: 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResponsiveCardPair(
                first: _InfoSectionCard(
                  title:       'Identità',
                  labelWidth:  160,
                  leadingIcon: const _StaticAvatar(icon: Icons.badge_rounded),
                  rows: [
                    _InfoRowData('Nome',           nome),
                    _InfoRowData('Cognome',        cognome),
                    _InfoRowData('Sesso',          sesso),
                    _InfoRowData('Codice fiscale', person.fiscalCode),
                    null,
                  ],
                ),
                second: _InfoSectionCard(
                  title:       'Residenza',
                  labelWidth:  110,
                  leadingIcon: const _StaticAvatar(icon: Icons.home_rounded),
                  rows: [
                    _InfoRowData('Indirizzo', indirizzo),
                    _InfoRowData('N°',        civico),
                    _InfoRowData('Città',     cittaResidenza),
                    _InfoRowData('Provincia', provResidenza),
                    _InfoRowData('CAP',       cap),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ResponsiveCardPair(
                first: _InfoSectionCard(
                  title:       'Dati anagrafici',
                  labelWidth:  160,
                  leadingIcon: const _StaticAvatar(icon: Icons.cake_rounded),
                  rows: [
                    _InfoRowData('Data di nascita',  dataNascita),
                    _InfoRowData('Città di nascita', cittaNascita),
                    _InfoRowData('Provincia',        provNascita),
                  ],
                ),
                second: _InfoSectionCard(
                  title:       'Contatti',
                  labelWidth:  110,
                  leadingIcon: const _StaticAvatar(icon: Icons.alternate_email_rounded),
                  rows: [
                    _InfoRowData('Email',    email),
                    _InfoRowData('Telefono', telefono),
                    null,
                  ],
                ),
              ),
              
              if (isStaff) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _InfoSectionCard(
                    title:       'Dettagli collaborazione',
                    labelWidth:  205,
                    leadingIcon: const _StaticAvatar(icon: Icons.account_balance_outlined),
                    rows: [
                      _InfoRowData('Tipo collaborazione', person.collaborationType ?? '-'),
                      //IbanNascostoDiDefault_MostratoSoloAlTapSull'iconaOcchio_VediIsSensitiveInInfoRowData
                      _InfoRowData(
                        'IBAN',
                        person.iban?.isNotEmpty == true ? person.iban! : '-',
                        isSensitive: true,
                      ),
                    ],
                  ),
                ),
              ],

              if (roles.contains('AMMINISTRATORE')) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _InfoSectionCard(
                    title:       'Dettagli amministratore',
                    labelWidth:  205,
                    leadingIcon: const _StaticAvatar(icon: Icons.computer_outlined),
                    rows: [
                      _InfoRowData('Ruolo', _getAdminRoleText(person)),
                    ],
                  ),
                ),
              ],

              if (roles.contains('DOCENTE')) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _InfoSectionCard(
                    title:       'Dettagli docente',
                    labelWidth:  205,
                    leadingIcon: const _StaticAvatar(icon: Icons.school_outlined),
                    rows: [
                      _InfoRowData('Studi scolastici',   person.schoolEducation?.isNotEmpty == true ? person.schoolEducation! : '-'),
                      _InfoRowData('Studi universitari', person.universityEducation?.isNotEmpty == true ? person.universityEducation! : '-'),
                    ],
                  ),
                ),
              ],

              if (roles.contains('STUDENTE')) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _InfoSectionCard(
                    title:       'Dettagli studente',
                    labelWidth:  205,
                    leadingIcon: const _StaticAvatar(icon: Icons.menu_book_outlined),
                    rows: [
                      _InfoRowData(
                        'Uscita anticipata', 
                        maggiorenne 
                            ? 'Autorizzata' 
                            : (person.earlyExit == null ? '-' : (person.earlyExit! ? 'Autorizzata' : 'Non autorizzata')),
                      ),
                    ],
                  ),
                ),
              ],

              if (roles.contains('CORSISTA')) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _InfoSectionCard(
                    title:       'Dettagli corsista',
                    labelWidth:  205,
                    leadingIcon: const _StaticAvatar(icon: Icons.self_improvement_rounded),
                    rows: [
                      _InfoRowData('Tipo corso',            person.courseType?.isNotEmpty == true ? person.courseType! : '-'),
                      _InfoRowData('Scadenza cert. medico', person.medicalCertificateExpiration != null ? DateFormat('dd/MM/yyyy').format(person.medicalCertificateExpiration!) : '-'),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),
              Center(
                child: SizedBox(
                  width: 255,
                  child: WizardAnimatedActionButton(
                    text:       'MODIFICA ANAGRAFICA',
                    icon:       Icons.edit_rounded,
                    baseColor:  const Color(0xFF003C82),
                    hoverColor: const Color(0xFF004D99),
                    onPressed:  onEdit,
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

//DecidesBetweenSideBySideAndStackedLayout_BasedOnActualAvailableWidth
class _ResponsiveCardPair extends StatelessWidget
{
  final Widget first;
  final Widget second;
  final double breakpoint;

  const _ResponsiveCardPair({
    required this.first,
    required this.second,
    this.breakpoint = _kCardPairBreakpoint,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: 24),
              second,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first),
              const SizedBox(width: 24),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}

class _InfoSectionCard extends StatelessWidget 
{
  final String               title;
  final Widget               leadingIcon;
  final double               labelWidth;
  final List<_InfoRowData?>? rows;

  const _InfoSectionCard({
    required this.title,
    required this.leadingIcon,
    this.labelWidth = 160,
    this.rows,
  });

  List<Widget> _buildRows() 
  {
    if (rows == null) 
    {
      return const [];
    }
    
    final List<Widget> widgets = [];
    
    for (int i = 0; i < rows!.length; i++) 
    {
      final bool          isLast  = i == rows!.length - 1;
      final _InfoRowData? rowData = rows![i];
      
      Widget rowWidget;
      
      if (rowData == null) 
      {
        rowWidget = Opacity(
          opacity: 0.0,
          child:   _InfoRow(
            label:      '-',
            value:      '-',
            labelWidth: labelWidth,
          ),
        );
      } 
      else if (rowData.isSensitive)
      {
        //RigaMascherataDiDefault_ToggleGestitoInternamenteDaObscurableInfoRow
        rowWidget = _ObscurableInfoRow(
          label:      rowData.label,
          value:      rowData.value,
          labelWidth: labelWidth,
        );
      }
      else 
      {
        rowWidget = _InfoRow(
          label:      rowData.label,
          value:      rowData.value,
          labelWidth: labelWidth,
        );
      }
      
      if (!isLast) 
      {
        rowWidget = Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child:   rowWidget,
        );
      }
      
      widgets.add(rowWidget);
    }
    
    return widgets;
  }

  @override
  Widget build(BuildContext context) 
  {
    return SelectionArea(
      child: Container(
        padding:    const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow:    const [
            BoxShadow(
              color:      Color(0x0A000000),
              offset:     Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leadingIcon,
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   26,
                        fontWeight: FontWeight.w700,
                        color:      const Color(0xFF003C82),
                        height:     1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child:   Divider(
                height:    1,
                thickness: 1,
                color:     Color(0xFFF1F5F9),
              ),
            ),
            Flexible(
              child: Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children:           _buildRows(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticAvatar extends StatelessWidget 
{
  final IconData icon;

  const _StaticAvatar({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) 
  {
    return Container(
      width:  90,
      height: 90,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EEF7),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size:  44,
        color: const Color(0xFF003C82),
      ),
    );
  }
}

//RevertedToTheSimpleFixedLabel+ExpandedValueStructure
//NoLayoutBuilderHere_ItWouldConflictWithTheAncestorIntrinsicHeightInResponsiveCardPair
//SafeBecause_ResponsiveCardPairAlreadyGuaranteesAdequateWidthBeforeTheseCardsSitSideBySide
class _InfoRow extends StatelessWidget 
{
  final String label;
  final String value;
  final double labelWidth;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.labelWidth,
  });

  @override
  Widget build(BuildContext context) 
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth, 
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w500,
              color:      const Color(0xFF7A7A7A),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w600,
              color:      const Color(0xFF2A2A2A),
            ),
          ),
        ),
      ],
    );
  }
}

//StessaLogicaDelToggleUsataInLoginTextField_MaStatoLocaleAllaSingolaRigaInveceCheAlCampoDiInput
//DefaultNascosto__isVisibleParteFalse_ComeRichiesto
class _ObscurableInfoRow extends StatefulWidget
{
  final String label;
  final String value;
  final double labelWidth;

  const _ObscurableInfoRow({
    required this.label,
    required this.value,
    required this.labelWidth,
  });

  @override
  State<_ObscurableInfoRow> createState() => _ObscurableInfoRowState();
}

class _ObscurableInfoRowState extends State<_ObscurableInfoRow>
{
  bool _isVisible = false;

  //NessunaIconaDaMostrareSeIlValoreEAssente_NonHaSensoUnToggleSuUnTrattino
  bool get _hasValue => widget.value.isNotEmpty && widget.value != '-';

  //SostituisceOgniCarattereNonSpazioConUnPallino_CosìLaStrutturaAGruppiRestaLeggibile
  String get _maskedValue => widget.value.replaceAll(RegExp(r'[^\s]'), '•');

  @override
  Widget build(BuildContext context)
  {
    final String displayValue = !_hasValue
        ? widget.value
        : (_isVisible ? widget.value : _maskedValue);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.labelWidth,
          child: Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w500,
              color:      const Color(0xFF7A7A7A),
            ),
          ),
        ),
        Expanded(
          child: Text(
            displayValue,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w600,
              color:      const Color(0xFF2A2A2A),
              letterSpacing: (_hasValue && !_isVisible) ? 3 : 0,
            ),
          ),
        ),
        if (_hasValue)
          IconButton(
            onPressed: ()
            {
              setState(()
              {
                _isVisible = !_isVisible;
              });
            },
            splashColor:    Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor:     Colors.transparent,
            focusColor:     Colors.transparent,
            padding:        EdgeInsets.zero,
            constraints:    const BoxConstraints(),
            icon: Icon(
              _isVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size:  22,
              color: const Color(0xFF6B7280),
            ),
          ),
      ],
    );
  }
}

class _InfoRowData 
{
  final String label;
  final String value;
  final bool   isSensitive;

  const _InfoRowData(this.label, this.value, {this.isSensitive = false});
}