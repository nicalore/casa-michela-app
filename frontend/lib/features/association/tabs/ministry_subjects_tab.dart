import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/shared_components.dart';
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
  bool _newSubjectHover = false;

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
              child: AnimatedSearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                hintText: 'Cerca materia ministeriale...',
              ),
            ),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _newSubjectHover = true),
              onExit: (_) => setState(() => _newSubjectHover = false),
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
                      color: _newSubjectHover ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Center(
                    child: Text(
                      'Nuova materia',
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
            CustomFilterMenu<String>(
              hint: 'Tutte le aree',
              icon: Icons.category_outlined,
              value: _filterArea,
              menuWidth: 200,
              showClearIcon: true,
              onChanged: (value) => setState(() => _filterArea = value),
              onClear: () => setState(() => _filterArea = null),
              options: subjectAreas
                  .map((area) => FilterOption(value: area.value, label: area.label))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          subjects.length == 1
              ? '1 materia trovata'
              : '${subjects.length} materie trovate',
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

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 20),
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
                hintText: 'Es. Lingua e cultura latina',
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
                  onSelected: (selected) => setState(()
                  {
                    _selectedLevel = selected ? level.value : null;
                  }),
                );
              }).toList(),
            ),
            _buildFieldLabel('Aree (massimo $_maxAreas)'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: subjectAreas.map((area)
              {
                return CustomChip(
                  label: area.label,
                  isSelected: _selectedAreas.contains(area.value),
                  onSelected: (selected) => _onAreaChanged(area.value, selected),
                );
              }).toList(),
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
              fontSize: 16,
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSearchBar(
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
                          isSelected: _selectedAssociations.contains(subject.id),
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
                        ? 'Modifica Materia (${_currentStep + 1}/2)'
                        : 'Nuova Materia (${_currentStep + 1}/2)',
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
                      : (isLastStep ? (_isEditing ? 'SALVA MODIFICHE' : 'CREA MATERIA') : 'AVANTI'),
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