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

    result.sort((a, b) => switch (_sortBy)
    {
      SortCriterion.nameAsc => a.name.compareTo(b.name),
      SortCriterion.nameDesc => b.name.compareTo(a.name),
      SortCriterion.dateAsc => a.createdAt.compareTo(b.createdAt),
      SortCriterion.dateDesc => b.createdAt.compareTo(a.createdAt),
    });

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                hintText: 'Cerca disciplina...',
              ),
            ),
            const SizedBox(width: 24),
            AppGradientButton(
              label: 'NUOVA DISCIPLINA',
              icon: Icons.add_rounded,
              height: 50,
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
              ? '1 disciplina trovata'
              : '${subjects.length} discipline trovate',
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
                  return AssociationSubjectCard(
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
{
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _selectedArea;
  bool _isSaving = false;

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

  void _resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _descController.clear();
      _selectedArea = null;
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

  Future<void> _save() async
  {
    if (_isSaving)
    {
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Il nome non può essere vuoto.', isError: true);
      return;
    }

    if (_selectedArea == null)
    {
      CustomSnackBar.show(context: context, message: "Seleziona un'area di appartenenza.", isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.onSave(
      name,
      _selectedArea!,
      _descController.text.trim(),
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

  @override
  Widget build(BuildContext context)
  {
    return AppDialogShell(
      eyebrow: 'Disciplina interna',
      title: _isEditing ? 'Modifica disciplina' : 'Nuova disciplina',
      width: 540,
      maxHeight: MediaQuery.of(context).size.height * 0.85,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'ANNULLA',
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _closeDialog,
        ),
        primary: AppGradientButton(
          label: _isEditing ? 'SALVA' : 'CREA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _save,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Nome',
                hintText: 'Es. Grammatica latina',
                textCapitalization: TextCapitalization.sentences,
              ),
              _buildFieldLabel('Area'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: subjectAreas.map((area)
                {
                  return AppSelectableChip(
                    label: area.label,
                    selected: _selectedArea == area.value,
                    onSelected: (selected) => setState(()
                    {
                      _selectedArea = selected ? area.value : null;
                    }),
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
      ),
    );
  }
}
