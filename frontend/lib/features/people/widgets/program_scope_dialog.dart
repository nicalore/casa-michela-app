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

// Past this many programmes the list gets a search field.
const int _searchFrom = 12;

class _ScopedProgram
{
  final StudyProgramItem program;
  final String group;

  const _ScopedProgram({required this.program, required this.group});

  String get label => program.name;
}

class ProgramScopeDialog extends StatefulWidget
{
  final String subjectName;
  final List<StudyProgramItem> programs;
  final Set<int> initialSelected;

  // An empty set means the discipline is being given up.
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

  _ScopedProgram _scope(StudyProgramItem program)
  {
    return _ScopedProgram(
      program: program,
      group: programScopeTitle(level: program.level, sector: program.sector),
    );
  }

  Map<String, List<_ScopedProgram>> get _groups
  {
    final query = _query.toLowerCase();
    final groups = <String, List<_ScopedProgram>>{};

    for (final program in widget.programs)
    {
      final scoped = _scope(program);

      // Matched against the full name: the sector is on the heading, not the
      // row, but is still what someone might type.
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

  // Half chosen counts as off, so the first press turns the group on.
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
            // Not Colors.transparent (black at zero alpha): the fade would pass
            // through grey.
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
