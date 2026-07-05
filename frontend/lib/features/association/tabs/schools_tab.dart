import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/school_item.dart';
import '../models/study_program_item.dart';
import '../models/ministry_subject_item.dart';
import '../widgets/school_card.dart';
import '../../../shared/widgets/snackbar.dart'; 
import '../../../services/api_service.dart';
import '../../../shared/widgets/shared_components.dart';

class SchoolsTab extends StatefulWidget 
{
  const SchoolsTab({super.key});

  @override
  State<SchoolsTab> createState() => _SchoolsTabState();
}

class _SchoolsTabState extends State<SchoolsTab> 
{
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _sortBy = 'date_desc';
  
  bool _newSchoolHover = false;
  bool _isLoading = true;

  List<SchoolItem> _schools = [];
  List<StudyProgramItem> _availableStudyPrograms = [];
  List<MinistrySubjectItem> _availableMinistrySubjects = [];

  @override
  void initState() 
  {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async 
  {
    try 
    {
      final results = await Future.wait([
        _apiService.getSchools(),
        _apiService.getStudyPrograms(),
        _apiService.getMinistrySubjects(),
      ]);

      if (mounted) 
      {
        setState(() 
        {
          _schools = results[0] as List<SchoolItem>;
          _availableStudyPrograms = results[1] as List<StudyProgramItem>;
          _availableMinistrySubjects = results[2] as List<MinistrySubjectItem>;
          _isLoading = false;
        });
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        setState(() => _isLoading = false);
        CustomSnackBar.show(context: context, message: 'Impossibile caricare i dati dal server.', isError: true);
      }
    }
  }

  List<SchoolItem> get _filteredSchools 
  {
    var result = _schools.where((school) 
    {
      final query = _searchText.toLowerCase();
      return school.name.toLowerCase().contains(query) ||
          school.mechanographicCode.toLowerCase().contains(query) ||
          school.city.toLowerCase().contains(query) ||
          school.province.toLowerCase().contains(query);
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

  Future<bool> _executeCreate(bool isPrivate, String code, String name, String city, String prov, List<int> programIds, Function(String) onError) async 
  {
    try 
    {
      final createdSchool = await _apiService.createSchool(isPrivate: isPrivate, code: code, name: name, city: city, province: prov, studyProgramIds: programIds);
      setState(() { _schools.add(createdSchool); });
      if (mounted) CustomSnackBar.show(context: context, message: 'Scuola creata con successo!', isError: false);
      return true;
    } 
    catch (e) 
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> _executeEdit(String oldCode, bool isPrivate, String newCode, String name, String city, String prov, List<int> programIds, Function(String) onError) async 
  {
    try 
    {
      final updatedSchool = await _apiService.updateSchool(oldCode: oldCode, isPrivate: isPrivate, newCode: newCode, name: name, city: city, province: prov, studyProgramIds: programIds);
      setState(() 
      {
        final index = _schools.indexWhere((s) => s.mechanographicCode == oldCode);
        if (index != -1) _schools[index] = updatedSchool;
      });
      return true;
    } 
    catch (e) 
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void _executeDelete(SchoolItem item) async 
  {
    try 
    {
      await _apiService.deleteSchool(item.mechanographicCode);
      setState(() { _schools.removeWhere((s) => s.mechanographicCode == item.mechanographicCode); });
    } 
    catch (e) 
    {
      if (mounted) CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showWizard({SchoolItem? school, VoidCallback? onCancelEdit}) 
  {
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: 'SchoolWizard', barrierColor: Colors.black.withValues(alpha: .15), transitionDuration: const Duration(milliseconds: 240),
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
              child: _SchoolWizardDialog(
                existingSchool: school,
                availableStudyPrograms: _availableStudyPrograms,
                onCancelEdit: onCancelEdit,
                onSave: (isPrivate, code, name, city, prov, programIds, onError) async 
                {
                  if (school == null) return await _executeCreate(isPrivate, code, name, city, prov, programIds, onError);
                  else return await _executeEdit(school.mechanographicCode, isPrivate, code, name, city, prov, programIds, onError);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  @override
  Widget build(BuildContext context) 
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: AnimatedSearchBar(controller: _searchController, onChanged: (value) => setState(() => _searchText = value), hintText: 'Cerca scuola...')),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _newSchoolHover = true), onExit: (_) => setState(() => _newSchoolHover = false),
              child: GestureDetector(
                onTap: () => _showWizard(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180), curve: Curves.easeOut, height: 50, padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: _newSchoolHover ? const Color(0xFF003C82) : Colors.transparent, width: 2), boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)]),
                  child: Center(child: Text('Nuova scuola', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)))),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _CustomFilterMenu<String>(
          hint: 'Ordina per', icon: Icons.sort_rounded, value: _sortBy, menuWidth: 180, showClearIcon: false, onChanged: (val) => setState(() => _sortBy = val), onClear: () {},
          options: [_FilterOption(value: 'date_desc', label: 'Più recente'), _FilterOption(value: 'date_asc', label: 'Meno recente'), _FilterOption(value: 'name_asc', label: 'Nome (A-Z)'), _FilterOption(value: 'name_desc', label: 'Nome (Z-A)')], 
        ),
        const SizedBox(height: 16),
        Text(_filteredSchools.length == 1 ? '1 scuola trovata' : '${_filteredSchools.length} scuole trovate', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF003C82))),
        const SizedBox(height: 16),
        //BloccoCardIsolato_SoloQuestaAreaScorre_HeaderEFiltriRestanoFissi
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
              : SingleChildScrollView(
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center, spacing: 20, runSpacing: 20,
                      children: _filteredSchools.map((school) {
                        return SchoolCard(school: school, availableStudyPrograms: _availableStudyPrograms, availableMinistrySubjects: _availableMinistrySubjects, onEditRequested: (onCancel) => _showWizard(school: school, onCancelEdit: onCancel), onDelete: () => _executeDelete(school));
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SchoolWizardDialog extends StatefulWidget 
{
  final SchoolItem? existingSchool;
  final List<StudyProgramItem> availableStudyPrograms;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(bool isPrivate, String code, String name, String city, String prov, List<int> programIds, Function(String) onError) onSave;
  
  const _SchoolWizardDialog({
    this.existingSchool, required this.availableStudyPrograms, this.onCancelEdit, required this.onSave,
  });

  @override
  State<_SchoolWizardDialog> createState() => _SchoolWizardDialogState();
}

class _SchoolWizardDialogState extends State<_SchoolWizardDialog> 
{
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isSaving = false;

  bool _isPrivate = false;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provController = TextEditingController();
  final TextEditingController _programSearchCtrl = TextEditingController();

  List<int> _selectedPrograms = [];

  @override
  void initState() 
  {
    super.initState();
    if (widget.existingSchool != null)
    {
      _isPrivate = widget.existingSchool!.mechanographicCode.startsWith('PRIV-');
      if (!_isPrivate) _codeController.text = widget.existingSchool!.mechanographicCode;
      _nameController.text = widget.existingSchool!.name;
      _cityController.text = widget.existingSchool!.city;
      _provController.text = widget.existingSchool!.province;
      _selectedPrograms = widget.existingSchool!.studyPrograms.map((p) => p.id).toList();
    }
  }

  @override
  void dispose() 
  {
    _codeController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _provController.dispose();
    _programSearchCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(() {
      _isPrivate = false;
      _codeController.clear();
      _nameController.clear();
      _cityController.clear();
      _provController.clear();
      _programSearchCtrl.clear();
      _selectedPrograms.clear();
      _currentStep = 0;
      _pageController.jumpToPage(0);
    });
  }

  void _nextStep() async
  {
    if (_currentStep == 0)
    {
      final code = _codeController.text.trim().toUpperCase();
      final name = _nameController.text.trim();
      final city = _cityController.text.trim();
      final prov = _provController.text.trim().toUpperCase();

      if (name.isEmpty || city.isEmpty) { CustomSnackBar.show(context: context, message: 'Compila tutti i campi richiesti.', isError: true); return; }
      if (prov.length != 2) { CustomSnackBar.show(context: context, message: 'La provincia deve essere esattamente di 2 lettere.', isError: true); return; }
      if (!_isPrivate) 
      { 
        if (code.isEmpty) { CustomSnackBar.show(context: context, message: 'Inserisci il codice meccanografico.', isError: true); return; }
        if (code.length != 10) { CustomSnackBar.show(context: context, message: 'Il codice meccanografico deve essere di 10 caratteri.', isError: true); return; }
        if (!code.startsWith(prov)) { CustomSnackBar.show(context: context, message: 'Le prime due lettere del codice devono corrispondere alla provincia ($prov).', isError: true); return; }
      }
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
    else
    {
      if (_selectedPrograms.isEmpty) { CustomSnackBar.show(context: context, message: 'Associa almeno un percorso di studio alla scuola.', isError: true); return; }

      setState(() => _isSaving = true);
      final code = _isPrivate ? "" : _codeController.text.trim().toUpperCase();
      
      bool success = await widget.onSave(_isPrivate, code, _nameController.text.trim(), _cityController.text.trim(), _provController.text.trim().toUpperCase(), _selectedPrograms, (errorMsg) {
        if (mounted) CustomSnackBar.show(context: context, message: errorMsg, isError: true);
      });

      if (mounted) setState(() => _isSaving = false);
      if (success) {
        if (widget.existingSchool != null) Navigator.of(context).pop();
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

  Widget _buildFieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 4, top: 16), child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 14)));

  @override
  Widget build(BuildContext context) 
  {
    bool isEditing = widget.existingSchool != null;
    return Dialog(
      backgroundColor: Colors.transparent, elevation: 0,
      child: Container(
        //LarghezzaResponsive_RiempieLoSpazioDisponibileMaMaiOltre600
        //SenzaQuestoIlBreakpointSulRigaDeiBottoniNonScatterebbeMai_LaLarghezzaEraFissaPrima
        width: double.infinity,
        height: 550,
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? 'Modifica Scuola (${_currentStep + 1}/2)' : 'Nuova Scuola (${_currentStep + 1}/2)', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  StaticHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () { Navigator.of(context).pop(); if (isEditing && widget.onCancelEdit != null) widget.onCancelEdit!(); }),
                ],
              ),
            ),
            Expanded(child: PageView(controller: _pageController, physics: const NeverScrollableScrollPhysics(), children: [_buildStep1(), _buildStep2()])),
            Padding(
              padding: const EdgeInsets.all(24),
              //IndietroSiComportaComeAnnulla_PartecipaAlloStackingPerCoerenza_ComeRichiesto
              child: _ResponsiveDialogButtonsRow(
                secondaryButton: _currentStep > 0
                    ? _OutlinedActionButton(text: 'INDIETRO', icon: Icons.arrow_back_rounded, onPressed: _prevStep)
                    : AnimatedActionButton(text: 'ANNULLA', icon: Icons.cancel_outlined, baseColor: const Color(0xFFE53935), hoverColor: const Color(0xFFEF5350), onPressed: () { Navigator.of(context).pop(); if (isEditing && widget.onCancelEdit != null) widget.onCancelEdit!(); }),
                //IconaSempreLaSpuntaPerLazioneDiSalvataggio_NonPiuIlDischetto_RichiestaEsplicita
                primaryButton: AnimatedActionButton(text: _isSaving ? 'SALVATAGGIO...' : (_currentStep == 1 ? (isEditing ? 'SALVA MODIFICHE' : 'CREA SCUOLA') : 'AVANTI'), icon: _currentStep == 1 ? Icons.check_circle_outline : Icons.arrow_forward_rounded, baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99), onPressed: _isSaving ? () {} : _nextStep),
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
            Row(
              children: [
                Switch(value: _isPrivate, activeColor: const Color(0xFF003C82), splashRadius: 0.0, hoverColor: Colors.transparent, focusColor: Colors.transparent, onChanged: (v) => setState(() { _isPrivate = v; if (v) _codeController.clear(); })),
                const SizedBox(width: 8),
                Text('Scuola Privata', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF003C82))),
              ],
            ),
            const SizedBox(height: 12),
            _buildFieldLabel('Codice Meccanografico'),
            TextField(controller: _codeController, enabled: !_isPrivate, textCapitalization: TextCapitalization.characters, style: GoogleFonts.plusJakartaSans(fontSize: 18, color: _isPrivate ? const Color(0xFF8A8A8A) : Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: _isPrivate ? 'Non richiesto' : 'Es. VIPC02000P', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2)))),
            _buildFieldLabel('Nome'),
            TextField(controller: _nameController, textCapitalization: TextCapitalization.words, style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Es. Liceo Statale F. Corradini', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2)))),
            Row(
              children: [
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Città'), TextField(controller: _cityController, textCapitalization: TextCapitalization.words, style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Es. Thiene', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))))])),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Provincia'), TextField(controller: _provController, textCapitalization: TextCapitalization.characters, maxLength: 2, style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(counterText: "", hintText: 'Es. VI', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))))])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() 
  {
    final query = _programSearchCtrl.text.toLowerCase();
    final filteredPrograms = widget.availableStudyPrograms.where((p) => p.name.toLowerCase().contains(query)).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona i percorsi di studio attivi in questa scuola', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF003C82), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AnimatedSearchBar(controller: _programSearchCtrl, onChanged: (_) => setState((){}), hintText: 'Cerca percorso di studio...'),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: Wrap(spacing: 12, runSpacing: 12, children: filteredPrograms.map((p) => CustomChip(label: p.name, isSelected: _selectedPrograms.contains(p.id), onSelected: (v) => setState(() { if (v) { _selectedPrograms.add(p.id); } else { _selectedPrograms.remove(p.id); } }))).toList()))),
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