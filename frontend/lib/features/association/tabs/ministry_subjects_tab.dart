import 'package:flutter/material.dart';
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
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../shared/widgets/wizard_dialog.dart';
import '../models/association_subject_item.dart';
import '../models/ministry_subject_item.dart';
import '../models/subject_taxonomy.dart';
import '../widgets/ministry_subject_card.dart';

class MinistrySubjectsTab extends StatefulWidget
{
  final List<MinistrySubjectItem> ministrySubjects;

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
  SortCriterion _sortBy = SortCriterion.nameAsc;
  String? _filterArea;
  String? _filterLevel;

  Set<int> _selectedAssociationSubjectIds = {};

  List<MinistrySubjectItem> get _filteredSubjects
  {
    final query = _searchText.toLowerCase();

    final result = widget.ministrySubjects.where((subject)
    {
      final matchesSearch = subject.name.toLowerCase().contains(query);
      final matchesArea = _filterArea == null || subject.areas.contains(_filterArea);
      final matchesLevel = _filterLevel == null || subject.level == _filterLevel;

      final matchesAssociationSubjects = _selectedAssociationSubjectIds.isEmpty ||
          subject.associationSubjects.any(
            (discipline) => _selectedAssociationSubjectIds.contains(discipline.id),
          );

      return matchesSearch && matchesArea && matchesLevel && matchesAssociationSubjects;
    }).toList();

    sortByCriterion(
      result,
      _sortBy,
      name: (item) => item.name,
      createdAt: (item) => item.createdAt,
    );

    return result;
  }

  void _showWizard({MinistrySubjectItem? subject, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'MinistrySubjectWizard',
      builder: (context) => _MinistrySubjectWizardDialog(
        existingSubject: subject,
        availableAssociationSubjects: widget.associationSubjects,
        onCancelEdit: onCancelEdit,
        onSave: (name, level, areas, description, associationIds, onError) async
        {
          if (subject == null)
          {
            return await widget.onCreate(name, level, areas, description, associationIds, onError);
          }

          return await widget.onEdit(subject.id, name, level, areas, description, associationIds, onError);
        },
      ),
    );
  }

  void _showAssociationSubjectFilterDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectFilterDialog',
      builder: (context) => MultiSelectFilterDialog<int>(
        title: 'Filtra per disciplina interna',
        hint: 'Es. Aritmetica',
        options: widget.associationSubjects
            .map((subject) => MultiSelectFilterOption(value: subject.id, label: subject.name))
            .toList(),
        initialSelected: _selectedAssociationSubjectIds,
        onApply: (ids) => setState(() => _selectedAssociationSubjectIds = ids),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final subjects = _filteredSubjects;

    return TabContent(
      header: entityTabHeader(
        searchController: _searchController,
        onSearchChanged: (value) => setState(() => _searchText = value),
        searchHint: 'Cerca materia ministeriale...',
        actionLabel: 'NUOVA MATERIA',
        onAction: () => _showWizard(),
        sort: _sortBy,
        onSortChanged: (value) => setState(() => _sortBy = value),
        countLabel: subjects.length == 1
            ? '1 materia trovata'
            : '${subjects.length} materie trovate',
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
          AppFilterPill<String>.filter(
            prefix: 'Area',
            hint: 'Tutte le aree',
            icon: Icons.category_outlined,
            value: _filterArea,
            menuWidth: 210,
            onChanged: (value) => setState(() => _filterArea = value),
            onClear: () => setState(() => _filterArea = null),
            options: subjectAreas
                .map((area) => FilterOption(value: area.value, label: area.label))
                .toList(),
          ),
          AppCountFilterPill(
            icon: Icons.auto_stories_outlined,
            label: 'Discipline interne',
            count: _selectedAssociationSubjectIds.length,
            onOpen: _showAssociationSubjectFilterDialog,
            onClear: () => setState(() => _selectedAssociationSubjectIds = {}),
          ),
        ],
      ),
      body: EntityCardGrid(
        children: subjects.map((subject)
        {
          return MinistrySubjectCard(
            subject: subject,
            onEditRequested: (onCancel) => _showWizard(subject: subject, onCancelEdit: onCancel),
            onDelete: () => widget.onDelete(subject),
          );
        }).toList(),
      ),
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
    this.existingSubject,
    required this.availableAssociationSubjects,
    this.onCancelEdit,
    required this.onSave,
  });

  @override
  State<_MinistrySubjectWizardDialog> createState() => _MinistrySubjectWizardDialogState();
}

