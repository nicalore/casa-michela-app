import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart' show FilterOption;
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../../association/models/subject_taxonomy.dart';
import '../models/person_item.dart';
import '../models/teacher_subject_item.dart';
import '../widgets/competence_picker.dart';
import '../widgets/person_detail_widgets.dart';

// The card a discipline is shown on: the width every entity card of the app is
// drawn at, and the gold outline they all take under the pointer.
const double _subjectCardWidth = 360;

// What sits between two of them, along the row and between the rows. It is also
// what says how many fit across, and so which beat each card leaves on.
const double _subjectCardGap = 16;
const double _subjectCardRadius = 30;

// The name gets two lines, since a discipline is commonly named in more words
// than one line of a card holds; the line under it gets one. Both line heights
// are spelled out below rather than left to the font, so the height here is the
// sum of its parts and not a figure somebody measured once:
//
//   2 x 17 x 1.15  the name           39.10
//   4              the gap between     4.00
//   1 x 13 x 1.25  the line under it  16.25
//   2 x 16         the padding        32.00
//   2 x 2          the border          4.00
//                                     -----
//                                     95.35
const double _subjectCardHeight = 96;

// What a name may take before it is cut. It is cut with an ellipsis and said in
// full under the pointer, which is the price of every card being the same
// height.
const int _subjectCardTitleLines = 2;
const double _subjectCardTitleHeight = 1.15;
const double _subjectCardDetailHeight = 1.25;

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

