import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../shared/widgets/wizard_dialog.dart';
import '../models/course_item.dart';
import '../widgets/course_card.dart';

typedef CourseWriter = Future<bool> Function(
  String name,
  String cost,
  String description,
  Function(String) onError,
);

typedef CourseEditor = Future<bool> Function(
  String originalName,
  String name,
  String cost,
  String description,
  Function(String) onError,
);

class CoursesTab extends StatefulWidget
{
  final List<CourseItem> courses;
  final CourseWriter onCreate;
  final CourseEditor onEdit;
  final void Function(CourseItem item) onDelete;

  const CoursesTab({
    super.key,
    required this.courses,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  SortCriterion _sortBy = SortCriterion.nameAsc;

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<CourseItem> get _filteredCourses
  {
    final query = _searchText.toLowerCase();

    final result = widget.courses
        .where((course) => course.name.toLowerCase().contains(query))
        .toList();

    sortByCriterion(
      result,
      _sortBy,
      name: (item) => item.name,
      createdAt: (item) => item.createdAt,
    );

    return result;
  }

  void _showWizard({CourseItem? course, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'CourseWizard',
      builder: (context) => _CourseWizardDialog(
        existingCourse: course,
        onCancelEdit: onCancelEdit,
        onSave: (name, cost, description, onError) async
        {
          if (course == null)
          {
            return await widget.onCreate(name, cost, description, onError);
          }

          return await widget.onEdit(course.name, name, cost, description, onError);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final courses = _filteredCourses;

    return TabContent(
      header: entityTabHeader(
        searchController: _searchController,
        onSearchChanged: (value) => setState(() => _searchText = value),
        searchHint: 'Cerca corso...',
        actionLabel: 'NUOVO CORSO',
        onAction: () => _showWizard(),
        sort: _sortBy,
        onSortChanged: (value) => setState(() => _sortBy = value),
        countLabel: courses.length == 1
            ? '1 corso trovato'
            : '${courses.length} corsi trovati',
      ),
      body: EntityCardGrid(
        children: courses.map((course)
        {
          return CourseCard(
            course: course,
            onEditRequested: (onCancel) => _showWizard(course: course, onCancelEdit: onCancel),
            onDelete: () => widget.onDelete(course),
          );
        }).toList(),
      ),
    );
  }
}

class _CourseWizardDialog extends StatefulWidget
{
  final CourseItem? existingCourse;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String name, String cost, String description, Function(String) onError) onSave;

  const _CourseWizardDialog({
    this.existingCourse,
    this.onCancelEdit,
    required this.onSave,
  });

  @override
  State<_CourseWizardDialog> createState() => _CourseWizardDialogState();
}

class _CourseWizardDialogState extends State<_CourseWizardDialog>
    with WizardDialogState
{
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  bool get isEditing => widget.existingCourse != null;

  @override
  VoidCallback? get onCancelEdit => widget.onCancelEdit;

  @override
  void initState()
  {
    super.initState();

    final course = widget.existingCourse;

    if (course != null)
    {
      _nameController.text = course.name;
      _costController.text = course.cost ?? '';
      _descController.text = course.description ?? '';
    }
  }

  @override
  void dispose()
  {
    _nameController.dispose();
    _costController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  void resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _costController.clear();
      _descController.clear();
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

    await runSave(
      (onError) => widget.onSave(
        name,
        _costController.text.trim(),
        _descController.text.trim(),
        onError,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return buildSingleStepDialog(
      eyebrow: 'Corso',
      title: isEditing ? 'Modifica corso' : 'Nuovo corso',
      onSubmit: _save,
      fields: [
        AppTextField(
          controller: _nameController,
          label: 'Nome',
          hintText: 'Es. Yoga',
          maxLength: FieldLimits.name,
          textCapitalization: TextCapitalization.sentences,
          nothingAbove: true,
        ),
        AppTextField(
          controller: _costController,
          label: 'Costo',
          hintText: 'Es. 45€ al mese',
          maxLength: FieldLimits.cost,
        ),
        DescriptionField(_descController),
      ],
    );
  }
}
