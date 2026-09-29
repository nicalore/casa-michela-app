import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/association/models/study_program_item.dart';
import '../../../../features/association/models/subject_taxonomy.dart';
import '../../../../shared/widgets/app_check_mark.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_sheet.dart';

// Past this many programmes the list gets a search field, as on the desktop.
const int _searchFrom = 12;

const double _rowRadius = 14;

// Worded as on the desktop.
String programsSummary(int chosen, int total)
{
  return chosen == total ? 'Tutti i percorsi ($total)' : '$chosen di $total percorsi';
}

// Null when dismissed; an empty set gives the discipline up, as on the desktop.
Future<Set<int>?> showMobileProgramsSheet({
  required BuildContext context,
  required String subjectName,
  required List<StudyProgramItem> programs,
  required Set<int> initialSelected,
  required bool removable,
})
{
  return showMobileSheet<Set<int>>(
    context: context,
    builder: (context) => _ProgramsSheet(
      subjectName: subjectName,
      programs: programs,
      initialSelected: initialSelected,
      removable: removable,
    ),
  );
}

class _ProgramsSheet extends StatefulWidget
{
  final String subjectName;
  final List<StudyProgramItem> programs;
  final Set<int> initialSelected;
  final bool removable;

  const _ProgramsSheet({
    required this.subjectName,
    required this.programs,
    required this.initialSelected,
    required this.removable,
  });

  @override
  State<_ProgramsSheet> createState() => _ProgramsSheetState();
}

class _ProgramsSheetState extends State<_ProgramsSheet>
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

  // The track is part of the key, or a course's biennio and triennio would merge.
  Map<String, List<StudyProgramItem>> get _groups
  {
    final String query = _query.toLowerCase();
    final Map<String, List<StudyProgramItem>> groups = {};

    for (final program in widget.programs)
    {
      // Full name: the sector heads the group, not the row, but people still type it.
      if (query.isNotEmpty && !program.fullName.toLowerCase().contains(query))
      {
        continue;
      }

      final String title = programScopeTitle(
        level: program.level,
        sector: program.sector,
        track: program.highSchoolTrack,
      );

      groups.putIfAbsent(title, () => []).add(program);
    }

    return groups;
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
  void _toggleGroup(List<StudyProgramItem> group)
  {
    final bool all = group.every((program) => _selected.contains(program.id));

    setState(()
    {
      for (final program in group)
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

  Widget _buildGroup(String title, List<StudyProgramItem> group)
  {
    final int chosen = group.where((program) => _selected.contains(program.id)).length;
    final bool all = chosen == group.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.trialInk.withValues(alpha: 0.62),
                ),
              ),
            ),
            Text(
              '$chosen/${group.length}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MobilePalette.mutedText,
              ),
            ),
            const SizedBox(width: 10),
            AppCheckMark(
              selected: all,
              partial: chosen > 0 && !all,
              onTap: () => _toggleGroup(group),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final program in group)
          _ProgramRow(
            label: program.name,
            selected: _selected.contains(program.id),
            onTap: () => _toggle(program.id),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Map<String, List<StudyProgramItem>> groups = _groups;

    return MobileSheet(
      eyebrow: 'Percorsi',
      title: widget.subjectName,
      body: [
        const SizedBox(height: 12),
        Text(
          programsSummary(_selected.length, widget.programs.length),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.trialTealDeep,
          ),
        ),
        if (widget.programs.length >= _searchFrom) ...[
          const SizedBox(height: 14),
          MobileSearchField(
            controller: _searchController,
            hintText: 'Cerca percorso...',
            onChanged: (value) => setState(() => _query = value),
            onGlass: true,
          ),
        ],
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              'Nessun percorso trovato.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: MobilePalette.mutedText,
              ),
            ),
          )
        else
          for (final entry in groups.entries) _buildGroup(entry.key, entry.value),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          MobileGoldButton(
            label: 'Conferma',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(_selected),
          ),
          if (widget.removable)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(<int>{}),
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'Rimuovi disciplina',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialDanger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgramRow extends StatelessWidget
{
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProgramRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          // Not Colors.transparent (black at zero alpha): the fade would pass through grey.
          color: selected ? kPickedSurface : kPickedSurface.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(_rowRadius),
        ),
        child: Row(
          children: [
            AppCheckMark(selected: selected, onTap: null),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.35,
                  color: selected ? AppTheme.trialTealDeep : AppTheme.trialInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
