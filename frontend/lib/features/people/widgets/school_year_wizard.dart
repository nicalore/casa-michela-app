import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/card_scroll_area.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/school_item.dart';
import '../../association/models/study_program_item.dart';
import '../../association/models/subject_taxonomy.dart';
import '../edit/widgets/person_edit_guide.dart';
import 'person_detail_widgets.dart';
import 'person_row_models.dart';
import 'school_enrollment_edit_row.dart';

// Wide enough for a school's full name and a programme's sector, cycle and name.
const double _cardWidth = 800;

const double _stackWidth =
    _cardWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap) + 64;

const double _yearFieldWidth = 150;

// Highest class per level; the programme's own span narrows it further.
const Map<String, int> _lastGradeByLevel = <String, int>{
  'PRIMARY_SCHOOL': 5,
  'MIDDLE_SCHOOL': 3,
  'HIGH_SCHOOL': 5,
};

// Ordered lowest level first.
const List<String> _levelsUpwards = <String>[
  'PRIMARY_SCHOOL',
  'MIDDLE_SCHOOL',
  'HIGH_SCHOOL',
];

enum _Step
{
  when(
    'In quale anno scolastico?',
    'Indica l\'anno in cui è iniziato e il livello frequentato.',
  ),

  school(
    'Quale scuola?',
    'Indica la scuola frequentata dallo studente nell\'anno scolastico inserito.',
  ),

  grade(
    'Che classe fa?',
    'Indica quale classe frequenta nell\'anno scolastico inserito.',
  ),

  program(
    'Quale indirizzo?',
    'Indica il percorso di studi frequentato dallo studente nell\'anno scolastico inserito.',
  );

  final String question;
  final String hint;

  const _Step(this.question, this.hint);
}

class SchoolYearChoice
{
  int? startYear;
  String? level;
  SchoolItem? school;

  // Roman numerals, as the row data stores it.
  String? grade;

  StudyProgramItem? program;

  SchoolYearChoice({
    this.startYear,
    this.level,
    this.school,
    this.grade,
    this.program,
  });

  // The level comes from the programme, so it stays null while the programme is.
  factory SchoolYearChoice.ofRow(SchoolEnrollmentRowData row)
  {
    return SchoolYearChoice(
      startYear: int.tryParse(row.yearCtrl.text.trim()),
      level: row.program?.level,
      school: row.school,
      grade: row.grade,
      program: row.program,
    );
  }
}

// The classes of a level, as Roman numerals.
List<String> gradeOptionsForLevel(String? level)
{
  final int? last = level == null ? null : _lastGradeByLevel[level];

  if (last == null)
  {
    return const [];
  }

  return [
    for (var grade = 1; grade <= last; grade++)
      if (kGradeLabels[grade] != null) kGradeLabels[grade]!,
  ];
}

List<SchoolItem> schoolsOfferingLevel(
  List<SchoolItem> schools,
  List<StudyProgramItem> allPrograms,
  String? level,
)
{
  if (level == null)
  {
    return const [];
  }

  return schools
      .where((school) => programsOfSchool(school, allPrograms)
          .any((program) => program.level == level))
      .toList();
}

// Resolved by id against the catalogue: a school can list a removed programme.
List<StudyProgramItem> programsOfSchool(
  SchoolItem? school,
  List<StudyProgramItem> allPrograms,
)
{
  if (school == null)
  {
    return const [];
  }

  final Set<int> offered = school.studyPrograms.map((option) => option.id).toSet();

  return allPrograms.where((program) => offered.contains(program.id)).toList();
}

List<StudyProgramItem> programsForChoice(
  SchoolItem? school,
  List<StudyProgramItem> allPrograms,
  String? level,
  String? grade,
)
{
  final int? year = grade == null ? null : kGradeNumbers[grade];

  if (level == null || year == null)
  {
    return const [];
  }

  return programsOfSchool(school, allPrograms)
      .where((program) =>
          program.level == level &&
          program.minYear <= year &&
          year <= program.maxYear)
      .toList();
}

class SchoolYearWizard extends StatefulWidget
{
  final List<SchoolItem> allSchools;
  final List<StudyProgramItem> allPrograms;

  // Years already used, which the wizard refuses; excludes the row being edited.
  final Set<int> takenYears;

  // Answers to start from; null opens on the current school year.
  final SchoolYearChoice? initial;

