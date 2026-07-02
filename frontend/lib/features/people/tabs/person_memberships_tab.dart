import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/membership_item.dart';
import '../models/person_item.dart';
import '../person_wizard_components.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../services/api_service.dart';

class PersonMembershipsTab extends StatelessWidget 
{
  final PersonItem   person;
  final VoidCallback onUpdate;

  const PersonMembershipsTab
  ({
    super.key,
    required this.person,
    required this.onUpdate,
  });

  void _showEditDialog(BuildContext context) 
  {
    showGeneralDialog
    (
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'EditMemberships', 
      barrierColor:       Colors.black.withValues(alpha: .15), 
      transitionDuration: const Duration(milliseconds: 240),
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
              child: _EditMembershipsDialog
              (
                person:   person, 
                onUpdate: onUpdate,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRevokeDialog(BuildContext context) 
  {
    showGeneralDialog
    (
      context:            context,
      barrierDismissible: true,
      barrierLabel:       'RevokeMembership',
      barrierColor:       Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
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
              child: _RevokeMembershipDialog
              (
                person:   person, 
                onUpdate: onUpdate,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    final List<MembershipItem> memberships = List<MembershipItem>.from(person.memberships ?? []);
    memberships.sort((a, b) => b.year.compareTo(a.year));

    final MembershipItem? latest = memberships.isNotEmpty ? memberships.first : null;
    
    bool isEnrolled = false;
    bool isRevoked  = false;

    if (latest != null)
    {
      if (latest.revocation != 'NO')
      {
        isRevoked = true;
      }
      final DateTime now = DateTime.now();
      if (latest.revocation == 'NO' && now.isBefore(latest.endDate.add(Duration(days: latest.renewalPeriodDays))))
      {
        isEnrolled = true;
      }
    }

    final MembershipItem?      currentMembership = isEnrolled ? latest : null;
    final List<MembershipItem> pastMemberships   = isEnrolled ? memberships.skip(1).toList() : memberships;

    final bool isFemale = person.gender == 'F';
    final bool isActive = isEnrolled ? (person.isActiveCollaborator ?? false) : false;

    return SingleChildScrollView
    (
      padding: const EdgeInsets.only(bottom: 40),
      child: Column
      (
        crossAxisAlignment: CrossAxisAlignment.start,
        children: 
        [
          _buildStatusCard(isEnrolled, isFemale, isActive),
          const SizedBox(height: 48),
          
          if (currentMembership != null) ...
          [
            Text
            (
              'Iscrizione attuale',
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   24,
                fontWeight: FontWeight.w700,
                color:      const Color(0xFF003C82),
              ),
            ),
            const SizedBox(height: 16),
            _buildMembershipCard(currentMembership, isCurrent: true),
            const SizedBox(height: 32),
          ],
          
          if (pastMemberships.isNotEmpty) ...
          [
            Text
            (
              'Iscrizioni passate',
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   24,
                fontWeight: FontWeight.w700,
                color:      const Color(0xFF003C82),
              ),
            ),
            const SizedBox(height: 16),
            ...pastMemberships.map((m) => Padding
            (
              padding: const EdgeInsets.only(bottom: 16),
              child:   _buildMembershipCard(m, isCurrent: false),
            )),
          ],
          
          if (currentMembership == null && pastMemberships.isEmpty) ...
          [
            Center
            (
              child: Text
              (
                'Nessuna iscrizione registrata.',
                style: GoogleFonts.plusJakartaSans
                (
                  fontSize:   16,
                  fontWeight: FontWeight.w500,
                  color:      const Color(0xFF64748B),
                ),
              ),
            ),
          ],
          
          if (!isRevoked && latest != null) ...
          [
            const SizedBox(height: 40),
            Center
            (
              child: _ResponsiveActionButtonsRow
              (
                primaryText:         'MODIFICA ISCRIZIONI',
                primaryIcon:         Icons.edit_rounded,
                primaryColor:        const Color(0xFF003C82),
                primaryHoverColor:   const Color(0xFF004D99),
                primaryOnPressed:    () => _showEditDialog(context),
                secondaryText:       'REVOCA ISCRIZIONE',
                secondaryIcon:       Icons.gavel_rounded,
                secondaryColor:      const Color(0xFFE53935),
                secondaryHoverColor: const Color(0xFFEF5350),
                secondaryOnPressed:  () => _showRevokeDialog(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isEnrolled, bool isFemale, bool isActiveCollaborator)
  {
    final String statusText = isEnrolled 
        ? (isFemale ? 'Iscritta' : 'Iscritto') 
        : (isFemale ? 'Non iscritta' : 'Non iscritto');
    
    final String collabText = isActiveCollaborator
        ? (isFemale ? 'Collaboratrice attiva' : 'Collaboratore attivo')
        : 'Non collaborante';

    final Color iconColor = isEnrolled ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

    //IsolateSelectionToCardBody
    return Center
    (
      child: SelectionArea
      (
        child: Container
        (
          width:       double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding:     const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration:  BoxDecoration
          (
            color:        Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: const Color(0xFFE2E8F0)),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: 
            [
              Row
              (
                mainAxisAlignment: MainAxisAlignment.center,
                children: 
                [
                  Icon
                  (
                    isEnrolled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: iconColor,
                    size:  32,
                  ),
                  const SizedBox(width: 12),
                  Text
                  (
                    statusText,
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize:   24,
                      fontWeight: FontWeight.w800,
                      color:      const Color(0xFF2A2A2A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container
              (
                padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration
                (
                  color:        const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(100),
                  border:       Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row
                (
                  mainAxisSize: MainAxisSize.min,
                  children: 
                  [
                    Icon
                    (
                      isActiveCollaborator ? Icons.handshake_outlined : Icons.work_off_rounded,
                      color: isActiveCollaborator ? const Color(0xFF003C82) : const Color(0xFF94A3B8),
                      size:  18,
                    ),
                    const SizedBox(width: 8),
                    Text
                    (
                      collabText,
                      style: GoogleFonts.plusJakartaSans
                      (
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      isActiveCollaborator ? const Color(0xFF003C82) : const Color(0xFF64748B),
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

  Widget _buildMembershipCard(MembershipItem membership, {required bool isCurrent})
  {
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
    final DateTime   deadline   = membership.endDate.add(Duration(days: membership.renewalPeriodDays));
    
    //IsolateSelectionToCardBody
    return SelectionArea
    (
      child: Container
      (
        width:      double.infinity,
        padding:    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all
          (
            color: const Color(0xFF003C82).withValues(alpha: 0.3),
            width: 2.0,
          ),
        ),
        child: Column
        (
          crossAxisAlignment: CrossAxisAlignment.center,
          children: 
          [
            Text
            (
              'Anno ${membership.year}',
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   24,
                fontWeight: FontWeight.w800,
                color:      const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
            if (membership.revocation != 'NO') ...
            [
              const SizedBox(height: 8),
              Text
              (
                membership.revocation == 'EXPULSION' ? 'Iscrizione revocata (Espulsione)' : 'Iscrizione revocata (Dimissioni)',
                style: GoogleFonts.plusJakartaSans
                (
                  fontSize:   15,
                  fontWeight: FontWeight.w600,
                  color:      const Color(0xFFE53935),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            //SempreIncolonnate_NonSoloQuandoLoSpazioNonBasta_RichiestaEsplicita
            _buildStackedDateItems
            (
              [
                _buildDateItem('Data inizio', dateFormat.format(membership.startDate)),
                _buildDateItem('Data fine', dateFormat.format(membership.endDate)),
                if (isCurrent)
                  _buildDateItem
                  (
                    'Rinnovo entro', 
                    membership.revocation == 'NO' ? dateFormat.format(deadline) : '-', 
                    highlight: false,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedDateItems(List<Widget> items)
  {
    final List<Widget> stacked = [];
    for (int i = 0; i < items.length; i++)
    {
      if (i > 0) stacked.add(const SizedBox(height: 20));
      stacked.add(items[i]);
    }
    return Column
    (
      mainAxisSize: MainAxisSize.min,
      children: stacked,
    );
  }

  Widget _buildDateItem(String label, String value, {bool highlight = false})
  {
    return Column
    (
      mainAxisSize: MainAxisSize.min,
      children: 
      [
        Text
        (
          label,
          style: GoogleFonts.plusJakartaSans
          (
            fontSize:   14,
            fontWeight: FontWeight.w600,
            color:      const Color(0xFF94A3B8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text
        (
          value,
          style: GoogleFonts.plusJakartaSans
          (
            fontSize:   18,
            fontWeight: FontWeight.w700,
            color:      highlight ? const Color(0xFF003C82) : const Color(0xFF334155),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

//DecidesBetweenSideBySideAndStackedButtons_BasedOnActualAvailableWidth
class _ResponsiveActionButtonsRow extends StatelessWidget
{
  final String primaryText;
  final IconData primaryIcon;
  final Color primaryColor;
  final Color primaryHoverColor;
  final VoidCallback primaryOnPressed;

  final String secondaryText;
  final IconData secondaryIcon;
  final Color secondaryColor;
  final Color secondaryHoverColor;
  final VoidCallback secondaryOnPressed;

  const _ResponsiveActionButtonsRow
  ({
    required this.primaryText,
    required this.primaryIcon,
    required this.primaryColor,
    required this.primaryHoverColor,
    required this.primaryOnPressed,
    required this.secondaryText,
    required this.secondaryIcon,
    required this.secondaryColor,
    required this.secondaryHoverColor,
    required this.secondaryOnPressed,
  });

  static const double _kButtonWidth = 240;
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

        final Widget primaryButton = SizedBox
        (
          width: _kButtonWidth,
          child: AnimatedActionButton
          (
            text:       primaryText,
            icon:       primaryIcon,
            baseColor:  primaryColor,
            hoverColor: primaryHoverColor,
            onPressed:  primaryOnPressed,
          ),
        );

        final Widget secondaryButton = SizedBox
        (
          width: _kButtonWidth,
          child: AnimatedActionButton
          (
            text:       secondaryText,
            icon:       secondaryIcon,
            baseColor:  secondaryColor,
            hoverColor: secondaryHoverColor,
            onPressed:  secondaryOnPressed,
          ),
        );

        if (isCompact)
        {
          return Column
          (
            mainAxisSize: MainAxisSize.min,
            children: 
            [
              primaryButton,
              const SizedBox(height: 16),
              secondaryButton,
            ],
          );
        }

        return Row
        (
          mainAxisAlignment: MainAxisAlignment.center,
          children: 
          [
            primaryButton,
            const SizedBox(width: _kSpacing),
            secondaryButton,
          ],
        );
      },
    );
  }
}

//UsataDentroIDueDialog_PulsantiAPienaLarghezzaCheSiImpilanoSottoSoglia
//IlPrimoParametro_confirm_VaSempreSopraQuandoImpilati_IlSecondo_cancel_VaSempreSotto
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

  //SottoQuestaLarghezzaTestiLunghiComeCONFERMAREVOCARischianoDiEssereSchiacciati
  static const double _kBreakpoint = 460;

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        final Widget cancelButton = AnimatedActionButton
        (
          text:       cancelText,
          icon:       cancelIcon,
          baseColor:  cancelColor,
          hoverColor: cancelHoverColor,
          onPressed:  cancelOnPressed,
        );

        final Widget confirmButton = AnimatedActionButton
        (
          text:       confirmText,
          icon:       confirmIcon,
          baseColor:  confirmColor,
          hoverColor: confirmHoverColor,
          onPressed:  confirmOnPressed,
        );

        if (isCompact)
        {
          //TastoAnnullaSempreInFondoQuandoIBottoniSiImpilano_RichiestaEsplicita
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
          children: 
          [
            Expanded(child: cancelButton),
            const SizedBox(width: 16),
            Expanded(child: confirmButton),
          ],
        );
      },
    );
  }
}

class _RevokeMembershipDialog extends StatefulWidget 
{
  final PersonItem   person;
  final VoidCallback onUpdate;

  const _RevokeMembershipDialog
  ({
    required this.person, 
    required this.onUpdate,
  });

  @override
  State<_RevokeMembershipDialog> createState() => _RevokeMembershipDialogState();
}

class _RevokeMembershipDialogState extends State<_RevokeMembershipDialog> 
{
  final ApiService _apiService   = ApiService();
  String           _selectedType = 'Dimissioni';
  bool             _isSaving     = false;

  Future<void> _submitRevocation() async 
  {
    setState(() => _isSaving = true);
    
    final String typeEn = _selectedType == 'Espulsione' ? 'EXPULSION' : 'RESIGNATION';
    
    try 
    {
      await _apiService.revokePersonMembership(widget.person.fiscalCode, typeEn);
      
      if (mounted) 
      {
        CustomSnackBar.show
        (
          context: context, 
          message: 'Iscrizione revocata con successo.', 
          isError: false,
        );
        Navigator.of(context).pop();
        widget.onUpdate();
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    return Dialog
    (
      backgroundColor: Colors.transparent,
      elevation:       0,
      child: Container
      (
        //LarghezzaResponsive_RiempieLoSpazioDisponibileMaMaiOltre540
        //SenzaQuestoIBottoniInternoNonRicevonoMaiUnoStrettoAbbastanzaDaImpilarsi
        width:       double.infinity,
        constraints: const BoxConstraints(maxWidth: 540),
        padding:     const EdgeInsets.all(32),
        decoration:  BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x1A000000),
              offset:     Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column
        (
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            Row
            (
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: 
              [
                Text
                (
                  'Revoca Iscrizione',
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                  ),
                ),
                FadeHoverIconButton
                (
                  icon:       Icons.close,
                  color:      const Color(0xFF003C82),
                  hoverColor: const Color(0xFFE3F2FD),
                  onTap:      () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Container
            (
              padding:    const EdgeInsets.all(16),
              decoration: BoxDecoration
              (
                color:        const Color(0xFF003C82).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: const Color(0xFF003C82).withValues(alpha: 0.3)),
              ),
              child: Row
              (
                children: 
                [
                  const Icon(Icons.warning_rounded, color: Color(0xFF003C82), size: 28),
                  const SizedBox(width: 16),
                  Expanded
                  (
                    child: Text
                    (
                      'ATTENZIONE: Questa operazione è irreversibile. L\'iscrizione terminerà in data odierna e lo stato di collaborazione verrà disattivato.',
                      style: GoogleFonts.plusJakartaSans
                      (
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      const Color(0xFF003C82),
                        height:     1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text
            (
              'Seleziona la motivazione della revoca:',
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color:      const Color(0xFF003C82),
              ),
            ),
            const SizedBox(height: 12),
            _FormOverlayDropdown
            (
              value:      _selectedType,
              options:    const ['Dimissioni', 'Espulsione'],
              onSelected: (val) => setState(() => _selectedType = val),
            ),
            const SizedBox(height: 32),
            _ResponsiveDialogButtonsRow
            (
              cancelText:        'ANNULLA',
              cancelIcon:        Icons.cancel_outlined,
              cancelColor:       const Color(0xFFE53935),
              cancelHoverColor:  const Color(0xFFEF5350),
              cancelOnPressed:   () => Navigator.of(context).pop(),
              confirmText:       _isSaving ? 'REVOCA...' : 'CONFERMA REVOCA',
              confirmIcon:       Icons.gavel_rounded,
              confirmColor:      const Color(0xFF003C82),
              confirmHoverColor: const Color(0xFF004D99),
              confirmOnPressed:  _isSaving ? () {} : _submitRevocation,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMembershipsDialog extends StatefulWidget 
{
  final PersonItem   person;
  final VoidCallback onUpdate;

  const _EditMembershipsDialog
  ({
    required this.person, 
    required this.onUpdate,
  });

  @override
  State<_EditMembershipsDialog> createState() => _EditMembershipsDialogState();
}

class _EditMembershipsDialogState extends State<_EditMembershipsDialog> 
{
  final ApiService _apiService = ApiService();
  bool             _isSaving   = false;
  
  late bool           _isActiveCollaborator;
  final List<_MembershipRowData> _rows = [];
  final Map<String, String>      _errors = {};

  @override
  void initState() 
  {
    super.initState();
    _isActiveCollaborator = widget.person.isActiveCollaborator ?? false;
    
    final dateFormat = DateFormat('dd/MM');
    final members    = widget.person.memberships ?? [];
    
    for (var m in members) 
    {
      _rows.add(_MembershipRowData
      (
        yearCtrl:   TextEditingController(text: m.year.toString()),
        dateCtrl:   TextEditingController(text: dateFormat.format(m.startDate)),
        revocation: m.revocation,
      ));
    }
  }

  @override
  void dispose() 
  {
    for (var r in _rows) 
    {
      r.yearCtrl.dispose();
      r.dateCtrl.dispose();
    }
    super.dispose();
  }

  void _sortRowsByYear()
  {
    _rows.sort((a, b) 
    {
      int yearA = int.tryParse(a.yearCtrl.text) ?? 0;
      int yearB = int.tryParse(b.yearCtrl.text) ?? 0;
      return yearB.compareTo(yearA);
    });
  }

  void _addEmptyRow() 
  {
    int lastYear = DateTime.now().year;
    if (_rows.isNotEmpty) 
    {
      int maxYear = 0;
      for (var r in _rows)
      {
        int y = int.tryParse(r.yearCtrl.text) ?? 0;
        if (y > maxYear) 
        {
          maxYear = y;
        }
      }
      lastYear = maxYear > 0 ? maxYear : lastYear;
    }
    
    setState(() 
    {
      _rows.add(_MembershipRowData
      (
        yearCtrl:   TextEditingController(text: (lastYear - 1).toString()),
        dateCtrl:   TextEditingController(),
        revocation: 'NO',
      ));
    });
  }

  bool _isValidDayMonthYear(String dm, String yearStr) 
  {
    try 
    {
      final parts = dm.split('/');
      if (parts.length != 2) 
      {
        return false;
      }
      
      final day   = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year  = int.parse(yearStr);
      final date  = DateTime(year, month, day);
      
      return date.year == year && date.month == month && date.day == day;
    } 
    catch (_)
    {
      return false;
    }
  }

  Future<void> _save() async 
  {
    setState(() => _errors.clear());
    bool hasErrors = false;
    
    List<Map<String, dynamic>> payloadMemberships = [];
    final Set<int>             distinctYears      = {};

    for (int i = 0; i < _rows.length; i++) 
    {
      final r         = _rows[i];
      bool  yearValid = false;

      if (r.yearCtrl.text.isEmpty || !RegExp(r'^\d{4}$').hasMatch(r.yearCtrl.text)) 
      {
        _errors['year_$i'] = 'Anno non valido';
        hasErrors          = true;
      }
      else
      {
        int parsedYear = int.parse(r.yearCtrl.text);
        if (distinctYears.contains(parsedYear))
        {
          _errors['year_$i'] = 'Anno già inserito';
          hasErrors          = true;
        }
        else
        {
          distinctYears.add(parsedYear);
          yearValid = true;
        }
      }
      
      if (r.dateCtrl.text.isEmpty)
      {
        _errors['start_$i'] = 'Campo obbligatorio';
        hasErrors           = true;
      }
      else if (yearValid && !_isValidDayMonthYear(r.dateCtrl.text.trim(), r.yearCtrl.text.trim())) 
      {
        _errors['start_$i'] = 'Data non valida';
        hasErrors           = true;
      }
      else if (!yearValid && !RegExp(r'^\d{2}/\d{2}$').hasMatch(r.dateCtrl.text.trim()))
      {
        _errors['start_$i'] = 'Formato gg/mm';
        hasErrors           = true;
      }

      if (!hasErrors) 
      {
        final partsStart = r.dateCtrl.text.split('/');
        final isoStart   = '${r.yearCtrl.text}-${partsStart[1]}-${partsStart[0]}';
        final isoEnd     = '${r.yearCtrl.text}-12-31';

        payloadMemberships.add
        ({
          "year":                int.parse(r.yearCtrl.text),
          "start_date":          isoStart,
          "end_date":            isoEnd,
          "renewal_period_days": 30,
          "revocation":          r.revocation,
        });
      }
    }

    if (_rows.isEmpty) 
    {
      CustomSnackBar.show
      (
        context: context, 
        message: 'Deve esserci almeno un\'iscrizione.', 
        isError: true,
      );
      return;
    }

    if (hasErrors) 
    {
      setState(() {});
      CustomSnackBar.show
      (
        context: context, 
        message: 'Correggi gli errori prima di salvare.', 
        isError: true,
      );
      return;
    }

    payloadMemberships.sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));

    bool isEnrolled = false;
    final now       = DateTime.now();
    for (var m in payloadMemberships)
    {
      if (m['revocation'] == 'NO')
      {
        try 
        {
          final endDate = DateTime.parse(m['end_date']);
          if (now.isBefore(endDate.add(Duration(days: m['renewal_period_days']))))
          {
            isEnrolled = true;
            break;
          }
        } 
        catch (_) {}
      }
    }

    if (_isActiveCollaborator && !isEnrolled) 
    {
      CustomSnackBar.show
      (
        context: context, 
        message: 'Impossibile impostare "Collaboratore attivo" senza un\'iscrizione in corso.', 
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try 
    {
      await _apiService.updatePersonMemberships
      (
        widget.person.fiscalCode,
        _isActiveCollaborator,
        payloadMemberships,
      );
      
      if (mounted) 
      {
        CustomSnackBar.show
        (
          context: context, 
          message: 'Iscrizioni aggiornate con successo!', 
          isError: false,
        );
        Navigator.of(context).pop();
        widget.onUpdate();
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
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildFieldLabel(String text) 
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 8),
      child: Text
      (
        text,
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   14,
          fontWeight: FontWeight.w700,
          color:      const Color(0xFF003C82),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    return Dialog
    (
      backgroundColor: Colors.transparent, 
      elevation:       0,
      child: Container
      (
        //LarghezzaResponsive_RiempieLoSpazioDisponibileMaMaiOltre680
        width:       double.infinity,
        constraints: BoxConstraints
        (
          maxWidth:  680,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration:  BoxDecoration
        (
          color:        Colors.white, 
          borderRadius: BorderRadius.circular(30), 
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x1A000000), 
              offset:     Offset(0, 8), 
              blurRadius: 24,
            ),
          ],
        ),
        child: Column
        (
          mainAxisSize: MainAxisSize.min,
          children: 
          [
            Padding
            (
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row
              (
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: 
                [
                  Text
                  (
                    'Modifica Iscrizioni', 
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize:   22, 
                      fontWeight: FontWeight.w700, 
                      color:      const Color(0xFF003C82),
                    ),
                  ),
                  FadeHoverIconButton
                  (
                    icon:       Icons.close, 
                    color:      const Color(0xFF003C82), 
                    hoverColor: const Color(0xFFE3F2FD), 
                    onTap:      () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Flexible
            (
              child: SingleChildScrollView
              (
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                child: SizedBox
                (
                  width: double.infinity,
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      _buildFieldLabel('Collaboratore attivo'),
                      _FormOverlayDropdown
                      (
                        value:      _isActiveCollaborator ? 'Sì' : 'No',
                        options:    const ['Sì', 'No'],
                        onSelected: (val) => setState(() => _isActiveCollaborator = (val == 'Sì')),
                      ),
                      const SizedBox(height: 32),
                      _buildFieldLabel('Storico Iscrizioni'),
                      //OgniRigaOraDecideDaSolaSeAffiancareOImpilareIDueCampi
                      ...List.generate(_rows.length, (i) 
                      {
                        final r = _rows[i];
                        return _MembershipEditRow
                        (
                          yearCtrl:      r.yearCtrl,
                          dateCtrl:      r.dateCtrl,
                          yearError:     _errors['year_$i'],
                          startError:    _errors['start_$i'],
                          onYearChanged: (_) => setState(() => _errors.remove('year_$i')),
                          onDateChanged: (_) => setState(() => _errors.remove('start_$i')),
                          onRemove:      () => setState(() => _rows.removeAt(i)),
                        );
                      }),
                      const SizedBox(height: 8),
                      Align
                      (
                        alignment: Alignment.centerRight,
                        child: WizardTextLinkButton
                        (
                          text:  'Aggiungi iscrizione',
                          icon:  Icons.add_rounded,
                          onTap: _addEmptyRow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding
            (
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
              child: _ResponsiveDialogButtonsRow
              (
                cancelText:        'ANNULLA',
                cancelIcon:        Icons.cancel_outlined,
                cancelColor:       const Color(0xFFE53935),
                cancelHoverColor:  const Color(0xFFEF5350),
                cancelOnPressed:   () => Navigator.of(context).pop(),
                confirmText:       _isSaving ? 'SALVATAGGIO...' : 'SALVA MODIFICHE',
                confirmIcon:       Icons.save_outlined,
                confirmColor:      const Color(0xFF003C82),
                confirmHoverColor: const Color(0xFF004D99),
                confirmOnPressed:  _isSaving ? () {} : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//DecideSeAffiancareOImpilareAnnoEDataInizio_InBaseAllaLarghezzaRealeDellaRiga
//DaImpilato_Il"-"SiSpostaAccantoAllUltimoCampo_AllineatoInBasso
class _MembershipEditRow extends StatelessWidget
{
  final TextEditingController yearCtrl;
  final TextEditingController dateCtrl;
  final String? yearError;
  final String? startError;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onRemove;

  const _MembershipEditRow
  ({
    required this.yearCtrl,
    required this.dateCtrl,
    required this.yearError,
    required this.startError,
    required this.onYearChanged,
    required this.onDateChanged,
    required this.onRemove,
  });

  static const double _kBreakpoint = 360;

  Widget _buildFieldBlock(String label, Widget field)
  {
    return Column
    (
      crossAxisAlignment: CrossAxisAlignment.start,
      children: 
      [
        Text
        (
          label, 
          style: GoogleFonts.plusJakartaSans
          (
            fontSize:   12, 
            fontWeight: FontWeight.w600, 
            color:      const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        field,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container
    (
      margin:     const EdgeInsets.only(bottom: 16),
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration
      (
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFFE2E8F0)),
        color:        const Color(0xFFF8FAFC),
      ),
      child: LayoutBuilder
      (
        builder: (context, constraints)
        {
          final bool isCompact = constraints.maxWidth < _kBreakpoint;

          final Widget yearField = _buildFieldBlock
          (
            'Anno',
            WizardAnimatedTextField
            (
              controller:   yearCtrl,
              hint:         'Es. 2024',
              errorText:    yearError,
              keyboardType: TextInputType.number,
              onChanged:    onYearChanged,
            ),
          );

          final Widget dateField = _buildFieldBlock
          (
            'Data inizio',
            WizardAnimatedTextField
            (
              controller:      dateCtrl,
              hint:            'gg/mm',
              errorText:       startError,
              inputFormatters: [WizardDayMonthInputFormatter()],
              keyboardType:    TextInputType.number,
              onChanged:       onDateChanged,
            ),
          );

          if (isCompact)
          {
            return Column
            (
              crossAxisAlignment: CrossAxisAlignment.start,
              children: 
              [
                yearField,
                const SizedBox(height: 16),
                Row
                (
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: 
                  [
                    Expanded(child: dateField),
                    const SizedBox(width: 8),
                    WizardRemoveRowButton(onTap: onRemove),
                  ],
                ),
              ],
            );
          }

          return Row
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              Expanded(flex: 2, child: yearField),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: dateField),
              Padding
              (
                padding: const EdgeInsets.only(top: 22, left: 8),
                child:   WizardRemoveRowButton(onTap: onRemove),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MembershipRowData 
{
  final TextEditingController yearCtrl;
  final TextEditingController dateCtrl;
  String                      revocation;

  _MembershipRowData
  ({
    required this.yearCtrl,
    required this.dateCtrl,
    required this.revocation,
  });
}

class _FormOverlayDropdown extends StatefulWidget 
{
  final String               value;
  final List<String>         options;
  final ValueChanged<String> onSelected;

  const _FormOverlayDropdown
  ({
    required this.value, 
    required this.options, 
    required this.onSelected,
  });

  @override
  State<_FormOverlayDropdown> createState() => _FormOverlayDropdownState();
}

class _FormOverlayDropdownState extends State<_FormOverlayDropdown> 
{
  final GlobalKey                         _buttonKey = GlobalKey();
  OverlayEntry?                           _overlayEntry;
  final GlobalKey<_FormOverlayContentState> _menuKey = GlobalKey();
  bool                                    _isHovered = false;

  void _toggleMenu() 
  {
    if (_overlayEntry != null) 
    {
      _closeMenu(); 
      return; 
    }
    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size      = renderBox.size;
    final offset    = renderBox.localToGlobal(Offset.zero);

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
            top:  offset.dy + size.height + 4,
            left: offset.dx,
            child: _FormOverlayContent
            (
              key:          _menuKey,
              currentValue: widget.value,
              options:      widget.options,
              width:        size.width,
              onSelected:   (val) 
              {
                widget.onSelected(val); 
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
          padding:    const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration
          (
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all
            (
              color: _isHovered ? const Color(0xFF003C82) : const Color(0xFFE2E8F0), 
              width: 1.5,
            ),
          ),
          child: Row
          (
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: 
            [
              Text
              (
                widget.value,
                style: GoogleFonts.plusJakartaSans
                (
                  fontSize:   16, 
                  fontWeight: FontWeight.w600, 
                  color:      const Color(0xFF2A2A2A),
                ),
              ),
              Icon
              (
                Icons.keyboard_arrow_down_rounded, 
                color: _isHovered ? const Color(0xFF003C82) : const Color(0xFF8A8A8A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormOverlayContent extends StatefulWidget 
{
  final String               currentValue;
  final List<String>         options;
  final ValueChanged<String> onSelected;
  final double               width;

  const _FormOverlayContent
  ({
    super.key, 
    required this.currentValue, 
    required this.options, 
    required this.onSelected, 
    required this.width,
  });

  @override
  State<_FormOverlayContent> createState() => _FormOverlayContentState();
}

class _FormOverlayContentState extends State<_FormOverlayContent> 
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
        setState(() => _expanded = true); 
      }
    });
  }

  Future<void> hide() async 
  {
    if (mounted) 
    {
      setState(() => _expanded = false);
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
        width:      widget.width,
        decoration: BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:        Color(0x14000000), 
              blurRadius:   20, 
              spreadRadius: 2,
            ),
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
                child: Column
                (
                  mainAxisSize:       MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:           widget.options.map((option) 
                  {
                    return _FormOverlayMenuItem
                    (
                      text:       option,
                      isSelected: widget.currentValue == option,
                      onTap:      () => widget.onSelected(option),
                    );
                  }).toList(),
                ),
              ) 
            : SizedBox
              (
                width:  widget.width, 
                height: 0,
              ),
        ),
      ),
    );
  }
}

class _FormOverlayMenuItem extends StatefulWidget 
{
  final String       text;
  final bool         isSelected;
  final VoidCallback onTap;

  const _FormOverlayMenuItem
  ({
    required this.text, 
    required this.isSelected, 
    required this.onTap,
  });

  @override
  State<_FormOverlayMenuItem> createState() => _FormOverlayMenuItemState();
}

class _FormOverlayMenuItemState extends State<_FormOverlayMenuItem> 
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
                    fontWeight: (widget.isSelected || _hover) ? FontWeight.w700 : FontWeight.w500,
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