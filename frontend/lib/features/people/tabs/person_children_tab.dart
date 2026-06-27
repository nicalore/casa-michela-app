import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/child_item.dart';
import '../models/person_item.dart';

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
  int _selectedChildIndex = 0;

  Widget _buildSubNavigation(List<ChildItem> children) 
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row
      (
        children: List.generate(children.length, (index) 
        {
          final isSelected = _selectedChildIndex == index;
          final child      = children[index];

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
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    final List<ChildItem> children = widget.person.children ?? [];

    if (children.isEmpty) 
    {
      return Center
      (
        child: Padding
        (
          padding: const EdgeInsets.only(top: 32.0),
          child: Text
          (
            'Nessun figlio associato a questa anagrafica genitore.',
            style: GoogleFonts.plusJakartaSans
            (
              fontSize:   16,
              fontWeight: FontWeight.w500,
              color:      const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    if (_selectedChildIndex >= children.length) 
    {
      _selectedChildIndex = 0;
    }

    final child = children[_selectedChildIndex];

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
              _buildSubNavigation(children),
              IntrinsicHeight
              (
                child: Row
                (
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: 
                  [
                    Expanded
                    (
                      child: _ChildSectionCard
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
                    ),
                    const SizedBox(width: 24),
                    Expanded
                    (
                      child: _ChildSectionCard
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
                      child: _ChildSectionCard
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
                      child: _ChildSectionCard
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
            ],
          ),
        ),
      ),
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