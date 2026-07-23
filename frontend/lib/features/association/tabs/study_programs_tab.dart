import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/association_subject_item.dart';
import '../models/ministry_subject_item.dart';
import '../models/study_program_item.dart';
import '../models/subject_taxonomy.dart';
import '../widgets/study_program_card.dart';

// Shared between the ListView itemExtent and the height of a single tile:
// the two must match exactly or the scroll math below lands on the wrong row.
const double _subjectOptionItemHeight = 44.0;

const int _middleSchoolMaxYear = 3;
const int _defaultMaxYear = 5;

int _maxYearForLevel(String? level)
{
  return level == 'MIDDLE_SCHOOL' ? _middleSchoolMaxYear : _defaultMaxYear;
}

class StudyProgramsTab extends StatefulWidget
{
  final List<StudyProgramItem> studyPrograms;

  // Read only: needed by the card and by the wizard to link the ministry
  // subjects, but owned by MinistrySubjectsTab.
  final List<MinistrySubjectItem> ministrySubjects;

  // Read only, used by the discipline filter alone.
  final List<AssociationSubjectItem> associationSubjects;

  final Future<bool> Function(String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) onCreate;
  final Future<bool> Function(int id, String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) onEdit;
  final void Function(StudyProgramItem item) onDelete;

  const StudyProgramsTab({
    super.key,
    required this.studyPrograms,
    required this.ministrySubjects,
    required this.associationSubjects,
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
  SortCriterion _sortBy = SortCriterion.nameAsc;
  String? _filterLevel;

  // Multi selection filters: a program passes when it matches at least one of
  // the selected ids, and the two filters are combined with the others in AND.
  Set<int> _selectedMinistrySubjectIds = {};
  Set<int> _selectedAssociationSubjectIds = {};

  bool _newProgramHover = false;

  List<StudyProgramItem> get _filteredPrograms
  {
    final query = _searchText.toLowerCase();

    final result = widget.studyPrograms.where((program)
    {
      final matchesSearch = program.name.toLowerCase().contains(query);
      final matchesLevel = _filterLevel == null || program.level == _filterLevel;

      final matchesMinistrySubjects = _selectedMinistrySubjectIds.isEmpty ||
          program.ministrySubjects.any((subject) => _selectedMinistrySubjectIds.contains(subject.id));

      // A discipline has no direct relation with the program: it is reached
      // through the ministry subjects of the program.
      final matchesAssociationSubjects = _selectedAssociationSubjectIds.isEmpty ||
          program.ministrySubjects.any(
            (subject) => subject.associationSubjects.any(
              (discipline) => _selectedAssociationSubjectIds.contains(discipline.id),
            ),
          );

      return matchesSearch && matchesLevel && matchesMinistrySubjects && matchesAssociationSubjects;
    }).toList();

    result.sort((a, b) => switch (_sortBy)
    {
      SortCriterion.nameAsc => a.name.compareTo(b.name),
      SortCriterion.nameDesc => b.name.compareTo(a.name),
      SortCriterion.dateAsc => a.createdAt.compareTo(b.createdAt),
      SortCriterion.dateDesc => b.createdAt.compareTo(a.createdAt),
    });

    return result;
  }

  void _showWizard({StudyProgramItem? program, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'StudyProgramWizard',
      builder: (context) => _StudyProgramWizardDialog(
        existingProgram: program,
        // Read here, so the list is refreshed by the next setState of
        // AssociationPage.
        availableMinistrySubjects: widget.ministrySubjects,
        onCancelEdit: onCancelEdit,
        onSave: (name, level, minYear, maxYear, description, subjectIds, onError) async
        {
          if (program == null)
          {
            return await widget.onCreate(name, level, minYear, maxYear, description, subjectIds, onError);
          }

          return await widget.onEdit(program.id, name, level, minYear, maxYear, description, subjectIds, onError);
        },
      ),
    );
  }

  void _showSubjectFilterDialog({
    required String title,
    required String hint,
    required List<_SubjectOption> options,
    required Set<int> initialSelectedIds,
    required ValueChanged<Set<int>> onApply,
  })
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectFilterDialog',
      builder: (context) => _SubjectFilterDialog(
        title: title,
        hint: hint,
        options: options,
        initialSelectedIds: initialSelectedIds,
        onApply: onApply,
      ),
    );
  }

