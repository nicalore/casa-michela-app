import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/association/models/program_tree.dart';
import '../../../../features/association/models/study_program_item.dart';
import '../../../../shared/widgets/unfolding_rows.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_danger_button.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../mobile_subjects_tour.dart';

// Past this many programmes the list gets a search field.
const int _searchFrom = 12;

const EdgeInsets _tourListInflate = EdgeInsets.fromLTRB(8, -8, 8, 4);
const double _tourListRadius = 18;
const EdgeInsets _tourHeadInflate = EdgeInsets.symmetric(horizontal: 8, vertical: 2);
const double _tourHeadRadius = 14;
const EdgeInsets _tourPanelInflate = EdgeInsets.all(5);
const double _tourPanelRadius = _panelRadius + 5;
const EdgeInsets _tourLineInflate = EdgeInsets.all(3);
const double _tourLineRadius = 15;
const EdgeInsets _tourButtonInflate = EdgeInsets.all(5);
const double _tourButtonRadius = 23;

const double _panelRadius = 18;
const Color _panelFill = Color(0xB8FFFFFF);
const double _panelEdgeAlpha = 0.06;
const double _hairlineAlpha = 0.07;

// Rows of an open sector start under its name, past the arrow.
const double _sectorRowIndent = 36;
const double _lineInset = 6;

const Duration _turn = Duration(milliseconds: 260);

typedef _Branch = ({ProgramGroup level, ProgramGroup? cycle, ProgramGroup? sector});

// Worded as on the desktop.
String programsSummary(int chosen, int total)
{
  return chosen == total ? 'Tutti i percorsi ($total)' : '$chosen di $total percorsi';
}

// Null when dismissed; confirming none gives a held discipline up.
// [taxCode] lets the sheet's tour start once it is up.
Future<Set<int>?> showMobileProgramsSheet({
  required BuildContext context,
  required String subjectName,
  required String? description,
  required List<StudyProgramItem> programs,
  required Set<int> initialSelected,
  required Future<void> Function(BuildContext sheet)? onRemove,
  String? taxCode,
})
{
  return showMobileSheet<Set<int>>(
    context: context,
    builder: (context) => _ProgramsSheet(
      subjectName: subjectName,
      description: description,
      programs: programs,
      initialSelected: initialSelected,
      onRemove: onRemove,
      taxCode: taxCode,
    ),
  );
}

class _ProgramsSheet extends StatefulWidget
{
  final String subjectName;
  final String? description;
  final List<StudyProgramItem> programs;
  final Set<int> initialSelected;
  final Future<void> Function(BuildContext sheet)? onRemove;
  final String? taxCode;

  const _ProgramsSheet({
    required this.subjectName,
    required this.description,
    required this.programs,
    required this.initialSelected,
    required this.onRemove,
    required this.taxCode,
  });

  @override
  State<_ProgramsSheet> createState() => _ProgramsSheetState();
}

