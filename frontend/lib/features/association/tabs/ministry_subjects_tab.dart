import 'package:flutter/material.dart';
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
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
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

    return TabContent(
      header: [
        TabHeaderRow(
          search: AppSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchText = value),
            hintText: 'Cerca materia ministeriale...',
          ),
          action: AppGradientButton(
            label: 'NUOVA MATERIA',
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
      ],
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
{
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  static const int _maxAreas = 3;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _disciplineSearchController = TextEditingController();

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
  List<String> _selectedAreas = [];
  List<int> _selectedAssociations = [];

  bool get _isEditing => widget.existingSubject != null;

  @override
  void initState()
  {
    super.initState();

    // The arrow lights up as soon as the name is there: without listening to
    // the field it would stay dark until something else repainted the dialog.
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

  // Why the first step does not let one move on, where it does not. It returns
  // the reason instead of shouting it: the arrow goes dark and says so on hover,
  // so one knows before pressing and not after.
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

  bool _validateFirstStep()
  {
    final reason = _firstStepBlockedReason;

    if (reason != null)
    {
      CustomSnackBar.show(context: context, message: reason, isError: true);

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

    if (_selectedAssociations.isEmpty)
    {
      _goToStep(1);
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

  // Small, tracked and muted over what it names, the way the settings cards and
  // the dialogs of this app label a value.
  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: AppFieldLabel(text),
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
        // A ceiling rather than the whole of what is left: the phase is a
        // piece floating on the page now, and there is no fixed panel height
        // for it to take a share of. Past this the list scrolls inside it.
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
    return AppDialogStack(
      eyebrow: 'Passo ${_currentStep + 1} di 2',
      title: _isEditing ? 'Modifica materia' : 'Nuova materia',
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