  void _showMinistrySubjectFilterDialog()
  {
    _showSubjectFilterDialog(
      title: 'Filtra per materia ministeriale',
      hint: 'Cerca materia ministeriale...',
      options: widget.ministrySubjects
          .map((subject) => _SubjectOption(
                id: subject.id,
                name: subject.name,
                subtitle: schoolLevelShortLabel(subject.level),
              ))
          .toList(),
      initialSelectedIds: _selectedMinistrySubjectIds,
      onApply: (ids) => setState(() => _selectedMinistrySubjectIds = ids),
    );
  }

  void _showAssociationSubjectFilterDialog()
  {
    _showSubjectFilterDialog(
      title: 'Filtra per disciplina interna',
      hint: 'Cerca disciplina...',
      options: widget.associationSubjects
          .map((subject) => _SubjectOption(id: subject.id, name: subject.name))
          .toList(),
      initialSelectedIds: _selectedAssociationSubjectIds,
      onApply: (ids) => setState(() => _selectedAssociationSubjectIds = ids),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final programs = _filteredPrograms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                hintText: 'Cerca percorso di studio...',
              ),
            ),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _newProgramHover = true),
              onExit: (_) => setState(() => _newProgramHover = false),
              child: GestureDetector(
                onTap: () => _showWizard(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: _newProgramHover ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Center(
                    child: Text(
                      'Nuovo percorso',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CustomFilterMenu<SortCriterion>(
              hint: 'Ordina per',
              icon: Icons.sort_rounded,
              value: _sortBy,
              menuWidth: 180,
              showClearIcon: false,
              onChanged: (value) => setState(() => _sortBy = value),
              onClear: () {},
              options: SortCriterion.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            CustomFilterMenu<String>(
              hint: 'Tutti i livelli',
              icon: Icons.school_outlined,
              value: _filterLevel,
              menuWidth: 200,
              showClearIcon: true,
              onChanged: (value) => setState(() => _filterLevel = value),
              onClear: () => setState(() => _filterLevel = null),
              options: schoolLevels
                  .map((level) => FilterOption(value: level.value, label: level.label))
                  .toList(),
            ),
            _FilterChipButton(
              icon: Icons.auto_stories_outlined,
              label: 'Discipline interne',
              count: _selectedAssociationSubjectIds.length,
              onTap: _showAssociationSubjectFilterDialog,
              onClear: () => setState(() => _selectedAssociationSubjectIds = {}),
            ),
            _FilterChipButton(
              icon: Icons.menu_book_outlined,
              label: 'Materie ministeriali',
              count: _selectedMinistrySubjectIds.length,
              onTap: _showMinistrySubjectFilterDialog,
              onClear: () => setState(() => _selectedMinistrySubjectIds = {}),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          programs.length == 1 ? '1 percorso trovato' : '${programs.length} percorsi trovati',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        // Only the card area scrolls, so header and filters stay pinned.
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: programs.map((program)
                {
                  return StudyProgramCard(
                    program: program,
                    availableMinistrySubjects: widget.ministrySubjects,
                    onEditRequested: (onCancel) => _showWizard(program: program, onCancelEdit: onCancel),
                    onDelete: () => widget.onDelete(program),
                  );
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
    this.existingProgram,
    required this.availableMinistrySubjects,
    this.onCancelEdit,
    required this.onSave,
  });

  @override
  State<_StudyProgramWizardDialog> createState() => _StudyProgramWizardDialogState();
}

class _StudyProgramWizardDialogState extends State<_StudyProgramWizardDialog>
{
  static const Duration _stepTransition = Duration(milliseconds: 300);

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minYearController = TextEditingController();
  final TextEditingController _maxYearController = TextEditingController();
  final TextEditingController _subjectSearchController = TextEditingController();

  int _currentStep = 0;
  bool _isSaving = false;
  String? _selectedLevel;
  List<int> _selectedSubjects = [];

  // Guard against re-entering the clamp while adjusting the other controller.
  bool _isClampingYears = false;

  bool get _isEditing => widget.existingProgram != null;

  int get _maxYearForSelectedLevel => _maxYearForLevel(_selectedLevel);

  @override
  void initState()
  {
    super.initState();

    final program = widget.existingProgram;

    if (program != null)
    {
      _nameController.text = program.name;
      _descController.text = program.description;
      _selectedLevel = program.level;
      _minYearController.text = program.minYear.toString();
      _maxYearController.text = program.maxYear.toString();
      _selectedSubjects = program.ministrySubjects.map((subject) => subject.id).toList();
    }
  }

  @override
  void dispose()
  {
    _nameController.dispose();
    _descController.dispose();
    _minYearController.dispose();
    _maxYearController.dispose();
    _subjectSearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _descController.clear();
      _minYearController.clear();
      _maxYearController.clear();
      _subjectSearchController.clear();
      _selectedLevel = null;
      _selectedSubjects.clear();
      _currentStep = 0;
      _pageController.jumpToPage(0);
    });
  }

  void _closeDialog()
  {
    Navigator.of(context).pop();

    if (_isEditing)
    {
      widget.onCancelEdit?.call();
    }
  }

  // Brings the year range inside the ceiling of the newly picked level. The
  // ceiling is computed from the incoming level, not from _selectedLevel,
  // which is only assigned at the end.
  void _clampYearsToLevel(String level)
  {
    final maxAllowed = _maxYearForLevel(level);

    var currentMin = int.tryParse(_minYearController.text);
    var currentMax = int.tryParse(_maxYearController.text);

    if (currentMin == null)
    {
      _minYearController.text = '1';
    }
    else if (currentMin < 1)
    {
      _minYearController.text = '1';
    }
    else if (currentMin > maxAllowed)
    {
      _minYearController.text = maxAllowed.toString();
    }

    if (currentMax == null)
    {
      _maxYearController.text = maxAllowed.toString();
    }
    else if (currentMax < 1)
    {
      _maxYearController.text = '1';
    }
    else if (currentMax > maxAllowed)
    {
      _maxYearController.text = maxAllowed.toString();
    }

    currentMin = int.tryParse(_minYearController.text);
    currentMax = int.tryParse(_maxYearController.text);

    if (currentMin != null && currentMax != null && currentMin > currentMax)
    {
      _minYearController.text = currentMax.toString();
    }
  }

  void _onLevelChanged(String level, bool isSelected)
  {
    setState(()
    {
      if (!isSelected)
      {
        _selectedLevel = null;
        return;
      }

      if (_selectedLevel != level)
      {
        _selectedSubjects.clear();
        _clampYearsToLevel(level);
      }

      _selectedLevel = level;
    });
  }

  // Clamps the value being typed and propagates it to the other end of the
  // range when it gets overtaken.
  void _onYearChanged(bool isMinField)
  {
    if (_isClampingYears)
    {
      return;
    }

    // Without a level there is no ceiling to apply yet: the step validation
    // takes care of it.
    if (_selectedLevel == null)
    {
      return;
    }

    final controller = isMinField ? _minYearController : _maxYearController;
    final otherController = isMinField ? _maxYearController : _minYearController;

    // The user is still typing, for instance right after clearing the field.
    if (controller.text.isEmpty)
    {
      return;
    }

    final typed = int.tryParse(controller.text);

    if (typed == null)
    {
      return;
    }

    final maxAllowed = _maxYearForSelectedLevel;
    final clamped = typed < 1 ? 1 : (typed > maxAllowed ? maxAllowed : typed);

    _isClampingYears = true;

    if (clamped != typed)
    {
      controller.value = controller.value.copyWith(
        text: clamped.toString(),
        selection: TextSelection.collapsed(offset: clamped.toString().length),
      );
    }

    final otherValue = int.tryParse(otherController.text);
    final isOvertaken = otherValue != null &&
        ((isMinField && clamped > otherValue) || (!isMinField && clamped < otherValue));

    if (isOvertaken)
    {
      otherController.value = otherController.value.copyWith(
        text: clamped.toString(),
        selection: TextSelection.collapsed(offset: clamped.toString().length),
      );
    }

    _isClampingYears = false;

    // Refreshes the supporting text below the fields.
    setState(() {});
  }

  bool _validateFirstStep()
  {
    if (_nameController.text.trim().isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Il nome non può essere vuoto.', isError: true);
      return false;
    }

    if (_selectedLevel == null)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona un livello scolastico.', isError: true);
      return false;
    }

    if (_minYearController.text.isEmpty || _maxYearController.text.isEmpty)
    {
      CustomSnackBar.show(context: context, message: "Compila l'intervallo degli anni di corso.", isError: true);
      return false;
    }

    final minYear = int.tryParse(_minYearController.text);
    final maxYear = int.tryParse(_maxYearController.text);

    if (minYear == null || maxYear == null || minYear > maxYear || minYear < 1)
    {
      CustomSnackBar.show(context: context, message: 'Intervallo di anni non valido.', isError: true);
      return false;
    }

    // Redundant with the live clamping, but covers programmatic input and
    // future refactors.
    if (maxYear > _maxYearForSelectedLevel)
    {
      CustomSnackBar.show(context: context, message: "Per il livello selezionato l'anno massimo consentito è $_maxYearForSelectedLevel.", isError: true);
      return false;
    }

    return true;
  }

  Future<void> _nextStep() async
  {
    if (_currentStep == 0)
    {
      if (!_validateFirstStep())
      {
        return;
      }

      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: _stepTransition, curve: Curves.easeInOut);

      return;
    }

    if (_selectedSubjects.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno una materia ministeriale.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.onSave(
      _nameController.text.trim(),
      _selectedLevel!,
      int.parse(_minYearController.text),
      int.parse(_maxYearController.text),
      _descController.text.trim(),
      _selectedSubjects,
      (errorMessage)
      {
        if (mounted)
        {
          CustomSnackBar.show(context: context, message: errorMessage, isError: true);
        }
      },
    );

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (!success)
    {
      return;
    }

    if (_isEditing)
    {
      Navigator.of(context).pop();
    }
    else
    {
      _resetForm();
    }
  }

  void _prevStep()
  {
    if (_currentStep <= 0)
    {
      return;
    }

    setState(() => _currentStep--);
    _pageController.animateToPage(_currentStep, duration: _stepTransition, curve: Curves.easeInOut);
  }

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 16),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildYearField(TextEditingController controller, String hint, {required bool isMinField})
  {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _onYearChanged(isMinField),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppTheme.hint),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
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
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Es. Liceo Classico (biennio)',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  color: AppTheme.hint,
                  fontWeight: FontWeight.w500,
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
            _buildFieldLabel('Livello scolastico'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: schoolLevels.map((level)
              {
                return CustomChip(
                  label: level.label,
                  isSelected: _selectedLevel == level.value,
                  onSelected: (selected) => _onLevelChanged(level.value, selected),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Anno Inizio'),
                      _buildYearField(_minYearController, 'Es. 1', isMinField: true),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Anno Fine'),
                      _buildYearField(_maxYearController, 'Es. 5', isMinField: false),
                    ],
                  ),
                ),
              ],
            ),
            // Shown only after a level has been picked, so the constraint does
            // not confuse the user before it applies.
            if (_selectedLevel != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Intervallo consentito per il livello selezionato: 1 - $_maxYearForSelectedLevel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.mutedText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            _buildFieldLabel('Descrizione (opzionale)'),
            TextField(
              controller: _descController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Aggiungi una descrizione...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AppTheme.hint,
                  fontWeight: FontWeight.w500,
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2()
  {
    final query = _subjectSearchController.text.toLowerCase();

    final availableSubjects = widget.availableMinistrySubjects
        .where((subject) => subject.level == _selectedLevel && subject.name.toLowerCase().contains(query))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleziona le materie ministeriali associate',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSearchBar(
            controller: _subjectSearchController,
            onChanged: (_) => setState(() {}),
            hintText: 'Cerca materia ministeriale...',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: availableSubjects.isEmpty
                ? Center(
                    child: Text(
                      'Nessuna materia trovata per il livello.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: AppTheme.mutedText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: availableSubjects.map((subject)
                      {
                        return CustomChip(
                          label: subject.name,
                          isSelected: _selectedSubjects.contains(subject.id),
                          onSelected: (selected) => setState(()
                          {
                            if (selected)
                            {
                              _selectedSubjects.add(subject.id);
                            }
                            else
                            {
                              _selectedSubjects.remove(subject.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final isLastStep = _currentStep == 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        height: 600,
        constraints: const BoxConstraints(maxWidth: 650),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing
                        ? 'Modifica Percorso (${_currentStep + 1}/2)'
                        : 'Nuovo Percorso (${_currentStep + 1}/2)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  FadeHoverIconButton(
                    icon: Icons.close,
                    color: AppTheme.primary,
                    hoverColor: AppTheme.iconHover,
                    onTap: _closeDialog,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildStep1(), _buildStep2()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ResponsiveDialogButtonsRow(
                secondaryButton: _currentStep > 0
                    ? OutlinedActionButton(
                        text: 'INDIETRO',
                        icon: Icons.arrow_back_rounded,
                        onPressed: _prevStep,
                      )
                    : AnimatedActionButton(
                        text: 'ANNULLA',
                        icon: Icons.cancel_outlined,
                        baseColor: AppTheme.danger,
                        hoverColor: AppTheme.dangerHover,
                        onPressed: _closeDialog,
                      ),
                primaryButton: AnimatedActionButton(
                  text: _isSaving
                      ? 'SALVATAGGIO...'
                      : (isLastStep ? (_isEditing ? 'SALVA MODIFICHE' : 'CREA PERCORSO') : 'AVANTI'),
                  icon: isLastStep ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
                  baseColor: AppTheme.primary,
                  hoverColor: AppTheme.primaryHover,
                  onPressed: _isSaving ? () {} : _nextStep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Generic id plus name option, used both for ministry subjects and for
// disciplines. The subtitle only disambiguates homonyms across levels.
class _SubjectOption
{
  final int id;
  final String name;
  final String? subtitle;

  const _SubjectOption({required this.id, required this.name, this.subtitle});
}

class _FilterChipButton extends StatefulWidget
{
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    required this.onClear,
  });

  @override
  State<_FilterChipButton> createState() => _FilterChipButtonState();
}

class _FilterChipButtonState extends State<_FilterChipButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    final isActive = widget.count > 0;
    final isHighlighted = _isHovered || isActive;
    final displayText = isActive ? '${widget.label} (${widget.count})' : widget.label;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 42,
          padding: EdgeInsets.only(left: 16, right: isActive ? 12 : 16),
          decoration: BoxDecoration(
            color: isHighlighted ? AppTheme.surfaceHover : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  displayText,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppTheme.primary : AppTheme.mutedText,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onClear,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
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

class _SubjectFilterDialog extends StatefulWidget
{
  final String title;
  final String hint;
  final List<_SubjectOption> options;
  final Set<int> initialSelectedIds;
  final ValueChanged<Set<int>> onApply;

  const _SubjectFilterDialog({
    required this.title,
    required this.hint,
    required this.options,
    required this.initialSelectedIds,
    required this.onApply,
  });

  @override
  State<_SubjectFilterDialog> createState() => _SubjectFilterDialogState();
}

class _SubjectFilterDialogState extends State<_SubjectFilterDialog>
{
  final TextEditingController _searchController = TextEditingController();

  late Set<int> _selectedIds;

  @override
  void initState()
  {
    super.initState();
    _selectedIds = Set<int>.from(widget.initialSelectedIds);
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<_SubjectOption> get _selectedOptions
  {
    final selected = widget.options.where((option) => _selectedIds.contains(option.id)).toList();
    selected.sort((a, b) => a.name.compareTo(b.name));

    return selected;
  }

  // Already selected options are not proposed again by the autocomplete.
  List<_SubjectOption> get _availableOptions =>
      widget.options.where((option) => !_selectedIds.contains(option.id)).toList();

  void _addOption(_SubjectOption option)
  {
    setState(() => _selectedIds.add(option.id));
  }

  void _removeOption(int id)
  {
    setState(() => _selectedIds.remove(id));
  }

  void _reset()
  {
    setState(()
    {
      _selectedIds.clear();
      _searchController.clear();
    });
  }

  void _apply()
  {
    widget.onApply(_selectedIds);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context)
  {
    final selectedOptions = _selectedOptions;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  FadeHoverIconButton(
                    icon: Icons.close,
                    color: AppTheme.primary,
                    hoverColor: AppTheme.iconHover,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SubjectAutocompleteField(
                      controller: _searchController,
                      hint: widget.hint,
                      options: _availableOptions,
                      onSelected: _addOption,
                    ),
                    const SizedBox(height: 16),
                    if (selectedOptions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Nessuna selezione.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppTheme.mutedText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedOptions.map((option)
                        {
                          return _DeletableChip(
                            label: option.name,
                            onDelete: () => _removeOption(option.id),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ResponsiveDialogButtonsRow(
                secondaryButton: AnimatedActionButton(
                  text: 'AZZERA',
                  icon: Icons.refresh_rounded,
                  baseColor: AppTheme.danger,
                  hoverColor: AppTheme.dangerHover,
                  onPressed: _reset,
                ),
                primaryButton: AnimatedActionButton(
                  text: 'APPLICA FILTRO',
                  icon: Icons.check_circle_outline,
                  baseColor: AppTheme.primary,
                  hoverColor: AppTheme.primaryHover,
                  onPressed: _apply,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Works on ids rather than plain strings, because ministry subject names can
// repeat across levels (uq_level_ministry_subject_name).
class _SubjectAutocompleteField extends StatefulWidget
{
  final TextEditingController controller;
  final String hint;
  final List<_SubjectOption> options;
  final ValueChanged<_SubjectOption> onSelected;

  const _SubjectAutocompleteField({
    required this.controller,
    required this.hint,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_SubjectAutocompleteField> createState() => _SubjectAutocompleteFieldState();
}

class _SubjectAutocompleteFieldState extends State<_SubjectAutocompleteField>
{
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose()
  {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return RawAutocomplete<_SubjectOption>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (textEditingValue)
      {
        if (textEditingValue.text.isEmpty)
        {
          return const Iterable<_SubjectOption>.empty();
        }

        final query = textEditingValue.text.toLowerCase();

        return widget.options.where((option) => option.name.toLowerCase().contains(query));
      },
      onSelected: (option)
      {
        widget.onSelected(option);

        // clear() alone leaves the selection collapsed at -1, which Flutter
        // renders as no caret at all, so it is restored explicitly.
        Future.microtask(()
        {
          widget.controller.clear();
          widget.controller.selection = const TextSelection.collapsed(offset: 0);
          _focusNode.requestFocus();
        });
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted)
      {
        return Container(
          height: 50,
          padding: const EdgeInsets.only(left: 16, right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => onFieldSubmitted(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.hint,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              if (textEditingController.text.isNotEmpty)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: ()
                    {
                      textEditingController.clear();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) => _SubjectAutocompleteOptionsList(
        options: options,
        onSelected: onSelected,
      ),
    );
  }
}

class _SubjectAutocompleteOptionsList extends StatefulWidget
{
  final Iterable<_SubjectOption> options;
  final AutocompleteOnSelected<_SubjectOption> onSelected;

  const _SubjectAutocompleteOptionsList({required this.options, required this.onSelected});

  @override
  State<_SubjectAutocompleteOptionsList> createState() => _SubjectAutocompleteOptionsListState();
}

class _SubjectAutocompleteOptionsListState extends State<_SubjectAutocompleteOptionsList>
{
  // Vertical padding of the ListView, on one side: it is the offset before the
  // first item in the scroll computation below.
  static const double _verticalPadding = 8;

  final ScrollController _scrollController = ScrollController();

  int? _lastHighlightedIndex;

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  // Scrolls by the minimum needed to reveal the arrow-highlighted option,
  // rather than always centring it.
  void _ensureHighlightedVisible(int index)
  {
    if (!_scrollController.hasClients)
    {
      return;
    }

    final itemTop = _verticalPadding + (index * _subjectOptionItemHeight);
    final itemBottom = itemTop + _subjectOptionItemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final visibleTop = _scrollController.offset;
    final visibleBottom = visibleTop + viewportHeight;

    double? target;

    if (itemTop < visibleTop)
    {
      target = itemTop;
    }
    else if (itemBottom > visibleBottom)
    {
      target = itemBottom - viewportHeight;
    }

    if (target == null)
    {
      return;
    }

    _scrollController.jumpTo(target.clamp(0.0, _scrollController.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context)
  {
    // Reading it here is what creates the reactive dependency on the notifier,
    // so this widget rebuilds on every arrow key press.
    final highlightedIndex = AutocompleteHighlightedOption.of(context);

    if (_lastHighlightedIndex != highlightedIndex)
    {
      _lastHighlightedIndex = highlightedIndex;

      // Deferred: the scrollable must already be laid out to expose
      // viewportDimension and maxScrollExtent.
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          _ensureHighlightedVisible(highlightedIndex);
        }
      });
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 436,
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 200),
          // Keeps the highlighted row from painting over the rounded corners.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.overlayShadow,
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              thumbColor: AppTheme.hint,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
                shrinkWrap: true,
                itemExtent: _subjectOptionItemHeight,
                itemCount: widget.options.length,
                itemBuilder: (context, index)
                {
                  final option = widget.options.elementAt(index);

                  return _SubjectAutocompleteItem(
                    option: option,
                    isHighlighted: index == highlightedIndex,
                    onTap: () => widget.onSelected(option),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectAutocompleteItem extends StatefulWidget
{
  final _SubjectOption option;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _SubjectAutocompleteItem({
    required this.option,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_SubjectAutocompleteItem> createState() => _SubjectAutocompleteItemState();
}

class _SubjectAutocompleteItemState extends State<_SubjectAutocompleteItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final isActive = widget.isHighlighted || _hover;
    final subtitle = widget.option.subtitle;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          height: _subjectOptionItemHeight,
          color: isActive ? AppTheme.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: isActive ? 16 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.option.name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText,
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

// Also present in people_filter_dialog.dart: private classes cannot be shared
// between Dart files.
class _DeletableChip extends StatefulWidget
{
  final String label;
  final VoidCallback onDelete;

  const _DeletableChip({required this.label, required this.onDelete});

  @override
  State<_DeletableChip> createState() => _DeletableChipState();
}

class _DeletableChipState extends State<_DeletableChip>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: _isHovered ? AppTheme.surfaceHover : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppTheme.border, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}