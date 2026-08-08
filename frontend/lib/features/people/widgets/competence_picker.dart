import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart' show FilterOption;
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../../association/models/subject_taxonomy.dart';
import 'person_detail_widgets.dart';
import 'program_scope_dialog.dart';

// The rows the competences window is made of, one per discipline.
//
// It used to be a grid of cards three hundred and sixty pixels wide. A catalogue
// of a hundred disciplines shown that way is a page you scroll rather than a
// list you read, and the four things a row has to say — is it in, what is it
// called, what area, and where is it taught — fit on one line.
//
// The rows never move. An earlier draft gathered the chosen ones into a section
// at the top, and a row that jumps away the moment it is ticked takes the scope
// control with it: restricting meant finding the discipline a second time.

// How long the move from unchosen to chosen takes: the background tinting, the
// mark appearing, and the commands on the right swapping. One duration for all
// three, because three movements of different lengths on the same row read as a
// flicker rather than as an answer.
const Duration _selectFade = Duration(milliseconds: 180);

/// What a chosen discipline says about the programmes it covers.
class CompetenceScope
{
  final int chosen;
  final int total;

  const CompetenceScope({required this.chosen, required this.total});

  bool get isAll => chosen >= total;

  String get label => isAll ? 'Tutti i percorsi · $total' : '$chosen di $total percorsi';
}

/// One discipline in the catalogue.
///
/// Ticking it is the whole of the common answer: the caller assigns it to every
/// programme that teaches it. The scope on the right is both the answer to
/// "where" and the way to change it — pressed, it opens the programmes. On a row
/// not yet chosen the same place holds the quiet way in for whoever already
/// knows they want only some programmes: it opens the picker directly, and
/// confirming there is what brings the discipline in.
class CompetenceRow extends StatefulWidget
{
  final String name;
  final String area;
  final bool selected;
  final CompetenceScope? scope;

  // What to say under the name: the discipline's description where there is
  // one. Where nobody wrote it, the area is left, which is the only other thing
  // known about it — and a service, having no area, says it is a service.
  final String? subtitle;

  // Whether the entry has programmes to narrow down. A service has none: it is
  // the same whoever asks for it, and the row goes without that command.
  final bool hasPrograms;

  final ValueChanged<bool> onSelected;
  final VoidCallback onEditScope;
  final VoidCallback onRemove;

  const CompetenceRow({
    super.key,
    required this.name,
    this.area = '',
    this.subtitle,
    this.hasPrograms = true,
    required this.selected,
    required this.scope,
    required this.onSelected,
    required this.onEditScope,
    required this.onRemove,
  });

  @override
  State<CompetenceRow> createState() => _CompetenceRowState();
}

class _CompetenceRowState extends State<CompetenceRow>
{
  bool _hover = false;

