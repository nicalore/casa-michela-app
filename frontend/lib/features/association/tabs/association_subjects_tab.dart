import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../shared/widgets/wizard_dialog.dart';
import '../models/association_subject_item.dart';
import '../models/subject_taxonomy.dart';
import '../widgets/association_subject_card.dart';

class AssociationSubjectsTab extends StatefulWidget
{
  final List<AssociationSubjectItem> associationSubjects;
  final Future<bool> Function(String name, String area, String description, Function(String) onError) onCreate;
  final Future<bool> Function(int id, String name, String area, String description, Function(String) onError) onEdit;
  final void Function(AssociationSubjectItem item) onDelete;

  const AssociationSubjectsTab({
    super.key,
    required this.associationSubjects,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<AssociationSubjectsTab> createState() => _AssociationSubjectsTabState();
}

class _AssociationSubjectsTabState extends State<AssociationSubjectsTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  SortCriterion _sortBy = SortCriterion.nameAsc;
  String? _filterArea;

  List<AssociationSubjectItem> get _filteredSubjects
  {
    final query = _searchText.toLowerCase();

    final result = widget.associationSubjects.where((subject)
    {
      final matchesSearch = subject.name.toLowerCase().contains(query);
      final matchesArea = _filterArea == null || subject.area == _filterArea;

      return matchesSearch && matchesArea;
    }).toList();

    sortByCriterion(
      result,
      _sortBy,
      name: (item) => item.name,
      createdAt: (item) => item.createdAt,
    );

    return result;
  }

  void _showWizard({AssociationSubjectItem? subject, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectWizard',
      builder: (context) => _AssociationSubjectWizardDialog(
        existingSubject: subject,
        onCancelEdit: onCancelEdit,
        onSave: (name, area, description, onError) async
        {
          if (subject == null)
          {
            return await widget.onCreate(name, area, description, onError);
          }

          return await widget.onEdit(subject.id, name, area, description, onError);
        },
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
        searchHint: 'Cerca disciplina...',
        actionLabel: 'NUOVA DISCIPLINA',
        onAction: () => _showWizard(),
        sort: _sortBy,
        onSortChanged: (value) => setState(() => _sortBy = value),
        countLabel: subjects.length == 1
            ? '1 disciplina trovata'
            : '${subjects.length} discipline trovate',
        filters: [
          const FilterGroupDivider(),
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
      body: EntityCardGrid(
        children: subjects.map((subject)
        {
          return AssociationSubjectCard(
            subject: subject,
            onEditRequested: (onCancel) => _showWizard(subject: subject, onCancelEdit: onCancel),
            onDelete: () => widget.onDelete(subject),
          );
        }).toList(),
      ),
    );
  }
}

class _AssociationSubjectWizardDialog extends StatefulWidget
{
  final AssociationSubjectItem? existingSubject;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String name, String area, String description, Function(String) onError) onSave;

  const _AssociationSubjectWizardDialog({
    this.existingSubject,
    this.onCancelEdit,
    required this.onSave,
  });

  @override
  State<_AssociationSubjectWizardDialog> createState() => _AssociationSubjectWizardDialogState();
}

class _AssociationSubjectWizardDialogState extends State<_AssociationSubjectWizardDialog>
    with WizardDialogState
{
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _selectedArea;

  @override
  bool get isEditing => widget.existingSubject != null;

  @override
  VoidCallback? get onCancelEdit => widget.onCancelEdit;

  @override
  void initState()
  {
    super.initState();

    final subject = widget.existingSubject;

    if (subject != null)
    {
      _nameController.text = subject.name;
      _descController.text = subject.description ?? '';
      _selectedArea = subject.area;
    }
  }

  @override
  void dispose()
  {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  void resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _descController.clear();
      _selectedArea = null;
    });
  }

  Future<void> _save() async
  {
    if (isSaving)
    {
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty)
    {
      showError('Il nome non può essere vuoto.');

      return;
    }

    final area = _selectedArea;

    if (area == null)
    {
      showError("Seleziona un'area di appartenenza.");

      return;
    }

    await runSave(
      (onError) => widget.onSave(
        name,
        area,
        _descController.text.trim(),
        onError,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return buildSingleStepDialog(
      eyebrow: 'Disciplina interna',
      title: isEditing ? 'Modifica disciplina' : 'Nuova disciplina',
      onSubmit: _save,
      fields: [
        AppTextField(
          controller: _nameController,
          label: 'Nome',
          hintText: 'Es. Grammatica latina',
          maxLength: FieldLimits.name,
          textCapitalization: TextCapitalization.sentences,
          nothingAbove: true,
        ),
        const WizardFieldLabel('Area'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: subjectAreas.map((area)
          {
            return AppSelectableChip(
              label: area.compactLabel,
              selected: _selectedArea == area.value,
              onSelected: (selected) => setState(()
              {
                _selectedArea = selected ? area.value : null;
              }),
            );
          }).toList(),
        ),
        DescriptionField(_descController),
      ],
    );
  }
}