class _ProgramsSheetState extends State<_ProgramsSheet>
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
    mobileProgramsSectorOpened.value = false;
    _tourLater();
  }

  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  // Once the sheet stands still.
  void _tourCheck()
  {
    final String? taxCode = widget.taxCode;

    if (!mounted || taxCode == null || isMobileTourShown)
    {
      return;
    }

    if (isMobileSheetMoving(context))
    {
      _tourLater();

      return;
    }

    startProgramsTour(taxCode: taxCode, held: widget.onRemove != null);
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
      mobileProgramsSectorOpened.value = true;
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

  void _toggle(int id)
  {
    setState(()
    {
      if (!_selected.remove(id))
      {
        _selected.add(id);
      }
    });
  }

  // Half chosen counts as off, so the first press turns the group on.
  void _toggleAll(List<StudyProgramItem> programs)
  {
    final bool all = programs.every((program) => _selected.contains(program.id));

    setState(()
    {
      for (final StudyProgramItem program in programs)
      {
        if (all)
        {
          _selected.remove(program.id);
        }
        else
        {
          _selected.add(program.id);
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
    final int chosen = _chosenOf(shown);
    final bool all = shown.isNotEmpty && chosen == shown.length;

    return Row(
      children: [
        Expanded(
          child: Text(
            programsSummary(_selected.length, widget.programs.length),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ),
        MobileTourTarget(
          id: programsTourTarget(ProgramsMark.all),
          inflate: const EdgeInsets.fromLTRB(10, 2, 2, 2),
          radius: _tourHeadRadius,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleAll(shown),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Text(
                  'Seleziona tutto',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialInk,
                  ),
                ),
                MobileSelectAllToggle(
                  selected: all,
                  partial: chosen > 0 && !all,
                  onTap: () => _toggleAll(shown),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(StudyProgramItem program, int? single, {required bool deep})
  {
    return Padding(
      padding: EdgeInsets.fromLTRB(deep ? _sectorRowIndent : _lineInset, 0, _lineInset, 4),
      child: MobileTourTarget(
        id: program.id == single ? programsTourTarget(ProgramsMark.single) : null,
        inflate: _tourLineInflate,
        radius: _tourLineRadius,
        clipped: true,
        child: MobileSelectLine(
          title: program.name,
          subtitle: programYearsLine(program),
          selected: _selected.contains(program.id),
          onTap: () => _toggle(program.id),
        ),
      ),
    );
  }

  Widget _head(ProgramGroup group, {String? tour})
  {
    final List<StudyProgramItem> programs = group.all;

    return MobileTourTarget(
      id: tour,
      inflate: _tourHeadInflate,
      radius: _tourHeadRadius,
      clipped: true,
      child: _GroupHead(
        title: group.title,
        cycle: group.kind == ProgramGroupKind.cycle,
        chosen: _chosenOf(programs),
        total: programs.length,
        onToggle: () => _toggleAll(programs),
      ),
    );
  }

  // One glass panel for the rows of a level or cycle and its sectors.
  Widget _panel(ProgramGroup group, _Branch? branch, int? single, {required bool tour})
  {
    final List<ProgramGroup> sectors = [
      for (final ProgramGroup child in group.children)
        if (child.kind == ProgramGroupKind.sector) child,
    ];
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    return MobileTourTarget(
      id: tour ? programsTourTarget(ProgramsMark.open) : null,
      inflate: _tourPanelInflate,
      radius: _tourPanelRadius,
      clipped: true,
      child: _Panel(
        children: [
          if (group.programs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final StudyProgramItem program in group.programs) _row(program, single, deep: false)],
              ),
            ),
          for (final (int index, ProgramGroup sector) in sectors.indexed) ...[
            MobileTourTarget(
              id: identical(sector, branch?.sector) ? programsGroupTarget(ProgramsGroupPart.sector) : null,
              inflate: _tourLineInflate,
              radius: _tourLineRadius,
              clipped: true,
              child: _SectorLine(
                title: sector.title,
                chosen: _chosenOf(sector.programs),
                total: sector.programs.length,
                open: _isOpen(sector),
                ruled: index > 0 || group.programs.isNotEmpty,
                onOpen: () => _toggleOpen(sector),
                onToggle: () => _toggleAll(sector.programs),
              ),
            ),
            UnfoldingRows(
              open: _isOpen(sector),
              animate: animate,
              padding: const EdgeInsets.only(bottom: 4),
              children: [for (final StudyProgramItem program in sector.programs) _row(program, single, deep: true)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLevel(ProgramGroup level, _Branch? branch, int? single, {required bool first})
  {
    final bool lit = identical(level, branch?.level);
    final bool panel = level.programs.isNotEmpty || level.children.any((g) => g.kind == ProgramGroupKind.sector);

    return Padding(
      padding: EdgeInsets.only(top: first ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(level, tour: lit ? programsGroupTarget(ProgramsGroupPart.level) : null),
          if (panel) ...[
            const SizedBox(height: 2),
            _panel(level, branch, single, tour: lit && branch?.cycle == null),
          ],
          for (final ProgramGroup cycle in level.children)
            if (cycle.kind == ProgramGroupKind.cycle) ...[
              const SizedBox(height: 8),
              _head(cycle, tour: identical(cycle, branch?.cycle) ? programsGroupTarget(ProgramsGroupPart.cycle) : null),
              const SizedBox(height: 2),
              _panel(cycle, branch, single, tour: identical(cycle, branch?.cycle)),
            ],
        ],
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

    return MobileSheet(
      eyebrow: 'Percorsi',
      title: widget.subjectName,
      body: [
        if (widget.description != null) ...[
          const SizedBox(height: 12),
          MobileSheetText(widget.description!),
        ],
        const SizedBox(height: 6),
        _buildSummary(shown),
        if (widget.programs.length >= _searchFrom) ...[
          const SizedBox(height: 8),
          MobileSearchField(
            controller: _searchController,
            hintText: 'Cerca percorso...',
            onChanged: _onQuery,
            onGlass: true,
          ),
        ],
        if (tree.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'Nessun percorso trovato.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: MobilePalette.mutedText,
                ),
              ),
            ),
          )
        else
          MobileTourTarget(
            id: programsTourTarget(ProgramsMark.list),
            inflate: _tourListInflate,
            radius: _tourListRadius,
            clipped: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (int index, ProgramGroup level) in tree.indexed)
                  _buildLevel(level, branch, single, first: index == 0),
              ],
            ),
          ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          MobileTourTarget(
            id: programsTourTarget(ProgramsMark.confirm),
            inflate: _tourButtonInflate,
            radius: _tourButtonRadius,
            child: MobileGoldButton(
              label: 'Conferma',
              icon: Icons.check_rounded,
              onPressed: ()
              {
                final Future<void> Function(BuildContext sheet)? remove = widget.onRemove;

                if (_selected.isEmpty && remove != null)
                {
                  remove(context);

                  return;
                }

                finishMobileSheet(context, _selected);
              },
            ),
          ),
          if (widget.onRemove != null) ...[
            const SizedBox(height: 12),
            MobileTourTarget(
              id: programsTourTarget(ProgramsMark.remove),
              inflate: _tourButtonInflate,
              radius: _tourButtonRadius,
              child: MobileDangerButton(
                label: 'Rimuovi disciplina',
                icon: Icons.delete_outline_rounded,
                onPressed: () => widget.onRemove!(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget
{
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context)
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelFill,
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: AppTheme.trialInk.withValues(alpha: _panelEdgeAlpha)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_panelRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
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
        color: MobilePalette.mutedText,
      ),
    );
  }
}

// A level reads as a title, a cycle as a small teal heading.
class _GroupHead extends StatelessWidget
{
  final String title;
  final bool cycle;
  final int chosen;
  final int total;
  final VoidCallback onToggle;

  const _GroupHead({
    required this.title,
    required this.cycle,
    required this.chosen,
    required this.total,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool all = chosen == total;

    return Row(
      children: [
        Expanded(
          child: Text(
            cycle ? title.toUpperCase() : title,
            style: cycle
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppTheme.trialTealDeep,
                  )
                : GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: AppTheme.trialInk,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        _GroupCount(chosen: chosen, total: total),
        MobileSelectAllToggle(selected: all, partial: chosen > 0 && !all, onTap: onToggle),
      ],
    );
  }
}

// A touch on the circle takes the whole sector; anywhere else opens or closes it.
class _SectorLine extends StatelessWidget
{
  final String title;
  final int chosen;
  final int total;
  final bool open;

  // A hairline above, against what comes before it in the panel.
  final bool ruled;

  final VoidCallback onOpen;
  final VoidCallback onToggle;

  const _SectorLine({
    required this.title,
    required this.chosen,
    required this.total,
    required this.open,
    required this.ruled,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool all = chosen == total;
    final Duration turn = MediaQuery.disableAnimationsOf(context) ? Duration.zero : _turn;

    return Semantics(
      button: true,
      expanded: open,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: ruled
                ? Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: _hairlineAlpha)))
                : null,
          ),
          child: Row(
            children: [
              AnimatedRotation(
                turns: open ? 0 : -0.25,
                duration: turn,
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: AppTheme.trialInk.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AnimatedDefaultTextStyle(
                    duration: turn,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: open ? AppTheme.trialTealDeep : AppTheme.trialInk,
                    ),
                    child: Text(title),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GroupCount(chosen: chosen, total: total),
              MobileSelectAllToggle(selected: all, partial: chosen > 0 && !all, onTap: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}
