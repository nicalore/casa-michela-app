import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../models/association_subject_item.dart';
import '../models/ministry_subject_item.dart';
import '../models/study_program_item.dart';
import '../models/subject_taxonomy.dart';
import '../widgets/study_program_card.dart';

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

  final Future<bool> Function(String name, String? sector, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) onCreate;
  final Future<bool> Function(int id, String name, String? sector, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) onEdit;
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
  String? _filterSector;

  // Multi selection filters: a program passes when it matches at least one of
  // the selected ids, and the two filters are combined with the others in AND.
  Set<int> _selectedMinistrySubjectIds = {};
  Set<int> _selectedAssociationSubjectIds = {};


  List<StudyProgramItem> get _filteredPrograms
  {
    final query = _searchText.toLowerCase();

    final result = widget.studyPrograms.where((program)
    {
      // Searched on the full name: the sector no longer lives inside the name,
      // but it is still what one types to reach a programme.
      final matchesSearch = program.fullName.toLowerCase().contains(query);
      final matchesLevel = _filterLevel == null || program.level == _filterLevel;
      final matchesSector = _filterSector == null || program.sector == _filterSector;

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

      return matchesSearch &&
          matchesLevel &&
          matchesSector &&
          matchesMinistrySubjects &&
          matchesAssociationSubjects;
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

  // The sectors the programmes really have, in alphabetical order: there is no
  // fixed list of sectors, they are written by whoever enters the programmes.
  List<String> get _knownSectors
  {
    final sectors = <String>{
      for (final program in widget.studyPrograms)
        if (program.sector != null) program.sector!,
    }.toList();

    sectors.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return sectors;
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
        knownSectors: _knownSectors,
        onCancelEdit: onCancelEdit,
        onSave: (name, sector, level, minYear, maxYear, description, subjectIds, onError) async
        {
          if (program == null)
          {
            return await widget.onCreate(name, sector, level, minYear, maxYear, description, subjectIds, onError);
          }

          return await widget.onEdit(program.id, name, sector, level, minYear, maxYear, description, subjectIds, onError);
        },
      ),
    );
  }

  void _showSubjectFilterDialog({
    required String title,
    required String hint,
    required List<MultiSelectFilterOption<int>> options,
    required Set<int> initialSelectedIds,
    required ValueChanged<Set<int>> onApply,
  })
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectFilterDialog',
      builder: (context) => MultiSelectFilterDialog<int>(
        title: title,
        hint: hint,
        options: options,
        initialSelected: initialSelectedIds,
        onApply: onApply,
      ),
    );
  }

  void _showMinistrySubjectFilterDialog()
  {
    _showSubjectFilterDialog(
      title: 'Filtra per materia ministeriale',
      hint: 'Es. Matematica',
      options: widget.ministrySubjects
          .map((subject) => MultiSelectFilterOption(
                value: subject.id,
                label: subject.name,
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
      hint: 'Es. Aritmetica',
      options: widget.associationSubjects
          .map((subject) => MultiSelectFilterOption(value: subject.id, label: subject.name))
          .toList(),
      initialSelectedIds: _selectedAssociationSubjectIds,
      onApply: (ids) => setState(() => _selectedAssociationSubjectIds = ids),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final programs = _filteredPrograms;

    return TabContent(
      header: [
        TabHeaderRow(
          search: AppSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchText = value),
            hintText: 'Cerca percorso di studio...',
          ),
          action: AppGradientButton(
            label: 'NUOVO PERCORSO',
            icon: Icons.add_rounded,
            height: 50,
            // Half its own height: the shape of the search bar it stands
            // beside.
            radius: 25,
            fontSize: 14,
            onPressed: () => _showWizard(),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppFilterPill<SortCriterion>.setting(
              prefix: 'Ordina',
              hint: 'Ordina per',
              icon: Icons.swap_vert_rounded,
              value: _sortBy,
              menuWidth: 190,
              onChanged: (value) => setState(() => _sortBy = value),
              options: SortCriterion.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            const FilterGroupDivider(),
            AppFilterPill<String>.filter(
              prefix: 'Livello',
              hint: 'Tutti i livelli',
              icon: Icons.school_outlined,
              value: _filterLevel,
              menuWidth: 210,
              onChanged: (value) => setState(() => _filterLevel = value),
              onClear: () => setState(() => _filterLevel = null),
              options: schoolLevels
                  .map((level) => FilterOption(value: level.value, label: level.compactLabel))
                  .toList(),
            ),
            if (_knownSectors.isNotEmpty)
              AppFilterPill<String>.filter(
                prefix: 'Settore',
                hint: 'Tutti i settori',
                icon: Icons.account_tree_outlined,
                value: _filterSector,
                menuWidth: 280,
                onChanged: (value) => setState(() => _filterSector = value),
                onClear: () => setState(() => _filterSector = null),
                options: _knownSectors
                    .map((sector) => FilterOption(value: sector, label: sector))
                    .toList(),
              ),
            AppCountFilterPill(
              icon: Icons.auto_stories_outlined,
              label: 'Discipline interne',
              count: _selectedAssociationSubjectIds.length,
              onOpen: _showAssociationSubjectFilterDialog,
              onClear: () => setState(() => _selectedAssociationSubjectIds = {}),
            ),
            AppCountFilterPill(
              icon: Icons.menu_book_outlined,
              label: 'Materie ministeriali',
              count: _selectedMinistrySubjectIds.length,
              onOpen: _showMinistrySubjectFilterDialog,
              onClear: () => setState(() => _selectedMinistrySubjectIds = {}),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          programs.length == 1 ? '1 percorso trovato' : '${programs.length} percorsi trovati',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 16),
      ],
      body: EntityCardGrid(
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
    );
  }
}

class _StudyProgramWizardDialog extends StatefulWidget
{
  final StudyProgramItem? existingProgram;
  final List<MinistrySubjectItem> availableMinistrySubjects;

  // The sectors already used by the other programmes, offered as choices so
  // that the same wording stays the same word.
  final List<String> knownSectors;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String name, String? sector, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) onSave;

  const _StudyProgramWizardDialog({
    this.existingProgram,
    required this.availableMinistrySubjects,
    required this.knownSectors,
    this.onCancelEdit,
    required this.onSave,
  });

  @override
  State<_StudyProgramWizardDialog> createState() => _StudyProgramWizardDialogState();
}

class _StudyProgramWizardDialogState extends State<_StudyProgramWizardDialog>
{
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sectorController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minYearController = TextEditingController();
  final TextEditingController _maxYearController = TextEditingController();
  final TextEditingController _subjectSearchController = TextEditingController();

  // How wide the card in the carousel is allowed to get, and the stack around
  // it: the card plus an arrow and a gap on either side.
  static const double _contentMaxWidth = 640;
  static const double _stackMaxWidth =
      _contentMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

  // How tall the list of things to pick can get before it scrolls on its own.
  static const double _optionsMaxHeight = 300;

  int _currentStep = 0;
  bool _movingForward = true;
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

    // The arrow lights up as soon as the mandatory fields are there: without
    // listening to them it would stay dark until something else repainted.
    _nameController.addListener(_refresh);
    _minYearController.addListener(_refresh);
    _maxYearController.addListener(_refresh);

    final program = widget.existingProgram;

    if (program != null)
    {
      _nameController.text = program.name;
      _sectorController.text = program.sector ?? '';
      _descController.text = program.description;
      _selectedLevel = program.level;
      _minYearController.text = program.minYear.toString();
      _maxYearController.text = program.maxYear.toString();
      _selectedSubjects = program.ministrySubjects.map((subject) => subject.id).toList();
    }
  }

  void _refresh()
  {
    if (mounted)
    {
      setState(() {});
    }
  }

  @override
  void dispose()
  {
    _nameController.removeListener(_refresh);
    _minYearController.removeListener(_refresh);
    _maxYearController.removeListener(_refresh);
    _nameController.dispose();
    _sectorController.dispose();
    _descController.dispose();
    _minYearController.dispose();
    _maxYearController.dispose();
    _subjectSearchController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _sectorController.clear();
      _descController.clear();
      _minYearController.clear();
      _maxYearController.clear();
      _subjectSearchController.clear();
      _selectedLevel = null;
      _selectedSubjects.clear();
      _currentStep = 0;
      _movingForward = false;
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

  // Fits the year range to the level just picked. The ceiling is computed from
  // the incoming level, not from _selectedLevel, which still holds the old one
  // and is assigned at the end.
  void _clampYearsToLevel(String level)
  {
    final maxAllowed = _maxYearForLevel(level);

    // The ceiling the range in the fields was written against. A range that ran
    // to the end of the old level means "all of it", so it follows the new level
    // up as well as down — going from the middle school to the high school it
    // used to stay at 1-3 while the line underneath said 1-5. A range somebody
    // picked by hand, 2 to 4 out of five, is left alone unless it no longer fits.
    final previousMax = _maxYearForLevel(_selectedLevel);

    final currentMin = int.tryParse(_minYearController.text);
    final currentMax = int.tryParse(_maxYearController.text);

    final int newMax;

    if (currentMax == null || currentMax >= previousMax || currentMax > maxAllowed)
    {
      newMax = maxAllowed;
    }
    else
    {
      newMax = currentMax < 1 ? 1 : currentMax;
    }

    final int newMin;

    if (currentMin == null || currentMin < 1)
    {
      newMin = 1;
    }
    else
    {
      // Covers the ceiling too: newMin can never pass newMax, which is already
      // inside it.
      newMin = currentMin > newMax ? newMax : currentMin;
    }

    _minYearController.text = newMin.toString();
    _maxYearController.text = newMax.toString();
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

  // Why the first step does not let one move on, where it does not. What stays
  // below is the full check, which holds on save too.
  String? get _firstStepBlockedReason
  {
    if (_nameController.text.trim().isEmpty)
    {
      return 'Scrivi il nome per andare avanti.';
    }

    if (_selectedLevel == null)
    {
      return 'Seleziona un livello scolastico per andare avanti.';
    }

    if (_minYearController.text.isEmpty || _maxYearController.text.isEmpty)
    {
      return "Compila l'intervallo degli anni per andare avanti.";
    }

    return null;
  }

  bool _validateFirstStep()
  {
    final blocked = _firstStepBlockedReason;

    if (blocked != null)
    {
      CustomSnackBar.show(context: context, message: blocked, isError: true);
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

  void _goToStep(int step)
  {
    setState(()
    {
      _movingForward = step > _currentStep;
      _currentStep = step;
    });
  }

  // Everything is checked from here, whichever phase you are standing on, and
  // whatever is missing is on the phase this puts you on.
  Future<void> _submit() async
  {
    if (!_validateFirstStep())
    {
      _goToStep(0);

      return;
    }

    if (_selectedSubjects.isEmpty)
    {
      _goToStep(1);
      CustomSnackBar.show(context: context, message: 'Seleziona almeno una materia ministeriale.', isError: true);

      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.onSave(
      _nameController.text.trim(),
      _sectorController.text.trim().isEmpty ? null : _sectorController.text.trim(),
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

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: AppFieldLabel(text),
    );
  }

  Widget _buildYearField(
    TextEditingController controller,
    String label,
    String hint, {
    required bool isMinField,
  })
  {
    return AppTextField(
      controller: controller,
      label: label,
      hintText: hint,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _onYearChanged(isMinField),
    );
  }

  Widget _buildStep1()
  {
    return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prima il settore, poi il nome: è l'ordine in cui si legge un
            // percorso — la famiglia, e poi quale.
            _SectorAutocompleteField(
              controller: _sectorController,
              label: 'Settore (opzionale)',
              hint: 'Es. Istituto tecnico economico',
              options: widget.knownSectors,
              onChanged: () => setState(() {}),
            ),
            AppTextField(
              controller: _nameController,
              label: 'Nome',
              hintText: 'Es. Amministrazione finanza e marketing (triennio)',
              textCapitalization: TextCapitalization.sentences,
            ),
            _buildFieldLabel('Livello scolastico'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: schoolLevels.map((level)
              {
                return AppSelectableChip(
                  label: level.compactLabel,
                  selected: _selectedLevel == level.value,
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
                      _buildYearField(_minYearController, 'Anno inizio', 'Es. 1', isMinField: true),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildYearField(_maxYearController, 'Anno fine', 'Es. 5', isMinField: false),
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
                    fontWeight: FontWeight.w500,
                    color: AppTheme.trialMutedText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            AppTextField(
              controller: _descController,
              label: 'Descrizione (opzionale)',
              hintText: 'Aggiungi una descrizione...',
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
            ),
          ],
        ),
      );
  }

  Widget _buildStep2()
  {
    final query = _subjectSearchController.text.toLowerCase();

    final availableSubjects = widget.availableMinistrySubjects
        .where((subject) => subject.level == _selectedLevel && subject.name.toLowerCase().contains(query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seleziona le materie ministeriali associate',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppTheme.trialMutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        AppSearchField(
          controller: _subjectSearchController,
          onChanged: (_) => setState(() {}),
          hintText: 'Cerca materia ministeriale...',
        ),
        const SizedBox(height: 16),
        // A ceiling rather than the whole of what is left: the phase is a
        // piece floating on the page now, and there is no fixed panel height
        // for it to take a share of. Past this the list scrolls inside it.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _optionsMaxHeight),
          child: availableSubjects.isEmpty
              ? Center(
                  child: Text(
                    'Nessuna materia trovata per il livello.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.trialMutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableSubjects.map((subject)
                    {
                      return AppSelectableChip(
                        label: subject.name,
                        selected: _selectedSubjects.contains(subject.id),
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
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Passo ${_currentStep + 1} di 2',
      title: _isEditing ? 'Modifica percorso' : 'Nuovo percorso',
      onClose: _closeDialog,
      maxWidth: _stackMaxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: _isEditing ? 'SALVA' : 'CREA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _submit,
        ),
      ),
      children: [
        AppCarouselFrame(
          index: _currentStep,
          movingForward: _movingForward,
          maxContentWidth: _contentMaxWidth,
          canGoBack: _currentStep > 0,
          canGoForward: _currentStep == 0,
          forwardBlockedReason:
              _currentStep == 0 ? _firstStepBlockedReason : null,
          onBack: () => _goToStep(0),
          onForward: () => _goToStep(1),
          child: AppDialogPill(
            child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
          ),
        ),
      ],
    );
  }
}

// A programme's sector, with autocomplete over the sectors already in use.
//
// Free text: a new sector is simply typed. The autocomplete is there because the
// grouping only holds if the same wording stays the same word, and retyping it
// by hand every time is the quickest way not to.
class _SectorAutocompleteField extends StatefulWidget
{
  final TextEditingController controller;
  final String label;
  final String hint;
  final List<String> options;
  final VoidCallback onChanged;

  const _SectorAutocompleteField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_SectorAutocompleteField> createState() => _SectorAutocompleteFieldState();
}

class _SectorAutocompleteFieldState extends State<_SectorAutocompleteField>
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
    // Measured here so the list, which lives in an overlay, can be as wide as
    // the field it opens under.
    return LayoutBuilder(builder: (context, constraints)
    {
      final double width = constraints.maxWidth;

      return RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: (value)
        {
          final query = value.text.trim().toLowerCase();

          // On an empty field everything is offered: there are five or six, and
          // seeing them is how they get reused instead of a seventh being
          // invented.
          return widget.options.where(
            (option) => query.isEmpty || option.toLowerCase().contains(query),
          );
        },
        // The chosen text stays in the field: nothing is being collected into a
        // list here, a single question is being answered.
        onSelected: (option) => widget.onChanged(),
        // The field is the one every other field is: a sector is typed the way
        // a name is typed, and the autocomplete is only what opens under it.
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted)
        {
          return AppTextField(
            controller: controller,
            focusNode: focusNode,
            label: widget.label,
            hintText: widget.hint,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => widget.onChanged(),
            onSubmitted: (_) => onFieldSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => AutocompleteOptionsList<String>(
          options: options,
          label: (sector) => sector,
          width: width,
          onSelected: onSelected,
        ),
      );
    });
  }
}
