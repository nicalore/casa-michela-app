import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../association/models/subject_taxonomy.dart';
import 'person_detail_widgets.dart';
import 'person_row_models.dart';

// Wide enough for a school name plus a programme's sector, cycle and name.
const double kSchoolYearsDialogWidth = 1280;

const int _schoolYearStartMonth = 9;

// Must cover all eight years a programme can span.
const Map<int, String> kGradeLabels = {
  1: 'I',
  2: 'II',
  3: 'III',
  4: 'IV',
  5: 'V',
  6: 'VI',
  7: 'VII',
  8: 'VIII',
};

final Map<String, int> kGradeNumbers = {
  for (final entry in kGradeLabels.entries) entry.value: entry.key,
};

// The school year turns over on 1 September; the date is injectable for tests.
int currentSchoolYearStart([DateTime? today])
{
  final now = today ?? DateTime.now();

  return now.month < _schoolYearStartMonth ? now.year - 1 : now.year;
}

String gradeLabel(int grade) => kGradeLabels[grade] ?? grade.toString();

class SchoolEnrollmentSummaryRow extends StatelessWidget
{
  final SchoolEnrollmentRowData row;

  // Errors by field: `year`, `school`, `program`, `grade`.
  final Map<String, String?> errors;

  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const SchoolEnrollmentSummaryRow({
    super.key,
    required this.row,
    required this.errors,
    required this.onEdit,
    required this.onRemove,
  });

  String get _yearSpan
  {
    final int? year = int.tryParse(row.yearCtrl.text.trim());

    return year == null
        ? 'Anno scolastico da completare'
        : 'Anno scolastico $year/${year + 1}';
  }

  String? get _firstError
  {
    for (final message in errors.values)
    {
      if (message != null)
      {
        return message;
      }
    }

    return null;
  }

  Widget _buildHeading()
  {
    final String? error = _firstError;

    return Row(
      children: [
        Expanded(
          child: OverflowTooltipText(
            text: _yearSpan,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Tooltip(
              message: error,
              textStyle: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: AppTheme.tooltipDecoration,
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.trialDanger,
                size: 22,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Tooltip(
            message: 'Modifica',
            waitDuration: const Duration(milliseconds: 400),
            child: FadeHoverIconButton(
              icon: Icons.edit_rounded,
              color: AppTheme.trialTealDeep,
              hoverColor: AppTheme.trialGoldSurface,
              onTap: onEdit,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: 'Rimuovi',
            waitDuration: const Duration(milliseconds: 400),
            child: FadeHoverIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.trialDanger,
              hoverColor: AppTheme.trialGoldSurface,
              onTap: onRemove,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<_RowFact> facts = [
      _RowFact(
        'Livello',
        row.program == null ? null : schoolLevelShortLabel(row.program!.level),
        flex: 2,
      ),
      _RowFact(
        'Scuola',
        row.school == null ? null : '${row.school!.name} (${row.school!.city})',
        flex: 4,
        lines: 2,
      ),
      _RowFact('Classe', row.grade),
      _RowFact('Percorso', row.program?.fullName, flex: 4, lines: 2),
    ];

    return PersonEditRow(
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeading(),
            const SizedBox(height: 12),
            _RowFactsLine(facts: facts),
          ],
        ),
      ),
    );
  }
}

class _RowFact
{
  final String label;

  // Null when the school or programme is no longer in the catalogue.
  final String? value;

  final int flex;

  final int lines;

  const _RowFact(this.label, this.value, {this.flex = 1, this.lines = 1});

  double get minWidth => 70 + 30.0 * flex;
}

class _RowFactsLine extends StatelessWidget
{
  static const double _gap = 16;

  final List<_RowFact> facts;

  const _RowFactsLine({required this.facts});

  Widget _buildFact(_RowFact fact)
  {
    final String? value = fact.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fact.label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 4),
        OverflowTooltipText(
          text: value ?? missingValue,
          maxLines: fact.lines,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: value == null ? AppTheme.trialMutedText : AppTheme.trialInk,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double needed =
        facts.fold<double>(0, (sum, fact) => sum + fact.minWidth) +
            _gap * (facts.length - 1);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < needed)
        {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildFact(facts[i]),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(flex: facts[i].flex, child: _buildFact(facts[i])),
            ],
          ],
        );
      },
    );
  }
}