  final bool isEditing;

  final ValueChanged<SchoolYearChoice> onConfirmed;

  const SchoolYearWizard({
    super.key,
    required this.allSchools,
    required this.allPrograms,
    required this.onConfirmed,
    this.takenYears = const {},
    this.initial,
    this.isEditing = false,
  });

  @override
  State<SchoolYearWizard> createState() => _SchoolYearWizardState();
}

class _SchoolYearWizardState extends State<SchoolYearWizard>
{
  late final SchoolYearChoice _choice = widget.initial ?? SchoolYearChoice();

  late final TextEditingController _yearController = TextEditingController(
    text: (_choice.startYear ?? currentSchoolYearStart()).toString(),
  );

  final TextEditingController _schoolSearchController = TextEditingController();
  final TextEditingController _programSearchController = TextEditingController();

  String _schoolQuery = '';
  String _programQuery = '';

  int _step = 0;
  bool _movingForward = true;

  @override
  void dispose()
  {
    _yearController.dispose();
    _schoolSearchController.dispose();
    _programSearchController.dispose();
    super.dispose();
  }

  _Step get _current => _Step.values[_step];

  void _goTo(int step)
  {
    if (step > _step && _blockedReason(_current) != null)
    {
      return;
    }

    setState(()
    {
      _movingForward = step > _step;
      _step = step.clamp(0, _Step.values.length - 1);
    });
  }

  int? get _year
  {
    final String text = _yearController.text.trim();

    return RegExp(r'^\d{4}$').hasMatch(text) ? int.parse(text) : null;
  }

  String? _blockedReason(_Step step)
  {
    return switch (step)
    {
      _Step.when => _whenBlockedReason,
      _Step.school => _choice.school == null ? 'Scegli la scuola per andare avanti.' : null,
      _Step.grade => _choice.grade == null ? 'Scegli la classe per andare avanti.' : null,
      _Step.program => _choice.program == null ? 'Scegli il percorso di studi.' : null,
    };
  }

  String? get _whenBlockedReason
  {
    final int? year = _year;

    if (year == null)
    {
      return 'Inserisci l\'anno di inizio, quattro cifre.';
    }

    if (year > currentSchoolYearStart())
    {
      return 'Non è possibile inserire un anno scolastico futuro.';
    }

    if (widget.takenYears.contains(year))
    {
      return 'C\'è già un anno scolastico ${_yearSpan(year)}.';
    }

    if (_choice.level == null)
    {
      return 'Scegli il livello di scuola per andare avanti.';
    }

    return null;
  }

  String _yearSpan(int year) => '$year/${year + 1}';

  // Changing the level clears the answers that depend on it.
  void _pickLevel(String level)
  {
    setState(()
    {
      _choice.level = level;
      _choice.school = null;
      _choice.grade = null;
      _choice.program = null;
    });
  }

  void _pickSchool(SchoolItem school)
  {
    setState(()
    {
      _choice.school = school;
      _choice.program = null;
    });
  }

  void _pickGrade(String grade)
  {
    setState(()
    {
      _choice.grade = grade;
      _choice.program = null;
    });
  }

  void _confirm()
  {
    for (final step in _Step.values)
    {
      final String? reason = _blockedReason(step);

      if (reason != null)
      {
        setState(()
        {
          _movingForward = step.index > _step;
          _step = step.index;
        });

        CustomSnackBar.show(context: context, message: reason, isError: true);

        return;
      }
    }

    _choice.startYear = _year;

    widget.onConfirmed(_choice);
    Navigator.of(context).pop();
  }

