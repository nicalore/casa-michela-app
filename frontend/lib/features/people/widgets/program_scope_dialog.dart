import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/unfolding_rows.dart';
import '../../association/models/program_tree.dart';
import '../../association/models/study_program_item.dart';
import '../subjects_tour.dart';
import '../utils/program_scope_strings.dart';
import 'person_detail_widgets.dart';

// Past this many programmes the list gets a search field.
const int _searchFrom = 12;

const double _cardEdge = 1.5;
const EdgeInsets _cardHeadPadding = EdgeInsets.fromLTRB(10, 10, 13, 10);

// Headings keep their check in the sector cards' column.
const double _checkInset = 13 + _cardEdge;

const Color _openCardSurface = Color(0xFFFAFCFC);
const Color _openCardEdge = Color(0xFFCFE3E0);

const Duration _fade = Duration(milliseconds: 180);
const Duration _turn = Duration(milliseconds: 220);

typedef _Branch = ({ProgramGroup level, ProgramGroup? cycle, ProgramGroup? sector});

class ProgramScopeDialog extends StatefulWidget
{
  final String subjectName;
  final List<StudyProgramItem> programs;
  final Set<int> initialSelected;

  // An empty set means the discipline is being given up.
  final ValueChanged<Set<int>> onSave;

  // A discipline not taken yet: confirming none is refused, there is nothing to give up.
  final bool adding;

  const ProgramScopeDialog({
    super.key,
    required this.subjectName,
    required this.programs,
    required this.initialSelected,
    required this.onSave,
    this.adding = false,
  });

  @override
  State<ProgramScopeDialog> createState() => _ProgramScopeDialogState();
}

class _ProgramScopeDialogState extends State<ProgramScopeDialog>
{
  final TextEditingController _searchController = TextEditingController();

  late Set<int> _selected;
  String _query = '';

  final Set<String> _open = {};

  // While searching every sector with results is open, save those closed by hand.
  final Set<String> _shutWhileSearching = {};