class _MinistrySubjectWizardDialogState extends State<_MinistrySubjectWizardDialog>
    with WizardDialogState, TwoStepWizardState
{
  static const int _maxAreas = 3;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _disciplineSearchController = TextEditingController();

  static const double _contentMaxWidth = 640;

  static const double _optionsMaxHeight = 300;

  String? _selectedLevel;
  List<String> _selectedAreas = [];
  List<int> _selectedAssociations = [];

  @override
  bool get isEditing => widget.existingSubject != null;

  @override
  VoidCallback? get onCancelEdit => widget.onCancelEdit;

  @override
  void initState()
  {
    super.initState();

    _nameController.addListener(_refresh);

    final subject = widget.existingSubject;

    if (subject != null)
    {
      _nameController.text = subject.name;
      _descController.text = subject.description ?? '';
      _selectedLevel = subject.level;
      _selectedAreas = List<String>.from(subject.areas);
      _selectedAssociations = subject.associationSubjects.map((a) => a.id).toList();
    }
  }

  @override
  void dispose()
  {
    _nameController.removeListener(_refresh);
    _nameController.dispose();
    _descController.dispose();
    _disciplineSearchController.dispose();
    super.dispose();
  }

  @override
  void resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _descController.clear();
      _disciplineSearchController.clear();
      _selectedLevel = null;
      _selectedAreas.clear();
      _selectedAssociations.clear();
      rewindSteps();
    });
  }

  void _onAreaChanged(String area, bool isSelected)
  {
    if (isSelected && _selectedAreas.length >= _maxAreas)
    {
      CustomSnackBar.show(context: context, message: 'Puoi selezionare al massimo $_maxAreas aree.', isError: true);
      return;
    }

    setState(()
    {
      if (isSelected)
      {
        _selectedAreas.add(area);
        return;
      }

      _selectedAreas.remove(area);

      final idsToRemove = widget.availableAssociationSubjects
          .where((subject) => subject.area == area)
          .map((subject) => subject.id)
          .toSet();

      _selectedAssociations.removeWhere(idsToRemove.contains);
    });
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

    if (_selectedAreas.isEmpty)
    {
      return "Seleziona almeno un'area per andare avanti.";
    }

    return null;
  }

  void _refresh()
  {
    if (mounted)
    {
      setState(() {});
    }
  }

  Future<void> _submit() async
  {
    if (!validateFirstStep())
    {
      goToStep(0);

      return;
    }

    if (_selectedAssociations.isEmpty)
    {
      goToStep(1);
      showError('Seleziona almeno una disciplina interna associata.');

      return;
    }

    await runSave(
      (onError) => widget.onSave(
        _nameController.text.trim(),
        _selectedLevel!,
        _selectedAreas,
        _descController.text.trim(),
        _selectedAssociations,
        onError,
      ),
    );
  }

  Widget _buildStep1()
  {
    return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Nome',
              hintText: 'Es. Lingua e cultura latina',
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
                  onSelected: (selected) => setState(()
                  {
                    _selectedLevel = selected ? level.value : null;
                  }),
                );
              }).toList(),
            ),
            const WizardFieldLabel('Aree (massimo $_maxAreas)'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: subjectAreas.map((area)
              {
                return AppSelectableChip(
                  label: area.compactLabel,
                  selected: _selectedAreas.contains(area.value),
                  onSelected: (selected) => _onAreaChanged(area.value, selected),
                );
              }).toList(),
            ),
            DescriptionField(_descController),
          ],
        ),
      );
  }

  Widget _buildStep2()
  {
    final query = _disciplineSearchController.text.toLowerCase();

    final availableSubjects = widget.availableAssociationSubjects
        .where((subject) => _selectedAreas.contains(subject.area) && subject.name.toLowerCase().contains(query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seleziona le discipline interne associate',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppTheme.trialMutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        AppSearchField(
          controller: _disciplineSearchController,
          onChanged: (_) => setState(() {}),
          hintText: 'Cerca disciplina interna...',
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _optionsMaxHeight),
          child: availableSubjects.isEmpty
              ? Center(
                  child: Text(
                    'Nessuna disciplina trovata per le aree selezionate.',
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
                        selected: _selectedAssociations.contains(subject.id),
                        onSelected: (selected) => setState(()
                        {
                          if (selected)
                          {
                            _selectedAssociations.add(subject.id);
                          }
                          else
                          {
                            _selectedAssociations.remove(subject.id);
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
      title: isEditing ? 'Modifica materia' : 'Nuova materia',
      contentMaxWidth: _contentMaxWidth,
      onSubmit: _submit,
      firstStep: _buildStep1,
      secondStep: _buildStep2,
    );
  }
}