  Widget _buildWhenStep()
  {
    final int? year = _year;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: _yearFieldWidth,
              child: AppTextField(
                controller: _yearController,
                label: 'Anno di inizio',
                nothingAbove: true,
                hintText: 'Es. ${currentSchoolYearStart()}',
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Padding(
                // Sits on the field's baseline, not on its label's.
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  year == null ? '' : 'Anno scolastico ${_yearSpan(year)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 10),
          child: AppFieldLabel('Livello di scuola'),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final level in schoolLevels)
              AppSelectableChip(
                label: level.compactLabel,
                selected: _choice.level == level.value,
                onSelected: (_) => _pickLevel(level.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSchoolStep()
  {
    final String query = _schoolQuery.toLowerCase();

    final List<SchoolItem> offering =
        schoolsOfferingLevel(widget.allSchools, widget.allPrograms, _choice.level);

    final List<SchoolItem> schools = offering
        .where((school) =>
            query.isEmpty ||
            '${school.name} ${school.city} ${school.province}'
                .toLowerCase()
                .contains(query))
        .toList();

    return _buildPickStep(
      controller: _schoolSearchController,
      hintText: 'Cerca scuola...',
      showSearch: offering.isNotEmpty,
      onQueryChanged: (value) => setState(() => _schoolQuery = value),
      empty: offering.isEmpty
          ? 'Nessuna scuola offre un percorso di questo livello.'
          : 'Nessuna scuola trovata per questa ricerca.',
      rows: [
        for (final school in schools)
          _PickRow(
            key: ValueKey('school-${school.id}'),
            name: school.name,
            subtitle: '${school.city} (${school.province})',
            selected: _choice.school?.id == school.id,
            onSelected: () => _pickSchool(school),
          ),
      ],
    );
  }

  Widget _buildGradeStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: AppFieldLabel('Classe'),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final grade in gradeOptionsForLevel(_choice.level))
              AppSelectableChip(
                label: grade,
                selected: _choice.grade == grade,
                onSelected: (_) => _pickGrade(grade),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgramStep()
  {
    final String query = _programQuery.toLowerCase();

    final List<StudyProgramItem> offered = programsForChoice(
      _choice.school,
      widget.allPrograms,
      _choice.level,
      _choice.grade,
    );

    final List<StudyProgramItem> programs = offered
        .where((program) =>
            query.isEmpty || program.fullName.toLowerCase().contains(query))
        .toList();

    return _buildPickStep(
      controller: _programSearchController,
      hintText: 'Cerca percorso...',
      showSearch: offered.isNotEmpty,
      onQueryChanged: (value) => setState(() => _programQuery = value),
      empty: offered.isEmpty
          ? 'La scuola non offre percorsi di questo livello per la classe scelta.'
          : 'Nessun percorso trovato per questa ricerca.',
      rows: [
        for (final program in programs)
          _PickRow(
            key: ValueKey('program-${program.id}'),
            eyebrow: program.scopeLine,
            name: program.name,
            subtitle: descriptionOrNull(program.description),
            selected: _choice.program?.id == program.id,
            onSelected: () => setState(() => _choice.program = program),
          ),
      ],
    );
  }

  Widget _buildPickStep({
    required TextEditingController controller,
    required String hintText,
    required bool showSearch,
    required ValueChanged<String> onQueryChanged,
    required String empty,
    required List<Widget> rows,
  })
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSearch) ...[
          AppSearchField(
            controller: controller,
            hintText: hintText,
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 14),
        ],
        if (rows.isEmpty)
          PersonEmptyState(message: empty)
        else
          CardScrollArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
      ],
    );
  }

  Widget _buildStep()
  {
    return switch (_current)
    {
      _Step.when => _buildWhenStep(),
      _Step.school => _buildSchoolStep(),
      _Step.grade => _buildGradeStep(),
      _Step.program => _buildProgramStep(),
    };
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Passo ${_step + 1} di ${_Step.values.length}',
      title: widget.isEditing
          ? 'Modifica anno scolastico'
          : 'Aggiungi anno scolastico',
      maxWidth: _stackWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: widget.isEditing ? 'SALVA' : 'AGGIUNGI',
          icon: Icons.check_rounded,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _confirm,
        ),
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _cardWidth),
            child: AppDialogPill(
              expand: true,
              child: PersonEditGuide(
                question: _current.question,
                hint: _current.hint,
              ),
            ),
          ),
        ),
        AppCarouselFrame(
          index: _step,
          movingForward: _movingForward,
          maxContentWidth: _cardWidth,
          canGoBack: _step > 0,
          canGoForward: _step < _Step.values.length - 1,
          forwardBlockedReason: _blockedReason(_current),
          onBack: () => _goTo(_step - 1),
          onForward: () => _goTo(_step + 1),
          child: AppDialogPill(expand: true, child: _buildStep()),
        ),
      ],
    );
  }
}

class _PickRow extends StatefulWidget
{
  final String? eyebrow;
  final String name;
  final String? subtitle;

  final bool selected;
  final VoidCallback onSelected;

