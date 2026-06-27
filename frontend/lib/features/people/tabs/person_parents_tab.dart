import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/api_service.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../models/parent_item.dart';
import '../models/person_item.dart';
import '../person_wizard_components.dart';

class PersonParentsTab extends StatefulWidget 
{
  final PersonItem   person;
  final VoidCallback onUpdate;

  const PersonParentsTab
  ({
    super.key,
    required this.person,
    required this.onUpdate,
  });

  @override
  State<PersonParentsTab> createState() => _PersonParentsTabState();
}

class _PersonParentsTabState extends State<PersonParentsTab> 
{
  int _selectedParentIndex = 0;

  void _openParentSelectionDialog() async 
  {
    final Set<String> currentParents = widget.person.parents?.map((p) => p.fiscalCode).toSet() ?? {};

    final Set<String>? newParents = await showGeneralDialog<Set<String>>
    (
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'SelectParent', 
      barrierColor:       Colors.black.withValues(alpha: .5), 
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter
        (
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition
          (
            opacity: animation,
            child: ScaleTransition
            (
              scale: CurvedAnimation
              (
                parent:       animation, 
                curve:        Curves.easeOutBack, 
                reverseCurve: Curves.easeIn,
              ),
              child: _ParentSelectionDialog
              (
                childTaxCode:           widget.person.fiscalCode,
                initialSelectedParents: currentParents,
              ),
            ),
          ),
        );
      },
    );

