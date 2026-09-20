import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart' show FilterOption;
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/study_program_item.dart';
import '../../association/models/subject_taxonomy.dart';
import '../models/person_item.dart';
import '../models/teacher_subject_item.dart';
import '../widgets/competence_picker.dart';
import '../widgets/program_scope_dialog.dart';
import '../widgets/teacher_competences_editor.dart';
import '../widgets/person_detail_widgets.dart';

const double _subjectCardWidth = 360;

const double _subjectCardGap = 16;
const double _subjectCardRadius = 30;

const double _subjectCardHeight = 96;

const int _subjectCardTitleLines = 2;
const double _subjectCardTitleHeight = 1.15;
const double _subjectCardDetailHeight = 1.25;

const double _confirmWidth = 480;

const String _updatedMessage = 'Discipline aggiornate con successo!';

enum _SubjectSort
{
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)');

  final String label;

  const _SubjectSort(this.label);
}

List<FilterOption<String>> _areaPillOptions()
{
  return [
    for (final area in subjectAreas)
      FilterOption(value: area.value, label: area.label),
    const FilterOption(value: kServicesFilterValue, label: 'Servizi'),
  ];
}

List<Map<String, dynamic>> _competencesOf(Iterable<TeacherSubjectItem> subjects)
{
  return [
    for (final subject in subjects)
      <String, dynamic>{
        'subject_id': subject.subjectId,
        'study_program_ids': subject.studyProgramIds,
      },
  ];
}

