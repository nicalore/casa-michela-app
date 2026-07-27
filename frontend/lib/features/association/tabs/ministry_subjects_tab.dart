import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/association_subject_item.dart';
import '../models/ministry_subject_item.dart';
import '../models/subject_taxonomy.dart';
import '../widgets/ministry_subject_card.dart';

class MinistrySubjectsTab extends StatefulWidget
{
  final List<MinistrySubjectItem> ministrySubjects;

  // Read only: the wizard needs it to link the internal disciplines, but the
  // owner of this list is AssociationSubjectsTab.
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

  List<MinistrySubjectItem> get _filteredSubjects
  {
    final query = _searchText.toLowerCase();

    final result = widget.ministrySubjects.where((subject)
    {
      final matchesSearch = subject.name.toLowerCase().contains(query);
      final matchesArea = _filterArea == null || subject.areas.contains(_filterArea);
      final matchesLevel = _filterLevel == null || subject.level == _filterLevel;

      return matchesSearch && matchesArea && matchesLevel;
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

  void _showWizard({MinistrySubjectItem? subject, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'MinistrySubjectWizard',
      builder: (context) => _MinistrySubjectWizardDialog(
        existingSubject: subject,
        // Read here, so the list is refreshed by the next setState of
        // AssociationPage.
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

  @override
  Widget build(BuildContext context)
  {
    final subjects = _filteredSubjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                hintText: 'Cerca materia ministeriale...',
              ),
            ),
            const SizedBox(width: 24),
            AppGradientButton(
              label: 'NUOVA MATERIA',
              icon: Icons.add_rounded,
              height: 50,
              // Half its own height: the shape of the search bar it stands
              // beside.
              radius: 25,
              fontSize: 14,
              onPressed: () => _showWizard(),
            ),
          ],
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
            // What is left of this line arranges the list, what is right of it
            // shortens it.
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: AppTheme.trialLine,
            ),
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
          ],
        ),
        const SizedBox(height: 20),
        Text(
          subjects.length == 1
              ? '1 materia trovata'
              : '${subjects.length} materie trovate',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
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
                children: subjects.map((subject)
                {
                  return MinistrySubjectCard(
                    subject: subject,
                    onEditRequested: (onCancel) => _showWizard(subject: subject, onCancelEdit: onCancel),
                    onDelete: () => widget.onDelete(subject),
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
{
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  static const int _maxAreas = 3;
  static const Duration _stepTransition = Duration(milliseconds: 300);

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _disciplineSearchController = TextEditingController();

  int _currentStep = 0;
  bool _isSaving = false;
  String? _selectedLevel;
  List<String> _selectedAreas = [];
  List<int> _selectedAssociations = [];

  bool get _isEditing => widget.existingSubject != null;

  @override
  void initState()
  {
    super.initState();

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
    _nameController.dispose();
    _descController.dispose();
    _disciplineSearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _descController.clear();
      _disciplineSearchController.clear();
      _selectedLevel = null;
      _selectedAreas.clear();
      _selectedAssociations.clear();
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

      // Drop only the internal disciplines belonging to the area just
      // deselected, leaving those of the other selected areas untouched.
      final idsToRemove = widget.availableAssociationSubjects
          .where((subject) => subject.area == area)
          .map((subject) => subject.id)
          .toSet();

      _selectedAssociations.removeWhere(idsToRemove.contains);
    });
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

    if (_selectedAreas.isEmpty)
    {
      CustomSnackBar.show(context: context, message: "Seleziona almeno un'area di appartenenza.", isError: true);
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

    if (_selectedAssociations.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno una disciplina interna associata.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.onSave(
      _nameController.text.trim(),
      _selectedLevel!,
      _selectedAreas,
      _descController.text.trim(),
      _selectedAssociations,
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

  // Small, tracked and muted over what it names, the way the settings cards and
  // the dialogs of this app label a value.
  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.trialMutedText,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 1.4,
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
            AppTextField(
              controller: _nameController,
              label: 'Nome',
              hintText: 'Es. Lingua e cultura latina',
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
                  onSelected: (selected) => setState(()
                  {
                    _selectedLevel = selected ? level.value : null;
                  }),
                );
              }).toList(),
            ),
            _buildFieldLabel('Aree (massimo $_maxAreas)'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: subjectAreas.map((area)
              {
                return AppSelectableChip(
                  label: area.label,
                  selected: _selectedAreas.contains(area.value),
                  onSelected: (selected) => _onAreaChanged(area.value, selected),
                );
              }).toList(),
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
      ),
    );
  }

  Widget _buildStep2()
  {
    final query = _disciplineSearchController.text.toLowerCase();

    final availableSubjects = widget.availableAssociationSubjects
        .where((subject) => _selectedAreas.contains(subject.area) && subject.name.toLowerCase().contains(query))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
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
          Expanded(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final isLastStep = _currentStep == 1;

    return AppDialogShell(
      // Which step you are on belongs over the title, not inside it: the title
      // is what you are doing, the eyebrow is where you are in doing it.
      eyebrow: 'Passo ${_currentStep + 1} di 2',
      title: _isEditing ? 'Modifica materia' : 'Nuova materia',
      width: 650,
      // Pinned, or the dialog would change height between a step of fields and
      // a step of chips while you are still working through it.
      height: 600,
      footer: AppDialogFooter(
        secondary: _currentStep > 0
            ? AppGradientButton(
                label: 'INDIETRO',
                icon: Icons.arrow_back_rounded,
                gradient: AppTheme.dismissGradient,
                accent: AppTheme.trialViolet,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                onPressed: _prevStep,
              )
            : AppGradientButton(
                label: 'ANNULLA',
                icon: Icons.close_rounded,
                gradient: AppTheme.dismissGradient,
                accent: AppTheme.trialViolet,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                onPressed: _closeDialog,
              ),
        primary: AppGradientButton(
          label: isLastStep ? (_isEditing ? 'SALVA' : 'CREA') : 'AVANTI',
          icon: isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _nextStep,
        ),
      ),
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildStep1(), _buildStep2()],
      ),
    );
  }
}