  @override
  void initState()
  {
    super.initState();
    _selected = Set<int>.from(widget.initialSelected);
    programsSectorOpened.value = false;
    startSubjectsTour(context, subjectsProgramsTour);
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  bool get _searching => _query.trim().isNotEmpty;

  bool _isOpen(ProgramGroup sector)
  {
    return _searching ? !_shutWhileSearching.contains(sector.key) : _open.contains(sector.key);
  }

  void _toggleOpen(ProgramGroup sector)
  {
    final bool opening = !_isOpen(sector);
    final Set<String> keys = _searching ? _shutWhileSearching : _open;

    setState(()
    {
      if (opening == _searching)
      {
        keys.remove(sector.key);
      }
      else
      {
        keys.add(sector.key);
      }
    });

    if (opening)
    {
      programsSectorOpened.value = true;
    }
  }

  void _onQuery(String value)
  {
    setState(()
    {
      _query = value;

      if (!_searching)
      {
        _shutWhileSearching.clear();
      }
    });
  }

  void _toggle(int id, bool selected)
  {
    setState(()
    {
      if (selected)
      {
        _selected.add(id);
      }
      else
      {
        _selected.remove(id);
      }
    });
  }

  // Half chosen counts as off, so the first press turns the group on.
  void _toggleAll(List<StudyProgramItem> programs, bool selected)
  {
    setState(()
    {
      for (final StudyProgramItem program in programs)
      {
        if (selected)
        {
          _selected.add(program.id);
        }
        else
        {
          _selected.remove(program.id);
        }
      }
    });
  }

  int _chosenOf(List<StudyProgramItem> programs)
  {
    return programs.where((program) => _selected.contains(program.id)).length;
  }

  // The tour lights a row of the sector it had opened; with none open, the first row on show.
  int? _singleRow(List<ProgramGroup> tree)
  {
    for (final ProgramGroup level in tree)
    {
      for (final ProgramGroup sector in level.sectors)
      {
        if (_isOpen(sector) && sector.programs.isNotEmpty)
        {
          return sector.programs.first.id;
        }
      }
    }

    for (final ProgramGroup level in tree)
    {
      final StudyProgramItem? loose = [
        ...level.programs,
        for (final ProgramGroup cycle in level.children) ...cycle.programs,
      ].firstOrNull;

      if (loose != null)
      {
        return loose.id;
      }
    }

    return null;
  }

  Widget _buildSummary(List<StudyProgramItem> shown)
  {
    final int total = widget.programs.length;
    final int chosen = _selected.length;
    final int shownChosen = _chosenOf(shown);
    final bool all = shown.isNotEmpty && shownChosen == shown.length;

    return Padding(
      padding: const EdgeInsets.only(right: _checkInset),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chosen == total ? 'Tutti i percorsi ($total)' : '$chosen di $total percorsi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialTealDeep,
              ),
            ),
          ),
          DesktopTourTarget(
            id: kTourProgramsAll,
            child: _SelectAll(
              selected: all,
              partial: shownChosen > 0 && !all,
              onTap: () => _toggleAll(shown, !all),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(List<StudyProgramItem> programs, int? single)
  {
    return [
      // The gap stays outside the tour's part, so its hole hugs the row.
      for (final StudyProgramItem program in programs)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: DesktopTourTarget(
            id: program.id == single ? kTourProgramsSingle : null,
            child: _ProgramRow(
              label: program.name,
              years: programYearsLine(program),
              selected: _selected.contains(program.id),
              onSelected: (selected) => _toggle(program.id, selected),
            ),
          ),
        ),
    ];
  }

  Widget _heading(ProgramGroup group, {String? tour})
  {
    final List<StudyProgramItem> programs = group.all;

    return _GroupHeading(
      title: group.title,
      cycle: group.kind == ProgramGroupKind.cycle,
      chosen: _chosenOf(programs),
      total: programs.length,
      onToggle: (selected) => _toggleAll(programs, selected),
      tour: tour,
    );
  }

  Widget _sectors(List<ProgramGroup> sectors, _Branch? branch, int? single, {required bool tour})
  {
    final bool animate = VisualEffects.of(context);

    return DesktopTourTarget(
      id: tour ? kTourProgramsSectors : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (int index, ProgramGroup sector) in sectors.indexed)
            DesktopTourTarget(
              id: identical(sector, branch?.sector) ? kTourProgramsSector : null,
              child: _SectorCard(
                title: sector.title,
                chosen: _chosenOf(sector.programs),
                total: sector.programs.length,
                open: _isOpen(sector),
                animate: animate,
                last: index == sectors.length - 1,
                onOpen: () => _toggleOpen(sector),
                onToggle: (selected) => _toggleAll(sector.programs, selected),
                rows: _rows(sector.programs, single),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCycle(ProgramGroup cycle, _Branch? branch, int? single, {required bool first})
  {
    final List<ProgramGroup> sectors = [...cycle.sectors];
    final bool lit = identical(cycle, branch?.cycle);

    return Padding(
      padding: EdgeInsets.only(top: first ? 4 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(cycle, tour: lit ? kTourProgramsCycle : null),
          _Rail(
            children: [
              ..._rows(cycle.programs, single),
              if (sectors.isNotEmpty) _sectors(sectors, branch, single, tour: lit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevel(ProgramGroup level, _Branch? branch, int? single, {required bool first})
  {
    final bool lit = identical(level, branch?.level);
    final List<ProgramGroup> sectors = [
      for (final ProgramGroup child in level.children)
        if (child.kind == ProgramGroupKind.sector) child,
    ];
    final List<ProgramGroup> cycles = [
      for (final ProgramGroup child in level.children)
        if (child.kind == ProgramGroupKind.cycle) child,
    ];

    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 28),
      child: DesktopTourTarget(
        id: lit ? kTourProgramsBranch : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(level, tour: lit ? kTourProgramsLevel : null),
            _Rail(
              children: [
                ..._rows(level.programs, single),
                if (sectors.isNotEmpty) _sectors(sectors, branch, single, tour: lit && branch?.cycle == null),
                for (final (int index, ProgramGroup cycle) in cycles.indexed)
                  _buildCycle(cycle, branch, single, first: index == 0 && sectors.isEmpty && level.programs.isEmpty),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<ProgramGroup> tree = programTree(widget.programs, query: _query);
    final List<StudyProgramItem> shown = [for (final ProgramGroup level in tree) ...level.all];
    final _Branch? branch = firstProgramBranch(tree);
    final int? single = _singleRow(tree);

    return AppDialogStack(
      eyebrow: 'Percorsi',
      title: widget.subjectName,
      maxWidth: 720,
      fillLast: true,
      footer: AppDialogFooter.single(
        DesktopTourTarget(
          id: kTourProgramsConfirm,
          child: AppGradientButton(
            label: 'CONFERMA',
            icon: Icons.check_rounded,
            height: kPersonDialogButtonHeight,
            fontSize: kPersonDialogButtonFontSize,
            onPressed: ()
            {
              if (widget.adding && _selected.isEmpty)
              {
                CustomSnackBar.show(context: context, message: kPickProgramToAdd, isError: true);

                return;
              }

              widget.onSave(_selected);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummary(shown),
              if (widget.programs.length >= _searchFrom) ...[
                const SizedBox(height: 14),
                AppSearchField(
                  controller: _searchController,
                  hintText: 'Cerca percorso...',
                  onChanged: _onQuery,
                ),
              ],
            ],
          ),
        ),
        DesktopTourTarget(
          id: kTourProgramsList,
          child: AppDialogPill(
            expand: true,
            child: tree.isEmpty
                ? const PersonEmptyState(message: 'Nessun percorso trovato.')
                : ScrollEdgeFade(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (int index, ProgramGroup level) in tree.indexed)
                            _buildLevel(level, branch, single, first: index == 0),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SelectAll extends StatelessWidget
{
  final bool selected;
  final bool partial;
  final VoidCallback onTap;

  const _SelectAll({required this.selected, required this.partial, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Seleziona tutto',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialInk,
              ),
            ),
            const SizedBox(width: 12),
            AppCheckMark(selected: selected, partial: partial),
          ],
        ),
      ),
    );
  }
}

// What a level or a cycle holds sits to the right of a thin line.
class _Rail extends StatelessWidget
{
  final List<Widget> children;

  const _Rail({required this.children});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.trialLine, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _GroupCount extends StatelessWidget
{
  final int chosen;
  final int total;

  const _GroupCount({required this.chosen, required this.total});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      '$chosen/$total',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialMutedText,
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget
{
  final String title;
  final bool cycle;
  final int chosen;
  final int total;
  final ValueChanged<bool> onToggle;

  final String? tour;

  const _GroupHeading({
    required this.title,
    required this.cycle,
    required this.chosen,
    required this.total,
    required this.onToggle,
    this.tour,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool all = chosen == total;

    return Padding(
      padding: EdgeInsets.only(bottom: cycle ? 8 : 10),
      child: DesktopTourTarget(
        id: tour,
        child: Container(
          constraints: BoxConstraints(minHeight: cycle ? 30 : 34),
          padding: const EdgeInsets.only(right: _checkInset),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: cycle ? 15 : 17,
                    fontWeight: cycle ? FontWeight.w700 : FontWeight.w800,
                    color: cycle ? AppTheme.trialTealDeep : AppTheme.trialInk,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _GroupCount(chosen: chosen, total: total),
              const SizedBox(width: 12),
              AppCheckMark(
                selected: all,
                partial: chosen > 0 && !all,
                onTap: () => onToggle(!all),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A click on the check takes the whole sector; anywhere else opens or closes it.
class _SectorCard extends StatefulWidget
{
  final String title;
  final int chosen;
  final int total;
  final bool open;
  final bool animate;
  final bool last;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final List<Widget> rows;

  const _SectorCard({
    required this.title,
    required this.chosen,
    required this.total,
    required this.open,
    required this.animate,
    required this.last,
    required this.onOpen,
    required this.onToggle,
    required this.rows,
  });

  @override
  State<_SectorCard> createState() => _SectorCardState();
}

class _SectorCardState extends State<_SectorCard>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool all = widget.chosen == widget.total;
    final Color edge = widget.open ? _openCardEdge : AppTheme.trialLine;

    return AnimatedContainer(
      duration: widget.animate ? _fade : Duration.zero,
      curve: Curves.easeOut,
      margin: EdgeInsets.only(bottom: widget.last ? 0 : 8),
      decoration: BoxDecoration(
        color: widget.open ? _openCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hover ? AppTheme.trialGold : edge, width: _cardEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpen,
              child: Padding(
                padding: _cardHeadPadding,
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: widget.open ? 0 : -0.25,
                      duration: widget.animate ? _turn : Duration.zero,
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.expand_more_rounded, size: 22, color: AppTheme.trialMutedText),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.trialInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _GroupCount(chosen: widget.chosen, total: widget.total),
                    const SizedBox(width: 12),
                    AppCheckMark(
                      selected: all,
                      partial: widget.chosen > 0 && !all,
                      onTap: () => widget.onToggle(!all),
                    ),
                  ],
                ),
              ),
            ),
          ),
          UnfoldingRows(
            open: widget.open,
            animate: widget.animate,
            keepInView: true,
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            children: widget.rows,
          ),
        ],
      ),
    );
  }
}

class _ProgramRow extends StatefulWidget
{
  final String label;
  final String? years;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _ProgramRow({
    required this.label,
    required this.years,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_ProgramRow> createState() => _ProgramRowState();
}

class _ProgramRowState extends State<_ProgramRow>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final String? years = widget.years;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.selected),
        child: AnimatedContainer(
          duration: _fade,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // Not Colors.transparent (black at zero alpha): the fade would pass through grey.
            color: widget.selected
                ? kPickedSurface
                : kPickedSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              AppCheckMark(selected: widget.selected, onTap: null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                        height: 1.35,
                        color: widget.selected ? AppTheme.trialTealDeep : AppTheme.trialInk,
                      ),
                    ),
                    if (years != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          years,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.trialMutedText,
                          ),
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
