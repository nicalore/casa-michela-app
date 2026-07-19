import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ministry_subject_item.dart';
import '../models/association_subject_item.dart';
import '../widgets/ministry_subject_card.dart';
import '../../../shared/widgets/snackbar.dart'; 
import '../../../shared/widgets/shared_components.dart';

class MinistrySubjectsTab extends StatefulWidget
{
  //DatiCondivisiRicevutiDallAlto_AssociationPageEUnicaFonteDiVeritaEProprietariaDelFetch
  final List<MinistrySubjectItem> ministrySubjects;
  //SoloLettura_ServeAlWizardPerAssociareLeDisciplineInterne_ProprietarioReaeEAssociationSubjectsTab
  final List<AssociationSubjectItem> associationSubjects;
  final Future<bool> Function(String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError) onCreate;
  final Future<bool> Function(int id, String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError) onEdit;
  final void Function(MinistrySubjectItem item) onDelete;

  const MinistrySubjectsTab({
    super.key,
    required this.ministrySubjects,
    required this.associationSubjects,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<MinistrySubjectsTab> createState() => _MinistrySubjectsTabState();
}

class _MinistrySubjectsTabState extends State<MinistrySubjectsTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _sortBy = 'name_asc';
  String? _filterArea;
  String? _filterLevel;

  bool _newSubjectHover = false;

  List<MinistrySubjectItem> get _filteredSubjects
  {
    var result = widget.ministrySubjects.where((subject)
    {
      final query = _searchText.toLowerCase();
      final matchesSearch = subject.name.toLowerCase().contains(query);
      final matchesArea = _filterArea == null || subject.areas.contains(_filterArea);
      final matchesLevel = _filterLevel == null || subject.level == _filterLevel;
      return matchesSearch && matchesArea && matchesLevel;
    }).toList();

    result.sort((a, b)
    {
      if (_sortBy == 'name_asc') return a.name.compareTo(b.name);
      if (_sortBy == 'name_desc') return b.name.compareTo(a.name);
      if (_sortBy == 'date_asc') return a.createdAt.compareTo(b.createdAt);
      if (_sortBy == 'date_desc') return b.createdAt.compareTo(a.createdAt);
      return 0;
    });

    return result;
  }

  void _showWizard({MinistrySubjectItem? subject, VoidCallback? onCancelEdit})
  {
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: 'MinistrySubjectWizard', barrierColor: Colors.black.withValues(alpha: .15), transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: _MinistrySubjectWizardDialog(
                existingSubject: subject,
                //LettaSempreDaWidget.associationSubjects_AggiornataAutomaticamenteDaAssociationPageAlProssimoSetState
                availableAssociationSubjects: widget.associationSubjects,
                onCancelEdit: onCancelEdit,
                onSave: (name, level, areas, description, associationIds, onError) async
                {
                  if (subject == null) return await widget.onCreate(name, level, areas, description, associationIds, onError);
                  else return await widget.onEdit(subject.id, name, level, areas, description, associationIds, onError);
                },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: AnimatedSearchBar(controller: _searchController, onChanged: (value) => setState(() => _searchText = value), hintText: 'Cerca materia ministeriale...')),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _newSubjectHover = true), onExit: (_) => setState(() => _newSubjectHover = false),
              child: GestureDetector(
                onTap: () => _showWizard(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180), curve: Curves.easeOut, height: 50, padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: _newSubjectHover ? const Color(0xFF003C82) : Colors.transparent, width: 2), boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)]),
                  child: Center(child: Text('Nuova materia', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)))),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CustomFilterMenu<String>(hint: 'Ordina per', icon: Icons.sort_rounded, value: _sortBy, menuWidth: 180, showClearIcon: false, onChanged: (val) => setState(() => _sortBy = val), onClear: () {}, options: [_FilterOption(value: 'name_asc', label: 'Nome (A-Z)'), _FilterOption(value: 'name_desc', label: 'Nome (Z-A)'), _FilterOption(value: 'date_desc', label: 'Più recente'), _FilterOption(value: 'date_asc', label: 'Meno recente')]),
            _CustomFilterMenu<String>(hint: 'Tutti i livelli', icon: Icons.school_outlined, value: _filterLevel, menuWidth: 200, showClearIcon: true, onChanged: (val) => setState(() => _filterLevel = val), onClear: () => setState(() => _filterLevel = null), options: [_FilterOption(value: 'PRIMARY_SCHOOL', label: 'Scuola Primaria'), _FilterOption(value: 'MIDDLE_SCHOOL', label: 'Secondaria di I Grado'), _FilterOption(value: 'HIGH_SCHOOL', label: 'Secondaria di II Grado')]),
            _CustomFilterMenu<String>(hint: 'Tutte le aree', icon: Icons.category_outlined, value: _filterArea, menuWidth: 200, showClearIcon: true, onChanged: (val) => setState(() => _filterArea = val), onClear: () => setState(() => _filterArea = null), options: [_FilterOption(value: 'HUMANITIES', label: 'Area Umanistica'), _FilterOption(value: 'LINGUISTICS', label: 'Area Linguistica'), _FilterOption(value: 'SCIENCES', label: 'Area Scientifica')]),
          ],
        ),
        const SizedBox(height: 16),
        Text(_filteredSubjects.length == 1 ? '1 materia trovata' : '${_filteredSubjects.length} materie trovate', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF003C82))),
        const SizedBox(height: 16),
        //BloccoCardIsolato_SoloQuestaAreaScorre_HeaderEFiltriRestanoFissi
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center, spacing: 20, runSpacing: 20,
                children: _filteredSubjects.map((subject) {
                  return MinistrySubjectCard(subject: subject, onEditRequested: (onCancel) => _showWizard(subject: subject, onCancelEdit: onCancel), onDelete: () => widget.onDelete(subject));
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MinistrySubjectWizardDialog extends StatefulWidget
{
  final MinistrySubjectItem? existingSubject;
  final List<AssociationSubjectItem> availableAssociationSubjects;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError) onSave;

  const _MinistrySubjectWizardDialog({
    this.existingSubject, required this.availableAssociationSubjects, this.onCancelEdit, required this.onSave
  });

  @override
  State<_MinistrySubjectWizardDialog> createState() => _MinistrySubjectWizardDialogState();
}

class _MinistrySubjectWizardDialogState extends State<_MinistrySubjectWizardDialog>
{
  static const int _kMaxAreas = 3;

  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _disciplineSearchCtrl = TextEditingController();

  String? _selectedLevel;
  List<String> _selectedAreas = [];
  List<int> _selectedAssociations = [];

  @override
  void initState()
  {
    super.initState();
    if (widget.existingSubject != null)
    {
      _nameController.text = widget.existingSubject!.name;
      _descController.text = widget.existingSubject!.description ?? '';
      _selectedLevel = widget.existingSubject!.level;
      _selectedAreas = List<String>.from(widget.existingSubject!.areas);
      _selectedAssociations = widget.existingSubject!.associationSubjects.map((a) => a.id).toList();
    }
  }

  @override
  void dispose()
  {
    _nameController.dispose();
    _descController.dispose();
    _disciplineSearchCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(() {
      _nameController.clear();
      _descController.clear();
      _disciplineSearchCtrl.clear();
      _selectedLevel = null;
      _selectedAreas = [];
      _selectedAssociations.clear();
      _currentStep = 0;
      _pageController.jumpToPage(0);
    });
  }

  void _onAreaChanged(String area, bool isSelected)
  {
    setState(()
    {
      if (isSelected)
      {
        if (_selectedAreas.length >= _kMaxAreas)
        {
          CustomSnackBar.show(context: context, message: 'Puoi selezionare al massimo $_kMaxAreas aree.', isError: true);
          return;
        }
        _selectedAreas.add(area);
      }
      else
      {
        _selectedAreas.remove(area);

        // Rimuove solo le discipline interne dell'area appena deselezionata,
        // lasciando intatte quelle delle altre aree ancora selezionate
        final idsToRemove = widget.availableAssociationSubjects
            .where((a) => a.area == area)
            .map((a) => a.id)
            .toSet();
        _selectedAssociations.removeWhere((id) => idsToRemove.contains(id));
      }
    });
  }

  void _nextStep() async
  {
    if (_currentStep == 0)
    {
      if (_nameController.text.trim().isEmpty) { CustomSnackBar.show(context: context, message: 'Il nome non può essere vuoto.', isError: true); return; }
      if (_selectedLevel == null) { CustomSnackBar.show(context: context, message: 'Seleziona un livello scolastico.', isError: true); return; }
      if (_selectedAreas.isEmpty) { CustomSnackBar.show(context: context, message: 'Seleziona almeno un\'area di appartenenza.', isError: true); return; }
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
    else
    {
      if (_selectedAssociations.isEmpty) { CustomSnackBar.show(context: context, message: 'Seleziona almeno una disciplina interna associata.', isError: true); return; }

      setState(() => _isSaving = true);
      
      bool success = await widget.onSave(_nameController.text.trim(), _selectedLevel!, _selectedAreas, _descController.text.trim(), _selectedAssociations, (errorMsg) {
        if (mounted) CustomSnackBar.show(context: context, message: errorMsg, isError: true);
      });

      if (mounted) setState(() => _isSaving = false);
      if (success) {
        if (widget.existingSubject != null) Navigator.of(context).pop();
        else _resetForm();
      }
    }
  }

  void _prevStep()
  {
    if (_currentStep > 0)
    {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Widget _buildFieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 20), child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)));

  @override
  Widget build(BuildContext context)
  {
    bool isEditing = widget.existingSubject != null;
    return Dialog(
      backgroundColor: Colors.transparent, elevation: 0,
      child: Container(
        //LarghezzaResponsive_RiempieLoSpazioDisponibileMaMaiOltre650
        width: double.infinity,
        height: 600,
        constraints: const BoxConstraints(maxWidth: 650),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? 'Modifica Materia (${_currentStep + 1}/2)' : 'Nuova Materia (${_currentStep + 1}/2)', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  FadeHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () { Navigator.of(context).pop(); if (isEditing && widget.onCancelEdit != null) widget.onCancelEdit!(); }),
                ],
              ),
            ),
            Expanded(child: PageView(controller: _pageController, physics: const NeverScrollableScrollPhysics(), children: [_buildStep1(), _buildStep2()])),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _ResponsiveDialogButtonsRow(
                secondaryButton: _currentStep > 0
                    ? _OutlinedActionButton(text: 'INDIETRO', icon: Icons.arrow_back_rounded, onPressed: _prevStep)
                    : AnimatedActionButton(text: 'ANNULLA', icon: Icons.cancel_outlined, baseColor: const Color(0xFFE53935), hoverColor: const Color(0xFFEF5350), onPressed: () { Navigator.of(context).pop(); if (isEditing && widget.onCancelEdit != null) widget.onCancelEdit!(); }),
                primaryButton: AnimatedActionButton(text: _isSaving ? 'SALVATAGGIO...' : (_currentStep == 1 ? (isEditing ? 'SALVA MODIFICHE' : 'CREA MATERIA') : 'AVANTI'), icon: _currentStep == 1 ? Icons.check_circle_outline : Icons.arrow_forward_rounded, baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99), onPressed: _isSaving ? () {} : _nextStep),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel('Nome'),
            TextField(controller: _nameController, textCapitalization: TextCapitalization.sentences, style: GoogleFonts.plusJakartaSans(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Es. Lingua e cultura latina', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 20, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2)))),
            _buildFieldLabel('Livello scolastico'),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                CustomChip(label: 'Scuola Primaria', isSelected: _selectedLevel == 'PRIMARY_SCHOOL', onSelected: (v) => setState(() => _selectedLevel = v ? 'PRIMARY_SCHOOL' : null)),
                CustomChip(label: 'Secondaria di I Grado', isSelected: _selectedLevel == 'MIDDLE_SCHOOL', onSelected: (v) => setState(() => _selectedLevel = v ? 'MIDDLE_SCHOOL' : null)),
                CustomChip(label: 'Secondaria di II Grado', isSelected: _selectedLevel == 'HIGH_SCHOOL', onSelected: (v) => setState(() => _selectedLevel = v ? 'HIGH_SCHOOL' : null)),
              ],
            ),
            _buildFieldLabel('Aree (massimo $_kMaxAreas)'),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                CustomChip(label: 'Area Umanistica', isSelected: _selectedAreas.contains('HUMANITIES'), onSelected: (v) => _onAreaChanged('HUMANITIES', v)),
                CustomChip(label: 'Area Linguistica', isSelected: _selectedAreas.contains('LINGUISTICS'), onSelected: (v) => _onAreaChanged('LINGUISTICS', v)),
                CustomChip(label: 'Area Scientifica', isSelected: _selectedAreas.contains('SCIENCES'), onSelected: (v) => _onAreaChanged('SCIENCES', v)),
              ],
            ),
            _buildFieldLabel('Descrizione (opzionale)'),
            TextField(controller: _descController, textCapitalization: TextCapitalization.sentences, maxLines: 4, minLines: 1, style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.black), decoration: InputDecoration(hintText: 'Aggiungi una descrizione...', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 1.5)))),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2()
  {
    final query = _disciplineSearchCtrl.text.toLowerCase();
    final filteredAssoc = widget.availableAssociationSubjects.where((a) => _selectedAreas.contains(a.area) && a.name.toLowerCase().contains(query)).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona le discipline interne associate', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF003C82), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AnimatedSearchBar(controller: _disciplineSearchCtrl, onChanged: (_) => setState((){}), hintText: 'Cerca disciplina interna...'),
          const SizedBox(height: 16),
          Expanded(child: filteredAssoc.isEmpty ? Center(child: Text('Nessuna disciplina trovata per le aree selezionate.', style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF8A8A8A), fontStyle: FontStyle.italic))) : SingleChildScrollView(child: Wrap(spacing: 12, runSpacing: 12, children: filteredAssoc.map((a) => CustomChip(label: a.name, isSelected: _selectedAssociations.contains(a.id), onSelected: (v) => setState(() { if (v) { _selectedAssociations.add(a.id); } else { _selectedAssociations.remove(a.id); } }))).toList()))),
        ],
      ),
    );
  }
}

