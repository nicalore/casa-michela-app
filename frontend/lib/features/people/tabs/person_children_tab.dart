import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../services/api_service.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../models/child_item.dart';
import '../models/parental_relationship_draft.dart';
import '../models/person_item.dart';
import '../person_wizard_components.dart';

class PersonChildrenTab extends StatefulWidget 
{
  final PersonItem person;

  const PersonChildrenTab
  ({
    super.key,
    required this.person,
  });

  @override
  State<PersonChildrenTab> createState() => _PersonChildrenTabState();
}

class _PersonChildrenTabState extends State<PersonChildrenTab> 
{
  late PersonItem _currentPerson;
  int             _selectedChildIndex = 0;
  bool            _isRefreshing       = false;

  @override
  void initState() 
  {
    super.initState();
    _currentPerson = widget.person;
  }

  @override
  void didUpdateWidget(covariant PersonChildrenTab oldWidget) 
  {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person != widget.person) 
    {
      _currentPerson      = widget.person;
      _selectedChildIndex = 0;
    }
  }

  void _openChildrenEditDialog() async 
  {
    final bool? changed = await showGeneralDialog<bool>
    (
      context:            context,
      barrierDismissible: true,
      barrierLabel:       'ChildrenEdit',
      barrierColor:       Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child) 
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter
        (
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child:  FadeTransition
          (
            opacity: animation,
            child:   ScaleTransition
            (
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: ChildrenEditDialog(person: _currentPerson),
            ),
          ),
        );
      },
    );

    if (changed == true) 
    {
      setState(() 
      {
        _isRefreshing = true;
      });

      try 
      {
        final allPeople     = await ApiService().getPeople();
        final updatedPerson = allPeople.firstWhere
        (
          (p)
          {
            return p.fiscalCode == _currentPerson.fiscalCode;
          },
          orElse: ()
          {
            return _currentPerson;
          },
        );

        if (mounted) 
        {
          setState(() 
          {
            _currentPerson      = updatedPerson;
            _selectedChildIndex = 0;
          });
        }
      } 
      catch (e) 
      {
        //SilentFail
      } 
      finally 
      {
        if (mounted) 
        {
          setState(() 
          {
            _isRefreshing = false;
          });
        }
      }
    }
  }

  //StackToNewLineInsteadOfHorizontalScroll_SameWrapNotShrinkPrincipleUsedElsewhere
  Widget _buildSubNavigation(List<ChildItem> childrenList) 
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Wrap
      (
        spacing:    12,
        runSpacing: 12,
        children: List.generate(childrenList.length, (index) 
        {
          final isSelected = _selectedChildIndex == index;
          final child      = childrenList[index];

          return MouseRegion
          (
            cursor: SystemMouseCursors.click,
            child: GestureDetector
            (
              onTap: () 
              {
                setState(() 
                {
                  _selectedChildIndex = index;
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
                  child: Text('${child.firstName} ${child.lastName}'),
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
    if (_isRefreshing) 
    {
      return const Center
      (
        child: Padding
        (
          padding: EdgeInsets.only(top: 32.0),
          child:   CircularProgressIndicator
          (
            color: Color(0xFF003C82),
          ),
        ),
      );
    }

    final List<ChildItem> currentChildren = _currentPerson.children ?? [];

    if (currentChildren.isEmpty) 
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
                'Nessun figlio associato a questa anagrafica genitore.',
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
                width: 255,
                child: WizardAnimatedActionButton
                (
                  text:       'AGGIUNGI FIGLI',
                  icon:       Icons.family_restroom_outlined,
                  baseColor:  const Color(0xFF003C82),
                  hoverColor: const Color(0xFF004D99),
                  onPressed:  _openChildrenEditDialog,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedChildIndex >= currentChildren.length) 
    {
      _selectedChildIndex = 0;
    }

    final child = currentChildren[_selectedChildIndex];

    final String nome           = child.firstName;
    final String cognome        = child.lastName;
    final String sesso          = child.gender ?? '-';
    final String email          = child.email ?? '-';
    final String telefono       = child.phoneNumber ?? '-';
    final String dataNascita    = child.birthDate != null ? DateFormat('dd/MM/yyyy').format(child.birthDate!) : '-';
    final String cittaNascita   = child.birthCity ?? '-';
    final String provNascita    = child.birthProvince ?? '-';
    
    final String tipoVia        = child.residenceType?.trim() ?? '';
    final String nomeVia        = child.address?.trim() ?? '';
    final String indirizzo      = '$tipoVia $nomeVia'.trim().isNotEmpty ? '$tipoVia $nomeVia'.trim() : '-';
    final String civico         = child.addressNumber ?? '-';
    final String cittaResidenza = child.city ?? '-';
    final String provResidenza  = child.province ?? '-';
    final String cap            = child.zipCode ?? '-';

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
              _buildSubNavigation(currentChildren),
              //StacksVerticallyBelowTheBreakpoint_SamePolicyAsPersonInfoTab
              _ResponsiveCardPair
              (
                first: _ChildSectionCard
                (
                  title:       'Identità',
                  leadingIcon: const _StaticAvatar(icon: Icons.badge_rounded),
                  rows: 
                  [
                    _InfoRowData('Nome',           nome),
                    _InfoRowData('Cognome',        cognome),
                    _InfoRowData('Sesso',          sesso),
                    _InfoRowData('Codice fiscale', child.fiscalCode),
                    null,
                  ],
                ),
                second: _ChildSectionCard
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
              const SizedBox(height: 24),
              _ResponsiveCardPair
              (
                first: _ChildSectionCard
                (
                  title:       'Dati anagrafici',
                  leadingIcon: const _StaticAvatar(icon: Icons.cake_rounded),
                  rows: 
                  [
                    _InfoRowData('Data di nascita',      dataNascita),
                    _InfoRowData('Città di nascita',     cittaNascita),
                    _InfoRowData('Provincia', provNascita),
                  ],
                ),
                second: _ChildSectionCard
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
              const SizedBox(height: 24),
              _AuthorizationSectionCard
              (
                authorized:        child.authorizedPickup,
                restrictionReason: child.pickupRestrictionReason,
              ),
              const SizedBox(height: 48),
              Center
              (
                child: SizedBox
                (
                  width: 255,
                  child: WizardAnimatedActionButton
                  (
                    text:       'GESTISCI FIGLI',
                    icon:       Icons.family_restroom_outlined,
                    baseColor:  const Color(0xFF003C82),
                    hoverColor: const Color(0xFF004D99),
                    onPressed:  _openChildrenEditDialog,
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
//LayoutBuilderStaysOutsideIntrinsicHeight_NeverInside_SameFixAppliedInPersonInfoTab
class _ResponsiveCardPair extends StatelessWidget
{
  final Widget first;
  final Widget second;
  final double breakpoint;

  const _ResponsiveCardPair
  ({
    required this.first,
    required this.second,
    this.breakpoint = 820.0,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
              first,
              const SizedBox(height: 24),
              second,
            ],
          );
        }

        return IntrinsicHeight
        (
          child: Row
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
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

class _ChildSectionCard extends StatelessWidget 
{
  final String               title;
  final Widget               leadingIcon;
  final List<_InfoRowData?>? rows;

  const _ChildSectionCard
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
          child:   _ChildInfoRow
          (
            label: '-',
            value: '-',
          ),
        );
      } 
      else 
      {
        rowWidget = _ChildInfoRow
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
              child: SingleChildScrollView
              (
                child: Column
                (
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:           _buildRows(),
                ),
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

class _ChildInfoRow extends StatelessWidget 
{
  final String label;
  final String value;

  const _ChildInfoRow
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

//CardALarghezzaPiena_MostraSeIlGenitoreCorrenteEAutorizzatoAlRitiroDiQuestoFiglio
class _AuthorizationSectionCard extends StatelessWidget
{
  final bool    authorized;
  final String? restrictionReason;

  const _AuthorizationSectionCard
  ({
    required this.authorized,
    required this.restrictionReason,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.min,
        children: 
        [
          Row
          (
            crossAxisAlignment: CrossAxisAlignment.center,
            children: 
            [
              const _StaticAvatar(icon: Icons.how_to_reg_outlined),
              const SizedBox(width: 24),
              Expanded
              (
                child: Text
                (
                  'Autorizzazione al ritiro',
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
          _ChildInfoRow
          (
            label: 'Autorizzato',
            value: authorized ? 'Sì' : 'No',
          ),
          if (!authorized) ...
          [
            const SizedBox(height: 16),
            _ChildInfoRow
            (
              label: 'Motivo',
              value: (restrictionReason?.isNotEmpty ?? false) ? restrictionReason! : '-',
            ),
          ],
        ],
      ),
    );
  }
}

class ChildrenEditDialog extends StatefulWidget 
{
  final PersonItem person;

  const ChildrenEditDialog
  ({
    super.key,
    required this.person,
  });

  @override
  State<ChildrenEditDialog> createState() => _ChildrenEditDialogState();
}

class _ChildrenEditDialogState extends State<ChildrenEditDialog> 
{
  bool                                          _isLoadingData    = true;
  bool                                          _isSubmitting     = false;
  List<PersonItem>                              _allMinors        = [];
  final Map<String, ParentalRelationshipDraft>  _selectedMinors   = {};

  final TextEditingController _searchMinorsCtrl = TextEditingController();
  String                      _searchMinorsText = '';
  String                      _sortMinorsBy     = 'surname_asc';
  String?                     _filterMinorsRole;

  @override
  void initState() 
  {
    super.initState();
    _initSelectedMinors();
    _loadAllData();
  }

  @override
  void dispose() 
  {
    _searchMinorsCtrl.dispose();
    super.dispose();
  }

  void _initSelectedMinors() 
  {
    if (widget.person.children != null) 
    {
      for (var child in widget.person.children!) 
      {
        _selectedMinors[child.fiscalCode] = ParentalRelationshipDraft
        (
          taxCode:           child.fiscalCode,
          authorizedPickup:  child.authorizedPickup,
          restrictionReason: child.pickupRestrictionReason,
        );
      }
    }
  }

  Future<void> _loadAllData() async 
  {
    try 
    {
      final allPeople = await ApiService().getPeople();
      
      if (mounted) 
      {
        setState(() 
        {
          _allMinors = allPeople.where((p) 
          {
            final bool isMinor        = p.age != null && p.age! < 18;
            final bool isAlreadyChild = widget.person.children?.any((c) => c.fiscalCode == p.fiscalCode) ?? false;
            final bool isNotSelf      = p.fiscalCode != widget.person.fiscalCode;
            return (isMinor || isAlreadyChild) && isNotSelf;
          }).toList();
          _isLoadingData = false;
        });
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        setState(() 
        {
          _isLoadingData = false;
        });
      }
    }
  }

  void _onCardTap(PersonItem minor) async 
  {
    final draft = await showAuthorizedPickupDialog
    (
      context,
      personTaxCode: minor.fiscalCode,
      parentName:    '${widget.person.firstName} ${widget.person.lastName}',
      childName:     '${minor.firstName} ${minor.lastName}',
      existing:      _selectedMinors[minor.fiscalCode],
    );

    if (draft != null && mounted) 
    {
      setState(() 
      {
        _selectedMinors[minor.fiscalCode] = draft;
      });
    }
  }

  List<PersonItem> get _filteredMinors
  {
    var result = _allMinors.where((minor)
    {
      final query         = _searchMinorsText.toLowerCase();
      final fullName      = '${minor.firstName} ${minor.lastName}'.toLowerCase();
      final matchesSearch = fullName.contains(query);
      final matchesRole   = _filterMinorsRole == null || minor.roles.any((r) => r.trim().toUpperCase() == _filterMinorsRole!.trim().toUpperCase());
      
      return matchesSearch && matchesRole;
    }).toList();

    result.sort((a, b)
    {
      if (_sortMinorsBy == 'name_asc') 
      {
        return a.firstName.compareTo(b.firstName);
      }
      if (_sortMinorsBy == 'name_desc') 
      {
        return b.firstName.compareTo(a.firstName);
      }
      if (_sortMinorsBy == 'surname_asc') 
      {
        return a.lastName.compareTo(b.lastName);
      }
      if (_sortMinorsBy == 'surname_desc') 
      {
        return b.lastName.compareTo(a.lastName);
      }
      if (_sortMinorsBy == 'date_desc') 
      {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (_sortMinorsBy == 'date_asc') 
      {
        return a.createdAt.compareTo(b.createdAt);
      }
      return 0;
    });

    return result;
  }

  void _onSave() async 
  {
    if (widget.person.children != null) 
    {
      bool hasAdultWarning = false;
      for (final child in widget.person.children!) 
      {
        if (!_selectedMinors.containsKey(child.fiscalCode)) 
        {
          final minorIterable = _allMinors.where((m) => m.fiscalCode == child.fiscalCode);
          if (minorIterable.isNotEmpty) 
          {
            final minorData  = minorIterable.first;
            final bool isAdult = minorData.age == null || minorData.age! >= 18;

            if (isAdult) 
            {
              hasAdultWarning = true;
            }
            else if (minorData.parents != null) 
            {
              final otherParents = minorData.parents!.where((p) => p.fiscalCode != widget.person.fiscalCode).toList();
              if (otherParents.isEmpty) 
              {
                CustomSnackBar.show
                (
                  context: context, 
                  message: 'Impossibile rimuovere il figlio: ${minorData.firstName} ${minorData.lastName} rimarrebbe senza genitori.', 
                  isError: true,
                );
                return;
              }
            }
          }
        }
      }

      if (hasAdultWarning) 
      {
        CustomSnackBar.show
        (
          context: context, 
          message: 'Attenzione: rimuovendo il figlio si perdono le responsabilità genitoriali su un figlio maggiorenne.', 
          isError: false,
        );
      }
    }

    //MaxParentsValidation
    for (final minorId in _selectedMinors.keys) 
    {
      final minorIterable = _allMinors.where((m) => m.fiscalCode == minorId);
      if (minorIterable.isNotEmpty) 
      {
        final minorData    = minorIterable.first;
        final otherParents = minorData.parents?.where((p) => p.fiscalCode != widget.person.fiscalCode).toList() ?? [];
        
        if (otherParents.length >= 2) 
        {
          CustomSnackBar.show
          (
            context: context, 
            message: 'Impossibile aggiungere ${minorData.firstName} ${minorData.lastName}: ha già due genitori associati.', 
            isError: true,
          );
          return;
        }
      }
    }

    setState(() 
    {
      _isSubmitting = true;
    });

    try 
    {
      final payload = 
      {
        "general_data": 
        {
          "first_name":              widget.person.firstName,
          "last_name":               widget.person.lastName,
          "tax_code":                widget.person.fiscalCode,
          "gender":                  widget.person.gender,
          "birth_date":              widget.person.birthDate != null ? DateFormat('yyyy-MM-dd').format(widget.person.birthDate!) : null,
          "birth_city":              widget.person.birthCity,
          "birth_province":          widget.person.birthProvince,
          "residence_type":          widget.person.residenceType,
          "residence_address":       widget.person.address,
          "residence_street_number": widget.person.addressNumber,
          "residence_city":          widget.person.city,
          "residence_province":      widget.person.province,
          "postal_code":             widget.person.zipCode,
          "email":                   widget.person.email,
          "phone":                   widget.person.phoneNumber,
        },
        "roles":         widget.person.roles,
        "relationships": 
        {
          "minors_tax_codes":  _selectedMinors.values.map((d) => d.toJson()).toList(),
          "parents_tax_codes": (widget.person.parents ?? []).map((p) => ParentalRelationshipDraft
          (
            taxCode:           p.fiscalCode,
            authorizedPickup:  p.authorizedPickup,
            restrictionReason: p.pickupRestrictionReason,
          ).toJson()).toList(),
        }
      };

      await ApiService().updatePerson
      (
        widget.person.fiscalCode,
        payload,
      );

      if (mounted) 
      {
        CustomSnackBar.show
        (
          context: context, 
          message: 'Associazione figli aggiornata con successo!', 
          isError: false,
        );
        Navigator.of(context).pop(true);
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        CustomSnackBar.show
        (
          context: context, 
          message: e.toString().replaceAll('Exception: ', ''), 
          isError: true,
        );
      }
    } 
    finally 
    {
      if (mounted) 
      {
        setState(() 
        {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    final validMinors = _filteredMinors;

    return Dialog
    (
      backgroundColor: Colors.transparent,
      elevation:       0,
      child: Container
      (
        width:       MediaQuery.of(context).size.width * 0.85,
        height:      MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration: BoxDecoration
        (
          color:        const Color(0xFFF4F7F9),
          borderRadius: BorderRadius.circular(40),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x26000000),
              offset:     Offset(0, 12),
              blurRadius: 36,
            )
          ],
        ),
        child: ClipRRect
        (
          borderRadius: BorderRadius.circular(40),
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
                        stops:  [0.0, 1.0]
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
                        stops:  [0.0, 1.0]
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
                          'Gestisci Figli',
                          style: GoogleFonts.plusJakartaSans
                          (
                            fontSize:   26, 
                            fontWeight: FontWeight.w700, 
                            color:      const Color(0xFF003C82),
                          ),
                        ),
                        WizardHoverCloseButton
                        (
                          onTap: () 
                          {
                            Navigator.of(context).pop();
                          }
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),
                  Expanded
                  (
                    child: Padding
                    (
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column
                      (
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: 
                        [
                          const SizedBox(height: 16),
                          //SideBySideWhenThereIsRoom_StacksOnlyBelowTheThreshold_NotAlwaysSplit
                          //RivistoDopoUnControlloSuccessivo_LaRichiestaOriginaleNonSpecificava"sempre"
                          Center
                          (
                            child: ConstrainedBox
                            (
                              constraints: const BoxConstraints(maxWidth: 1320),
                              child: _ResponsiveSearchFilterRow
                              (
                                breakpoint: 750,
                                searchBar: WizardAnimatedSearchBar
                                (
                                  controller: _searchMinorsCtrl, 
                                  onChanged:  (value) 
                                  {
                                    setState(() 
                                    {
                                      _searchMinorsText = value;
                                    });
                                  }, 
                                  hintText:   'Cerca minore...',
                                ),
                                filterWidgets: 
                                [
                                  WizardFilterMenu<String>
                                  (
                                    hint:          'Ordina per', 
                                    icon:          Icons.sort_rounded, 
                                    value:         _sortMinorsBy, 
                                    menuWidth:     180, 
                                    showClearIcon: false, 
                                    onChanged:     (val) 
                                    {
                                      setState(() 
                                      {
                                        _sortMinorsBy = val;
                                      });
                                    }, 
                                    onClear:       () 
                                    {
                                    }, 
                                    options: 
                                    [
                                      WizardFilterOption(value: 'surname_asc',  label: 'Cognome (A-Z)'), 
                                      WizardFilterOption(value: 'surname_desc', label: 'Cognome (Z-A)'), 
                                      WizardFilterOption(value: 'name_asc',     label: 'Nome (A-Z)'), 
                                      WizardFilterOption(value: 'name_desc',    label: 'Nome (Z-A)'), 
                                      WizardFilterOption(value: 'date_desc',    label: 'Più recente'), 
                                      WizardFilterOption(value: 'date_asc',     label: 'Meno recente'),
                                    ]
                                  ),
                                  WizardFilterMenu<String>
                                  (
                                    hint:          'Tutti i ruoli', 
                                    icon:          Icons.badge_outlined, 
                                    value:         _filterMinorsRole, 
                                    menuWidth:     200, 
                                    showClearIcon: true, 
                                    onChanged:     (val) 
                                    {
                                      setState(() 
                                      {
                                        _filterMinorsRole = val;
                                      });
                                    }, 
                                    onClear:       () 
                                    {
                                      setState(() 
                                      {
                                        _filterMinorsRole = null;
                                      });
                                    }, 
                                    options: 
                                    [
                                      WizardFilterOption(value: 'STUDENTE',  label: 'Studente'), 
                                      WizardFilterOption(value: 'CORSISTA',  label: 'Corsista'), 
                                      WizardFilterOption(value: 'DOCENTE',   label: 'Docente'),
                                      WizardFilterOption(value: 'ASSOCIATO', label: 'Solo Associato'),
                                    ]
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded
                          (
                            child: _isLoadingData 
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
                              : SizedBox
                                (
                                  width: double.infinity,
                                  child: SingleChildScrollView
                                  (
                                    padding: const EdgeInsets.only(bottom: 40),
                                    child: Center
                                    (
                                      child: ConstrainedBox
                                      (
                                        constraints: const BoxConstraints(maxWidth: 1320),
                                        child: Wrap
                                        (
                                          spacing:    16,
                                          runSpacing: 16,
                                          alignment:  WrapAlignment.start,
                                          children:   validMinors.map((minor) 
                                          {
                                            final minorId    = minor.fiscalCode;
                                            final isSelected = _selectedMinors.containsKey(minorId);
                                            
                                            return WizardSelectablePersonCard
                                            (
                                              person:     minor,
                                              isSelected: isSelected,
                                              onTap:      () => _onCardTap(minor),
                                              onEdit:     isSelected ? () => _onCardTap(minor) : null,
                                              onRemove:   isSelected 
                                                  ? () => setState(() => _selectedMinors.remove(minorId)) 
                                                  : null,
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
                  Padding
                  (
                    padding: const EdgeInsets.only(top: 16, bottom: 32, left: 32, right: 32),
                    child: Center
                    (
                      child: _ResponsiveDialogButtonsRow
                      (
                        cancelText:        'ANNULLA',
                        cancelIcon:        Icons.close_rounded,
                        cancelColor:       const Color(0xFFE53935),
                        cancelHoverColor:  const Color(0xFFEF5350),
                        cancelOnPressed:   () => Navigator.of(context).pop(),
                        confirmText:       _isSubmitting ? 'SALVATAGGIO...' : 'SALVA MODIFICHE',
                        confirmIcon:       Icons.check_circle_outline,
                        confirmColor:      const Color(0xFF003C82),
                        confirmHoverColor: const Color(0xFF004D99),
                        confirmOnPressed:  _isSubmitting ? () {} : _onSave,
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

//UsataNelBottomBarDelDialogGestisciFigli_ImpilaITastiSottoSoglia_SalvaSopra_AnnullaSotto
class _ResponsiveDialogButtonsRow extends StatelessWidget
{
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

  const _ResponsiveDialogButtonsRow
  ({
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
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        final Widget cancelButton = SizedBox
        (
          width: _kButtonWidth,
          child: WizardAnimatedActionButton
          (
            text:       cancelText,
            icon:       cancelIcon,
            baseColor:  cancelColor,
            hoverColor: cancelHoverColor,
            onPressed:  cancelOnPressed,
          ),
        );

        final Widget confirmButton = SizedBox
        (
          width: _kButtonWidth,
          child: WizardAnimatedActionButton
          (
            text:       confirmText,
            icon:       confirmIcon,
            baseColor:  confirmColor,
            hoverColor: confirmHoverColor,
            onPressed:  confirmOnPressed,
          ),
        );

        if (isCompact)
        {
          return Column
          (
            mainAxisSize: MainAxisSize.min,
            children: 
            [
              confirmButton,
              const SizedBox(height: 16),
              cancelButton,
            ],
          );
        }

        return Row
        (
          mainAxisAlignment: MainAxisAlignment.center,
          children: 
          [
            cancelButton,
            const SizedBox(width: _kSpacing),
            confirmButton,
          ],
        );
      },
    );
  }
}

//DecideSeAffiancareRicercaEFiltriOImpilarli_SoloSottoSoglia_NonSempreCome_LaVersionePrecedenteSbagliava
class _ResponsiveSearchFilterRow extends StatelessWidget
{
  final Widget searchBar;
  final List<Widget> filterWidgets;
  final double breakpoint;
  final double spacing;

  const _ResponsiveSearchFilterRow
  ({
    required this.searchBar,
    required this.filterWidgets,
    this.breakpoint = 700,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
              searchBar,
              SizedBox(height: spacing),
              Wrap
              (
                spacing:    spacing,
                runSpacing: spacing,
                children:   filterWidgets,
              ),
            ],
          );
        }

        final List<Widget> rowChildren = [Expanded(child: searchBar)];
        for (final w in filterWidgets)
        {
          rowChildren.add(SizedBox(width: spacing));
          rowChildren.add(w);
        }

        return Row(children: rowChildren);
      },
    );
  }
}