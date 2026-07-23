import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/study_program_item.dart';
import '../../association/models/subject_taxonomy.dart';
import '../models/person_item.dart';
import '../models/teacher_subject_item.dart';
import '../person_wizard_components.dart';

const Color _chipBackground = Color(0xFFF5F7FA);
const Color _strongTextColor = Color(0xFF2A2A2A);
const Color _dialogBackground = Color(0xFFF4F7F9);

const double _dialogRadius = 40;

enum _SubjectSort
{
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)');

  final String label;

  const _SubjectSort(this.label);

  int compare(TeacherSubjectItem a, TeacherSubjectItem b)
  {
    return this == _SubjectSort.nameAsc
        ? a.subjectName.compareTo(b.subjectName)
        : b.subjectName.compareTo(a.subjectName);
  }
}

enum _CatalogSort
{
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  dateDesc('Più recente'),
  dateAsc('Meno recente');

  final String label;

  const _CatalogSort(this.label);

  int compare(AssociationSubjectItem a, AssociationSubjectItem b)
  {
    return switch (this)
    {
      _CatalogSort.nameAsc => a.name.compareTo(b.name),
      _CatalogSort.nameDesc => b.name.compareTo(a.name),
      _CatalogSort.dateDesc => b.createdAt.compareTo(a.createdAt),
      _CatalogSort.dateAsc => a.createdAt.compareTo(b.createdAt),
    };
  }
}

List<WizardFilterOption<String>> _areaFilterOptions()
{
  return subjectAreas
      .map((area) => WizardFilterOption(value: area.value, label: area.label))
      .toList();
}

class PersonSubjectsTab extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const PersonSubjectsTab({
    super.key,
    required this.person,
    required this.onUpdate,
  });

  @override
  State<PersonSubjectsTab> createState() => _PersonSubjectsTabState();
}