//DecideSoloSeAffiancareOImpilare_LaModalitaAffiancataRestaComEra_SoloLoStackingUsaLarghezzaFissa
class _ResponsiveDialogButtonsRow extends StatelessWidget
{
  final Widget secondaryButton;
  final Widget primaryButton;
  final double breakpoint;

  const _ResponsiveDialogButtonsRow
  ({
    required this.secondaryButton,
    required this.primaryButton,
    this.breakpoint = 460,
  });

  static const double _kStackedButtonWidth = 240;

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
            mainAxisSize: MainAxisSize.min,
            children: 
            [
              SizedBox(width: _kStackedButtonWidth, child: primaryButton),
              const SizedBox(height: 16),
              SizedBox(width: _kStackedButtonWidth, child: secondaryButton),
            ],
          );
        }

        return Row
        (
          children: 
          [
            Expanded(child: secondaryButton),
            const SizedBox(width: 16),
            Expanded(child: primaryButton),
          ],
        );
      },
    );
  }
}

class CustomChip extends StatefulWidget { final String label; final bool isSelected; final ValueChanged<bool> onSelected; const CustomChip({required this.label, required this.isSelected, required this.onSelected, super.key}); @override State<CustomChip> createState() => _CustomChipState(); }
class _CustomChipState extends State<CustomChip> { bool _isHovered = false; @override Widget build(BuildContext context) { return MouseRegion(cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _isHovered = true), onExit: (_) => setState(() => _isHovered = false), child: GestureDetector(onTap: () => widget.onSelected(!widget.isSelected), child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: widget.isSelected ? const Color(0xFF003C82) : (_isHovered ? const Color(0xFFF5F8FC) : Colors.white), borderRadius: BorderRadius.circular(100), border: Border.all(color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), width: 1.0)), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 150), style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isSelected ? Colors.white : const Color(0xFF003C82)), child: Text(widget.label))))); } }
class _OutlinedActionButton extends StatefulWidget { final String text; final IconData icon; final VoidCallback onPressed; const _OutlinedActionButton({required this.text, required this.icon, required this.onPressed}); @override State<_OutlinedActionButton> createState() => _OutlinedActionButtonState(); }
class _OutlinedActionButtonState extends State<_OutlinedActionButton> { bool _isHovered = false; bool _isPressed = false; @override Widget build(BuildContext context) { return MouseRegion(cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _isHovered = true), onExit: (_) => setState(() => _isHovered = false), child: GestureDetector(onTapDown: (_) => setState(() => _isPressed = true), onTapUp: (_) { setState(() => _isPressed = false); widget.onPressed(); }, onTapCancel: () => setState(() => _isPressed = false), child: AnimatedScale(scale: _isPressed ? 0.95 : 1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutQuint, child: AnimatedContainer(duration: const Duration(milliseconds: 250), curve: Curves.easeOutQuint, height: 56, decoration: BoxDecoration(color: _isHovered ? const Color(0xFFF5F8FC) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF003C82), width: 1.5)), alignment: Alignment.center, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(widget.icon, color: const Color(0xFF003C82), size: 20), const SizedBox(width: 8), Text(widget.text, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF003C82), letterSpacing: 1.2))]))))); } }
class _FilterOption<T> { final T value; final String label; _FilterOption({required this.value, required this.label}); }
class _CustomFilterMenu<T> extends StatefulWidget { final String hint; final IconData icon; final T? value; final List<_FilterOption<T>> options; final ValueChanged<T> onChanged; final VoidCallback onClear; final double menuWidth; final bool showClearIcon; const _CustomFilterMenu({required this.hint, required this.icon, required this.value, required this.options, required this.onChanged, required this.onClear, required this.menuWidth, required this.showClearIcon}); @override State<_CustomFilterMenu<T>> createState() => _CustomFilterMenuState<T>(); }
class _CustomFilterMenuState<T> extends State<_CustomFilterMenu<T>> { final GlobalKey _buttonKey = GlobalKey(); OverlayEntry? _overlayEntry; final GlobalKey<_FilterOverlayContentState> _menuKey = GlobalKey(); bool _isHovered = false; void _toggleMenu() { if (_overlayEntry != null) { _closeMenu(); return; } final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox; final size = renderBox.size; final offset = renderBox.localToGlobal(Offset.zero); _overlayEntry = OverlayEntry(builder: (context) => Stack(children: [Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeMenu, child: Container())), Positioned(top: offset.dy + size.height + 8, left: offset.dx, child: _FilterOverlayContent<T>(key: _menuKey, currentValue: widget.value, options: widget.options, menuWidth: widget.menuWidth, onSelected: (val) { widget.onChanged(val); _closeMenu(); }))] )); Overlay.of(context).insert(_overlayEntry!); } void _closeMenu() async { if (_overlayEntry != null) { await _menuKey.currentState?.hide(); _overlayEntry?.remove(); _overlayEntry = null; } } @override Widget build(BuildContext context) { final bool isActive = widget.value != null; String displayText = widget.hint; if (isActive) { final selectedOption = widget.options.firstWhere((o) => o.value == widget.value, orElse: () => _FilterOption(value: widget.value!, label: '')); displayText = selectedOption.label; } return MouseRegion(cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _isHovered = true), onExit: (_) => setState(() => _isHovered = false), child: GestureDetector(onTap: _toggleMenu, child: AnimatedContainer(key: _buttonKey, duration: const Duration(milliseconds: 200), height: 42, padding: EdgeInsets.only(left: 16, right: (isActive && widget.showClearIcon) ? 12 : 16), decoration: BoxDecoration(color: _isHovered || isActive ? const Color(0xFFF5F8FC) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _isHovered || isActive ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), width: 1.5), boxShadow: const [BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 8)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(widget.icon, color: const Color(0xFF003C82), size: 18), const SizedBox(width: 8), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: Text(displayText, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF003C82) : const Color(0xFF8A8A8A)))), if (isActive && widget.showClearIcon) ...[const SizedBox(width: 8), GestureDetector(onTap: () { widget.onClear(); if (_overlayEntry != null) _closeMenu(); }, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: const Color(0xFFE53935).withValues(alpha: .1), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE53935))))]] )))); } }
class _FilterOverlayContent<T> extends StatefulWidget { final T? currentValue; final List<_FilterOption<T>> options; final ValueChanged<T> onSelected; final double menuWidth; const _FilterOverlayContent({super.key, required this.currentValue, required this.options, required this.onSelected, required this.menuWidth}); @override State<_FilterOverlayContent<T>> createState() => _FilterOverlayContentState<T>(); }
class _FilterOverlayContentState<T> extends State<_FilterOverlayContent<T>> { bool _expanded = false; @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _expanded = true); }); } Future<void> hide() async { if (mounted) setState(() => _expanded = false); await Future.delayed(const Duration(milliseconds: 180)); } @override Widget build(BuildContext context) { return Material(color: Colors.transparent, child: Container(width: widget.menuWidth, constraints: const BoxConstraints(maxHeight: 350), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, spreadRadius: 2)]), child: AnimatedSize(duration: const Duration(milliseconds: 180), curve: Curves.easeOut, alignment: Alignment.topCenter, child: _expanded ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: widget.options.map((option) { return _FilterMenuItem(text: option.label, isSelected: widget.currentValue == option.value, onTap: () => widget.onSelected(option.value)); }).toList()))) : SizedBox(width: widget.menuWidth, height: 0)))); } }
class _FilterMenuItem extends StatefulWidget { final String text; final bool isSelected; final VoidCallback onTap; const _FilterMenuItem({required this.text, required this.isSelected, required this.onTap}); @override State<_FilterMenuItem> createState() => _FilterMenuItemState(); }
class _FilterMenuItemState extends State<_FilterMenuItem> { bool _hover = false; @override Widget build(BuildContext context) { return MouseRegion(cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _hover = true), onExit: (_) => setState(() => _hover = false), child: GestureDetector(onTap: widget.onTap, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Colors.transparent, child: Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 150), width: 2, height: (_hover || widget.isSelected) ? 16 : 0, decoration: BoxDecoration(color: const Color(0xFF003C82), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Expanded(child: Text(widget.text, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500, color: const Color(0xFF003C82))))])))); } }