  // A fade and not a swap: the programmes command and the delete button used to
  // appear all at once while the background was still tinting, and two movements
  // out of step on the same row read as a flicker.
  Widget _buildTrailing()
  {
    return AnimatedSwitcher(
      duration: _selectFade,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: Row(
        key: ValueKey(widget.selected),
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildScope(),
          if (widget.selected)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FadeHoverIconButton(
                icon: Icons.delete_outline_rounded,
                color: AppTheme.trialDanger,
                hoverColor: AppTheme.trialGoldSurface,
                onTap: widget.onRemove,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScope()
  {
    // Niente da restringere, niente da offrire: su un servizio la spunta è
    // tutta la risposta.
    if (!widget.hasPrograms)
    {
      return const SizedBox.shrink();
    }

    final CompetenceScope? scope = widget.scope;

    if (widget.selected && scope != null)
    {
      return Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _ScopeButton(label: scope.label, onTap: widget.onEditScope),
      );
    }

    // The way in for whoever wants to restrict from the start, without going
    // through "everywhere" first. Icon only: on an unchosen row it is an offer,
    // not an answer.
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: 'Scegli i percorsi',
        waitDuration: const Duration(milliseconds: 400),
        child: FadeHoverIconButton(
          icon: Icons.tune_rounded,
          color: AppTheme.trialMutedText,
          hoverColor: AppTheme.trialGoldSurface,
          onTap: widget.onEditScope,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.selected),
        child: AnimatedContainer(
          duration: _selectFade,
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            // Transparent *in this colour* and not `Colors.transparent`, which
            // is black at zero opacity: halfway through the fade the row used to
            // pass through a grey nobody asked for.
            color: widget.selected
                ? kPickedSurface
                : kPickedSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(16),
            // Under the pointer the row outlines itself in gold, the mark the
            // app uses everywhere for "the pointer is here". The border is
            // always there, transparent, so lighting up does not shift the
            // contents by two pixels.
            border: Border.all(
              color: _hover
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              AppCheckMark(selected: widget.selected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OverflowTooltipText(
                      text: widget.name,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    const SizedBox(height: 2),
                    OverflowTooltipText(
                      maxLines: 1,
                      text: widget.subtitle ?? subjectAreaLabel(widget.area),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.trialMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTrailing(),
            ],
          ),
        ),
      ),
    );
  }
}

// Where the discipline is taught, and the way in to change it. Quiet: it is a
// footnote to the row, not a second decision competing with the tick.
class _ScopeButton extends StatefulWidget
{
  final String label;
  final VoidCallback onTap;

  const _ScopeButton({required this.label, required this.onTap});

  @override
  State<_ScopeButton> createState() => _ScopeButtonState();
}

class _ScopeButtonState extends State<_ScopeButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        // Stops the tap from reaching the row, which would untick the discipline
        // instead of opening its programmes.
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            // The outline only: filling it with gold made it look chosen,
            // whereas gold here says no more than where the pointer is.
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialTealDeep,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.tune_rounded, size: 15, color: AppTheme.trialTealDeep),
            ],
          ),
        ),
      ),
    );
  }
}


// The value standing for "the services" in the filter. Not an area: there are
// three areas, and the services are the fourth entry of that menu because that
// is where one goes looking for them. The double underscore keeps it out of the
// real values.
const String kServicesFilterValue = '__SERVICES__';

// An entry of the catalogue: a discipline, or a service. The two are picked
// from the same list and sorted together, so they share a name and a date; what
// tells them apart — the programmes, which only disciplines have — stays on the
// two subtypes.
sealed class CompetenceEntry
{
  const CompetenceEntry();

  String get name;
  DateTime get createdAt;
}

final class SubjectEntry extends CompetenceEntry
{
  final AssociationSubjectItem subject;

  const SubjectEntry(this.subject);

  @override
  String get name => subject.name;

  @override
  DateTime get createdAt => subject.createdAt;
}

final class ServiceEntry extends CompetenceEntry
{
  final ServiceItem service;

  const ServiceEntry(this.service);

  @override
  String get name => service.name;

  @override
  DateTime get createdAt => service.createdAt;
}

/// Come si ordina il catalogo.
enum CompetenceSort
{
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  dateDesc('Più recente'),
  dateAsc('Meno recente');

  final String label;

  const CompetenceSort(this.label);

  int compare(CompetenceEntry a, CompetenceEntry b)
  {
    return switch (this)
    {
      CompetenceSort.nameAsc => a.name.compareTo(b.name),
      CompetenceSort.nameDesc => b.name.compareTo(a.name),
      CompetenceSort.dateDesc => b.createdAt.compareTo(a.createdAt),
      CompetenceSort.dateAsc => a.createdAt.compareTo(b.createdAt),
    };
  }
}

