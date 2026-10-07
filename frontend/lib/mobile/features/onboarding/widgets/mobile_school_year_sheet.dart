import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/association/models/school_item.dart';
import '../../../../features/association/models/study_program_item.dart';
import '../../../../features/association/models/subject_taxonomy.dart';
import '../../../../features/people/widgets/school_enrollment_edit_row.dart';
import '../../../../features/people/widgets/school_year_wizard.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_danger_button.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_height_reporter.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_wizard_parts.dart';
import '../../settings/widgets/mobile_choice_tile.dart';

const Duration _turn = Duration(milliseconds: 340);
const Curve _turnCurve = Curves.easeInOutCubic;

const double _labelGap = 8;
const double _blockGap = 18;
const double _tileGap = 8;

const double _stepperHeight = 58;
const double _stepperRadius = 18;

// Assumed page height until measured.
const double _unmeasured = 360;

const String _removeLabel = 'Rimuovi anno scolastico';

// The confirmed answers, or the year given up.
class MobileSchoolYearOutcome
{
  final SchoolYearChoice? choice;

  const MobileSchoolYearOutcome.chosen(SchoolYearChoice this.choice);

  const MobileSchoolYearOutcome.removed() : choice = null;

  bool get removed => choice == null;
}

// Not drag-dismissible, which would lose the answers.
Future<MobileSchoolYearOutcome?> showMobileSchoolYearSheet({
  required BuildContext context,
  required List<SchoolItem> schools,
  required List<StudyProgramItem> programs,
  required Set<int> takenYears,
  SchoolYearChoice? initial,
  bool editing = false,
  Future<bool> Function(BuildContext sheet)? confirmRemoval,
})
{
  return showMobileSheet<MobileSchoolYearOutcome>(
    context: context,
    draggable: false,
    builder: (context) => _YearSheet(
      schools: schools,
      programs: programs,
      takenYears: takenYears,
      initial: initial,
      editing: editing,
      confirmRemoval: confirmRemoval,
    ),
  );
}

class _YearSheet extends StatefulWidget
{
  final List<SchoolItem> schools;
  final List<StudyProgramItem> programs;
  final Set<int> takenYears;
  final SchoolYearChoice? initial;
  final bool editing;
  final Future<bool> Function(BuildContext sheet)? confirmRemoval;

  const _YearSheet({
    required this.schools,
    required this.programs,
    required this.takenYears,
    required this.initial,
    required this.editing,
    required this.confirmRemoval,
  });

  @override
  State<_YearSheet> createState() => _YearSheetState();
}

class _YearSheetState extends State<_YearSheet>
{
  static const List<SchoolYearStep> _steps = SchoolYearStep.values;

  final PageController _pages = PageController();
  final ValueNotifier<Map<SchoolYearStep, double>> _heights = ValueNotifier(const {});

  // A copy: the answers only reach the caller once confirmed.
  late final SchoolYearChoice _choice = SchoolYearChoice(
    startYear: widget.initial?.startYear,
    level: widget.initial?.level,
    school: widget.initial?.school,
    grade: widget.initial?.grade,
    program: widget.initial?.program,
  );

  late final TextEditingController _year = TextEditingController(
    text: (_choice.startYear ?? currentSchoolYearStart()).toString(),
  );

  final TextEditingController _schoolSearch = TextEditingController();
  final TextEditingController _programSearch = TextEditingController();

  int _step = 0;

  @override
  void initState()
  {
    super.initState();
    _year.addListener(_onYearTyped);
  }

  @override
  void dispose()
  {
    _pages.dispose();
    _heights.dispose();
    _year.dispose();
    _schoolSearch.dispose();
    _programSearch.dispose();
    super.dispose();
  }

  void _onYearTyped()
  {
    setState(() {});
  }

  int? get _startYear => parseSchoolStartYear(_year.text);

  bool get _last => _step == _steps.length - 1;

  String? _blocked(SchoolYearStep step)
  {
    return schoolYearBlockedReason(step, _choice, year: _startYear, takenYears: widget.takenYears);
  }

  void _measured(SchoolYearStep step, double height)
  {
    if (_heights.value[step] != height)
    {
      _heights.value = {..._heights.value, step: height};
    }
  }

  void _turnTo(int step)
  {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
    _pages.animateToPage(step, duration: _turn, curve: _turnCurve);
  }