class PersonSubjectsTab extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  // Rendered above the filters and under the add button, inside the scroll.
  final Widget? intro;
  final Widget? footer;

  const PersonSubjectsTab({
    super.key,
    required this.person,
    required this.onUpdate,
    this.intro,
    this.footer,
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

  // The catalogue of programmes, read once the first edit asks for it.
  List<StudyProgramItem>? _programs;

  bool _isSaving = false;

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<TeacherSubjectItem> get _subjects => widget.person.teacherSubjects ?? const [];

  List<String> get _services => widget.person.teacherServices ?? const [];

  bool get _showingOnlyServices => _filterArea == kServicesFilterValue;

  List<TeacherSubjectItem> get _filteredSubjects
  {
    if (_showingOnlyServices)
    {
      return const [];
    }

    final query = _searchText.toLowerCase();

    return _subjects.where((subject)
    {
      final matchesArea = _filterArea == null || subject.subjectArea == _filterArea;

      return subject.subjectName.toLowerCase().contains(query) && matchesArea;
    }).toList();
  }

  List<String> get _filteredServices
  {
    if (_filterArea != null && !_showingOnlyServices)
    {
      return const [];
    }

    final query = _searchText.toLowerCase();

    return _services.where((service) => service.toLowerCase().contains(query)).toList();
  }

  bool get _hasAnything => _subjects.isNotEmpty || _services.isNotEmpty;

  Future<void> _save(List<Map<String, dynamic>> competences, List<String> services) async
  {
    if (_isSaving)
    {
      return;
    }

    setState(() => _isSaving = true);

    try
    {
      await ApiService().updateTeacherCompetences(
        widget.person.fiscalCode,
        competences,
        services,
        widget.person.teacherUpdatedAt,
      );

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: _updatedMessage, isError: false);
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
        setState(() => _isSaving = false);
      }
    }
  }

  void _removeSubject(TeacherSubjectItem subject)
  {
    _save(
      _competencesOf(_subjects.where((held) => held.subjectId != subject.subjectId)),
      _services,
    );
  }

  void _removeService(String service)
  {
    _save(
      _competencesOf(_subjects),
      _services.where((held) => held != service).toList(),
    );
  }

  void _rescopeSubject(TeacherSubjectItem subject, Set<int> programIds)
  {
    _save(
      [
        for (final held in _subjects)
          <String, dynamic>{
            'subject_id': held.subjectId,
            'study_program_ids': held.subjectId == subject.subjectId
                ? programIds.toList()
                : held.studyProgramIds,
          },
      ],
      _services,
    );
  }

  Future<List<StudyProgramItem>?> _programsTeaching(int subjectId) async
  {
    try
    {
      _programs ??= await ApiService().getStudyPrograms();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }

      return null;
    }

    return _programs!.where((program) => program.teaches(subjectId)).toList();
  }

  Future<void> _openScopeDialog(TeacherSubjectItem subject) async
  {
    final List<StudyProgramItem>? programs = await _programsTeaching(subject.subjectId);

    if (programs == null || !mounted)
    {
      return;
    }

    showBlurredDialog(
      context: context,
      barrierLabel: 'ProgramsSelection',
      builder: (context) => ProgramScopeDialog(
        subjectName: subject.subjectName,
        programs: programs,
        initialSelected: subject.studyProgramIds.toSet(),
        // Confirming with no programme left means giving up the discipline.
        onSave: (selected) => selected.isEmpty
            ? _removeSubject(subject)
            : _rescopeSubject(subject, selected),
      ),
    );
  }

  void _confirmRemoval({required TextSpan warning, required VoidCallback onConfirm})
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmCompetenceRemoval',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Rimozione',
        title: 'Confermi?',
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: kPersonDialogButtonHeight,
            fontSize: kPersonDialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: 'RIMUOVI',
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: kPersonDialogButtonHeight,
            fontSize: kPersonDialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              onConfirm();
            },
          ),
        ),
        children: [
          AppDialogPill(
            child: Text.rich(
              warning,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _warning(String before, String name, String after)
  {
    return TextSpan(
      children: [
        TextSpan(text: before),
        TextSpan(
          text: name,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: after),
      ],
    );
  }

  void _confirmRemoveSubject(TeacherSubjectItem subject)
  {
    _confirmRemoval(
      warning: _warning(
        'La disciplina ',
        subject.subjectName,
        ' verrà rimossa.',
      ),
      onConfirm: () => _removeSubject(subject),
    );
  }

  void _confirmRemoveService(String service)
  {
    _confirmRemoval(
      warning: _warning('Il servizio ', service, ' verrà rimosso da quelli seguiti.'),
      onConfirm: () => _removeService(service),
    );
  }

  List<Widget> _buildCards()
  {
    final entries = <({String name, Widget card})>[
      for (final subject in _filteredSubjects)
        (
          name: subject.subjectName,
          card: _CompetenceCard(
            title: subject.subjectName,
            subtitle: subject.studyPrograms.length == 1
                ? '1 percorso'
                : '${subject.studyPrograms.length} percorsi',
            onEdit: () => _openScopeDialog(subject),
            onRemove: () => _confirmRemoveSubject(subject),
          ),
        ),
      for (final service in _filteredServices)
        (
          name: service,
          card: _CompetenceCard(
            title: service,
            subtitle: 'Servizio',
            onRemove: () => _confirmRemoveService(service),
          ),
        ),
    ];

    entries.sort((a, b) => _sort == _SubjectSort.nameAsc
        ? a.name.compareTo(b.name)
        : b.name.compareTo(a.name));

    return entries.map((entry) => entry.card).toList();
  }

  void _openAddDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'AddSubjects',
      builder: (context) => _SubjectsAddDialog(
        person: widget.person,
        onUpdate: widget.onUpdate,
      ),
    );
  }

  Widget _buildAddButton()
  {
    return AppGradientButton(
      label: 'AGGIUNGI DISCIPLINE',
      icon: Icons.add_rounded,
      onPressed: _openAddDialog,
    );
  }

  Widget _buildEmptyState()
  {
    return PersonEmptyState(
      message: 'Nessuna disciplina o servizio a sistema.',
      action: _buildAddButton(),
    );
  }

  Widget _buildFilters()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          controller: _searchController,
          hintText: 'Cerca disciplina o servizio...',
          onChanged: (value) => setState(() => _searchText = value),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AppFilterPill<_SubjectSort>.setting(
              prefix: 'Ordina',
              hint: 'Ordina',
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 190,
              onChanged: (value) => setState(() => _sort = value),
              options: _SubjectSort.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            AppFilterPill<String>.filter(
              prefix: 'Area',
              hint: 'Tutte le aree',
              icon: Icons.category_rounded,
              value: _filterArea,
              menuWidth: 220,
              onChanged: (value) => setState(() => _filterArea = value),
              onClear: () => setState(() => _filterArea = null),
              options: _areaPillOptions(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (!_hasAnything)
    {
      final Widget? intro = widget.intro;
      final Widget? footer = widget.footer;

      if (intro == null && footer == null)
      {
        return _buildEmptyState();
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (intro != null)
                  PageTransitionItem(slot: PageTransitionItem.header, child: intro),
                _buildEmptyState(),
                if (footer != null) ...[
                  const SizedBox(height: 48),
                  footer,
                ],
              ],
            ),
          ),
        ),
      );
    }

    final cards = _buildCards();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1520),
          child: LayoutBuilder(
            builder: (context, constraints)
            {
              final columns = ((constraints.maxWidth + _subjectCardGap) /
                      (_subjectCardWidth + _subjectCardGap))
                  .floor();

              final int closing = cards.isEmpty
                  ? PageTransitionItem.list + 1
                  : PageTransitionItem.list + (cards.length - 1) ~/ columns + columns;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.header,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.intro != null) widget.intro!,
                        _buildFilters(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (cards.isEmpty)
                    PageTransitionItem(
                      slot: PageTransitionItem.list,
                      child: PersonEmptyState(
                        message: _showingOnlyServices
                            ? 'Nessun servizio trovato per questa ricerca.'
                            : 'Nessuna disciplina trovata per questa ricerca.',
                      ),
                    )
                  else
                    Wrap(
                      spacing: _subjectCardGap,
                      runSpacing: _subjectCardGap,
                      children: [
                        for (final card in cards)
                          PageTransitionItem.wave(child: card),
                      ],
                    ),
                  const SizedBox(height: 48),
                  PageTransitionItem(
                    slot: closing,
                    child: Center(child: _buildAddButton()),
                  ),
                  if (widget.footer != null) ...[
                    const SizedBox(height: 48),
                    widget.footer!,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompetenceCard extends StatefulWidget
{
  final String title;
  final String subtitle;

  // Services have no programmes to edit.
  final VoidCallback? onEdit;
  final VoidCallback onRemove;

  const _CompetenceCard({
    required this.title,
    required this.subtitle,
    this.onEdit,
    required this.onRemove,
  });

  @override
  State<_CompetenceCard> createState() => _CompetenceCardState();
}

class _CompetenceCardState extends State<_CompetenceCard>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: _subjectCardWidth,
        height: _subjectCardHeight,
        padding: const EdgeInsets.fromLTRB(22, 16, 14, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_subjectCardRadius),
          border: Border.all(
            color: _isHovering
                ? AppTheme.trialGold
                : AppTheme.trialGold.withValues(alpha: 0),
            width: 2,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OverflowTooltipText(
                    text: widget.title,
                    maxLines: _subjectCardTitleLines,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.trialOcean,
                      height: _subjectCardTitleHeight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.trialMutedText,
                      height: _subjectCardDetailHeight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (widget.onEdit != null)
              FadeHoverIconButton(
                icon: Icons.edit_outlined,
                color: AppTheme.trialTealDeep,
                hoverColor: AppTheme.trialGoldSurface,
                onTap: widget.onEdit!,
              ),
            FadeHoverIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.trialDanger,
              hoverColor: AppTheme.trialGoldSurface,
              onTap: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// Offers only competences not held yet; held ones are sent along unchanged.
class _SubjectsAddDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const _SubjectsAddDialog({required this.person, required this.onUpdate});

  @override
  State<_SubjectsAddDialog> createState() => _SubjectsAddDialogState();
}

class _SubjectsAddDialogState extends State<_SubjectsAddDialog>
{
  TeacherCompetencesDraft? _draft;

  bool _isSubmitting = false;

  Future<void> _submitForm() async
  {
    final TeacherCompetencesDraft? draft = _draft;

    if (draft == null || draft.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Seleziona almeno una disciplina o un servizio per salvare.',
        isError: true,
      );

      return;
    }

    setState(() => _isSubmitting = true);

    try
    {
      await ApiService().updateTeacherCompetences(
        widget.person.fiscalCode,
        [
          ..._competencesOf(widget.person.teacherSubjects ?? const []),
          ...draft.competences,
        ],
        [...widget.person.teacherServices ?? const <String>[], ...draft.services],
        widget.person.teacherUpdatedAt,
      );

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: _updatedMessage, isError: false);

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

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Discipline',
      title: 'Aggiungi discipline',
      maxWidth: 860,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'CONFERMA',
          icon: Icons.check_rounded,
          busy: _isSubmitting,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _submitForm,
        ),
      ),
      children: [
        TeacherCompetencesEditor(
          person: widget.person,
          onlyNew: true,
          onChanged: (draft) => _draft = draft,
          builder: (context, filters, list) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDialogPiece(
                index: 1,
                named: false,
                child: AppDialogPill(expand: true, child: filters),
              ),
              const SizedBox(height: 26),
              Flexible(
                child: AppDialogPiece(
                  index: 2,
                  named: false,
                  child: AppDialogPill(expand: true, child: list),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