  const _PickRow({
    super.key,
    this.eyebrow,
    required this.name,
    this.subtitle,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_PickRow> createState() => _PickRowState();
}

class _PickRowState extends State<_PickRow>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final String? eyebrow = widget.eyebrow;
    final String? subtitle = widget.subtitle;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // Not Colors.transparent: black at zero alpha fades through grey.
            color: widget.selected
                ? kPickedSurface
                : kPickedSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(16),
            // Border always present (transparent) so hover does not shift the contents.
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
                    if (eyebrow != null) ...[
                      OverflowTooltipText(
                        text: eyebrow.toUpperCase(),
                        maxLines: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppTheme.trialMutedText,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    OverflowTooltipText(
                      text: widget.name,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      OverflowTooltipText(
                        text: subtitle,
                        maxLines: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.trialMutedText,
                        ),
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

void showSchoolYearWizard({
  required BuildContext context,
  required List<SchoolItem> allSchools,
  required List<StudyProgramItem> allPrograms,
  required Set<int> takenYears,
  required ValueChanged<SchoolYearChoice> onConfirmed,
  SchoolYearChoice? initial,
  bool isEditing = false,
})
{
  showBlurredDialog(
    context: context,
    barrierLabel: 'SchoolYearWizard',
    builder: (context) => SchoolYearWizard(
      allSchools: allSchools,
      allPrograms: allPrograms,
      takenYears: takenYears,
      initial: initial,
      isEditing: isEditing,
      onConfirmed: onConfirmed,
    ),
  );
}

SchoolEnrollmentRowData schoolEnrollmentRowOf(SchoolYearChoice choice)
{
  return SchoolEnrollmentRowData.empty(
    year: choice.startYear!.toString(),
    school: choice.school,
    program: choice.program,
    grade: choice.grade,
  );
}

void applySchoolYearChoice(SchoolEnrollmentRowData row, SchoolYearChoice choice)
{
  row.yearCtrl.text = choice.startYear!.toString();
  row.school = choice.school;
  row.program = choice.program;
  row.grade = choice.grade;
}

// Newest school year first.
void sortSchoolYearRows(List<SchoolEnrollmentRowData> rows)
{
  int yearOf(SchoolEnrollmentRowData row) => int.tryParse(row.yearCtrl.text.trim()) ?? 0;

  rows.sort((a, b) => yearOf(b).compareTo(yearOf(a)));
}

// Guesses the year before the oldest row: one class back, one level down when
// there is no class before. Null when there is nothing to infer from.
SchoolYearChoice? previousSchoolYearOf(List<SchoolEnrollmentRowData> rows)
{
  SchoolEnrollmentRowData? oldest;
  int? oldestYear;

  for (final row in rows)
  {
    final int? year = int.tryParse(row.yearCtrl.text.trim());

    if (year != null && (oldestYear == null || year < oldestYear))
    {
      oldestYear = year;
      oldest = row;
    }
  }

  if (oldest == null || oldestYear == null)
  {
    return null;
  }

  final SchoolYearChoice choice = SchoolYearChoice(startYear: oldestYear - 1);

  final String? level = oldest.program?.level;
  final int? grade = oldest.grade == null ? null : kGradeNumbers[oldest.grade];

  if (level == null || grade == null)
  {
    return choice;
  }

  if (grade > 1)
  {
    final int before = grade - 1;
    final StudyProgramItem program = oldest.program!;

    choice.level = level;
    choice.grade = kGradeLabels[before];
    choice.school = oldest.school;

    if (program.minYear <= before && before <= program.maxYear)
    {
      choice.program = program;
    }

    return choice;
  }

  final int index = _levelsUpwards.indexOf(level);

  // Nothing precedes the first class of primary school.
  if (index > 0)
  {
    final String below = _levelsUpwards[index - 1];

    choice.level = below;
    choice.grade = kGradeLabels[_lastGradeByLevel[below]!];
  }

  return choice;
}

// Years already used; `except` skips the row being edited.
Set<int> takenSchoolYears(List<SchoolEnrollmentRowData> rows, {int? except})
{
  final Set<int> years = {};

  for (var i = 0; i < rows.length; i++)
  {
    if (i == except)
    {
      continue;
    }

    final int? year = int.tryParse(rows[i].yearCtrl.text.trim());

    if (year != null)
    {
      years.add(year);
    }
  }

  return years;
}