  // Refuses on tap with a reason, never through a disabled button.
  void _next()
  {
    if (!_last)
    {
      final String? reason = _blocked(_steps[_step]);

      if (reason != null)
      {
        MobileNotice.show(context, reason, error: true);
        return;
      }

      _turnTo(_step + 1);

      return;
    }

    for (final step in _steps)
    {
      final String? reason = _blocked(step);

      if (reason != null)
      {
        _turnTo(step.index);
        MobileNotice.show(context, reason, error: true);

        return;
      }
    }

    _choice.startYear = _startYear;
    finishMobileSheet(context, MobileSchoolYearOutcome.chosen(_choice));
  }

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

  void _shiftYear(int by)
  {
    final int year = (_startYear ?? currentSchoolYearStart()) + by;

    // Never past the running school year.
    if (year > currentSchoolYearStart())
    {
      return;
    }

    _year.text = year.toString();
  }

  List<Widget> _buildWhen()
  {
    final int? year = _startYear;

    return [
      const _Label('Anno di inizio'),
      _YearStepper(
        controller: _year,
        onLess: () => _shiftYear(-1),
        onMore: () => _shiftYear(1),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(
          year == null ? '' : 'Anno scolastico $year/${year + 1}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.trialTealDeep,
          ),
        ),
      ),
      const SizedBox(height: _blockGap),
      const _Label('Livello di scuola'),
      for (final level in schoolLevels)
        _Tile(
          label: level.compactLabel,
          chosen: _choice.level == level.value,
          onTap: () => _pickLevel(level.value),
        ),
    ];
  }

  List<Widget> _buildSchool()
  {
    final String query = _schoolSearch.text.toLowerCase();
    final List<SchoolItem> offering =
        schoolsOfferingLevel(widget.schools, widget.programs, _choice.level);

    final List<SchoolItem> shown = offering
        .where((school) =>
            query.isEmpty ||
            '${school.name} ${school.city} ${school.province}'.toLowerCase().contains(query))
        .toList();

    return _buildPick(
      search: offering.isEmpty ? null : _schoolSearch,
      hintText: 'Cerca scuola...',
      empty: offering.isEmpty
          ? 'Nessuna scuola offre un percorso di questo livello.'
          : 'Nessuna scuola trovata per questa ricerca.',
      tiles: [
        for (final school in shown)
          _Tile(
            key: ValueKey('school-${school.id}'),
            label: school.name,
            detail: '${school.city} (${school.province})',
            chosen: _choice.school?.id == school.id,
            onTap: () => _pickSchool(school),
          ),
      ],
    );
  }

  List<Widget> _buildGrade()
  {
    return [
      const _Label('Classe'),
      for (final grade in gradeOptionsForLevel(_choice.level))
        _Tile(
          label: grade,
          chosen: _choice.grade == grade,
          onTap: () => _pickGrade(grade),
        ),
    ];
  }

  List<Widget> _buildProgram()
  {
    final String query = _programSearch.text.toLowerCase();
    final List<StudyProgramItem> offered =
        programsForChoice(_choice.school, widget.programs, _choice.level, _choice.grade);

    final List<StudyProgramItem> shown = offered
        .where((program) => query.isEmpty || program.fullName.toLowerCase().contains(query))
        .toList();

    return _buildPick(
      search: offered.isEmpty ? null : _programSearch,
      hintText: 'Cerca percorso...',
      empty: offered.isEmpty
          ? 'La scuola non offre percorsi di questo livello per la classe scelta.'
          : 'Nessun percorso trovato per questa ricerca.',
      tiles: [
        for (final program in shown)
          _Tile(
            key: ValueKey('program-${program.id}'),
            eyebrow: program.scopeLine,
            label: program.name,
            detail: descriptionOrNull(program.description),
            chosen: _choice.program?.id == program.id,
            onTap: () => setState(() => _choice.program = program),
          ),
      ],
    );
  }

  List<Widget> _buildPick({
    required TextEditingController? search,
    required String hintText,
    required String empty,
    required List<Widget> tiles,
  })
  {
    return [
      if (search != null) ...[
        MobileSearchField(
          controller: search,
          hintText: hintText,
          onGlass: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
      ],
      if (tiles.isEmpty)
        MobileSheetText(empty)
      else
        ...tiles,
    ];
  }

  List<Widget> _buildStep(SchoolYearStep step)
  {
    return [
      _Guide(step: step),
      const SizedBox(height: _blockGap),
      ...switch (step)
      {
        SchoolYearStep.when => _buildWhen(),
        SchoolYearStep.school => _buildSchool(),
        SchoolYearStep.grade => _buildGrade(),
        SchoolYearStep.program => _buildProgram(),
      },
    ];
  }

  Widget _buildPage(SchoolYearStep step)
  {
    return SingleChildScrollView(
      key: PageStorageKey(step),
      child: MobileHeightReporter(
        onHeight: (height) => _measured(step, height),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MobileSheet.sidePadding, 20, MobileSheet.sidePadding, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildStep(step),
          ),
        ),
      ),
    );
  }

  // Height interpolates between steps during a turn.
  Widget _buildPager()
  {
    return AnimatedBuilder(
      animation: Listenable.merge([_pages, _heights]),
      builder: (context, child)
      {
        final double page = _pages.hasClients && _pages.position.haveDimensions
            ? (_pages.page ?? _step.toDouble())
            : _step.toDouble();

        final int low = page.floor().clamp(0, _steps.length - 1);
        final int high = page.ceil().clamp(0, _steps.length - 1);

        final Map<SchoolYearStep, double> heights = _heights.value;
        final double from = heights[_steps[low]] ?? heights[_steps[high]] ?? _unmeasured;
        final double to = heights[_steps[high]] ?? from;

        return SizedBox(height: ui.lerpDouble(from, to, page - low), child: child);
      },
      // Turned by the buttons only, so no step is left unanswered by a swipe.
      child: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        allowImplicitScrolling: true,
        children: [for (final step in _steps) _buildPage(step)],
      ),
    );
  }

  Widget _buildFooter()
  {
    final String label = _last ? (widget.editing ? 'Salva' : 'Aggiungi') : 'Avanti';

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MobileWizardBackSlot(onBack: _step > 0 ? () => _turnTo(_step - 1) : null),
              Expanded(
                child: MobileGoldButton(
                  label: label,
                  icon: _last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  onPressed: _next,
                ),
              ),
            ],
          ),
          if (widget.editing && widget.confirmRemoval != null) ...[
            const SizedBox(height: 12),
            MobileDangerButton(
              label: _removeLabel,
              icon: Icons.delete_outline_rounded,
              onPressed: () async
              {
                if (await widget.confirmRemoval!(context) && mounted)
                {
                  finishMobileSheet(context, const MobileSchoolYearOutcome.removed());
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MobileSheet(
        eyebrow: 'Scuola',
        title: widget.editing ? 'Modifica anno scolastico' : 'Aggiungi anno scolastico',
        aboveKeyboard: true,
        subhead: MobileWizardDots(count: _steps.length, position: _pages, fallback: _step),
        content: _buildPager(),
        footer: _buildFooter(),
      ),
    );
  }
}

class _Guide extends StatelessWidget
{
  final SchoolYearStep step;

  const _Guide({required this.step});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.question,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.2,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.hint,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: MobilePalette.mutedText,
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget
{
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: _labelGap),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppTheme.trialInk.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget
{
  final String label;
  final String? eyebrow;
  final String? detail;
  final bool chosen;
  final VoidCallback onTap;

  const _Tile({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
    this.eyebrow,
    this.detail,
  });

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: _tileGap),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MobileChoiceTile(label: label, chosen: chosen, eyebrow: eyebrow, detail: detail),
      ),
    );
  }
}

class _YearStepper extends StatelessWidget
{
  final TextEditingController controller;
  final VoidCallback onLess;
  final VoidCallback onMore;

  const _YearStepper({required this.controller, required this.onLess, required this.onMore});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: _stepperHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(_stepperRadius),
        border: Border.all(color: AppTheme.trialOcean.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          _StepButton(icon: Icons.remove_rounded, label: 'Anno precedente', onTap: onLess),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              cursorColor: AppTheme.trialGold,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.trialInk,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          _StepButton(icon: Icons.add_rounded, label: 'Anno successivo', onTap: onMore),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget
{
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.trialTealDeep.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: AppTheme.trialTealDeep),
        ),
      ),
    );
  }
}