// The discipline catalogue with its filters: the head that shortens the list,
// and the list itself.
//
// It keeps only the filters for itself; the selection lives in the two maps
// handed to it, which it edits in place while notifying their owner.
//
// The two parts go back to the caller separately, because in a stack of pills
// the filters stay put in one and the list scrolls inside another.
class CompetenceCatalogue extends StatefulWidget
{
  final List<AssociationSubjectItem> subjects;
  final Map<int, List<StudyProgramItem>> programsBySubjectId;

  // Which disciplines are chosen, and with which programmes.
  final Map<int, bool> isSelected;
  final Map<int, Set<int>> programsBySubject;

  // The services to choose from, and which are chosen. A set of names and not
  // of ids because the name is a service's key. There is none of the programme
  // map the disciplines have: a service is the same whoever asks for it.
  final List<ServiceItem> services;
  final Set<String> selectedServices;

  final bool isLoading;
  final VoidCallback onChanged;

  // Where to put the head and where the list.
  final Widget Function(BuildContext context, Widget filters, Widget list) builder;

  const CompetenceCatalogue({
    super.key,
    required this.subjects,
    required this.programsBySubjectId,
    required this.isSelected,
    required this.programsBySubject,
    required this.services,
    required this.selectedServices,
    required this.onChanged,
    required this.builder,
    this.isLoading = false,
  });

  @override
  State<CompetenceCatalogue> createState() => _CompetenceCatalogueState();
}

