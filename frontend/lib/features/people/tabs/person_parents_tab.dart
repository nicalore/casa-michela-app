import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/config/api_config.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../models/parent_item.dart';
import '../models/person_item.dart';
import '../person_wizard_components.dart';

class PersonParentsTab extends StatefulWidget {
  final PersonItem person;
  final VoidCallback onUpdate;
  //ChiamatoSoloDopoLaRimozioneDelleResponsabilitàGenitoriali_RiportaAllaTabInformazioniPersonali
  //PerchéIlTabGenitoriSparisceDallaListaEL'IndexedStackResterebbeAllaVecchiaPosizioneVuota
  final VoidCallback onResponsibilityRemoved;

  const PersonParentsTab({
    super.key,
    required this.person,
    required this.onUpdate,
    required this.onResponsibilityRemoved,
  });

  @override
  State<PersonParentsTab> createState() => _PersonParentsTabState();
}

class _PersonParentsTabState extends State<PersonParentsTab> {
  int _selectedParentIndex = 0;

  void _openParentSelectionDialog() async {
    final Set<String> currentParents =
        widget.person.parents?.map((p) => p.fiscalCode).toSet() ?? {};

    final Set<String>? newParents = await showGeneralDialog<Set<String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SelectParent',
      barrierColor: Colors.black.withValues(alpha: .5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (animation, secondaryAnimation, child) =>
          const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final blurValue = animation.value * 8.0;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
              child: _ParentSelectionDialog(
                childTaxCode: widget.person.fiscalCode,
                initialSelectedParents: currentParents,
              ),
            ),
          ),
        );
      },
    );

    if (newParents != null && mounted) {
      final added = newParents.difference(currentParents);
      final removed = currentParents.difference(newParents);

      if (added.isEmpty && removed.isEmpty) {
        return;
      }

      try {
        //ProcessRemovalsFirstToPreventLocks
        for (var c in removed) {
          await ApiService().removeParent(widget.person.fiscalCode, c);
        }
        for (var c in added) {
          await ApiService().addParent(widget.person.fiscalCode, c);
        }

        CustomSnackBar.show(
          context: context,
          message: 'Associazioni aggiornate con successo!',
          isError: false,
        );
        widget.onUpdate();
      } catch (e) {
        CustomSnackBar.show(
          context: context,
          message: e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  void _onRemoveResponsibilityTap() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rimuovi Responsabilità Genitoriali',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF003C82),
          ),
        ),
        content: Text(
          'Dopo la rimozione delle responsabilità genitoriali, questa persona gestirà autonomamente il proprio rapporto con l\'Associazione. L\'operazione è irreversibile.',
          style: GoogleFonts.plusJakartaSans(fontSize: 16),
        ),
        actions: [
          TextButton(
            style: ButtonStyle(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'ANNULLA',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            style: ButtonStyle(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                for (final parent in widget.person.parents!) {
                  await ApiService().removeParent(
                    widget.person.fiscalCode,
                    parent.fiscalCode,
                  );
                }
                CustomSnackBar.show(
                  context: context,
                  message: 'Responsabilità rimosse con successo.',
                  isError: false,
                );
                //NonPiuWidget.onUpdate()QuiI_LaTabGenitoriStaPerSparire_ServeIlRedirectEsplicito
                widget.onResponsibilityRemoved();
              } catch (e) {
                CustomSnackBar.show(
                  context: context,
                  message: e.toString().replaceAll('Exception: ', ''),
                  isError: true,
                );
              }
            },
            child: Text(
              'RIMUOVI',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFE53935),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavigation(List<ParentItem> parents) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(parents.length, (index) {
          final isSelected = _selectedParentIndex == index;
          final parent = parents[index];

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedParentIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF003C82) : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF003C82)
                        : const Color(0xFFE2E8F0),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF64748B),
                  ),
                  child: Text('${parent.firstName} ${parent.lastName}'),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ParentItem> parents = widget.person.parents ?? [];

    if (parents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nessun genitore associato a sistema.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: WizardAnimatedActionButton(
                  text: 'AGGIUNGI GENITORI',
                  icon: Icons.add_rounded,
                  baseColor: const Color(0xFF003C82),
                  hoverColor: const Color(0xFF004D99),
                  onPressed: _openParentSelectionDialog,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedParentIndex >= parents.length) {
      _selectedParentIndex = 0;
    }

    final ParentItem currentParent = parents[_selectedParentIndex];

    final String nome = currentParent.firstName;
    final String cognome = currentParent.lastName;
    final String sesso = currentParent.gender ?? '-';
    final String email = currentParent.email ?? '-';
    final String telefono = currentParent.phoneNumber ?? '-';
    final String dataNascita = currentParent.birthDate != null
        ? DateFormat('dd/MM/yyyy').format(currentParent.birthDate!)
        : '-';
    final String cittaNascita = currentParent.birthCity ?? '-';
    final String provNascita = currentParent.birthProvince ?? '-';

    final String tipoVia = currentParent.residenceType?.trim() ?? '';
    final String nomeVia = currentParent.address?.trim() ?? '';
    final String indirizzo = '$tipoVia $nomeVia'.trim().isNotEmpty
        ? '$tipoVia $nomeVia'.trim()
        : '-';
    final String civico = currentParent.addressNumber ?? '-';
    final String cittaResidenza = currentParent.city ?? '-';
    final String provResidenza = currentParent.province ?? '-';
    final String cap = currentParent.zipCode ?? '-';

    final bool isAdult = widget.person.age != null && widget.person.age! >= 18;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, left: 0, right: 0, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubNavigation(parents),
              _ResponsiveCardPair(
                first: _ParentSectionCard(
                  title: 'Identità',
                  leadingIcon: const _StaticAvatar(
                    icon: Icons.badge_rounded,
                  ),
                  rows: [
                    _InfoRowData('Nome', nome),
                    _InfoRowData('Cognome', cognome),
                    _InfoRowData('Sesso', sesso),
                    _InfoRowData(
                      'Codice fiscale',
                      currentParent.fiscalCode,
                    ),
                    null,
                  ],
                ),
                second: _ParentSectionCard(
                  title: 'Residenza',
                  leadingIcon: const _StaticAvatar(
                    icon: Icons.home_rounded,
                  ),
                  rows: [
                    _InfoRowData('Indirizzo', indirizzo),
                    _InfoRowData('N°', civico),
                    _InfoRowData('Città', cittaResidenza),
                    _InfoRowData('Provincia', provResidenza),
                    _InfoRowData('CAP', cap),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ResponsiveCardPair(
                first: _ParentSectionCard(
                  title: 'Dati anagrafici',
                  leadingIcon: const _StaticAvatar(
                    icon: Icons.cake_rounded,
                  ),
                  rows: [
                    _InfoRowData('Data di nascita', dataNascita),
                    _InfoRowData('Città di nascita', cittaNascita),
                    _InfoRowData('Provincia', provNascita),
                  ],
                ),
                second: _ParentSectionCard(
                  title: 'Contatti',
                  leadingIcon: const _StaticAvatar(
                    icon: Icons.alternate_email_rounded,
                  ),
                  rows: [
                    _InfoRowData('Email', email),
                    _InfoRowData('Telefono', telefono),
                    null,
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Center(
                child: _ResponsiveParentActionButtonsRow(
                  onModify: _openParentSelectionDialog,
                  onRemoveResponsibility:
                      isAdult ? _onRemoveResponsibilityTap : null,
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
//LayoutBuilderStaysOutsideIntrinsicHeight_NeverInside_SameFixAppliedInPersonInfoTab
class _ResponsiveCardPair extends StatelessWidget {
  final Widget first;
  final Widget second;
  final double breakpoint;

  const _ResponsiveCardPair({
    required this.first,
    required this.second,
    this.breakpoint = 820.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact) {
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

//DecideSoloSeAffiancareOImpilare_LaLARGHEZZADeiBottoniRestaSempreFissa_MaiStretch
//LaSceltaTraEtichettaLungaOCortaEStaticaPerModalitaDiLayout_NonRicalcolataAOgniResize
class _ResponsiveParentActionButtonsRow extends StatelessWidget {
  final VoidCallback onModify;
  final VoidCallback? onRemoveResponsibility;

  const _ResponsiveParentActionButtonsRow({
    required this.onModify,
    required this.onRemoveResponsibility,
  });

  static const double _kPrimaryWidth = 230;
  static const double _kSecondaryWidthSideBySide = 395;
  static const double _kSecondaryWidthStacked = 300;
  static const double _kSpacing = 16;
  static const double _kSideBySideBreakpoint =
      _kPrimaryWidth + _kSpacing + _kSecondaryWidthSideBySide + 40;

  @override
  Widget build(BuildContext context) {
    final Widget primaryButton = SizedBox(
      width: _kPrimaryWidth,
      child: WizardAnimatedActionButton(
        text: 'MODIFICA GENITORI',
        icon: Icons.edit_rounded,
        baseColor: const Color(0xFF003C82),
        hoverColor: const Color(0xFF004D99),
        onPressed: onModify,
      ),
    );

    if (onRemoveResponsibility == null) {
      return primaryButton;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool sideBySide = constraints.maxWidth >= _kSideBySideBreakpoint;

        if (sideBySide) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              primaryButton,
              const SizedBox(width: _kSpacing),
              SizedBox(
                width: _kSecondaryWidthSideBySide,
                child: WizardAnimatedActionButton(
                  text: 'RIMUOVI RESPONSABILITÀ GENITORIALI',
                  icon: Icons.gavel_rounded,
                  baseColor: const Color(0xFFE53935),
                  hoverColor: const Color(0xFFEF5350),
                  onPressed: onRemoveResponsibility!,
                ),
              ),
            ],
          );
        }

        //ModificaGenitoriSempreSopra_RimuoviResponsabilitàSotto_RichiestaEsplicita
        //LarghezzaFissaAncheQuiConSizedBox_NoStretch_NoCrossAxisAlignmentStretch
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            primaryButton,
            const SizedBox(height: 16),
            SizedBox(
              width: _kSecondaryWidthStacked,
              child: WizardAnimatedActionButton(
                text: 'RIMUOVI RESPONSABILITÀ',
                icon: Icons.gavel_rounded,
                baseColor: const Color(0xFFE53935),
                hoverColor: const Color(0xFFEF5350),
                onPressed: onRemoveResponsibility!,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParentSectionCard extends StatelessWidget {
  final String title;
  final Widget leadingIcon;
  final List<_InfoRowData?>? rows;

  const _ParentSectionCard({
    required this.title,
    required this.leadingIcon,
    this.rows,
  });

  List<Widget> _buildRows() {
    if (rows == null) {
      return const [];
    }

    final List<Widget> widgets = [];

    for (int i = 0; i < rows!.length; i++) {
      final bool isLast = i == rows!.length - 1;
      final _InfoRowData? rowData = rows![i];

      Widget rowWidget;

      if (rowData == null) {
        rowWidget = const Opacity(
          opacity: 0.0,
          child: _ParentInfoRow(label: '-', value: '-'),
        );
      } else {
        rowWidget = _ParentInfoRow(label: rowData.label, value: rowData.value);
      }

      if (!isLast) {
        rowWidget = Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: rowWidget,
        );
      }

      widgets.add(rowWidget);
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    //IsolateSelectionToCardBody
    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003C82),
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildRows(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticAvatar extends StatelessWidget {
  final IconData icon;

  const _StaticAvatar({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EEF7),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 44, color: const Color(0xFF003C82)),
    );
  }
}

class _ParentInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ParentInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7A7A7A),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2A2A2A),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRowData {
  final String label;
  final String value;

  const _InfoRowData(this.label, this.value);
}

class _ParentSelectionDialog extends StatefulWidget {
  final String childTaxCode;
  final Set<String> initialSelectedParents;

  const _ParentSelectionDialog({
    required this.childTaxCode,
    required this.initialSelectedParents,
  });

  @override
  State<_ParentSelectionDialog> createState() => _ParentSelectionDialogState();
}

class _ParentSelectionDialogState extends State<_ParentSelectionDialog> {
  bool _isLoading = true;
  List<PersonItem> _allAdults = [];
  late Set<String> _selectedCodes;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';
  String _sortBy = 'surname_asc';

  @override
  void initState() {
    super.initState();
    _selectedCodes = Set.from(widget.initialSelectedParents);
    _fetchAdults();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAdults() async {
    try {
      final allPeople = await ApiService().getPeople();
      if (mounted) {
        setState(() {
          _allAdults = allPeople
              .where(
                (p) =>
                    (p.age == null || p.age! >= 18) &&
                    p.roles.any((r) => r.toUpperCase() == 'GENITORE') &&
                    p.fiscalCode != widget.childTaxCode,
              )
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PersonItem> get _filteredAdults {
    var result = _allAdults.where((adult) {
      final query = _searchText.toLowerCase();
      final fullName = '${adult.firstName} ${adult.lastName}'.toLowerCase();
      return fullName.contains(query);
    }).toList();

    result.sort((a, b) {
      if (_sortBy == 'name_asc') {
        return a.firstName.compareTo(b.firstName);
      }
      if (_sortBy == 'name_desc') {
        return b.firstName.compareTo(a.firstName);
      }
      if (_sortBy == 'surname_asc') {
        return a.lastName.compareTo(b.lastName);
      }
      if (_sortBy == 'surname_desc') {
        return b.lastName.compareTo(a.lastName);
      }
      if (_sortBy == 'date_desc') {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (_sortBy == 'date_asc') {
        return a.createdAt.compareTo(b.createdAt);
      }
      return 0;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final validAdults = _filteredAdults;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7F9),
          borderRadius: BorderRadius.circular(40),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              offset: Offset(0, 12),
              blurRadius: 36,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              Positioned(
                right: -400,
                top: -400,
                child: IgnorePointer(
                  child: Container(
                    width: 800,
                    height: 800,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x22003C82), Color(0x00003C82)],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -400,
                bottom: -400,
                child: IgnorePointer(
                  child: Container(
                    width: 800,
                    height: 800,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x22003C82), Color(0x00003C82)],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gestisci Genitori',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF003C82),
                          ),
                        ),
                        WizardHoverCloseButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Center(
                            //SideBySideWhenThereIsRoom_StacksOnlyBelowTheThreshold_NotAlwaysSplit
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1320),
                              child: _ResponsiveSearchFilterRow(
                                breakpoint: 500,
                                searchBar: _LocalAnimatedSearchBar(
                                  controller: _searchCtrl,
                                  hintText: 'Cerca genitore...',
                                  onChanged: (val) => setState(() => _searchText = val),
                                ),
                                filterWidgets: [
                                  _LocalFilterMenu<String>(
                                    hint: 'Ordina per',
                                    icon: Icons.sort_rounded,
                                    value: _sortBy,
                                    menuWidth: 180,
                                    showClearIcon: false,
                                    onChanged: (val) => setState(() => _sortBy = val),
                                    onClear: () {},
                                    options: [
                                      _LocalFilterOption(value: 'surname_asc', label: 'Cognome (A-Z)'),
                                      _LocalFilterOption(value: 'surname_desc', label: 'Cognome (Z-A)'),
                                      _LocalFilterOption(value: 'name_asc', label: 'Nome (A-Z)'),
                                      _LocalFilterOption(value: 'name_desc', label: 'Nome (Z-A)'),
                                      _LocalFilterOption(value: 'date_desc', label: 'Più recente'),
                                      _LocalFilterOption(value: 'date_asc', label: 'Meno recente'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
                                : SizedBox(
                                    width: double.infinity,
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.only(bottom: 40),
                                      child: validAdults.isEmpty
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 40),
                                              child: Center(
                                                child: Text(
                                                  'Nessun genitore disponibile trovato.',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 1320),
                                                child: Wrap(
                                                  spacing: 16,
                                                  runSpacing: 16,
                                                  alignment: WrapAlignment.start,
                                                  children: validAdults.map((adult) {
                                                    final bool isSelected = _selectedCodes.contains(adult.fiscalCode);
                                                    return _LocalSelectablePersonCard(
                                                      person: adult,
                                                      isSelected: isSelected,
                                                      onTap: () => setState(() {
                                                        if (isSelected) {
                                                          _selectedCodes.remove(adult.fiscalCode);
                                                        } else {
                                                          if (_selectedCodes.length >= 2) {
                                                            CustomSnackBar.show(
                                                              context: context,
                                                              message: 'Massimo 2 genitori selezionabili.',
                                                              isError: true,
                                                            );
                                                            return;
                                                          }
                                                          _selectedCodes.add(adult.fiscalCode);
                                                        }
                                                      }),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32, left: 32, right: 32),
                    child: Center(
                      child: _ResponsiveDialogButtonsRow(
                        cancelText: 'ANNULLA',
                        cancelIcon: Icons.close_rounded,
                        cancelColor: const Color(0xFFE53935),
                        cancelHoverColor: const Color(0xFFEF5350),
                        cancelOnPressed: () => Navigator.of(context).pop(),
                        confirmText: 'CONFERMA',
                        confirmIcon: Icons.check_circle_outline,
                        confirmColor: const Color(0xFF003C82),
                        confirmHoverColor: const Color(0xFF004D99),
                        confirmOnPressed: () {
                          if (_selectedCodes.isEmpty) {
                            CustomSnackBar.show(
                              context: context,
                              message: 'Seleziona almeno un genitore per procedere.',
                              isError: true,
                            );
                            return;
                          }
                          Navigator.of(context).pop(_selectedCodes);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//UsataNelBottomBarDelDialogGestisciGenitori_ImpilaITastiSottoSoglia_ConfermaSopra_AnnullaSotto
//GiaCorrettaConSizedBoxALarghezzaFissa_NessunaModificaNecessariaQui
class _ResponsiveDialogButtonsRow extends StatelessWidget {
  final String cancelText;
  final IconData cancelIcon;
  final Color cancelColor;
  final Color cancelHoverColor;
  final VoidCallback cancelOnPressed;

  final String confirmText;
  final IconData confirmIcon;
  final Color confirmColor;
  final Color confirmHoverColor;
  final VoidCallback confirmOnPressed;

  const _ResponsiveDialogButtonsRow({
    required this.cancelText,
    required this.cancelIcon,
    required this.cancelColor,
    required this.cancelHoverColor,
    required this.cancelOnPressed,
    required this.confirmText,
    required this.confirmIcon,
    required this.confirmColor,
    required this.confirmHoverColor,
    required this.confirmOnPressed,
  });

  static const double _kButtonWidth = 230;
  static const double _kSpacing = 24;
  static const double _kBreakpoint = _kButtonWidth * 2 + _kSpacing + 40;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        final Widget cancelButton = SizedBox(
          width: _kButtonWidth,
          child: WizardAnimatedActionButton(
            text: cancelText,
            icon: cancelIcon,
            baseColor: cancelColor,
            hoverColor: cancelHoverColor,
            onPressed: cancelOnPressed,
          ),
        );

        final Widget confirmButton = SizedBox(
          width: _kButtonWidth,
          child: WizardAnimatedActionButton(
            text: confirmText,
            icon: confirmIcon,
            baseColor: confirmColor,
            hoverColor: confirmHoverColor,
            onPressed: confirmOnPressed,
          ),
        );

        if (isCompact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              confirmButton,
              const SizedBox(height: 16),
              cancelButton,
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            cancelButton,
            const SizedBox(width: _kSpacing),
            confirmButton,
          ],
        );
      },
    );
  }
}

class _LocalAnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const _LocalAnimatedSearchBar({
    required this.controller,
    required this.onChanged,
    this.hintText = 'Cerca...',
  });

  @override
  State<_LocalAnimatedSearchBar> createState() =>
      _LocalAnimatedSearchBarState();
}

class _LocalAnimatedSearchBarState extends State<_LocalAnimatedSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuint,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: _isFocused
              ? const Color(0xFF003C82).withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? const Color(0x15003C82)
                : const Color(0x0A000000),
            offset: const Offset(0, 4),
            blurRadius: _isFocused ? 24 : 16,
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: const Color(0xFF003C82),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF003C82),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFB3B3B3),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 28, bottom: 2),
          suffixIcon: Icon(
            Icons.search,
            size: 24,
            color: _isFocused
                ? const Color(0xFF003C82)
                : const Color(0xFFB3B3B3),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 64,
            minHeight: 50,
          ),
        ),
      ),
    );
  }
}

class _LocalFilterOption<T> {
  final T value;
  final String label;

  _LocalFilterOption({required this.value, required this.label});
}

class _LocalFilterMenu<T> extends StatefulWidget {
  final String hint;
  final IconData icon;
  final T? value;
  final List<_LocalFilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final VoidCallback onClear;
  final double menuWidth;
  final bool showClearIcon;

  const _LocalFilterMenu({
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onClear,
    required this.menuWidth,
    required this.showClearIcon,
  });

  @override
  State<_LocalFilterMenu<T>> createState() => _LocalFilterMenuState<T>();
}

class _LocalFilterMenuState<T> extends State<_LocalFilterMenu<T>> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final GlobalKey<_LocalFilterOverlayState> _menuKey = GlobalKey();
  bool _isHovered = false;

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }

    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              child: Container(),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 8,
            left: offset.dx,
            child: _LocalFilterOverlay<T>(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
              menuWidth: widget.menuWidth,
              onSelected: (val) {
                widget.onChanged(val);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeMenu() async {
    if (_overlayEntry != null) {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.value != null;
    String displayText = widget.hint;

    if (isActive) {
      final _LocalFilterOption<T> selectedOption = widget.options.firstWhere(
        (o) => o.value == widget.value,
        orElse: () => _LocalFilterOption(value: widget.value!, label: ''),
      );
      displayText = selectedOption.label;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 200),
          height: 50,
          padding: EdgeInsets.only(
            left: 16,
            right: (isActive && widget.showClearIcon) ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: _isHovered || isActive
                ? const Color(0xFFF5F8FC)
                : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _isHovered || isActive
                  ? const Color(0xFF003C82)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: const Color(0xFF003C82), size: 18),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  displayText,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF003C82)
                        : const Color(0xFF8A8A8A),
                  ),
                ),
              ),
              if (isActive && widget.showClearIcon) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    widget.onClear();
                    if (_overlayEntry != null) {
                      _closeMenu();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalFilterOverlay<T> extends StatefulWidget {
  final T? currentValue;
  final List<_LocalFilterOption<T>> options;
  final ValueChanged<T> onSelected;
  final double menuWidth;

  const _LocalFilterOverlay({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.menuWidth,
  });

  @override
  State<_LocalFilterOverlay<T>> createState() => _LocalFilterOverlayState<T>();
}

class _LocalFilterOverlayState<T> extends State<_LocalFilterOverlay<T>> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _expanded = true;
        });
      }
    });
  }

  Future<void> hide() async {
    if (mounted) {
      setState(() {
        _expanded = false;
      });
    }
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.menuWidth,
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.options.map((option) {
                        return _LocalFilterMenuItem(
                          text: option.label,
                          isSelected: widget.currentValue == option.value,
                          onTap: () => widget.onSelected(option.value),
                        );
                      }).toList(),
                    ),
                  ),
                )
              : SizedBox(width: widget.menuWidth, height: 0),
        ),
      ),
    );
  }
}

class _LocalFilterMenuItem extends StatefulWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _LocalFilterMenuItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LocalFilterMenuItem> createState() => _LocalFilterMenuItemState();
}

class _LocalFilterMenuItemState extends State<_LocalFilterMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF003C82),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: const Color(0xFF003C82),
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

class _LocalSelectablePersonCard extends StatefulWidget {
  final PersonItem person;
  final bool isSelected;
  final VoidCallback onTap;

  const _LocalSelectablePersonCard({
    required this.person,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LocalSelectablePersonCard> createState() =>
      _LocalSelectablePersonCardState();
}

class _LocalSelectablePersonCardState
    extends State<_LocalSelectablePersonCard> {
  bool _isHovering = false;

  Widget _buildAvatar() {
    final String initials =
        '${widget.person.firstName[0]}${widget.person.lastName[0]}'
            .toUpperCase();

    final Widget fallbackWidget = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        ),
      ),
    );

    String? imageUrl = widget.person.profileImageUrl?.trim();
    if (imageUrl != null && imageUrl.startsWith('/')) {
      imageUrl = ApiConfig.buildUrl(imageUrl);
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF003C82), width: 2.5),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return fallbackWidget;
                },
              )
            : fallbackWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> processedRoles = RoleLabelMapper.processRoles(
      widget.person.roles,
    );
    final String fullName =
        '${widget.person.firstName} ${widget.person.lastName}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 420,
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFE8F0FA) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: (_isHovering || widget.isSelected)
                  ? const Color(0xFF003C82)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardOverflowTooltipText(
                      text: fullName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003C82),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LocalRoleChipsRow(roles: processedRoles),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostra i chip dei ruoli su una singola riga. Se non entrano tutti nello
/// spazio disponibile, tronca la lista e sostituisce quelli in eccesso con
/// un chip "+N" che, al passaggio del mouse, mostra i ruoli nascosti.
class _LocalRoleChipsRow extends StatelessWidget {
  final List<String> roles;

  const _LocalRoleChipsRow({required this.roles});

  static const double _chipHorizontalPadding = 20; // 10 sinistra + 10 destra
  static const double _chipBorderAllowance = 2;    // 1px di bordo per lato
  static const double _chipSpacing = 6;

  double _measureChipWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width + _chipHorizontalPadding + _chipBorderAllowance;
  }

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final chipStyle = GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        );
        final extraStyle = GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        );

        int visibleCount = roles.length;
        while (visibleCount > 1) {
          double totalWidth = 0;
          for (int i = 0; i < visibleCount; i++) {
            totalWidth += _measureChipWidth(roles[i], chipStyle);
            if (i > 0) totalWidth += _chipSpacing;
          }

          final int remaining = roles.length - visibleCount;
          if (remaining > 0) {
            totalWidth += _chipSpacing + _measureChipWidth('+$remaining', extraStyle);
          }

          if (totalWidth <= constraints.maxWidth) break;
          visibleCount--;
        }

        final int extraCount = roles.length - visibleCount;
        final List<String> hiddenRoles = roles.sublist(visibleCount);

        final List<Widget> chips = [];
        for (int i = 0; i < visibleCount; i++) {
          if (i > 0) chips.add(const SizedBox(width: _chipSpacing));
          chips.add(_LocalRoleChip(label: roles[i], style: chipStyle));
        }
        if (extraCount > 0) {
          chips.add(const SizedBox(width: _chipSpacing));
          chips.add(_LocalRoleChip(
            label: '+$extraCount',
            style: extraStyle,
            hiddenRoles: hiddenRoles,
          ));
        }

        return Row(mainAxisSize: MainAxisSize.min, children: chips);
      },
    );
  }
}

