import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/study_program_item.dart';
import '../models/ministry_subject_item.dart';
import '../widgets/study_program_card.dart';
import '../../../shared/widgets/snackbar.dart'; 
import '../../../shared/widgets/shared_components.dart';

class StudyProgramsTab extends StatefulWidget
{
  //DatiCondivisiRicevutiDallAlto_AssociationPageEUnicaFonteDiVeritaEProprietariaDelFetch
  final List<StudyProgramItem> studyPrograms;
  //SoloLettura_ServeAllaCardEAlWizardPerAssociareLeMaterieMinisteriali_ProprietarioReaeEMinistrySubjectsTab
  final List<MinistrySubjectItem> ministrySubjects;
  final Future<bool> Function(String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) onCreate;
  final Future<bool> Function(int id, String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) onEdit;
  final void Function(StudyProgramItem item) onDelete;

  const StudyProgramsTab({
    super.key,
    required this.studyPrograms,
    required this.ministrySubjects,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<StudyProgramsTab> createState() => _StudyProgramsTabState();
}

class _StudyProgramsTabState extends State<StudyProgramsTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _sortBy = 'date_desc';
  String? _filterLevel;

  bool _newProgramHover = false;

  List<StudyProgramItem> get _filteredPrograms
  {
    var result = widget.studyPrograms.where((program)
    {
      final query = _searchText.toLowerCase();
      final matchesSearch = program.name.toLowerCase().contains(query);
      final matchesLevel = _filterLevel == null || program.level == _filterLevel;
      return matchesSearch && matchesLevel;
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

  void _showWizard({StudyProgramItem? program, VoidCallback? onCancelEdit})
  {
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: 'StudyProgramWizard', barrierColor: Colors.black.withValues(alpha: .15), transitionDuration: const Duration(milliseconds: 240),
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
              child: _StudyProgramWizardDialog(
                existingProgram: program,
                //LettaSempreDaWidget.ministrySubjects_AggiornataAutomaticamenteDaAssociationPageAlProssimoSetState
                availableMinistrySubjects: widget.ministrySubjects,
                onCancelEdit: onCancelEdit,
                onSave: (name, level, minYear, maxYear, description, subjectIds, onError) async
                {
                  if (program == null) return await widget.onCreate(name, level, minYear, maxYear, description, subjectIds, onError);
                  else return await widget.onEdit(program.id, name, level, minYear, maxYear, description, subjectIds, onError);
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
            Expanded(child: AnimatedSearchBar(controller: _searchController, onChanged: (value) => setState(() => _searchText = value), hintText: 'Cerca percorso di studio...')),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _newProgramHover = true), onExit: (_) => setState(() => _newProgramHover = false),
              child: GestureDetector(
                onTap: () => _showWizard(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180), curve: Curves.easeOut, height: 50, padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: _newProgramHover ? const Color(0xFF003C82) : Colors.transparent, width: 2), boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)]),
                  child: Center(child: Text('Nuovo percorso', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)))),
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
            _CustomFilterMenu<String>(hint: 'Tutti i livelli', icon: Icons.school_outlined, value: _filterLevel, menuWidth: 200, showClearIcon: true, onChanged: (val) => setState(() => _filterLevel = val), onClear: () => setState(() => _filterLevel = null), options: [_FilterOption(value: 'PRIMARY_SCHOOL', label: 'Scuola Primaria'), _FilterOption(value: 'MIDDLE_SCHOOL', label: 'Secondaria di I Grado'), _FilterOption(value: 'HIGH_SCHOOL', label: 'Secondaria di II Grado')]),
          ],
        ),
        const SizedBox(height: 16),
        Text(_filteredPrograms.length == 1 ? '1 percorso trovato' : '${_filteredPrograms.length} percorsi trovati', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF003C82))),
        const SizedBox(height: 16),
        //BloccoCardIsolato_SoloQuestaAreaScorre_HeaderEFiltriRestanoFissi
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center, spacing: 20, runSpacing: 20,
                children: _filteredPrograms.map((program) {
                  return StudyProgramCard(program: program, availableMinistrySubjects: widget.ministrySubjects, onEditRequested: (onCancel) => _showWizard(program: program, onCancelEdit: onCancel), onDelete: () => widget.onDelete(program));
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudyProgramWizardDialog extends StatefulWidget
{
  final StudyProgramItem? existingProgram;
  final List<MinistrySubjectItem> availableMinistrySubjects;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) onSave;

  const _StudyProgramWizardDialog({
    this.existingProgram, required this.availableMinistrySubjects, this.onCancelEdit, required this.onSave
  });

  @override
  State<_StudyProgramWizardDialog> createState() => _StudyProgramWizardDialogState();
}

class _StudyProgramWizardDialogState extends State<_StudyProgramWizardDialog>
{
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isSaving = false;
  bool _isClampingYears = false; //Guardia_EvitaRicorsioneQuandoAggiustiamoIlSecondoControllerACascata

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minYearController = TextEditingController();
  final TextEditingController _maxYearController = TextEditingController();
  final TextEditingController _subjectSearchCtrl = TextEditingController();

  String? _selectedLevel;
  List<int> _selectedSubjects = [];

  //TettoMassimoAnniAmmessoPerIlLivelloCorrentementeSelezionato_3perMedie_5perElementariESuperiori
  int get _maxYearForSelectedLevel => _selectedLevel == 'MIDDLE_SCHOOL' ? 3 : 5;

  @override
  void initState()
  {
    super.initState();
    if (widget.existingProgram != null)
    {
      _nameController.text = widget.existingProgram!.name;
      _descController.text = widget.existingProgram!.description;
      _selectedLevel = widget.existingProgram!.level;
      _minYearController.text = widget.existingProgram!.minYear.toString();
      _maxYearController.text = widget.existingProgram!.maxYear.toString();
      _selectedSubjects = widget.existingProgram!.ministrySubjects.map((s) => s.id).toList();
    }
  }

  @override
  void dispose()
  {
    _nameController.dispose();
    _descController.dispose();
    _minYearController.dispose();
    _maxYearController.dispose();
    _subjectSearchCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(() {
      _nameController.clear();
      _descController.clear();
      _minYearController.clear();
      _maxYearController.clear();
      _subjectSearchCtrl.clear();
      _selectedLevel = null;
      _selectedSubjects.clear();
      _currentStep = 0;
      _pageController.jumpToPage(0);
    });
  }

  void _onLevelChanged(String level, bool isSelected)
  {
    setState(()
    {
      if (isSelected)
      {
        if (_selectedLevel != level) 
        {
          _selectedSubjects.clear();
          
          int maxAllowed = 5;
          if (level == 'MIDDLE_SCHOOL') maxAllowed = 3;

          int? currentMin = int.tryParse(_minYearController.text);
          int? currentMax = int.tryParse(_maxYearController.text);

          if (currentMin == null) { _minYearController.text = '1'; } 
          else {
            if (currentMin < 1) _minYearController.text = '1';
            if (currentMin > maxAllowed) _minYearController.text = maxAllowed.toString();
          }

          if (currentMax == null) { _maxYearController.text = maxAllowed.toString(); } 
          else {
            if (currentMax < 1) _maxYearController.text = '1';
            if (currentMax > maxAllowed) _maxYearController.text = maxAllowed.toString();
          }
          
          currentMin = int.tryParse(_minYearController.text);
          currentMax = int.tryParse(_maxYearController.text);
          
          if (currentMin != null && currentMax != null && currentMin > currentMax) {
            _minYearController.text = currentMax.toString();
          }
        }
        _selectedLevel = level;
      }
      else
      {
        _selectedLevel = null;
      }
    });
  }

  //ClampaInTempoRealeIlValoreAppenaDigitato_EPropagaAlSecondoEstremoSeVieneScavalcato
  void _onYearChanged(bool isMinField)
  {
    if (_isClampingYears) return;
    if (_selectedLevel == null) return; // Senza livello non c'è ancora un tetto da applicare, ci pensa la validazione dello step

    final TextEditingController controller = isMinField ? _minYearController : _maxYearController;
    final TextEditingController otherController = isMinField ? _maxYearController : _minYearController;

    if (controller.text.isEmpty) return; // L'utente sta ancora digitando (es. ha appena cancellato tutto)

    final int? typed = int.tryParse(controller.text);
    if (typed == null) return;

    final int maxAllowed = _maxYearForSelectedLevel;
    final int clamped = typed < 1 ? 1 : (typed > maxAllowed ? maxAllowed : typed);

    _isClampingYears = true;

    if (clamped != typed)
    {
      controller.value = controller.value.copyWith(text: clamped.toString(), selection: TextSelection.collapsed(offset: clamped.toString().length));
    }

    final int? otherValue = int.tryParse(otherController.text);
    if (otherValue != null && ((isMinField && clamped > otherValue) || (!isMinField && clamped < otherValue)))
    {
      otherController.value = otherController.value.copyWith(text: clamped.toString(), selection: TextSelection.collapsed(offset: clamped.toString().length));
    }

    _isClampingYears = false;
    setState((){}); // Aggiorna il testo di supporto sotto ai campi
  }

  void _nextStep() async
  {
    if (_currentStep == 0)
    {
      if (_nameController.text.trim().isEmpty) { CustomSnackBar.show(context: context, message: 'Il nome non può essere vuoto.', isError: true); return; }
      if (_selectedLevel == null) { CustomSnackBar.show(context: context, message: 'Seleziona un livello scolastico.', isError: true); return; }
      if (_minYearController.text.isEmpty || _maxYearController.text.isEmpty) { CustomSnackBar.show(context: context, message: 'Compila l\'intervallo degli anni di corso.', isError: true); return; }

      final minYear = int.tryParse(_minYearController.text);
      final maxYear = int.tryParse(_maxYearController.text);

      if (minYear == null || maxYear == null || minYear > maxYear || minYear < 1) { CustomSnackBar.show(context: context, message: 'Intervallo di anni non valido.', isError: true); return; }

      //ControlloDifensivoRidondanteRispettoAlClampInTempoReale_CopreEdgeCaseComeInputProgrammaticiOFuturiRefactor
      if (maxYear > _maxYearForSelectedLevel) { CustomSnackBar.show(context: context, message: 'Per il livello selezionato l\'anno massimo consentito è $_maxYearForSelectedLevel.', isError: true); return; }

      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
    else
    {
      if (_selectedSubjects.isEmpty) { CustomSnackBar.show(context: context, message: 'Seleziona almeno una materia ministeriale.', isError: true); return; }

      setState(() => _isSaving = true);
      
      final minYear = int.parse(_minYearController.text);
      final maxYear = int.parse(_maxYearController.text);

      bool success = await widget.onSave(_nameController.text.trim(), _selectedLevel!, minYear, maxYear, _descController.text.trim(), _selectedSubjects, (errorMsg) {
        if (mounted) CustomSnackBar.show(context: context, message: errorMsg, isError: true);
      });

      if (mounted) setState(() => _isSaving = false);
      
      if (success) {
        if (widget.existingProgram != null) Navigator.of(context).pop();
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

  Widget _buildFieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 16), child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)));

  @override
  Widget build(BuildContext context)
  {
    bool isEditing = widget.existingProgram != null;

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
                  Text(isEditing ? 'Modifica Percorso (${_currentStep + 1}/2)' : 'Nuovo Percorso (${_currentStep + 1}/2)', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
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
                primaryButton: AnimatedActionButton(text: _isSaving ? 'SALVATAGGIO...' : (_currentStep == 1 ? (isEditing ? 'SALVA MODIFICHE' : 'CREA PERCORSO') : 'AVANTI'), icon: _currentStep == 1 ? Icons.check_circle_outline : Icons.arrow_forward_rounded, baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99), onPressed: _isSaving ? () {} : _nextStep),
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
            TextField(controller: _nameController, textCapitalization: TextCapitalization.sentences, style: GoogleFonts.plusJakartaSans(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Es. Liceo Classico (biennio)', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 20, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2)))),
            _buildFieldLabel('Livello scolastico'),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                CustomChip(label: 'Scuola Primaria', isSelected: _selectedLevel == 'PRIMARY_SCHOOL', onSelected: (v) => _onLevelChanged('PRIMARY_SCHOOL', v)),
                CustomChip(label: 'Secondaria di I Grado', isSelected: _selectedLevel == 'MIDDLE_SCHOOL', onSelected: (v) => _onLevelChanged('MIDDLE_SCHOOL', v)),
                CustomChip(label: 'Secondaria di II Grado', isSelected: _selectedLevel == 'HIGH_SCHOOL', onSelected: (v) => _onLevelChanged('HIGH_SCHOOL', v)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Anno Inizio'), TextField(controller: _minYearController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => _onYearChanged(true), style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Es. 1', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 1.5))))])),
                const SizedBox(width: 32),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Anno Fine'), TextField(controller: _maxYearController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => _onYearChanged(false), style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Es. 5', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 1.5))))])),
              ],
            ),
            //FeedbackVisivoDelVincolo_CompareSoloDopoLaSceltaDelLivelloPerNonConfondereLUtentePrima
            if (_selectedLevel != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Intervallo consentito per il livello selezionato: 1 - $_maxYearForSelectedLevel', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF8A8A8A), fontStyle: FontStyle.italic)),
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
    final query = _subjectSearchCtrl.text.toLowerCase();
    final filteredSubjects = widget.availableMinistrySubjects.where((m) => m.level == _selectedLevel && m.name.toLowerCase().contains(query)).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona le materie ministeriali associate', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF003C82), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AnimatedSearchBar(controller: _subjectSearchCtrl, onChanged: (_) => setState((){}), hintText: 'Cerca materia ministeriale...'),
          const SizedBox(height: 16),
          Expanded(child: filteredSubjects.isEmpty ? Center(child: Text('Nessuna materia trovata per il livello.', style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF8A8A8A), fontStyle: FontStyle.italic))) : SingleChildScrollView(child: Wrap(spacing: 12, runSpacing: 12, children: filteredSubjects.map((s) => CustomChip(label: s.name, isSelected: _selectedSubjects.contains(s.id), onSelected: (v) => setState(() { if (v) { _selectedSubjects.add(s.id); } else { _selectedSubjects.remove(s.id); } }))).toList()))),
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