import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../association/models/study_program_item.dart';
import '../../association/models/subject_taxonomy.dart';
import 'person_detail_widgets.dart';

// Past this many programmes the list gets a field to shorten it: under it,
// searching a list you can already see is a control that does nothing.
const int _searchFrom = 12;

// A programme as the picker reads it: which group it belongs to, and the name
// it keeps once the group has said the rest.
class _ScopedProgram
{
  final StudyProgramItem program;
  final String group;

  const _ScopedProgram({required this.program, required this.group});

  String get label => program.name;
}

// Where a discipline is taught, chosen programme by programme.
//
// The list used to be a flat wrap of chips carrying the whole name of every
// programme — ten of them, each wrapping onto three lines, for a discipline as
// common as Italian grammar. Here they are gathered by school level and by
// sector, so that a row carries only what tells it apart from its neighbours.
//
// The sector is a field of the programme. An earlier draft read it out of the
// name, splitting on the bar somebody had typed there by habit: it worked on
// the data at hand and would have quietly stopped grouping anything the day
// someone wrote a name their own way.
class ProgramScopeDialog extends StatefulWidget
{
  final String subjectName;
  final List<StudyProgramItem> programs;
  final Set<int> initialSelected;

  // Called with the chosen ids on confirm. An empty set means the discipline is
  // being given up: the caller decides what that means.
  final ValueChanged<Set<int>> onSave;

  const ProgramScopeDialog({
    super.key,
    required this.subjectName,
    required this.programs,
    required this.initialSelected,
    required this.onSave,
  });

  @override
  State<ProgramScopeDialog> createState() => _ProgramScopeDialogState();
}

class _ProgramScopeDialogState extends State<ProgramScopeDialog>
{
  final TextEditingController _searchController = TextEditingController();

  late Set<int> _selected;
  String _query = '';

  @override
  void initState()
  {
    super.initState();
    _selected = Set<int>.from(widget.initialSelected);
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  // The heading a programme stands under: the level, which every programme has,
  // and the sector where there is one — primary and middle school have no
  // streams to tell apart.
  _ScopedProgram _scope(StudyProgramItem program)
  {
    return _ScopedProgram(
      program: program,
      group: programScopeTitle(level: program.level, sector: program.sector),
    );
  }

  // Groups in the order their first programme appears, so a list read twice
  // reads the same way.
  Map<String, List<_ScopedProgram>> get _groups
  {
    final query = _query.toLowerCase();
    final groups = <String, List<_ScopedProgram>>{};

    for (final program in widget.programs)
    {
      final scoped = _scope(program);

      // Matched against the full name, sector included: the sector is on the
      // heading rather than on the row, but it is still what someone might type.
      if (query.isNotEmpty && !program.fullName.toLowerCase().contains(query))
      {
        continue;
      }

      groups.putIfAbsent(scoped.group, () => []).add(scoped);
    }

    return groups;
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

  // A heading answers for the rows under it: all of them on, or all of them off.
  // Half chosen counts as off, so the first press turns the group on rather than
  // wiping what was already there.
  void _toggleGroup(List<_ScopedProgram> group, bool selected)
  {
    setState(()
    {
      for (final scoped in group)
      {
        if (selected)
        {
          _selected.add(scoped.program.id);
        }
        else
        {
          _selected.remove(scoped.program.id);
        }
      }
    });
  }

  // How many programmes are inside. The count alone: the "all / none" that sat
  // next to it answered for the whole dialog, whereas the answer needed is
  // almost always for one sector, and that is given by its header's tick.
  Widget _buildSummary()
  {
    final int total = widget.programs.length;
    final int chosen = _selected.length;

    return Text(
      chosen == total ? 'Tutti i percorsi ($total)' : '$chosen di $total percorsi',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialTealDeep,
      ),
    );
  }

  Widget _buildGroup(String title, List<_ScopedProgram> group)
  {
    final int chosen =
        group.where((scoped) => _selected.contains(scoped.program.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _GroupHeading(
          title: title,
          chosen: chosen,
          total: group.length,
          onToggle: (selected) => _toggleGroup(group, selected),
        ),
        for (final scoped in group)
          _ProgramRow(
            label: scoped.label,
            selected: _selected.contains(scoped.program.id),
            onSelected: (selected) => _toggle(scoped.program.id, selected),
          ),
        const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final groups = _groups;

    return AppDialogStack(
      eyebrow: 'Percorsi',
      title: widget.subjectName,
      maxWidth: 720,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'CONFERMA',
          icon: Icons.check_rounded,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: ()
          {
            widget.onSave(_selected);
            Navigator.of(context).pop();
          },
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummary(),
              if (widget.programs.length >= _searchFrom) ...[
                const SizedBox(height: 14),
                AppSearchField(
                  controller: _searchController,
                  hintText: 'Cerca percorso...',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ],
          ),
        ),
        AppDialogPill(
          expand: true,
          child: groups.isEmpty
              ? const PersonEmptyState(message: 'Nessun percorso trovato.')
              : SingleChildScrollView(
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
    );
  }
}

// The name of a group and, at its right, the mark that answers for the whole of
// it: full, empty, or half filled where only some of the rows are on.
class _GroupHeading extends StatelessWidget
{
  final String title;
  final int chosen;
  final int total;
  final ValueChanged<bool> onToggle;

  const _GroupHeading({
    required this.title,
    required this.chosen,
    required this.total,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool all = chosen == total;
    final bool some = chosen > 0 && !all;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: AppEyebrow(title)),
          Text(
            '$chosen/$total',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(width: 10),
          AppCheckMark(
            selected: all,
            partial: some,
            onTap: () => onToggle(!all),
          ),
        ],
      ),
    );
  }
}

// One programme. A row rather than a chip: these names run to a line of text,
// and a chip that wraps three times has stopped being a chip.
class _ProgramRow extends StatefulWidget
{
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _ProgramRow({
    required this.label,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // Transparent in this colour: `Colors.transparent` is black at
            // zero opacity, and fading over it the row passes through grey.
            color: widget.selected
                ? kPickedSurface
                : kPickedSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(14),
            // As in the disciplines: gold says where the pointer is, grey says
            // nothing and flickers.
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
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.35,
                    color: widget.selected ? AppTheme.trialTealDeep : AppTheme.trialInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