    if (newParents != null && mounted) 
    {
      final added   = newParents.difference(currentParents);
      final removed = currentParents.difference(newParents);
      
      if (added.isEmpty && removed.isEmpty) 
      {
        return;
      }

      try 
      {
        //ProcessRemovalsFirstToPreventLocks
        for (var c in removed) 
        {
          await ApiService().removeParent(widget.person.fiscalCode, c);
        }
        for (var c in added)   
        {
          await ApiService().addParent(widget.person.fiscalCode, c);
        }
        
        CustomSnackBar.show
        (
          context: context, 
          message: 'Associazioni aggiornate con successo!', 
          isError: false,
        );
        widget.onUpdate();
      } 
      catch (e) 
      {
        CustomSnackBar.show
        (
          context: context, 
          message: e.toString().replaceAll('Exception: ', ''), 
          isError: true,
        );
      }
    }
  }

  void _onRemoveResponsibilityTap() 
  {
    showDialog
    (
      context: context,
      builder: (ctx) => AlertDialog
      (
        backgroundColor: Colors.white,
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:           Text
        (
          'Rimuovi Responsabilità', 
          style: GoogleFonts.plusJakartaSans
          (
            fontWeight: FontWeight.w700, 
            color:      const Color(0xFFE53935),
          ),
        ),
        content: Text
        (
          'Sei sicuro di voler rimuovere irreversibilmente ogni responsabilità genitoriale collegata a questa anagrafica?\nGli ex-genitori non avranno più alcun accesso ai dati di questo utente.',
          style: GoogleFonts.plusJakartaSans(fontSize: 16),
        ),
        actions: 
        [
          TextButton
          (
            style: ButtonStyle
            (
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            onPressed: () => Navigator.pop(ctx),
            child:     Text
            (
              'ANNULLA', 
              style: GoogleFonts.plusJakartaSans
              (
                color:      const Color(0xFF64748B), 
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton
          (
            style: ButtonStyle
            (
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            onPressed: () async 
            {
              Navigator.pop(ctx);
              try 
              {
                for (final parent in widget.person.parents!)
                {
                  await ApiService().removeParent(widget.person.fiscalCode, parent.fiscalCode);
                }
                CustomSnackBar.show
                (
                  context: context, 
                  message: 'Responsabilità rimosse con successo.', 
                  isError: false,
                );
                widget.onUpdate();
              } 
              catch (e) 
              {
                CustomSnackBar.show
                (
                  context: context, 
                  message: e.toString().replaceAll('Exception: ', ''), 
                  isError: true,
                );
              }
            },
            child: Text
            (
              'RIMUOVI', 
              style: GoogleFonts.plusJakartaSans
              (
                color:      const Color(0xFFE53935), 
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavigation(List<ParentItem> parents) 
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row
      (
        children: List.generate(parents.length, (index) 
        {
          final isSelected = _selectedParentIndex == index;
          final parent     = parents[index];

          return Padding
          (
            padding: const EdgeInsets.only(right: 12.0),
            child: MouseRegion
            (
              cursor: SystemMouseCursors.click,
              child: GestureDetector
              (
                onTap: () 
                {
                  setState(() 
                  {
                    _selectedParentIndex = index;
                  });
                },
                child: AnimatedContainer
                (
                  duration:   const Duration(milliseconds: 250),
                  curve:      Curves.easeInOut,
                  padding:    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration
                  (
                    color:        isSelected ? const Color(0xFF003C82) : Colors.white,
                    border:       Border.all
                    (
                      color: isSelected ? const Color(0xFF003C82) : const Color(0xFFE2E8F0),
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: AnimatedDefaultTextStyle
                  (
                    duration: const Duration(milliseconds: 250),
                    curve:    Curves.easeInOut,
                    style:    GoogleFonts.plusJakartaSans
                    (
                      fontSize:   14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color:      isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    child: Text('${parent.firstName} ${parent.lastName}'),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    final List<ParentItem> parents = widget.person.parents ?? [];

    if (parents.isEmpty) 
    {
      return Center
      (
        child: Padding
        (
          padding: const EdgeInsets.only(top: 32.0),
          child: Column
          (
            mainAxisSize: MainAxisSize.min,
            children: 
            [
              Text
              (
                'Nessun genitore associato a sistema.',
                style: GoogleFonts.plusJakartaSans
                (
                  fontSize:   16,
                  fontWeight: FontWeight.w500,
                  color:      const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox
              (
                width: 240,
                child: WizardAnimatedActionButton
                (
                  text:       'AGGIUNGI GENITORI',
                  icon:       Icons.add_rounded,
                  baseColor:  const Color(0xFF003C82),
                  hoverColor: const Color(0xFF004D99),
                  onPressed:  _openParentSelectionDialog,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedParentIndex >= parents.length) 
    {
      _selectedParentIndex = 0;
    }

    final ParentItem currentParent = parents[_selectedParentIndex];

    final String nome           = currentParent.firstName;
    final String cognome        = currentParent.lastName;
    final String sesso          = currentParent.gender ?? '-';
    final String email          = currentParent.email ?? '-';
    final String telefono       = currentParent.phoneNumber ?? '-';
    final String dataNascita    = currentParent.birthDate != null ? DateFormat('dd/MM/yyyy').format(currentParent.birthDate!) : '-';
    final String cittaNascita   = currentParent.birthCity ?? '-';
    final String provNascita    = currentParent.birthProvince ?? '-';
    
    final String tipoVia        = currentParent.residenceType?.trim() ?? '';
    final String nomeVia        = currentParent.address?.trim() ?? '';
    final String indirizzo      = '$tipoVia $nomeVia'.trim().isNotEmpty ? '$tipoVia $nomeVia'.trim() : '-';
    final String civico         = currentParent.addressNumber ?? '-';
    final String cittaResidenza = currentParent.city ?? '-';
    final String provResidenza  = currentParent.province ?? '-';
    final String cap            = currentParent.zipCode ?? '-';

    final bool isAdult = widget.person.age != null && widget.person.age! >= 18;

    return SingleChildScrollView
    (
      padding: const EdgeInsets.only
      (
        top:    16,
        left:   0,
        right:  0,
        bottom: 32,
      ),
      child: Center
      (
        child: ConstrainedBox
        (
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              _buildSubNavigation(parents),
              IntrinsicHeight
              (
                child: Row
                (
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: 
                  [
                    Expanded
                    (
                      child: _ParentSectionCard
                      (
                        title:       'Identità',
                        leadingIcon: const _StaticAvatar(icon: Icons.badge_rounded),
                        rows: 
                        [
                          _InfoRowData('Nome',           nome),
                          _InfoRowData('Cognome',        cognome),
                          _InfoRowData('Sesso',          sesso),
                          _InfoRowData('Codice fiscale', currentParent.fiscalCode),
                          null,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded
                    (
                      child: _ParentSectionCard
                      (
                        title:       'Residenza',
                        leadingIcon: const _StaticAvatar(icon: Icons.home_rounded),
                        rows: 
                        [
                          _InfoRowData('Indirizzo', indirizzo),
                          _InfoRowData('N°',        civico),
                          _InfoRowData('Città',     cittaResidenza),
                          _InfoRowData('Provincia', provResidenza),
                          _InfoRowData('CAP',       cap),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight
              (
                child: Row
                (
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: 
                  [
                    Expanded
                    (
                      child: _ParentSectionCard
                      (
                        title:       'Dati anagrafici',
                        leadingIcon: const _StaticAvatar(icon: Icons.cake_rounded),
                        rows: 
                        [
                          _InfoRowData('Data di nascita',  dataNascita),
                          _InfoRowData('Città di nascita', cittaNascita),
                          _InfoRowData('Provincia',        provNascita),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded
                    (
                      child: _ParentSectionCard
                      (
                        title:       'Contatti',
                        leadingIcon: const _StaticAvatar(icon: Icons.alternate_email_rounded),
                        rows: 
                        [
                          _InfoRowData('Email',    email),
                          _InfoRowData('Telefono', telefono),
                          null,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Center
              (
                child: Column
                (
                  mainAxisSize: MainAxisSize.min,
                  children: 
                  [
                    SizedBox
                    (
                      width: 230,
                      child: WizardAnimatedActionButton
                      (
                        text:       'MODIFICA GENITORI',
                        icon:       Icons.edit_rounded,
                        baseColor:  const Color(0xFF003C82),
                        hoverColor: const Color(0xFF004D99),
                        onPressed:  _openParentSelectionDialog,
                      ),
                    ),
                    if (isAdult) ...
                    [
                      const SizedBox(height: 16),
                      SizedBox
                      (
                        width: 544,
                        child: WizardAnimatedActionButton
                        (
                          text:       'RIMUOVI RESPONSABILITÀ GENITORIALI',
                          icon:       Icons.gavel_rounded,
                          baseColor:  const Color(0xFFE53935),
                          hoverColor: const Color(0xFFEF5350),
                          onPressed:  _onRemoveResponsibilityTap,
                        ),
                      ),
                    ],
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

class _ParentSectionCard extends StatelessWidget 
{
  final String               title;
  final Widget               leadingIcon;
  final List<_InfoRowData?>? rows;

  const _ParentSectionCard
  ({
    required this.title,
    required this.leadingIcon,
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
        rowWidget = const Opacity
        (
          opacity: 0.0,
          child:   _ParentInfoRow
          (
            label: '-',
            value: '-',
          ),
        );
      } 
      else 
      {
        rowWidget = _ParentInfoRow
        (
          label: rowData.label,
          value: rowData.value,
        );
      }
      
      if (!isLast) 
      {
        rowWidget = Padding
        (
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
    //IsolateSelectionToCardBody
    return SelectionArea
    (
      child: Container
      (
        padding:    const EdgeInsets.all(32),
        decoration: BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x0A000000),
              offset:     Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column
        (
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            SizedBox
            (
              height: 90,
              child: Row
              (
                crossAxisAlignment: CrossAxisAlignment.center,
                children: 
                [
                  leadingIcon,
                  const SizedBox(width: 24),
                  Expanded
                  (
                    child: Text
                    (
                      title,
                      style: GoogleFonts.plusJakartaSans
                      (
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
            const Padding
            (
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child:   Divider
              (
                height:    1,
                thickness: 1,
                color:     Color(0xFFF1F5F9),
              ),
            ),
            Flexible
            (
              child: Column
              (
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

  const _StaticAvatar
  ({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) 
  {
    return Container
    (
      width:  90,
      height: 90,
      decoration: const BoxDecoration
      (
        color: Color(0xFFE8EEF7),
        shape: BoxShape.circle,
      ),
      child: Icon
      (
        icon,
        size:  44,
        color: const Color(0xFF003C82),
      ),
    );
  }
}

class _ParentInfoRow extends StatelessWidget 
{
  final String label;
  final String value;

  const _ParentInfoRow
  ({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) 
  {
    return Row
    (
      crossAxisAlignment: CrossAxisAlignment.start,
      children: 
      [
        SizedBox
        (
          width: 160, 
          child: Text
          (
            label,
            style: GoogleFonts.plusJakartaSans
            (
              fontSize:   18,
              fontWeight: FontWeight.w500,
              color:      const Color(0xFF7A7A7A),
            ),
          ),
        ),
        Expanded
        (
          child: Text
          (
            value,
            style: GoogleFonts.plusJakartaSans
            (
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

class _InfoRowData 
{
  final String label;
  final String value;

  const _InfoRowData(this.label, this.value);
}

class _ParentSelectionDialog extends StatefulWidget 
{
  final String      childTaxCode;
  final Set<String> initialSelectedParents;

  const _ParentSelectionDialog
  ({
    required this.childTaxCode,
    required this.initialSelectedParents,
  });

  @override
  State<_ParentSelectionDialog> createState() => _ParentSelectionDialogState();
}

class _ParentSelectionDialogState extends State<_ParentSelectionDialog> 
{
  bool             _isLoading = true;
  List<PersonItem> _allAdults = [];
  late Set<String> _selectedCodes;
  
  final TextEditingController _searchCtrl = TextEditingController();
  String                      _searchText = '';
  String                      _sortBy     = 'surname_asc';

  @override
  void initState() 
  {
    super.initState();
    _selectedCodes = Set.from(widget.initialSelectedParents);
    _fetchAdults();
  }

  @override
  void dispose() 
  {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAdults() async 
  {
    try 
    {
      final allPeople = await ApiService().getPeople();
      if (mounted) 
      {
        setState(() 
        {
          _allAdults = allPeople.where((p) => 
            (p.age == null || p.age! >= 18) && 
            p.roles.any((r) => r.toUpperCase() == 'GENITORE') &&
            p.fiscalCode != widget.childTaxCode 
          ).toList();
          _isLoading = false;
        });
      }
    } 
    catch (_) 
    {
      if (mounted) 
      {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PersonItem> get _filteredAdults 
  {
    var result = _allAdults.where((adult) 
    {
      final query    = _searchText.toLowerCase();
      final fullName = '${adult.firstName} ${adult.lastName}'.toLowerCase();
      return fullName.contains(query);
    }).toList();

    result.sort((a, b) 
    {
      if (_sortBy == 'name_asc')     
      {
        return a.firstName.compareTo(b.firstName);
      }
      if (_sortBy == 'name_desc')    
      {
        return b.firstName.compareTo(a.firstName);
      }
      if (_sortBy == 'surname_asc')  
      {
        return a.lastName.compareTo(b.lastName);
      }
      if (_sortBy == 'surname_desc') 
      {
        return b.lastName.compareTo(a.lastName);
      }
      if (_sortBy == 'date_desc')    
      {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (_sortBy == 'date_asc')     
      {
        return a.createdAt.compareTo(b.createdAt);
      }
      return 0;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) 
  {
    final validAdults = _filteredAdults;

    return Dialog
    (
      backgroundColor: Colors.transparent,
      elevation:       0,
      child: Container
      (
        width:       900,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration
        (
          color:        const Color(0xFFF4F7F9),
          borderRadius: BorderRadius.circular(30),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x1A000000),
              offset:     Offset(0, 8),
              blurRadius: 24,
            )
          ],
        ),
        child: ClipRRect
        (
          borderRadius: BorderRadius.circular(30),
          child: Stack
          (
            children: 
            [
              Positioned
              (
                right: -400,
                top:   -400,
                child: IgnorePointer
                (
                  child: Container
                  (
                    width:  800,
                    height: 800,
                    decoration: const BoxDecoration
                    (
                      shape:    BoxShape.circle,
                      gradient: RadialGradient
                      (
                        colors: [Color(0x22003C82), Color(0x00003C82)],
                        stops:  [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned
              (
                left:   -400,
                bottom: -400,
                child: IgnorePointer
                (
                  child: Container
                  (
                    width:  800,
                    height: 800,
                    decoration: const BoxDecoration
                    (
                      shape:    BoxShape.circle,
                      gradient: RadialGradient
                      (
                        colors: [Color(0x22003C82), Color(0x00003C82)],
                        stops:  [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Column
              (
                children: 
                [
                  Padding
                  (
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
                    child: Row
                    (
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: 
                      [
                        Text
                        (
                          'Gestisci Genitori',
                          style: GoogleFonts.plusJakartaSans
                        (
                            fontSize:   24,
                            fontWeight: FontWeight.w700,
                            color:      const Color(0xFF003C82),
                          ),
                        ),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),
                  Padding
                  (
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Row
                    (
                      children: 
                      [
                        Expanded
                        (
                          child: _LocalAnimatedSearchBar
                          (
                            controller: _searchCtrl,
                            hintText:   'Cerca per nome...',
                            onChanged:  (val) => setState(() => _searchText = val),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _LocalFilterMenu<String>
                        (
                          hint:          'Ordina per',
                          icon:          Icons.sort_rounded,
                          value:         _sortBy,
                          menuWidth:     180,
                          showClearIcon: false,
                          onChanged:     (val) => setState(() => _sortBy = val),
                          onClear:       () {},
                          options: 
                          [
                            _LocalFilterOption(value: 'surname_asc',  label: 'Cognome (A-Z)'),
                            _LocalFilterOption(value: 'surname_desc', label: 'Cognome (Z-A)'),
                            _LocalFilterOption(value: 'name_asc',     label: 'Nome (A-Z)'),
                            _LocalFilterOption(value: 'name_desc',    label: 'Nome (Z-A)'),
                            _LocalFilterOption(value: 'date_desc',    label: 'Più recente'),
                            _LocalFilterOption(value: 'date_asc',     label: 'Meno recente'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded
                  (
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
                      : SingleChildScrollView
                        (
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: validAdults.isEmpty 
                            ? Center
                              (
                                child: Text
                                (
                                  'Nessun genitore disponibile trovato.',
                                  style: GoogleFonts.plusJakartaSans
                                  (
                                    fontSize:   16,
                                    fontWeight: FontWeight.w500,
                                    color:      const Color(0xFF64748B),
                                  ),
                                ),
                              )
                            : Wrap
                              (
                                spacing:    16,
                                runSpacing: 16,
                                alignment:  WrapAlignment.center,
                                children:   validAdults.map((adult) 
                                {
                                  final bool isSelected = _selectedCodes.contains(adult.fiscalCode);
                                  return _LocalSelectablePersonCard
                                  (
                                    person:     adult,
                                    isSelected: isSelected,
                                    onTap: () => setState(() 
                                    {
                                      if (isSelected) 
                                      {
                                        _selectedCodes.remove(adult.fiscalCode);
                                      } 
                                      else 
                                      {
                                        if (_selectedCodes.length >= 2) 
                                        {
                                          CustomSnackBar.show
                                          (
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
                  Padding
                  (
                    padding: const EdgeInsets.all(32),
                    child: Row
                    (
                      children: 
                      [
                        Expanded
                        (
                          child: WizardAnimatedActionButton
                          (
                            text:       'ANNULLA',
                            icon:       Icons.close_rounded,
                            baseColor:  const Color(0xFFE53935),
                            hoverColor: const Color(0xFFEF5350),
                            onPressed:  () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded
                        (
                          child: WizardAnimatedActionButton
                          (
                            text:       'CONFERMA',
                            icon:       Icons.check_circle_outline,
                            baseColor:  const Color(0xFF003C82),
                            hoverColor: const Color(0xFF004D99),
                            onPressed: () 
                            {
                              if (_selectedCodes.isEmpty) 
                              {
                                CustomSnackBar.show
                                (
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
                      ],
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

class _LocalAnimatedSearchBar extends StatefulWidget 
{
  final TextEditingController controller;
  final ValueChanged<String>  onChanged;
  final String                hintText;

  const _LocalAnimatedSearchBar
  ({
    required this.controller,
    required this.onChanged,
    this.hintText = 'Cerca...',
  });

  @override
  State<_LocalAnimatedSearchBar> createState() => _LocalAnimatedSearchBarState();
}

class _LocalAnimatedSearchBarState extends State<_LocalAnimatedSearchBar> 
{
  final FocusNode _focusNode = FocusNode();
  bool            _isFocused = false;

  @override
  void initState() 
  {
    super.initState();
    _focusNode.addListener(() 
    {
      setState(() 
      {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() 
  {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) 
  {
    return AnimatedContainer
    (
      duration:   const Duration(milliseconds: 250),
      curve:      Curves.easeOutQuint,
      height:     50,
      decoration: BoxDecoration
      (
        color:        Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all
        (
          color: _isFocused ? const Color(0xFF003C82).withValues(alpha: 0.3) : Colors.transparent, 
          width: 1.5,
        ),
        boxShadow: 
        [
          BoxShadow
          (
            color:      _isFocused ? const Color(0x15003C82) : const Color(0x0A000000), 
            offset:     const Offset(0, 4), 
            blurRadius: _isFocused ? 24 : 16,
          ),
        ],
      ),
      child: TextField
      (
        controller:        widget.controller,
        focusNode:         _focusNode,
        onChanged:         widget.onChanged,
        textAlignVertical: TextAlignVertical.center,
        cursorColor:       const Color(0xFF003C82), 
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   16, 
          fontWeight: FontWeight.w600, 
          color:      const Color(0xFF003C82),
        ),
        decoration: InputDecoration
        (
          hintText:  widget.hintText,
          hintStyle: GoogleFonts.plusJakartaSans
          (
            fontSize:   16, 
            fontWeight: FontWeight.w500, 
            color:      const Color(0xFFB3B3B3),
          ),
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 28, bottom: 2), 
          suffixIcon: Icon
          (
            Icons.search, 
            size:  24, 
            color: _isFocused ? const Color(0xFF003C82) : const Color(0xFFB3B3B3),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 64, minHeight: 50),
        ),
      ),
    );
  }
}

class _LocalFilterOption<T> 
{
  final T      value;
  final String label;

  _LocalFilterOption
  ({
    required this.value, 
    required this.label,
  });
}

class _LocalFilterMenu<T> extends StatefulWidget 
{
  final String                      hint;
  final IconData                    icon;
  final T?                          value;
  final List<_LocalFilterOption<T>> options;
  final ValueChanged<T>             onChanged;
  final VoidCallback                onClear;
  final double                      menuWidth;
  final bool                        showClearIcon;

  const _LocalFilterMenu
  ({
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

class _LocalFilterMenuState<T> extends State<_LocalFilterMenu<T>> 
{
  final GlobalKey                           _buttonKey = GlobalKey();
  OverlayEntry?                             _overlayEntry;
  final GlobalKey<_LocalFilterOverlayState> _menuKey   = GlobalKey();
  bool                                      _isHovered = false;

  void _toggleMenu() 
  {
    if (_overlayEntry != null) 
    {
      _closeMenu();
      return;
    }
    
    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Size      size      = renderBox.size;
    final Offset    offset    = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry
    (
      builder: (context) => Stack
      (
        children: 
        [
          Positioned.fill
          (
            child: GestureDetector
            (
              behavior: HitTestBehavior.opaque,
              onTap:    _closeMenu,
              child:    Container(),
            ),
          ),
          Positioned
          (
            top:  offset.dy + size.height + 8,
            left: offset.dx,
            child: _LocalFilterOverlay<T>
            (
              key:          _menuKey,
              currentValue: widget.value,
              options:      widget.options,
              menuWidth:    widget.menuWidth,
              onSelected:   (val) 
              {
                widget.onChanged(val);
                _closeMenu();
              },
            ),
          )
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeMenu() async 
  {
    if (_overlayEntry != null) 
    {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    final bool isActive    = widget.value != null;
    String     displayText = widget.hint;

    if (isActive) 
    {
      final _LocalFilterOption<T> selectedOption = widget.options.firstWhere
      (
        (o) => o.value == widget.value,
        orElse: () => _LocalFilterOption(value: widget.value!, label: ''),
      );
      displayText = selectedOption.label;
    }

    return MouseRegion
    (
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector
      (
        onTap: _toggleMenu,
        child: AnimatedContainer
        (
          key:        _buttonKey,
          duration:   const Duration(milliseconds: 200),
          height:     50,
          padding:    EdgeInsets.only(left: 16, right: (isActive && widget.showClearIcon) ? 12 : 16),
          decoration: BoxDecoration
          (
            color:        _isHovered || isActive ? const Color(0xFFF5F8FC) : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all
            (
              color: _isHovered || isActive ? const Color(0xFF003C82) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: const 
            [
              BoxShadow
              (
                color:      Color(0x0A000000),
                offset:     Offset(0, 4),
                blurRadius: 16,
              )
            ],
          ),
          child: Row
          (
            mainAxisSize: MainAxisSize.min,
            children: 
            [
              Icon
              (
                widget.icon, 
                color: const Color(0xFF003C82), 
                size:  18,
              ),
              const SizedBox(width: 8),
              ConstrainedBox
              (
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text
                (
                  displayText,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   16,
                    fontWeight: FontWeight.w600,
                    color:      isActive ? const Color(0xFF003C82) : const Color(0xFF8A8A8A),
                  ),
                ),
              ),
              if (isActive && widget.showClearIcon) ...
              [
                const SizedBox(width: 8),
                GestureDetector
                (
                  onTap: () 
                  {
                    widget.onClear();
                    if (_overlayEntry != null) 
                    {
                      _closeMenu();
                    }
                  },
                  child: Container
                  (
                    padding:    const EdgeInsets.all(4),
                    decoration: BoxDecoration
                    (
                      color: const Color(0xFFE53935).withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon
                    (
                      Icons.close_rounded, 
                      size:  16, 
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

class _LocalFilterOverlay<T> extends StatefulWidget 
{
  final T?                          currentValue;
  final List<_LocalFilterOption<T>> options;
  final ValueChanged<T>             onSelected;
  final double                      menuWidth;

  const _LocalFilterOverlay
  ({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.menuWidth,
  });

  @override
  State<_LocalFilterOverlay<T>> createState() => _LocalFilterOverlayState<T>();
}

class _LocalFilterOverlayState<T> extends State<_LocalFilterOverlay<T>> 
{
  bool _expanded = false;

  @override
  void initState() 
  {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) 
    {
      if (mounted) 
      {
        setState(() 
        {
          _expanded = true;
        });
      }
    });
  }

  Future<void> hide() async 
  {
    if (mounted) 
    {
      setState(() 
      {
        _expanded = false;
      });
    }
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) 
  {
    return Material
    (
      color: Colors.transparent,
      child: Container
      (
        width:       widget.menuWidth,
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const 
          [
            BoxShadow
            (
              color:        Color(0x14000000),
              blurRadius:   20,
              spreadRadius: 2,
            )
          ],
        ),
        child: AnimatedSize
        (
          duration:  const Duration(milliseconds: 180),
          curve:     Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding
                (
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView
                  (
                    child: Column
                    (
                      mainAxisSize:       MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.options.map((option) 
                      {
                        return _LocalFilterMenuItem
                        (
                          text:       option.label,
                          isSelected: widget.currentValue == option.value,
                          onTap:      () => widget.onSelected(option.value),
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

class _LocalFilterMenuItem extends StatefulWidget 
{
  final String       text;
  final bool         isSelected;
  final VoidCallback onTap;

  const _LocalFilterMenuItem
  ({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LocalFilterMenuItem> createState() => _LocalFilterMenuItemState();
}

class _LocalFilterMenuItemState extends State<_LocalFilterMenuItem> 
{
  bool _hover = false;

  @override
  Widget build(BuildContext context) 
  {
    return MouseRegion
    (
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector
      (
        onTap: widget.onTap,
        child: Container
        (
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color:   Colors.transparent,
          child: Row
          (
            children: 
            [
              AnimatedContainer
              (
                duration:   const Duration(milliseconds: 150),
                width:      2,
                height:     (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration
                (
                  color:        const Color(0xFF003C82),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded
              (
                child: Text
                (
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   14,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:      const Color(0xFF003C82),
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

class _LocalSelectablePersonCard extends StatefulWidget 
{
  final PersonItem   person;
  final bool         isSelected;
  final VoidCallback onTap;

  const _LocalSelectablePersonCard
  ({
    required this.person,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LocalSelectablePersonCard> createState() => _LocalSelectablePersonCardState();
}

class _LocalSelectablePersonCardState extends State<_LocalSelectablePersonCard> 
{
  bool _isHovering = false;

  Widget _buildAvatar() 
  {
    final String initials = '${widget.person.firstName[0]}${widget.person.lastName[0]}'.toUpperCase();
    
    final Widget fallbackWidget = Center
    (
      child: Text
      (
        initials,
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   26,
          fontWeight: FontWeight.w700,
          color:      const Color(0xFF64748B),
        ),
      ),
    );

    String? imageUrl = widget.person.profileImageUrl?.trim();
    if (imageUrl != null && imageUrl.startsWith('/')) 
    {
      const String backendBaseUrl = 'http://127.0.0.1:8000'; 
      imageUrl                    = '$backendBaseUrl$imageUrl';
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container
    (
      width:  80,
      height: 80,
      decoration: BoxDecoration
      (
        color:  const Color(0xFFE2E8F0),
        shape:  BoxShape.circle,
        border: Border.all
        (
          color: const Color(0xFF003C82),
          width: 2.5,
        ),
      ),
      child: ClipOval
      (
        child: hasImage
            ? Image.network
              (
                imageUrl,
                fit:          BoxFit.cover,
                errorBuilder: (context, error, stackTrace) 
                {
                  return fallbackWidget;
                },
              )
            : fallbackWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    final List<String> processedRoles = RoleLabelMapper.processRoles(widget.person.roles);

    return MouseRegion
    (
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit:  (_) => setState(() => _isHovering = false),
      child: GestureDetector
      (
        onTap: widget.onTap,
        child: AnimatedContainer
        (
          duration:    const Duration(milliseconds: 180),
          curve:       Curves.easeOut,
          width:       380,
          constraints: const BoxConstraints(minHeight: 140),
          padding:     const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration
          (
            color:        widget.isSelected ? const Color(0xFFE8F0FA) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all
            (
              color: (_isHovering || widget.isSelected) ? const Color(0xFF003C82) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const 
            [
              BoxShadow
              (
                color:      Color(0x0A000000),
                offset:     Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row
          (
            crossAxisAlignment: CrossAxisAlignment.center,
            children: 
            [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded
              (
                child: Column
                (
                  mainAxisSize:       MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: 
                  [
                    Text
                    (
                      '${widget.person.firstName} ${widget.person.lastName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans
                      (
                        fontSize:   20,
                        fontWeight: FontWeight.w700,
                        color:      const Color(0xFF003C82),
                        height:     1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap
                    (
                      spacing:    6,
                      runSpacing: 6,
                      children: processedRoles.map((role) 
                      {
                        return Container
                        (
                          padding: const EdgeInsets.symmetric
                          (
                            horizontal: 10,
                            vertical:   4,
                          ),
                          decoration: BoxDecoration
                          (
                            color:        const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all
                            (
                              color: const Color(0xFFE0E5EC),
                            ),
                          ),
                          child: Text
                          (
                            role,
                            style: GoogleFonts.plusJakartaSans
                            (
                              fontSize:   12,
                              fontWeight: FontWeight.w600,
                              color:      const Color(0xFF64748B),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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