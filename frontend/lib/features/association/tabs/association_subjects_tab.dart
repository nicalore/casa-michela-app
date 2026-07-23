import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/shared_components.dart';
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
  bool _newSubjectHover = false;

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
              child: AnimatedSearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                hintText: 'Cerca disciplina...',
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
                      'Nuova disciplina',
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
              ? '1 disciplina trovata'
              : '${subjects.length} discipline trovate',
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

  @override
  Widget build(BuildContext context)
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Modifica Disciplina' : 'Nuova Disciplina',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
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
            const Divider(height: 32, thickness: 1, color: AppTheme.divider),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
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
                          hintText: 'Es. Grammatica latina',
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
                      const SizedBox(height: 16),
                      _buildFieldLabel('Area'),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: subjectAreas.map((area)
                        {
                          return CustomChip(
                            label: area.label,
                            isSelected: _selectedArea == area.value,
                            onSelected: (selected) => setState(()
                            {
                              _selectedArea = selected ? area.value : null;
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 24),
              child: ResponsiveDialogButtonsRow(
                secondaryButton: AnimatedActionButton(
                  text: 'ANNULLA',
                  icon: Icons.cancel_outlined,
                  baseColor: AppTheme.danger,
                  hoverColor: AppTheme.dangerHover,
                  onPressed: _closeDialog,
                ),
                primaryButton: AnimatedActionButton(
                  text: _isSaving ? 'SALVATAGGIO...' : (_isEditing ? 'SALVA MODIFICHE' : 'CREA'),
                  icon: Icons.check_circle_outline,
                  baseColor: AppTheme.primary,
                  hoverColor: AppTheme.primaryHover,
                  onPressed: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}