class _PersonSubjectsTabState extends State<PersonSubjectsTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  _SubjectSort _sort = _SubjectSort.nameAsc;
  String? _filterArea;

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<TeacherSubjectItem> get _filteredSubjects
  {
    final query = _searchText.toLowerCase();

    final result = (widget.person.teacherSubjects ?? []).where((subject)
    {
      final matchesArea = _filterArea == null || subject.subjectArea == _filterArea;

      return subject.subjectName.toLowerCase().contains(query) && matchesArea;
    }).toList();

    result.sort(_sort.compare);

    return result;
  }

  void _openEditDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'EditSubjects',
      builder: (context) => _SubjectsEditDialog(
        person: widget.person,
        onUpdate: widget.onUpdate,
      ),
    );
  }

  void _openProgramsDialog(TeacherSubjectItem subject)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'ViewPrograms',
      builder: (context) => _ReadOnlyProgramsDialog(subject: subject),
    );
  }

  Widget _buildEditButton({required double width})
  {
    return SizedBox(
      width: width,
      child: WizardAnimatedActionButton(
        text: 'MODIFICA DISCIPLINE',
        icon: Icons.edit_rounded,
        baseColor: AppTheme.primary,
        hoverColor: AppTheme.primaryHover,
        onPressed: _openEditDialog,
      ),
    );
  }

  Widget _buildMessage(String text)
  {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.slate500,
        ),
      ),
    );
  }

  Widget _buildEmptyState()
  {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMessage('Nessuna disciplina insegnata a sistema.'),
            const SizedBox(height: 24),
            _buildEditButton(width: 280),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters()
  {
    return _ResponsiveSearchFilterRow(
      breakpoint: 650,
      searchBar: WizardAnimatedSearchBar(
        controller: _searchController,
        hintText: 'Cerca disciplina...',
        onChanged: (value) => setState(() => _searchText = value),
      ),
      filterWidgets: [
        WizardFilterMenu<_SubjectSort>(
          hint: 'Ordina per',
          icon: Icons.sort_rounded,
          value: _sort,
          menuWidth: 180,
          showClearIcon: false,
          onClear: () {},
          onChanged: (value) => setState(() => _sort = value),
          options: _SubjectSort.values
              .map((sort) => WizardFilterOption(value: sort, label: sort.label))
              .toList(),
        ),
        WizardFilterMenu<String>(
          hint: 'Tutte le aree',
          icon: Icons.category_outlined,
          value: _filterArea,
          menuWidth: 200,
          showClearIcon: true,
          onChanged: (value) => setState(() => _filterArea = value),
          onClear: () => setState(() => _filterArea = null),
          options: _areaFilterOptions(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if ((widget.person.teacherSubjects ?? []).isEmpty)
    {
      return _buildEmptyState();
    }

    final subjects = _filteredSubjects;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilters(),
              const SizedBox(height: 24),
              if (subjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: _buildMessage('Nessuna disciplina trovata per questa ricerca.'),
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: subjects
                      .map((subject) => _SubjectReadOnlyCard(
                            subject: subject,
                            onTap: () => _openProgramsDialog(subject),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 48),
              Center(child: _buildEditButton(width: 320)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectReadOnlyCard extends StatefulWidget
{
  final TeacherSubjectItem subject;
  final VoidCallback onTap;

  const _SubjectReadOnlyCard({required this.subject, required this.onTap});

  @override
  State<_SubjectReadOnlyCard> createState() => _SubjectReadOnlyCardState();
}

class _SubjectReadOnlyCardState extends State<_SubjectReadOnlyCard>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    final count = widget.subject.studyProgramIds.length;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 360,
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovering ? AppTheme.primary : AppTheme.slate200,
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              const Icon(Icons.subject_rounded, size: 32, color: AppTheme.hint),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OverflowTooltipText(
                      text: widget.subject.subjectName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _strongTextColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 1 ? '1 percorso' : '$count percorsi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyProgramsDialog extends StatelessWidget
{
  final TeacherSubjectItem subject;

  const _ReadOnlyProgramsDialog({required this.subject});

  Widget _buildProgramChip(String name)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.border, width: 1.0),
      ),
      child: Text(
        name,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.slate500,
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
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subject.subjectName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
              child: Text(
                'Percorsi assegnati',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: subject.studyPrograms.map(_buildProgramChip).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectsEditDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const _SubjectsEditDialog({required this.person, required this.onUpdate});

  @override
  State<_SubjectsEditDialog> createState() => _SubjectsEditDialogState();
}

class _SubjectsEditDialogState extends State<_SubjectsEditDialog>
{
  static const double _contentMaxWidth = 1140;

  final TextEditingController _searchController = TextEditingController();

  // Which disciplines the teacher covers, and with which study programs. Kept as
  // two maps because a discipline can be switched off while keeping the programs
  // that were picked for it, until the dialog is closed.
  final Map<int, bool> _isSubjectSelected = {};
  final Map<int, Set<int>> _programsBySubject = {};

  // Programs linked to each discipline, computed once after loading instead of on
  // every rebuild: the lookup walks every program and all its nested subjects.
  final Map<int, List<StudyProgramItem>> _programsBySubjectId = {};

  bool _isLoadingData = true;
  bool _isSubmitting = false;

  List<AssociationSubjectItem> _allSubjects = [];
  List<StudyProgramItem> _allPrograms = [];

  String _searchText = '';
  _CatalogSort _sort = _CatalogSort.nameAsc;
  String? _filterArea;

  @override
  void initState()
  {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  // A program teaches a discipline when one of its ministry subjects lists it.
  // The nested disciplines come with the study programs payload: if the backend
  // stopped including them, every discipline would look unteachable and the grid
  // would come out empty.
  List<StudyProgramItem> _findProgramsFor(AssociationSubjectItem subject)
  {
    return _allPrograms
        .where((program) => program.ministrySubjects.any(
              (ministry) =>
                  ministry.associationSubjects.any((assoc) => assoc.id == subject.id),
            ))
        .toList();
  }

  Future<void> _loadAllData() async
  {
    try
    {
      final results = await Future.wait([
        ApiService().getAssociationSubjects(),
        ApiService().getStudyPrograms(),
      ]);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _allSubjects = results[0] as List<AssociationSubjectItem>;
        _allPrograms = results[1] as List<StudyProgramItem>;

        for (final subject in _allSubjects)
        {
          _programsBySubjectId[subject.id] = _findProgramsFor(subject);
        }

        for (final competence in widget.person.teacherSubjects ?? <TeacherSubjectItem>[])
        {
          _isSubjectSelected[competence.subjectId] = true;
          _programsBySubject[competence.subjectId] = competence.studyProgramIds.toSet();
        }

        _isLoadingData = false;
      });
    }
    catch (_)
    {
      if (mounted)
      {
        setState(() => _isLoadingData = false);
      }
    }
  }

  // Disciplines nobody can teach are hidden: without a program to attach them to
  // they cannot be assigned.
  List<AssociationSubjectItem> get _filteredSubjects
  {
    final query = _searchText.toLowerCase();

    final result = _allSubjects.where((subject)
    {
      if ((_programsBySubjectId[subject.id] ?? const []).isEmpty)
      {
        return false;
      }

      final matchesArea = _filterArea == null || subject.area == _filterArea;

      return subject.name.toLowerCase().contains(query) && matchesArea;
    }).toList();

    result.sort(_sort.compare);

    return result;
  }

  void _openProgramsDialog(AssociationSubjectItem subject)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'ProgramsSelection',
      builder: (context) => WizardProgramsSelectionDialog(
        subject: subject,
        programs: _programsBySubjectId[subject.id] ?? const [],
        initialSelected: _programsBySubject[subject.id] ?? {},
        // Confirming with no program selected means giving the discipline up.
        onSave: (selected) => setState(()
        {
          if (selected.isEmpty)
          {
            _deselectSubject(subject.id);
          }
          else
          {
            _isSubjectSelected[subject.id] = true;
            _programsBySubject[subject.id] = selected;
          }
        }),
        // Cancelling leaves an already assigned discipline untouched, and cleans
        // up one that was only being explored.
        onCancel: () => setState(()
        {
          if (!(_isSubjectSelected[subject.id] ?? false))
          {
            _deselectSubject(subject.id);
          }
        }),
      ),
    );
  }

  void _deselectSubject(int subjectId)
  {
    _isSubjectSelected[subjectId] = false;
    _programsBySubject.remove(subjectId);
  }

  Future<void> _submitForm() async
  {
    if (!_isSubjectSelected.values.any((isSelected) => isSelected))
    {
      CustomSnackBar.show(
        context: context,
        message: 'Seleziona almeno una disciplina per salvare.',
        isError: true,
      );

      return;
    }

    setState(() => _isSubmitting = true);

    try
    {
      final competences = _isSubjectSelected.entries
          .where((entry) => entry.value)
          .map((entry) => <String, dynamic>{
                'subject_id': entry.key,
                'study_program_ids': _programsBySubject[entry.key]?.toList() ?? [],
              })
          .toList();

      // teacherUpdatedAt is the optimistic concurrency token for the teacher
      // aggregate: the server refuses the update if it has changed meanwhile.
      await ApiService().updateTeacherCompetences(
        widget.person.fiscalCode,
        competences,
        widget.person.teacherUpdatedAt,
      );

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Discipline aggiornate con successo!',
          isError: false,
        );

        Navigator.of(context).pop();
        widget.onUpdate();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildDialogGlow({required bool topRight})
  {
    return Positioned(
      right: topRight ? -400 : null,
      top: topRight ? -400 : null,
      left: topRight ? null : -400,
      bottom: topRight ? null : -400,
      child: const IgnorePointer(
        child: SizedBox(
          width: 800,
          height: 800,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x22003C82), Color(0x00003C82)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters()
  {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: _ResponsiveSearchFilterRow(
          breakpoint: 650,
          searchBar: WizardAnimatedSearchBar(
            controller: _searchController,
            hintText: 'Cerca disciplina...',
            onChanged: (value) => setState(() => _searchText = value),
          ),
          filterWidgets: [
            WizardFilterMenu<_CatalogSort>(
              hint: 'Ordina per',
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 180,
              showClearIcon: false,
              onClear: () {},
              onChanged: (value) => setState(() => _sort = value),
              options: _CatalogSort.values
                  .map((sort) => WizardFilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            WizardFilterMenu<String>(
              hint: 'Tutte le aree',
              icon: Icons.category_outlined,
              value: _filterArea,
              menuWidth: 200,
              showClearIcon: true,
              onChanged: (value) => setState(() => _filterArea = value),
              onClear: () => setState(() => _filterArea = null),
              options: _areaFilterOptions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsGrid(List<AssociationSubjectItem> subjects)
  {
    if (subjects.isEmpty)
    {
      return Center(
        child: Text(
          'Nessuna disciplina trovata per questa ricerca.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.slate500,
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: subjects.map((subject)
          {
            return WizardSubjectGridCard(
              subject: subject,
              isSelected: _isSubjectSelected[subject.id] ?? false,
              selectedCount: (_programsBySubject[subject.id] ?? const {}).length,
              onTap: () => _openProgramsDialog(subject),
              onRemove: () => setState(() => _deselectSubject(subject.id)),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final subjects = _filteredSubjects;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration: BoxDecoration(
          color: _dialogBackground,
          borderRadius: BorderRadius.circular(_dialogRadius),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_dialogRadius),
          child: Stack(
            children: [
              _buildDialogGlow(topRight: true),
              _buildDialogGlow(topRight: false),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Modifica Discipline',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: AppTheme.slate200),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: _buildFilters(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingData
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.primary),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            child: _buildSubjectsGrid(subjects),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: ResponsiveDialogButtonsRow(
                      secondaryButton: WizardAnimatedActionButton(
                        text: 'ANNULLA',
                        icon: Icons.close_rounded,
                        baseColor: AppTheme.danger,
                        hoverColor: AppTheme.dangerHover,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      primaryButton: WizardAnimatedActionButton(
                        text: _isSubmitting ? 'SALVATAGGIO...' : 'CONFERMA',
                        icon: Icons.check_circle_outline,
                        baseColor: AppTheme.primary,
                        hoverColor: AppTheme.primaryHover,
                        onPressed: _isSubmitting ? () {} : _submitForm,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Search bar and filters on one row while there is room, stacked below the
// threshold rather than always split.
class _ResponsiveSearchFilterRow extends StatelessWidget
{
  static const double _spacing = 12;

  final Widget searchBar;
  final List<Widget> filterWidgets;
  final double breakpoint;

  const _ResponsiveSearchFilterRow({
    required this.searchBar,
    required this.filterWidgets,
    this.breakpoint = 700,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < breakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchBar,
              const SizedBox(height: _spacing),
              Wrap(spacing: _spacing, runSpacing: _spacing, children: filterWidgets),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBar),
            for (final filter in filterWidgets) ...[
              const SizedBox(width: _spacing),
              filter,
            ],
          ],
        );
      },
    );
  }
}