List<FilterOption<String>> _areaPillOptions()
{
  return [
    for (final area in subjectAreas)
      FilterOption(value: area.value, label: area.label),
    // Last, and under the three areas: the services are not a fourth area,
    // they are the other thing a teacher can take on.
    const FilterOption(value: kServicesFilterValue, label: 'Servizi'),
  ];
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

  bool get _showingOnlyServices => _filterArea == kServicesFilterValue;

  List<TeacherSubjectItem> get _filteredSubjects
  {
    if (_showingOnlyServices)
    {
      return const [];
    }

    final query = _searchText.toLowerCase();

    final result = (widget.person.teacherSubjects ?? []).where((subject)
    {
      final matchesArea = _filterArea == null || subject.subjectArea == _filterArea;

      return subject.subjectName.toLowerCase().contains(query) && matchesArea;
    }).toList();

    result.sort(_sort.compare);

    return result;
  }

  // A service has no area, so asking for a real one leaves it out.
  List<String> get _filteredServices
  {
    if (_filterArea != null && !_showingOnlyServices)
    {
      return const [];
    }

    final query = _searchText.toLowerCase();

    return (widget.person.teacherServices ?? const <String>[])
        .where((service) => service.toLowerCase().contains(query))
        .toList();
  }

  bool get _hasAnything =>
      (widget.person.teacherSubjects ?? const []).isNotEmpty ||
      (widget.person.teacherServices ?? const []).isNotEmpty;

  // Disciplines and services in a single list, sorted together as the pill
  // says: whoever reads the page is looking at what the teacher can take on, not
  // at two separate lists.
  List<Widget> _buildCards()
  {
    final entries = <({String name, Widget card})>[
      for (final subject in _filteredSubjects)
        (
          name: subject.subjectName,
          card: _ReadOnlyCard(
            title: subject.subjectName,
            subtitle: subject.studyPrograms.length == 1
                ? '1 percorso'
                : '${subject.studyPrograms.length} percorsi',
            onTap: () => _openProgramsDialog(subject),
          ),
        ),
      for (final service in _filteredServices)
        (
          name: service,
          // No onTap: a service has no programmes to open, and a card lighting
          // up under the pointer without doing anything promises a dialog that
          // is not there.
          card: _ReadOnlyCard(
            title: service,
            subtitle: 'Servizio',
          ),
        ),
    ];

    entries.sort((a, b) => _sort == _SubjectSort.nameAsc
        ? a.name.compareTo(b.name)
        : b.name.compareTo(a.name));

    return entries.map((entry) => entry.card).toList();
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

  Widget _buildEditButton()
  {
    return AppGradientButton(
      label: 'MODIFICA DISCIPLINE',
      icon: Icons.edit_rounded,
      onPressed: _openEditDialog,
    );
  }

  Widget _buildEmptyState()
  {
    return PersonEmptyState(
      message: 'Nessuna disciplina o servizio a sistema.',
      action: _buildEditButton(),
    );
  }

  // The head of the list, as on every other list of the app: the field that
  // shortens it, then the pills that narrow it.
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
      return _buildEmptyState();
    }

    final cards = _buildCards();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1520),
          // Laid out by hand rather than by [pageTransitionBlocks], which gives
          // one beat to each block it is handed: the grid went in as a single
          // block, so a teacher's disciplines all left and came back together
          // while the rest of the page walked. The cards carry their own beats
          // here, and the button below waits for the last of them.
          child: LayoutBuilder(
            builder: (context, constraints)
            {
              final columns = ((constraints.maxWidth + _subjectCardGap) /
                      (_subjectCardWidth + _subjectCardGap))
                  .floor();

              // One past the last card, whichever row it fell on, so what closes
              // the page arrives behind the grid and not in the middle of it.
              final int closing = cards.isEmpty
                  ? PageTransitionItem.list + 1
                  : PageTransitionItem.list + (cards.length - 1) ~/ columns + columns;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.header,
                    child: _buildFilters(),
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
                        for (var i = 0; i < cards.length; i++)
                          PageTransitionItem(
                            slot: PageTransitionItem.gridSlot(i, columns),
                            child: cards[i],
                          ),
                      ],
                    ),
                  const SizedBox(height: 48),
                  PageTransitionItem(
                    slot: closing,
                    child: Center(child: _buildEditButton()),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// The name and what is said about it, and nothing else.
//
// There used to be a glyph in a circle: the same one for every discipline and
// the same for every service, so it told no card from another — it said
// "discipline" beside a line already saying how many programmes there are. It
// took half the card's width and held the other half's height.
class _ReadOnlyCard extends StatefulWidget
{
  final String title;
  final String subtitle;

  // What pressing it opens, where there is something to open. Null on a
  // service: it has no programmes, and the card does not light up under the
  // pointer, because gold in this app means "this can be pressed".
  final VoidCallback? onTap;

  const _ReadOnlyCard({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  State<_ReadOnlyCard> createState() => _ReadOnlyCardState();
}

class _ReadOnlyCardState extends State<_ReadOnlyCard>
{
  bool _isHovering = false;

  bool get _isPressable => widget.onTap != null;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: _isPressable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovering = _isPressable),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: _subjectCardWidth,
          // A height and not a minimum. A minimum only lines up the cards whose
          // names take the same number of lines: a name that wrapped to a second
          // one pushed its own card taller than the ones beside it, and the row
          // came out ragged. Every card of a grid in this app is a fixed height
          // for that reason.
          height: _subjectCardHeight,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_subjectCardRadius),
            // Gold under the pointer, the mark every card of the app takes.
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
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
      ),
    );
  }
}

// Where a discipline is taught, opened from its card. Read-only: the same list
// as the dialog that picks them, without the ticks.
//
// The programmes sit under their level and their sector, and the row carries
// only the name, which is the part that tells them apart — rather than a wall of
// chips each holding a programme's full name.
class _ReadOnlyProgramsDialog extends StatelessWidget
{
  final TeacherSubjectItem subject;

  const _ReadOnlyProgramsDialog({required this.subject});

  // In the order the first programme of each group turns up, so a list read
  // twice reads the same.
  Map<String, List<TeacherProgramItem>> get _groups
  {
    final groups = <String, List<TeacherProgramItem>>{};

    for (final program in subject.studyPrograms)
    {
      final String title = programScopeTitle(
        level: program.level,
        sector: program.sector,
      );

      groups.putIfAbsent(title, () => []).add(program);
    }

    return groups;
  }

