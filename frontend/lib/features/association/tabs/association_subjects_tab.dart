import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/association_subject_item.dart';
import '../widgets/association_subject_card.dart';
import '../../../shared/widgets/snackbar.dart'; 
import '../../../services/api_service.dart';
import '../../../shared/widgets/shared_components.dart';

class AssociationSubjectsTab extends StatefulWidget
{
  const AssociationSubjectsTab({super.key});

  @override
  State<AssociationSubjectsTab> createState() => _AssociationSubjectsTabState();
}

class _AssociationSubjectsTabState extends State<AssociationSubjectsTab>
{
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _sortBy = 'date_desc';
  String? _filterArea;

  bool _newSubjectHover = false;
  bool _isLoading = true;

  List<AssociationSubjectItem> _subjects = [];

  @override
  void initState()
  {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async
  {
    try
    {
      final data = await _apiService.getAssociationSubjects();
      if (mounted)
      {
        setState(()
        {
          _subjects = data;
          _isLoading = false;
        });
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _isLoading = false);
        CustomSnackBar.show(context: context, message: 'Impossibile caricare le materie dal server.', isError: true);
      }
    }
  }

  List<AssociationSubjectItem> get _filteredSubjects
  {
    var result = _subjects.where((subject)
    {
      final query = _searchText.toLowerCase();
      final matchesSearch = subject.name.toLowerCase().contains(query);
      final matchesArea = _filterArea == null || subject.area == _filterArea;
      return matchesSearch && matchesArea;
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

  Future<bool> _executeCreate(String name, String area, String description, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createAssociationSubject(name, area, description);
      setState(() { _subjects.add(created); });
      if (mounted) CustomSnackBar.show(context: context, message: 'Disciplina interna creata con successo!', isError: false);
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> _executeEdit(int id, String name, String area, String description, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateAssociationSubject(id, name, area, description);
      setState(()
      {
        final index = _subjects.indexWhere((s) => s.id == id);
        if (index != -1) _subjects[index] = updated;
      });
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void _executeDelete(AssociationSubjectItem item) async
  {
    try
    {
      await _apiService.deleteAssociationSubject(item.id);
      setState(() { _subjects.removeWhere((s) => s.id == item.id); });
    }
    catch (e)
    {
      if (mounted) CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showWizard({AssociationSubjectItem? subject, VoidCallback? onCancelEdit})
  {
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: 'SubjectWizard', barrierColor: Colors.black.withValues(alpha: .15), transitionDuration: const Duration(milliseconds: 240),
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
              child: _AssociationSubjectWizardDialog(
                existingSubject: subject,
                onCancelEdit: onCancelEdit,
                onSave: (name, area, description, onError) async
                {
                  if (subject == null) return await _executeCreate(name, area, description, onError);
                  else return await _executeEdit(subject.id, name, area, description, onError);
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
            Expanded(child: AnimatedSearchBar(controller: _searchController, onChanged: (value) => setState(() => _searchText = value), hintText: 'Cerca disciplina...')),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _newSubjectHover = true), onExit: (_) => setState(() => _newSubjectHover = false),
              child: GestureDetector(
                onTap: () => _showWizard(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180), curve: Curves.easeOut, height: 50, padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: _newSubjectHover ? const Color(0xFF003C82) : Colors.transparent, width: 2), boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)]),
                  child: Center(child: Text('Nuova disciplina', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)))),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CustomFilterMenu<String>(hint: 'Ordina per', icon: Icons.sort_rounded, value: _sortBy, menuWidth: 180, showClearIcon: false, onChanged: (val) => setState(() => _sortBy = val), onClear: () {}, options: [_FilterOption(value: 'date_desc', label: 'Più recente'), _FilterOption(value: 'date_asc', label: 'Meno recente'), _FilterOption(value: 'name_asc', label: 'Nome (A-Z)'), _FilterOption(value: 'name_desc', label: 'Nome (Z-A)')]),
            _CustomFilterMenu<String>(hint: 'Tutte le aree', icon: Icons.category_outlined, value: _filterArea, menuWidth: 200, showClearIcon: true, onChanged: (val) => setState(() => _filterArea = val), onClear: () => setState(() => _filterArea = null), options: [_FilterOption(value: 'HUMANITIES', label: 'Area Umanistica'), _FilterOption(value: 'LINGUISTICS', label: 'Area Linguistica'), _FilterOption(value: 'SCIENCES', label: 'Area Scientifica')]),
          ],
        ),
        const SizedBox(height: 16),
        Text(_filteredSubjects.length == 1 ? '1 disciplina trovata' : '${_filteredSubjects.length} discipline trovate', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF003C82))),
        const SizedBox(height: 16),
        if (_isLoading) const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: Color(0xFF003C82))))
        else Center(
          child: Wrap(
            alignment: WrapAlignment.center, spacing: 20, runSpacing: 20,
            children: _filteredSubjects.map((subject) {
              return AssociationSubjectCard(subject: subject, onEditRequested: (onCancel) => _showWizard(subject: subject, onCancelEdit: onCancel), onDelete: () => _executeDelete(subject));
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _AssociationSubjectWizardDialog extends StatefulWidget
{
  final AssociationSubjectItem? existingSubject;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String name, String area, String description, Function(String) onError) onSave;

  const _AssociationSubjectWizardDialog({this.existingSubject, this.onCancelEdit, required this.onSave});

  @override
  State<_AssociationSubjectWizardDialog> createState() => _AssociationSubjectWizardDialogState();
}

class _AssociationSubjectWizardDialogState extends State<_AssociationSubjectWizardDialog>
{
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedArea;
  bool _isSaving = false;

  @override
  void initState()
  {
    super.initState();
    if (widget.existingSubject != null)
    {
      _nameController.text = widget.existingSubject!.name;
      _descController.text = widget.existingSubject!.description ?? '';
      _selectedArea = widget.existingSubject!.area;
    }
  }

  @override
  void dispose()
  {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(() {
      _nameController.clear();
      _selectedArea = null;
      _descController.clear();
    });
  }

  Widget _buildFieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 16), child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)));

  @override
  Widget build(BuildContext context)
  {
    bool isEditing = widget.existingSubject != null;
    return Dialog(
      backgroundColor: Colors.transparent, elevation: 0,
      child: Container(
        width: 540, constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? 'Modifica Disciplina' : 'Nuova Disciplina', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  FadeHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () { Navigator.of(context).pop(); if (isEditing && widget.onCancelEdit != null) widget.onCancelEdit!(); }),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Nome'),
                      TextField(controller: _nameController, textCapitalization: TextCapitalization.sentences, style: GoogleFonts.plusJakartaSans(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Es. Storia dell\'Arte', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 20, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2)))),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Area di appartenenza'),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: [
                          CustomChip(label: 'Area Umanistica', isSelected: _selectedArea == 'HUMANITIES', onSelected: (v) => setState(() => _selectedArea = v ? 'HUMANITIES' : null)),
                          CustomChip(label: 'Area Linguistica', isSelected: _selectedArea == 'LINGUISTICS', onSelected: (v) => setState(() => _selectedArea = v ? 'LINGUISTICS' : null)),
                          CustomChip(label: 'Area Scientifica', isSelected: _selectedArea == 'SCIENCES', onSelected: (v) => setState(() => _selectedArea = v ? 'SCIENCES' : null)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Descrizione (Opzionale)'),
                      TextField(controller: _descController, textCapitalization: TextCapitalization.sentences, maxLines: 4, minLines: 1, style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.black), decoration: InputDecoration(hintText: 'Aggiungi una descrizione...', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 1.5)))),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 24),
              child: Row(
                children: [
                  Expanded(child: AnimatedActionButton(text: 'ANNULLA', icon: Icons.cancel_outlined, baseColor: const Color(0xFFE53935), hoverColor: const Color(0xFFEF5350), onPressed: () { Navigator.of(context).pop(); if (isEditing && widget.onCancelEdit != null) widget.onCancelEdit!(); })),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: _isSaving ? 'SALVATAGGIO...' : (isEditing ? 'SALVA MODIFICHE' : 'CREA'), icon: isEditing ? Icons.save_outlined : Icons.check_circle_outline, baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99),
                      onPressed: () async
                      {
                        if (_isSaving) return;
                        final name = _nameController.text.trim();
                        if (name.isEmpty) { CustomSnackBar.show(context: context, message: "Il nome non può essere vuoto.", isError: true); return; }
                        if (_selectedArea == null) { CustomSnackBar.show(context: context, message: "Seleziona un'area di appartenenza.", isError: true); return; }
                        
                        setState(() => _isSaving = true);
                        bool success = await widget.onSave(name, _selectedArea!, _descController.text.trim(), (errorMsg) { if (mounted) CustomSnackBar.show(context: context, message: errorMsg, isError: true); });
                        if (mounted) setState(() => _isSaving = false);
                        
                        if (success) { if (isEditing) Navigator.of(context).pop(); else _resetForm(); }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomChip extends StatefulWidget { final String label; final bool isSelected; final ValueChanged<bool> onSelected; const CustomChip({required this.label, required this.isSelected, required this.onSelected, super.key}); @override State<CustomChip> createState() => _CustomChipState(); }
class _CustomChipState extends State<CustomChip> { bool _isHovered = false; @override Widget build(BuildContext context) { return MouseRegion(cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _isHovered = true), onExit: (_) => setState(() => _isHovered = false), child: GestureDetector(onTap: () => widget.onSelected(!widget.isSelected), child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: widget.isSelected ? const Color(0xFF003C82) : (_isHovered ? const Color(0xFFF5F8FC) : Colors.white), borderRadius: BorderRadius.circular(100), border: Border.all(color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), width: 1.0)), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 150), style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isSelected ? Colors.white : const Color(0xFF003C82)), child: Text(widget.label))))); } }
class _FilterOption<T> { final T value; final String label; _FilterOption({required this.value, required this.label}); }
class _CustomFilterMenu<T> extends StatefulWidget { final String hint; final IconData icon; final T? value; final List<_FilterOption<T>> options; final ValueChanged<T> onChanged; final VoidCallback onClear; final double menuWidth; final bool showClearIcon; const _CustomFilterMenu({required this.hint, required this.icon, required this.value, required this.options, required this.onChanged, required this.onClear, required this.menuWidth, required this.showClearIcon}); @override State<_CustomFilterMenu<T>> createState() => _CustomFilterMenuState<T>(); }
class _CustomFilterMenuState<T> extends State<_CustomFilterMenu<T>> { final GlobalKey _buttonKey = GlobalKey(); OverlayEntry? _overlayEntry; final GlobalKey<_FilterOverlayContentState> _menuKey = GlobalKey(); bool _isHovered = false; void _toggleMenu() { if (_overlayEntry != null) { _closeMenu(); return; } final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox; final size = renderBox.size; final offset = renderBox.localToGlobal(Offset.zero); _overlayEntry = OverlayEntry(builder: (context) => Stack(children: [Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeMenu, child: Container())), Positioned(top: offset.dy + size.height + 8, left: offset.dx, child: _FilterOverlayContent<T>(key: _menuKey, currentValue: widget.value, options: widget.options, menuWidth: widget.menuWidth, onSelected: (val) { widget.onChanged(val); _closeMenu(); }))] )); Overlay.of(context).insert(_overlayEntry!); } void _closeMenu() async { if (_overlayEntry != null) { await _menuKey.currentState?.hide(); _overlayEntry?.remove(); _overlayEntry = null; } } @override Widget build(BuildContext context) { final bool isActive = widget.value != null; String displayText = widget.hint; if (isActive) { final selectedOption = widget.options.firstWhere((o) => o.value == widget.value, orElse: () => _FilterOption(value: widget.value!, label: '')); displayText = selectedOption.label; } return MouseRegion(cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _isHovered = true), onExit: (_) => setState(() => _isHovered = false), child: GestureDetector(onTap: _toggleMenu, child: AnimatedContainer(key: _buttonKey, duration: const Duration(milliseconds: 200), height: 42, padding: EdgeInsets.only(left: 16, right: (isActive && widget.showClearIcon) ? 12 : 16), decoration: BoxDecoration(color: _isHovered || isActive ? const Color(0xFFF5F8FC) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _isHovered || isActive ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), width: 1.5), boxShadow: const [BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 8)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(widget.icon, color: const Color(0xFF003C82), size: 18), const SizedBox(width: 8), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: Text(displayText, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF003C82) : const Color(0xFF8A8A8A)))), if (isActive && widget.showClearIcon) ...[const SizedBox(width: 8), GestureDetector(onTap: () { widget.onClear(); if (_overlayEntry != null) _closeMenu(); }, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: const Color(0xFFE53935).withValues(alpha: .1), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE53935))))]] )))); } }
class _FilterOverlayContent<T> extends StatefulWidget { final T? currentValue; final List<_FilterOption<T>> options; final ValueChanged<T> onSelected; final double menuWidth; const _FilterOverlayContent({super.key, required this.currentValue, required this.options, required this.onSelected, required this.menuWidth}); @override State<_FilterOverlayContent<T>> createState() => _FilterOverlayContentState<T>(); }
class _FilterOverlayContentState<T> extends State<_FilterOverlayContent<T>> { bool _expanded = false; @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _expanded = true); }); } Future<void> hide() async { if (mounted) setState(() => _expanded = false); await Future.delayed(const Duration(milliseconds: 180)); } @override Widget build(BuildContext context) { return Material(color: Colors.transparent, child: Container(width: widget.menuWidth, constraints: const BoxConstraints(maxHeight: 350), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, spreadRadius: 2)]), child: AnimatedSize(duration: const Duration(milliseconds: 180), curve: Curves.easeOut, alignment: Alignment.topCenter, child: _expanded ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: widget.options.map((option) { return _FilterMenuItem(text: option.label, isSelected: widget.currentValue == option.value, onTap: () => widget.onSelected(option.value)); }).toList()))) : SizedBox(width: widget.menuWidth, height: 0)))); } }
class _FilterMenuItem extends StatefulWidget { final String text; final bool isSelected; final VoidCallback onTap; const _FilterMenuItem({required this.text, required this.isSelected, required this.onTap}); @override State<_FilterMenuItem> createState() => _FilterMenuItemState(); }
class _FilterMenuItemState extends State<_FilterMenuItem> { bool _hover = false; @override Widget build(BuildContext context) { return MouseRegion(cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _hover = true), onExit: (_) => setState(() => _hover = false), child: GestureDetector(onTap: widget.onTap, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Colors.transparent, child: Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 150), width: 2, height: (_hover || widget.isSelected) ? 16 : 0, decoration: BoxDecoration(color: const Color(0xFF003C82), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Expanded(child: Text(widget.text, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500, color: const Color(0xFF003C82))))])))); } }