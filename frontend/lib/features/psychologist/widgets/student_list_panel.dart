import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../../people/models/person_item.dart';
import '../psychologist_strings.dart';
import 'certifications_dialog.dart' show kCertificationLabels;
import 'student_sheet.dart' show CertificationChip;

const double _panelRadius = 32;
const double _rowHeight = 68;
const double _faceSize = 52;

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
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_panelRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            controller: searchController,
            onChanged: onSearchChanged,
            hintText: kStudentSearchHint,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AppCountFilterPill(
                label: 'Filtri',
                icon: Icons.tune_rounded,
                count: filtersCount,
                onOpen: onOpenFilters,
                onClear: onClearFilters,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  studentsCount(students.length),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRect(
              child: ScrollEdgeFade(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 18),
                  itemCount: students.length,
                  itemBuilder: (context, index)
                  {
                    final PersonItem student = students[index];

                    return _StudentRow(
                      student: student,
                      selected: student.fiscalCode == selectedCode,
                      onTap: () => onSelected(student),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatefulWidget
{
  final PersonItem student;
  final bool selected;
  final VoidCallback onTap;

  const _StudentRow({required this.student, required this.selected, required this.onTap});

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
          constraints: const BoxConstraints(minHeight: _rowHeight),
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
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
              const SizedBox(width: 9),
              PersonAvatar(person: student, size: _faceSize),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.firstName} ${student.lastName}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    if (labels.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [for (final label in labels) CertificationChip(label)],
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