class _LocalRoleChip extends StatelessWidget {
  final String label;
  final TextStyle style;
  final List<String>? hiddenRoles;

  const _LocalRoleChip({required this.label, required this.style, this.hiddenRoles});

  @override
  Widget build(BuildContext context) {
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Text(label, style: style),
    );

    if (hiddenRoles == null || hiddenRoles!.isEmpty) return chip;

    return Tooltip(
      waitDuration: const Duration(milliseconds: 600),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: .98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
        ],
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: 'Altri ruoli:\n',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          TextSpan(
            text: hiddenRoles!.join('\n'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
      child: chip,
    );
  }
}

//DecideSeAffiancareRicercaEFiltriOImpilarli_SoloSottoSoglia_NonSempreCome_LaVersionePrecedenteSbagliava
class _ResponsiveSearchFilterRow extends StatelessWidget {
  final Widget searchBar;
  final List<Widget> filterWidgets;
  final double breakpoint;
  final double spacing;

  const _ResponsiveSearchFilterRow({
    required this.searchBar,
    required this.filterWidgets,
    this.breakpoint = 700,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchBar,
              SizedBox(height: spacing),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: filterWidgets,
              ),
            ],
          );
        }

        final List<Widget> rowChildren = [Expanded(child: searchBar)];
        for (final w in filterWidgets) {
          rowChildren.add(SizedBox(width: spacing));
          rowChildren.add(w);
        }

        return Row(children: rowChildren);
      },
    );
  }
}

class _CardOverflowTooltipText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;

  const _CardOverflowTooltipText({
    required this.text,
    required this.style,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
        )..layout(maxWidth: constraints.maxWidth);

        final Widget textWidget = Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );

        if (!painter.didExceedMaxLines) return textWidget;

        return Tooltip(
          message: text,
          waitDuration: const Duration(milliseconds: 600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: .98),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
            ],
          ),
          child: textWidget,
        );
      },
    );
  }
}