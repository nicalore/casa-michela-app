import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../../people/models/person_item.dart';
import '../psychologist_strings.dart';
import 'certifications_dialog.dart' show kCertificationLabels;
import 'student_sheet.dart' show CertificationChip;

const double _panelRadius = 32;
const double _rowHeight = 68;
const double _faceSize = 52;

// Below the wide window (AppPageDensity), and in the heading's menu.
const double _densePanelRadius = 24;
const double _densePanelPadding = 14;
const double _denseRowHeight = 56;
const double _denseFaceSize = 40;
const double _menuRadius = 18;
const double _menuPadding = 10;

const String kTourStudentList = 'psychologist.list';
const String kTourStudentSearch = 'psychologist.search';
const String kTourStudentFilters = 'psychologist.filters';
const String kTourStudentRows = 'psychologist.rows';

const double _markWidth = 3;
const double _markHeight = 20;
const Duration _markFade = Duration(milliseconds: 150);

class StudentListPanel extends StatelessWidget
{
  final List<PersonItem> students;

  // Null while none is open.
  final String? selectedCode;

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  final int filtersCount;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;

  final ValueChanged<PersonItem> onSelected;

  // Inside the heading's menu below 1000 px: a menu card, and no tour parts (the tour waits for a wider window).
  final bool inMenu;

  const StudentListPanel({
    super.key,
    required this.students,
    required this.selectedCode,
    required this.searchController,
    required this.onSearchChanged,
    required this.filtersCount,
    required this.onOpenFilters,
    required this.onClearFilters,
    required this.onSelected,
    this.inMenu = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool dense = inMenu || AppPageDensity.of(context);
    final double padding = inMenu ? _menuPadding : (dense ? _densePanelPadding : 18);

    final Widget panel = Container(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(inMenu ? _menuRadius : (dense ? _densePanelRadius : _panelRadius)),
        boxShadow: inMenu ? AppTheme.overlayShadow : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopTourTarget(
            id: inMenu ? null : kTourStudentSearch,
            child: AppSearchField(
              controller: searchController,
              onChanged: onSearchChanged,
              hintText: kStudentSearchHint,
            ),
          ),
          SizedBox(height: dense ? 10 : 14),
          Row(
            children: [
              DesktopTourTarget(
                id: inMenu ? null : kTourStudentFilters,
                child: AppCountFilterPill(
                  label: 'Filtri',
                  icon: Icons.tune_rounded,
                  count: filtersCount,
                  onOpen: onOpenFilters,
                  onClear: onClearFilters,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  studentsCount(students.length),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: dense ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 6 : 12),
          Expanded(
            child: DesktopTourTarget(
              id: inMenu ? null : kTourStudentRows,
              child: ClipRect(
                child: ScrollEdgeFade(
                  child: ListView.builder(
                    padding: EdgeInsets.only(bottom: dense ? 12 : 18),
                    itemCount: students.length,
                    itemBuilder: (context, index)
                    {
                      final PersonItem student = students[index];

                      return _StudentRow(
                        student: student,
                        selected: student.fiscalCode == selectedCode,
                        dense: dense,
                        onTap: () => onSelected(student),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (inMenu)
    {
      // The search field needs a Material above it, which the overlay does not give.
      return Material(color: Colors.transparent, child: panel);
    }

    return DesktopTourTarget(id: kTourStudentList, child: panel);
  }
}

class _StudentRow extends StatefulWidget
{
  final PersonItem student;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;

  const _StudentRow({required this.student, required this.selected, required this.dense, required this.onTap});

  @override
  State<_StudentRow> createState() => _StudentRowState();
}

class _StudentRowState extends State<_StudentRow>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final PersonItem student = widget.student;
    final bool dense = widget.dense;

    final List<String> labels = [
      for (final entry in kCertificationLabels.entries)
        if (student.certificationTypes.contains(entry.key)) entry.value,
    ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: dense ? _denseRowHeight : _rowHeight),
          padding: dense ? const EdgeInsets.fromLTRB(12, 6, 8, 6) : const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: widget.selected || _hover ? 1 : 0),
                duration: _markFade,
                curve: Curves.easeOut,
                builder: (context, factor, child) => Transform.scale(
                  scaleY: factor,
                  alignment: Alignment.center,
                  child: child,
                ),
                child: Container(
                  width: _markWidth,
                  height: _markHeight,
                  decoration: BoxDecoration(
                    color: AppTheme.trialGold,
                    borderRadius: BorderRadius.circular(_markWidth),
                  ),
                ),
              ),
              SizedBox(width: dense ? 8 : 9),
              PersonAvatar(person: student, size: dense ? _denseFaceSize : _faceSize),
              SizedBox(width: dense ? 10 : 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.firstName} ${student.lastName}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: dense ? 14.5 : 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    if (labels.isNotEmpty) ...[
                      SizedBox(height: dense ? 3 : 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [for (final label in labels) CertificationChip(label, dense: dense)],
                      ),
                    ],
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
