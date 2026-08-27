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

// One duration for background, check mark, and trailing swap: out-of-step
// animations on the same row read as flicker.
const Duration _selectFade = Duration(milliseconds: 180);

class CompetenceScope
{
  final int chosen;
  final int total;

  const CompetenceScope({required this.chosen, required this.total});

  bool get isAll => chosen >= total;

  String get label => isAll ? 'Tutti i percorsi · $total' : '$chosen di $total percorsi';
}

class CompetenceRow extends StatefulWidget
{
  final String name;
  final String area;
  final bool selected;
  final CompetenceScope? scope;

  final String? subtitle;

  // Services have no programmes to narrow down.
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
            // Not Colors.transparent (black at zero alpha): the fade would pass
            // through grey.
            color: widget.selected
                ? kPickedSurface
                : kPickedSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(16),
            // Border always present (transparent) so hover does not shift the
            // contents.
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
        // Keeps the tap from reaching the row, which would untick the discipline.
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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


// Sentinel for "services" in the area filter; the underscores keep it out of
// the real area values.
const String kServicesFilterValue = '__SERVICES__';

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

// The selection maps are caller-owned and edited in place, notifying via
// onChanged.
class CompetenceCatalogue extends StatefulWidget
{
  final List<AssociationSubjectItem> subjects;
  final Map<int, List<StudyProgramItem>> programsBySubjectId;

  final Map<int, bool> isSelected;
  final Map<int, Set<int>> programsBySubject;

  // Keyed by name: the name is a service's key.
  final List<ServiceItem> services;
  final Set<String> selectedServices;

  final bool isLoading;
  final VoidCallback onChanged;

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

  // Subjects with no programmes are excluded: they cannot be assigned.
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

  // Ticking assigns the discipline to every programme that teaches it.
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
        // An unchosen discipline starts with all programmes ticked.
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
