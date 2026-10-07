import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/association/association_strings.dart';
import '../../../../features/association/models/subject_taxonomy.dart';
import '../../../../features/association/teacher_opinions.dart';
import '../../../../features/people/models/teacher_subject_item.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_dismiss_button.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../settings/widgets/mobile_choice_tile.dart';

const double _tileGap = 8;

// Null when dismissed; a tap on an order chooses it and closes.
Future<TeacherSort?> showMobileTeacherSortSheet({
  required BuildContext context,
  required TeacherSort current,
})
{
  return showMobileSheet<TeacherSort>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: kAssociationTeachersLabel,
      title: kTeachersSortHint,
      body: [
        const SizedBox(height: 16),
        for (final sort in TeacherSort.values)
          Padding(
            padding: const EdgeInsets.only(bottom: _tileGap),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => finishMobileSheet(context, sort),
              child: MobileChoiceTile(label: sort.label, chosen: sort == current),
            ),
          ),
      ],
    ),
  );
}

// Null when dismissed; the choice applies only through "Applica", as on the desktop.
Future<Set<int>?> showMobileSubjectFilterSheet({
  required BuildContext context,
  required List<TeacherSubjectItem> options,
  required Set<int> selected,
})
{
  return showMobileSheet<Set<int>>(
    context: context,
    builder: (_) => _SubjectFilterSheet(options: options, selected: selected),
  );
}

class _SubjectFilterSheet extends StatefulWidget
{
  final List<TeacherSubjectItem> options;
  final Set<int> selected;

  const _SubjectFilterSheet({required this.options, required this.selected});

  @override
  State<_SubjectFilterSheet> createState() => _SubjectFilterSheetState();
}

class _SubjectFilterSheetState extends State<_SubjectFilterSheet>
{
  final TextEditingController _search = TextEditingController();

  late final Set<int> _selected = {...widget.selected};

  @override
  void dispose()
  {
    _search.dispose();
    super.dispose();
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

  void _reset()
  {
    setState(()
    {
      _selected.clear();
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final String query = _search.text.toLowerCase();
    final List<TeacherSubjectItem> shown = [
      for (final option in widget.options)
        if (option.subjectName.toLowerCase().contains(query)) option,
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MobileSheet(
        eyebrow: 'Filtro',
        title: kSubjectsFilterTitle,
        body: [
          const SizedBox(height: 14),
          MobileSearchField(
            controller: _search,
            hintText: kSubjectsFilterHint,
            onChanged: (_) => setState(() {}),
            onGlass: true,
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                kMobileNoSearchMatch,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: MobilePalette.mutedText,
                ),
              ),
            )
          else
            for (final group in groupByArea(shown, (option) => option.subjectArea)) ...[
              const SizedBox(height: 18),
              MobileSelectGroupHead(title: group.title),
              const SizedBox(height: 6),
              for (final option in group.items)
                MobileSelectRow(
                  title: option.subjectName,
                  selected: _selected.contains(option.subjectId),
                  onTap: () => _toggle(option.subjectId),
                ),
            ],
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(
            children: [
              Expanded(
                child: MobileDismissButton(label: 'Azzera', icon: Icons.refresh_rounded, onPressed: _reset),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MobileGoldButton(
                  label: 'Applica',
                  icon: Icons.check_rounded,
                  onPressed: () => finishMobileSheet(context, _selected),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
