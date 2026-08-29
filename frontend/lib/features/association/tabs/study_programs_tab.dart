import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../shared/widgets/wizard_dialog.dart';
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

  final List<MinistrySubjectItem> ministrySubjects;

  final List<AssociationSubjectItem> associationSubjects;

  final Future<bool> Function(String name, String? sector, String level, String? highSchoolTrack, int? minYear, int? maxYear, String description, List<int> subjectIds, Function(String) onError) onCreate;
  final Future<bool> Function(int id, String name, String? sector, String level, String? highSchoolTrack, int? minYear, int? maxYear, String description, List<int> subjectIds, Function(String) onError) onEdit;
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

  Set<int> _selectedMinistrySubjectIds = {};
  Set<int> _selectedAssociationSubjectIds = {};

  List<StudyProgramItem> get _filteredPrograms
  {
    final query = _searchText.toLowerCase();

    final result = widget.studyPrograms.where((program)
    {
      final matchesSearch = program.fullName.toLowerCase().contains(query);
      final matchesLevel = _filterLevel == null || program.level == _filterLevel;
      final matchesSector = _filterSector == null || program.sector == _filterSector;

      final matchesMinistrySubjects = _selectedMinistrySubjectIds.isEmpty ||
          program.ministrySubjects.any((subject) => _selectedMinistrySubjectIds.contains(subject.id));

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

    sortByCriterion(
      result,
      _sortBy,
      name: (item) => item.name,
      createdAt: (item) => item.createdAt,
    );

    return result;
  }

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
        availableMinistrySubjects: widget.ministrySubjects,
        knownSectors: _knownSectors,
        onCancelEdit: onCancelEdit,
        onSave: (name, sector, level, highSchoolTrack, minYear, maxYear, description, subjectIds, onError) async
        {
          if (program == null)
          {
            return await widget.onCreate(name, sector, level, highSchoolTrack, minYear, maxYear, description, subjectIds, onError);
          }

          return await widget.onEdit(program.id, name, sector, level, highSchoolTrack, minYear, maxYear, description, subjectIds, onError);
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
      header: entityTabHeader(
        searchController: _searchController,
        onSearchChanged: (value) => setState(() => _searchText = value),
        searchHint: 'Cerca percorso di studio...',
        actionLabel: 'NUOVO PERCORSO',
        onAction: () => _showWizard(),
        sort: _sortBy,
        onSortChanged: (value) => setState(() => _sortBy = value),
        countLabel: programs.length == 1
            ? '1 percorso trovato'
            : '${programs.length} percorsi trovati',
        filters: [
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

  final List<String> knownSectors;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String name, String? sector, String level, String? highSchoolTrack, int? minYear, int? maxYear, String description, List<int> subjectIds, Function(String) onError) onSave;

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
    with WizardDialogState, TwoStepWizardState
{
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sectorController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minYearController = TextEditingController();
  final TextEditingController _maxYearController = TextEditingController();
  final TextEditingController _subjectSearchController = TextEditingController();

  static const double _contentMaxWidth = 640;

  static const double _optionsMaxHeight = 300;

  String? _selectedLevel;

  String? _selectedTrack;

  List<int> _selectedSubjects = [];

  bool _isClampingYears = false;

  @override
  bool get isEditing => widget.existingProgram != null;

  @override
  VoidCallback? get onCancelEdit => widget.onCancelEdit;

  int get _maxYearForSelectedLevel => _maxYearForLevel(_selectedLevel);

  bool get _isHighSchool => _selectedLevel == 'HIGH_SCHOOL';

  @override
  void initState()
  {
    super.initState();

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
      _selectedTrack = program.highSchoolTrack;
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

  @override
  void resetForm()
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
      _selectedTrack = null;
      _selectedSubjects.clear();
      rewindSteps();
    });
  }

  void _clampYearsToLevel(String level)
  {
    final maxAllowed = _maxYearForLevel(level);

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
        _selectedTrack = null;

        if (level == 'HIGH_SCHOOL')
        {
          // Cleared so stale digits cannot slip past the blocked-reason check
          // into the payload.
          _minYearController.clear();
          _maxYearController.clear();
        }
        else
        {
          _clampYearsToLevel(level);
        }
      }

      _selectedLevel = level;
    });
  }

  void _onYearChanged(bool isMinField)
  {
    if (_isClampingYears)
    {
      return;
    }

    if (_selectedLevel == null)
    {
      return;
    }

    final controller = isMinField ? _minYearController : _maxYearController;
    final otherController = isMinField ? _maxYearController : _minYearController;

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

    setState(() {});
  }

  @override
  String? get firstStepBlockedReason
  {
    if (_nameController.text.trim().isEmpty)
    {
      return 'Scrivi il nome per andare avanti.';
    }

    if (_selectedLevel == null)
    {
      return 'Seleziona un livello scolastico per andare avanti.';
    }

    if (_isHighSchool)
    {
      return _selectedTrack == null
          ? "Seleziona l'articolazione per andare avanti."
          : null;
    }

    if (_minYearController.text.isEmpty || _maxYearController.text.isEmpty)
    {
      return "Compila l'intervallo degli anni per andare avanti.";
    }

    return null;
  }

  bool _validateScope()
  {
    if (!validateFirstStep())
    {
      return false;
    }

    // firstStepBlockedReason already required the track, the only field high
    // school sends.
    if (_isHighSchool)
    {
      return true;
    }

    final minYear = int.tryParse(_minYearController.text);
    final maxYear = int.tryParse(_maxYearController.text);

    if (minYear == null || maxYear == null || minYear > maxYear || minYear < 1)
    {
      showError('Intervallo di anni non valido.');

      return false;
    }

    if (maxYear > _maxYearForSelectedLevel)
    {
      showError(
        "Per il livello selezionato l'anno massimo consentito è "
        '$_maxYearForSelectedLevel.',
      );

      return false;
    }

    return true;
  }

  Future<void> _submit() async
  {
    if (!_validateScope())
    {
      goToStep(0);

      return;
    }

    if (_selectedSubjects.isEmpty)
    {
      goToStep(1);
      showError('Seleziona almeno una materia ministeriale.');

      return;
    }

    final sector = _sectorController.text.trim();

    await runSave(
      (onError) => widget.onSave(
        _nameController.text.trim(),
        sector.isEmpty ? null : sector,
        _selectedLevel!,
        _isHighSchool ? _selectedTrack : null,
        // Null for high school: the server derives them from the track.
        _isHighSchool ? null : int.parse(_minYearController.text),
        _isHighSchool ? null : int.parse(_maxYearController.text),
        _descController.text.trim(),
        _selectedSubjects,
        onError,
      ),
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

  Widget _buildHint(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.trialMutedText,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildYearRangeFields()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (_selectedLevel != null)
          _buildHint('Intervallo consentito per il livello selezionato: 1 - $_maxYearForSelectedLevel'),
      ],
    );
  }

  Widget _buildTrackField()
  {
    final HighSchoolTrack? chosen = highSchoolTrackOf(_selectedTrack);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WizardFieldLabel('Articolazione'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: highSchoolTracks.map((track)
          {
            return AppSelectableChip(
              label: track.label,
              selected: _selectedTrack == track.value,
              onSelected: (selected) => setState(()
              {
                _selectedTrack = selected ? track.value : null;
              }),
            );
          }).toList(),
        ),
        if (chosen != null)
          _buildHint('Anni di corso: ${chosen.minYear} - ${chosen.maxYear}'),
      ],
    );
  }

  Widget _buildStep1()
  {
    return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              hintText: 'Es. Amministrazione, finanza e marketing',
              maxLength: FieldLimits.name,
              textCapitalization: TextCapitalization.sentences,
            ),
            const WizardFieldLabel('Livello scolastico'),
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
            if (_isHighSchool) _buildTrackField() else _buildYearRangeFields(),
            DescriptionField(_descController),
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
    return buildTwoStepDialog(
      title: isEditing ? 'Modifica percorso' : 'Nuovo percorso',
      contentMaxWidth: _contentMaxWidth,
      onSubmit: _submit,
      firstStep: _buildStep1,
      secondStep: _buildStep2,
    );
  }
}

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
    return LayoutBuilder(builder: (context, constraints)
    {
      final double width = constraints.maxWidth;

      return RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: (value)
        {
          final query = value.text.trim().toLowerCase();

          return widget.options.where(
            (option) => query.isEmpty || option.toLowerCase().contains(query),
          );
        },
        onSelected: (option) => widget.onChanged(),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted)
        {
          return AppTextField(
            controller: controller,
            focusNode: focusNode,
            label: widget.label,
            hintText: widget.hint,
            maxLength: FieldLimits.sector,
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