class _CompetenceCatalogueState extends State<CompetenceCatalogue>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  CompetenceSort _sort = CompetenceSort.nameAsc;
  String? _filterArea;

  // Narrows the list to what the teacher already covers. A filter and not a
  // section: gathering the chosen rows at the top moved the row at the very
  // moment it was ticked, and the programmes command went with it.
  bool _onlySelected = false;

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<StudyProgramItem> _programsOf(AssociationSubjectItem subject) =>
      widget.programsBySubjectId[subject.id] ?? const [];

  int get _selectedCount =>
      widget.isSelected.values.where((selected) => selected).length +
      widget.selectedServices.length;

  bool get _showingOnlyServices => _filterArea == kServicesFilterValue;

  // Disciplines and services in a single list, sorted together: whoever reads
  // it is choosing among the things a teacher can take on, not between two
  // catalogues.
  //
  // Disciplines nobody can teach stay out: with no programme to attach them to
  // they cannot be assigned. A service has no programmes, and that rule does not
  // concern it.
  List<CompetenceEntry> get _filteredEntries
  {
    final String query = _searchText.toLowerCase();
    final List<CompetenceEntry> result = [];

    if (!_showingOnlyServices)
    {
      for (final subject in widget.subjects)
      {
        if (_programsOf(subject).isEmpty)
        {
          continue;
        }

        if (_onlySelected && !(widget.isSelected[subject.id] ?? false))
        {
          continue;
        }

        if (_filterArea != null && subject.area != _filterArea)
        {
          continue;
        }

        if (subject.name.toLowerCase().contains(query))
        {
          result.add(SubjectEntry(subject));
        }
      }
    }

    if (_filterArea == null || _showingOnlyServices)
    {
      for (final service in widget.services)
      {
        if (_onlySelected && !widget.selectedServices.contains(service.name))
        {
          continue;
        }

        if (service.name.toLowerCase().contains(query))
        {
          result.add(ServiceEntry(service));
        }
      }
    }

    result.sort(_sort.compare);

    return result;
  }

  // Ticking a discipline is the whole common answer: it assigns it wherever it
  // is taught. Narrowing it down is a second step, taken only when true.
  void _select(AssociationSubjectItem subject)
  {
    widget.isSelected[subject.id] = true;
    widget.programsBySubject[subject.id] =
        _programsOf(subject).map((program) => program.id).toSet();

    widget.onChanged();
    setState(() {});
  }

  void _deselect(int subjectId)
  {
    widget.isSelected[subjectId] = false;
    widget.programsBySubject.remove(subjectId);

    widget.onChanged();
    setState(() {});
  }

  // On a service the tick is the whole answer: there is no where to narrow.
  void _toggleService(ServiceItem service, bool selected)
  {
    if (selected)
    {
      widget.selectedServices.add(service.name);
    }
    else
    {
      widget.selectedServices.remove(service.name);
    }

    widget.onChanged();
    setState(() {});
  }

  void _openPrograms(AssociationSubjectItem subject)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'ProgramsSelection',
      builder: (context) => ProgramScopeDialog(
        subjectName: subject.name,
        programs: _programsOf(subject),
        // On a discipline not yet chosen everything starts ticked: coming here
        // from the catalogue is the way in for someone already narrowing down,
        // and removing costs less than adding one by one.
        initialSelected: widget.programsBySubject[subject.id] ??
            _programsOf(subject).map((program) => program.id).toSet(),
        // Confirming with no programme left means giving up the discipline.
        onSave: (selected)
        {
          if (selected.isEmpty)
          {
            _deselect(subject.id);

            return;
          }

          widget.isSelected[subject.id] = true;
          widget.programsBySubject[subject.id] = selected;

          widget.onChanged();
          setState(() {});
        },
      ),
    );
  }

  CompetenceScope _scopeOf(AssociationSubjectItem subject)
  {
    return CompetenceScope(
      chosen: (widget.programsBySubject[subject.id] ?? const <int>{}).length,
      total: _programsOf(subject).length,
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
          // The chip is shorter than the pills: centred it lines up with them,
          // at the top it looks slipped upwards.
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppFilterPill<CompetenceSort>.setting(
              prefix: 'Ordina',
              hint: 'Ordina',
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 190,
              onChanged: (value) => setState(() => _sort = value),
              options: CompetenceSort.values
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
              options: [
                for (final area in subjectAreas)
                  FilterOption(value: area.value, label: area.label),
                // Last, and under the three areas: the services are not a
                // fourth area, they are the other thing that can be picked in
                // here.
                const FilterOption(value: kServicesFilterValue, label: 'Servizi'),
              ],
            ),
            AppSelectableChip(
              label: 'Solo selezionate ($_selectedCount)',
              selected: _onlySelected,
              onSelected: (value) => setState(() => _onlySelected = value),
            ),
          ],
        ),
      ],
    );
  }

  // A single list, in the order the pill says, with rows that stay where they
  // are: ticking changes the row under the pointer instead of sending it off to
  // a section at the top of the dialog.
  Widget _buildList()
  {
    if (widget.isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
      );
    }

    final List<CompetenceEntry> entries = _filteredEntries;

    if (entries.isEmpty)
    {
      final String what = _showingOnlyServices ? 'servizio' : 'voce';

      return PersonEmptyState(
        message: _onlySelected
            ? 'Nessun $what selezionato.'
            : 'Nessun $what trovato per questa ricerca.',
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in entries)
            switch (entry)
            {
              SubjectEntry(:final subject) => CompetenceRow(
                  key: ValueKey('subject-${subject.id}'),
                  name: subject.name,
                  area: subject.area,
                  subtitle: descriptionOrNull(subject.description),
                  selected: widget.isSelected[subject.id] ?? false,
                  scope: (widget.isSelected[subject.id] ?? false)
                      ? _scopeOf(subject)
                      : null,
                  onSelected: (value) =>
                      value ? _select(subject) : _deselect(subject.id),
                  onEditScope: () => _openPrograms(subject),
                  onRemove: () => _deselect(subject.id),
                ),
              ServiceEntry(:final service) => CompetenceRow(
                  key: ValueKey('service-${service.name}'),
                  name: service.name,
                  subtitle: 'Servizio',
                  hasPrograms: false,
                  selected: widget.selectedServices.contains(service.name),
                  scope: null,
                  onSelected: (value) => _toggleService(service, value),
                  onEditScope: () {},
                  onRemove: () => _toggleService(service, false),
                ),
            },
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return widget.builder(context, _buildFilters(), _buildList());
  }
}