  Widget _buildGroup(String title, List<TeacherProgramItem> group)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: AppEyebrow(title)),
              Text(
                '${group.length}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ],
          ),
        ),
        for (final program in group) _ProgramLine(label: program.name),
        const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final int total = subject.studyPrograms.length;
    final groups = _groups;

    final String? description = subject.subjectDescription?.trim();

    return AppDialogStack(
      eyebrow: 'Percorsi assegnati',
      title: subject.subjectName,
      maxWidth: 720,
      fillLast: true,
      children: [
        // What the discipline is, before where it is taught: the name is in
        // the pill above and says no more than what it is called. Where nobody
        // wrote it the pill is absent, rather than opening on an empty line.
        if (description != null && description.isNotEmpty)
          AppDialogPill(
            expand: true,
            child: SelectionArea(
              child: Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ),
          ),
        // How many and which, in a single pill: the count is the title of the
        // list under it, and split from it was a one-line pill saying something
        // incomplete. The count stays put while the list scrolls.
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  total == 1 ? '1 percorso' : '$total percorsi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
              ),
              if (groups.isEmpty)
                const PersonEmptyState(
                  message: 'Nessun percorso assegnato a questa disciplina.',
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in groups.entries)
                          _buildGroup(entry.key, entry.value),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// A programme, to read and nothing else: the dot in place of the tick says
// there is nothing to press here.
class _ProgramLine extends StatelessWidget
{
  final String label;

  const _ProgramLine({required this.label});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: 12),
            decoration: const BoxDecoration(
              gradient: AppTheme.brandGradient,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
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
  // Which disciplines the teacher covers, and with which study programs. Kept as
  // two maps because a discipline can be switched off while keeping the programs
  // that were picked for it, until the dialog is closed.
  final Map<int, bool> _isSubjectSelected = {};
  final Map<int, Set<int>> _programsBySubject = {};

  // The services the teacher takes on, by name: they have no programmes to
  // narrow down.
  final Set<String> _selectedServices = {};

  // Programs linked to each discipline, computed once after loading instead of on
  // every rebuild: the lookup walks every program and all its nested subjects.
  final Map<int, List<StudyProgramItem>> _programsBySubjectId = {};

  bool _isLoadingData = true;
  bool _isSubmitting = false;

  List<AssociationSubjectItem> _allSubjects = [];
  List<StudyProgramItem> _allPrograms = [];
  List<ServiceItem> _allServices = [];

  @override
  void initState()
  {
    super.initState();
    _loadAllData();
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
        ApiService().getServices(),
      ]);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _allSubjects = results[0] as List<AssociationSubjectItem>;
        _allPrograms = results[1] as List<StudyProgramItem>;
        _allServices = results[2] as List<ServiceItem>;

        for (final subject in _allSubjects)
        {
          _programsBySubjectId[subject.id] = _findProgramsFor(subject);
        }

        for (final competence in widget.person.teacherSubjects ?? <TeacherSubjectItem>[])
        {
          _isSubjectSelected[competence.subjectId] = true;
          _programsBySubject[competence.subjectId] = competence.studyProgramIds.toSet();
        }

        _selectedServices.addAll(widget.person.teacherServices ?? const <String>[]);

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

  // Ticking a discipline is the whole of the common answer: it is assigned
  // wherever it is taught. Restricting it is a second step, and one that is only
  // taken when it is true — most teachers teach a discipline in every programme
  // that offers it, and the window that asked them programme by programme asked
  // them something they had no reason to answer.
  Future<void> _submitForm() async
  {
    // A teacher who only takes on services is still a teacher: what cannot be
    // saved is one who does neither.
    if (!_isSubjectSelected.values.any((isSelected) => isSelected) &&
        _selectedServices.isEmpty)
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
        _selectedServices.toList(),
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

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Discipline',
      title: 'Modifica discipline',
      maxWidth: 860,
      // Search and filters stay put; only the list of disciplines moves.
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
        CompetenceCatalogue(
          subjects: _allSubjects,
          programsBySubjectId: _programsBySubjectId,
          isSelected: _isSubjectSelected,
          programsBySubject: _programsBySubject,
          services: _allServices,
          selectedServices: _selectedServices,
          isLoading: _isLoadingData,
          onChanged: () => setState(() {}),
          // Two pieces standing in the room of one child, and a beat each: the
          // stack counts the title 0 and this child 1, so the filters take that
          // beat and the list comes after them. Under a single piece the two
          // arrived together, which is not what the windows next door do — the
          // minors and the parents hand the stack the same two pills as two
          // children and they arrive one after the other.
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
