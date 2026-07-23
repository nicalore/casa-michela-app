import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/school_item.dart';
import '../../association/models/study_program_item.dart';
import '../models/person_item.dart';
import '../models/school_enrollment_item.dart';
import '../person_wizard_components.dart';

const Color _subtleBackground = Color(0xFFF8FAFC);
const Color _disabledText = Color(0xFFCBD5E1);
const Color _strongTextColor = Color(0xFF2A2A2A);

// Month the school year starts in: before September the current year is still the
// previous one.
const int _schoolYearStartMonth = 9;

// Single source of truth for the grade labels, used both to show a saved grade and
// to translate the chosen one back. Study programs can span up to eight years, so
// the map has to cover them all: a shorter one would turn an unknown label back
// into the first year.
const Map<int, String> _gradeLabels = {
  1: 'I',
  2: 'II',
  3: 'III',
  4: 'IV',
  5: 'V',
  6: 'VI',
  7: 'VII',
  8: 'VIII',
};

final Map<String, int> _gradeNumbers = {
  for (final entry in _gradeLabels.entries) entry.value: entry.key,
};

/// Start year of the running school year.
int currentSchoolYearStart()
{
  final now = DateTime.now();

  return now.month < _schoolYearStartMonth ? now.year - 1 : now.year;
}

String _gradeLabel(int grade) => _gradeLabels[grade] ?? grade.toString();

class PersonSchoolsTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const PersonSchoolsTab({
    super.key,
    required this.person,
    required this.onUpdate,
  });

  // Repeating a year means the same grade at the same education level as the year
  // before: moving from third year of middle school to third of high school is a
  // progression, not a repeat.
  bool _isRepeating(SchoolEnrollmentItem current, List<SchoolEnrollmentItem> all)
  {
    final previous =
        all.where((item) => item.startYear == current.startYear - 1).firstOrNull;

    if (previous == null)
    {
      return false;
    }

    return current.grade == previous.grade &&
        current.educationLevel == previous.educationLevel;
  }

  void _showEditDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'EditSchools',
      builder: (context) => _EditSchoolsDialog(person: person, onUpdate: onUpdate),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool highlight = false})
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: highlight ? AppTheme.danger : AppTheme.slate700,
          ),
        ),
      ],
    );
  }

  Widget _buildEnrollmentCard(
    SchoolEnrollmentItem item,
    List<SchoolEnrollmentItem> all, {
    required bool isCurrent,
  })
  {
    return SelectionArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 2.0),
          // Only the running year is raised, so it stands out among the history.
          boxShadow: isCurrent ? AppTheme.cardShadow : null,
        ),
        child: Column(
          children: [
            Text(
              'Anno scolastico ${item.startYear}/${item.startYear + 1}',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.slate700,
              ),
            ),
            const SizedBox(height: 32),
            _ResponsiveInfoItemsRow(
              items: [
                _buildInfoItem('Scuola', item.schoolName),
                _buildInfoItem('Livello', item.educationLevel),
                _buildInfoItem('Percorso', item.studyProgramName),
                _buildInfoItem('Classe', _gradeLabel(item.grade)),
                _buildInfoItem(
                  'Ripetente',
                  _isRepeating(item, all) ? 'Sì' : 'No',
                  highlight: _isRepeating(item, all),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final enrollments = [...?person.schoolEnrollments];
    enrollments.sort((a, b) => b.startYear.compareTo(a.startYear));

    final currentYear = currentSchoolYearStart();
    final current =
        enrollments.where((item) => item.startYear == currentYear).firstOrNull;
    final past = enrollments.where((item) => item.startYear < currentYear).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current != null) ...[
            _buildSectionTitle('Anno scolastico attuale'),
            const SizedBox(height: 16),
            _buildEnrollmentCard(current, enrollments, isCurrent: true),
            const SizedBox(height: 48),
          ],
          if (past.isNotEmpty) ...[
            _buildSectionTitle('Anni scolastici passati'),
            const SizedBox(height: 16),
            ...past.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildEnrollmentCard(item, enrollments, isCurrent: false),
                )),
          ],
          if (current == null && past.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Nessun anno scolastico registrato.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slate500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
          Center(
            child: SizedBox(
              width: 300,
              child: AnimatedActionButton(
                text: 'MODIFICA ANNI SCOLASTICI',
                icon: Icons.edit_rounded,
                baseColor: AppTheme.primary,
                hoverColor: AppTheme.primaryHover,
                onPressed: () => _showEditDialog(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Side by side while every item has room, stacked otherwise. The threshold scales
// with the number of items.
class _ResponsiveInfoItemsRow extends StatelessWidget
{
  static const double _minItemWidth = 150;

  final List<Widget> items;

  const _ResponsiveInfoItemsRow({required this.items});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < items.length * _minItemWidth)
        {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                items[i],
              ],
            ],
          );
        }

        // Expanded rather than spaceEvenly: a school or programme name can be far
        // longer than the estimated width per item, and Expanded lets it wrap to a
        // second line instead of overflowing the row.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) => Expanded(child: item)).toList(),
        );
      },
    );
  }
}

// Year, school, programme and grade side by side, stacked below the threshold.
// Once stacked the remove button moves next to the grade, aligned to its bottom.
class _ResponsiveFourFieldRow extends StatelessWidget
{
  // Below this width four fields side by side become unreadable, school and
  // programme in particular.
  static const double _breakpoint = 700;

  final Widget yearField;
  final Widget schoolField;
  final Widget programField;
  final Widget gradeField;
  final VoidCallback onRemove;

  const _ResponsiveFourFieldRow({
    required this.yearField,
    required this.schoolField,
    required this.programField,
    required this.gradeField,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _breakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              yearField,
              const SizedBox(height: 16),
              schoolField,
              const SizedBox(height: 16),
              programField,
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: gradeField),
                  const SizedBox(width: 8),
                  WizardRemoveRowButton(onTap: onRemove),
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: yearField),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: schoolField),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: programField),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: gradeField),
            Padding(
              padding: const EdgeInsets.only(top: 28, left: 16),
              child: WizardRemoveRowButton(onTap: onRemove),
            ),
          ],
        );
      },
    );
  }
}

class _SchoolRowData
{
  final TextEditingController yearController;

  SchoolItem? selectedSchool;
  StudyProgramItem? selectedProgram;
  String? selectedGrade;

  _SchoolRowData({
    required this.yearController,
    this.selectedSchool,
    this.selectedProgram,
    this.selectedGrade,
  });

  void dispose()
  {
    yearController.dispose();
  }
}

class _EditSchoolsDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const _EditSchoolsDialog({required this.person, required this.onUpdate});

  @override
  State<_EditSchoolsDialog> createState() => _EditSchoolsDialogState();
}

class _EditSchoolsDialogState extends State<_EditSchoolsDialog>
{
  final ApiService _apiService = ApiService();
  final List<_SchoolRowData> _rows = [];
  final Map<String, String> _errors = {};

  bool _isLoading = true;
  bool _isSaving = false;

  List<SchoolItem> _allSchools = [];
  List<StudyProgramItem> _allPrograms = [];

  @override
  void initState()
  {
    super.initState();
    _loadData();
  }

  @override
  void dispose()
  {
    for (final row in _rows)
    {
      row.dispose();
    }

    super.dispose();
  }

  Future<void> _loadData() async
  {
    try
    {
      final results = await Future.wait([
        _apiService.getSchools(),
        _apiService.getStudyPrograms(),
      ]);

      _allSchools = results[0] as List<SchoolItem>;
      _allPrograms = results[1] as List<StudyProgramItem>;

      for (final enrollment in widget.person.schoolEnrollments ?? <SchoolEnrollmentItem>[])
      {
        final school =
            _allSchools.where((item) => item.id == enrollment.schoolId).firstOrNull;
        final program =
            _allPrograms.where((item) => item.id == enrollment.studyProgramId).firstOrNull;

        _rows.add(_SchoolRowData(
          yearController: TextEditingController(text: enrollment.startYear.toString()),
          selectedSchool: school,
          selectedProgram: program,
          // Only meaningful once the programme is known, since the grade is picked
          // from that programme's range.
          selectedGrade: program == null ? null : _gradeLabels[enrollment.grade],
        ));
      }

      if (mounted)
      {
        setState(() => _isLoading = false);
      }
    }
    catch (_)
    {
      if (mounted)
      {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addEmptyRow()
  {
    var latestYear = DateTime.now().year;

    for (final row in _rows)
    {
      final year = int.tryParse(row.yearController.text) ?? 0;

      if (year > latestYear)
      {
        latestYear = year;
      }
    }

    setState(()
    {
      // Proposes the year before the most recent one, since rows are added going
      // back in time.
      _rows.add(_SchoolRowData(
        yearController: TextEditingController(text: (latestYear - 1).toString()),
      ));
    });
  }

  void _removeRow(int index)
  {
    setState(() => _rows.removeAt(index).dispose());
  }

  String _schoolLabel(SchoolItem school) => '${school.name} (${school.city})';

  // Programmes actually taught by the chosen school, narrowed to those still
  // present in the global list: a school can reference a programme that has since
  // been removed from the association's catalogue.
  List<String> _programNamesFor(SchoolItem? school)
  {
    if (school == null)
    {
      return const [];
    }

    final names = <String>[];

    for (final option in school.studyPrograms)
    {
      final isKnown = _allPrograms.any((program) => program.name == option.name);

      if (isKnown && !names.contains(option.name))
      {
        names.add(option.name);
      }
    }

    return names;
  }

  // Grades allowed by the chosen programme. Falls back to the first five when the
  // programme declares a range the labels do not cover.
  List<String> _gradeOptionsFor(StudyProgramItem? program)
  {
    if (program == null)
    {
      return const [];
    }

    final options = <String>[];

    for (var year = program.minYear; year <= program.maxYear; year++)
    {
      final label = _gradeLabels[year];

      if (label != null && !options.contains(label))
      {
        options.add(label);
      }
    }

    return options.isEmpty ? const ['I', 'II', 'III', 'IV', 'V'] : options;
  }

  // Fills _errors and reports whether every row is usable. Each row is checked on
  // its own, so one bad year does not hide the problems of the rows below it.
  bool _validateRows()
  {
    _errors.clear();

    final seenYears = <int>{};
    final currentYear = currentSchoolYearStart();

    for (var i = 0; i < _rows.length; i++)
    {
      final row = _rows[i];
      final yearText = row.yearController.text.trim();

      if (!RegExp(r'^\d{4}$').hasMatch(yearText))
      {
        _errors['year_$i'] = 'Errore';
      }
      else
      {
        final year = int.parse(yearText);

        if (year > currentYear)
        {
          _errors['year_$i'] = 'Anno futuro';
        }
        else if (!seenYears.add(year))
        {
          _errors['year_$i'] = 'Duplicato';
        }
      }

      if (row.selectedSchool == null)
      {
        _errors['school_$i'] = 'Obbligatorio';
      }

      if (row.selectedProgram == null)
      {
        _errors['program_$i'] = 'Obbligatorio';
      }

      if (row.selectedGrade == null)
      {
        _errors['grade_$i'] = 'Obbligatorio';
      }
    }

    return _errors.isEmpty;
  }

  bool get _hasFutureYearError => _errors.values.contains('Anno futuro');

  List<Map<String, dynamic>> _buildPayload()
  {
    return _rows
        .map((row) => <String, dynamic>{
              'start_year': int.parse(row.yearController.text.trim()),
              'school_id': row.selectedSchool!.id,
              'study_program_id': row.selectedProgram!.id,
              'grade': _gradeNumbers[row.selectedGrade!] ?? 1,
            })
        .toList();
  }

  Future<void> _save() async
  {
    if (_rows.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Lo studente deve avere almeno un anno scolastico.',
        isError: true,
      );

      return;
    }

    if (!_validateRows())
    {
      setState(() {});
      CustomSnackBar.show(
        context: context,
        message: _hasFutureYearError
            ? 'Non è possibile inserire iscrizioni per anni scolastici futuri.'
            : 'Correggi gli errori prima di salvare.',
        isError: true,
      );

      return;
    }

    setState(() => _isSaving = true);

    try
    {
      // studentUpdatedAt is the optimistic concurrency token for the student
      // aggregate: the server refuses the update if it changed meanwhile.
      await _apiService.updatePersonSchoolEnrollments(
        widget.person.fiscalCode,
        _buildPayload(),
        widget.person.studentUpdatedAt,
      );

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Anni scolastici aggiornati con successo!',
          isError: false,
        );

        Navigator.of(context).pop();
        widget.onUpdate();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate500,
        ),
      ),
    );
  }

  Widget _buildLabelledField(String label, Widget field)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        field,
      ],
    );
  }

  // Choosing a school clears programme and grade, and choosing a programme clears
  // the grade: each one narrows the options of the next, so a stale value would no
  // longer be valid.
  Widget _buildRow(int index)
  {
    final row = _rows[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.slate200),
        color: _subtleBackground,
      ),
      child: _ResponsiveFourFieldRow(
        onRemove: () => _removeRow(index),
        yearField: _buildLabelledField(
          'Anno inizio',
          WizardAnimatedTextField(
            controller: row.yearController,
            hint: 'Es. 2024',
            errorText: _errors['year_$index'],
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _errors.remove('year_$index')),
          ),
        ),
        schoolField: _buildLabelledField(
          'Scuola',
          _FormOverlayDropdown(
            value: row.selectedSchool == null ? null : _schoolLabel(row.selectedSchool!),
            options: _allSchools.map(_schoolLabel).toList(),
            hint: 'Seleziona scuola',
            errorText: _errors['school_$index'],
            onSelected: (label) => setState(()
            {
              row.selectedSchool =
                  _allSchools.firstWhere((school) => _schoolLabel(school) == label);
              row.selectedProgram = null;
              row.selectedGrade = null;
              _errors.remove('school_$index');
            }),
          ),
        ),
        programField: _buildLabelledField(
          'Percorso',
          _FormOverlayDropdown(
            value: row.selectedProgram?.name,
            options: _programNamesFor(row.selectedSchool),
            hint: 'Seleziona percorso',
            errorText: _errors['program_$index'],
            onSelected: (name) => setState(()
            {
              row.selectedProgram =
                  _allPrograms.firstWhere((program) => program.name == name);
              row.selectedGrade = null;
              _errors.remove('program_$index');
            }),
          ),
        ),
        gradeField: _buildLabelledField(
          'Classe',
          _FormOverlayDropdown(
            value: row.selectedGrade,
            options: _gradeOptionsFor(row.selectedProgram),
            hint: 'Classe',
            errorText: _errors['grade_$index'],
            onSelected: (grade) => setState(()
            {
              row.selectedGrade = grade;
              _errors.remove('grade_$index');
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        // Fills the available space but never past 980: without an explicit width
        // the breakpoints on the buttons and on the rows would never trigger.
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Modifica anni scolastici',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: AppTheme.divider),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _rows.length; i++) _buildRow(i),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: WizardTextLinkButton(
                                text: 'Aggiungi anno',
                                icon: Icons.add_rounded,
                                onTap: _addEmptyRow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
                    child: ResponsiveDialogButtonsRow(
                      stackedButtonWidth: null,
                      secondaryButton: WizardAnimatedActionButton(
                        text: 'ANNULLA',
                        icon: Icons.cancel_outlined,
                        baseColor: AppTheme.danger,
                        hoverColor: AppTheme.dangerHover,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      primaryButton: WizardAnimatedActionButton(
                        text: _isSaving ? 'SALVATAGGIO...' : 'SALVA MODIFICHE',
                        icon: Icons.check_circle_outline,
                        baseColor: AppTheme.primary,
                        hoverColor: AppTheme.primaryHover,
                        onPressed: _isSaving ? () {} : _save,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Dropdown for a form field, with a hint, an inline error and support for being
// disabled when there is nothing to choose from. Separate from the filter menus in
// shared/widgets, which are built around clearing rather than picking one value.
class _FormOverlayDropdown extends StatefulWidget
{
  final String? value;
  final List<String> options;
  final String hint;
  final String? errorText;
  final ValueChanged<String> onSelected;

  const _FormOverlayDropdown({
    required this.value,
    required this.options,
    required this.hint,
    required this.onSelected,
    this.errorText,
  });

  @override
  State<_FormOverlayDropdown> createState() => _FormOverlayDropdownState();
}

class _FormOverlayDropdownState extends State<_FormOverlayDropdown>
{
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey<_FormOverlayContentState> _menuKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isHovered = false;

  // Empty options mean the field upstream has not been chosen yet, so there is
  // nothing to open.
  bool get _isDisabled => widget.options.isEmpty;

  void _toggleMenu()
  {
    if (_overlayEntry != null || _isDisabled)
    {
      _closeMenu();
      return;
    }

    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              child: Container(),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 4,
            left: offset.dx,
            child: _FormOverlayContent(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
              width: size.width,
              onSelected: (value)
              {
                widget.onSelected(value);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // The overlay is removed only after the collapse animation has run, so the menu
  // does not disappear abruptly.
  void _closeMenu() async
  {
    if (_overlayEntry == null)
    {
      return;
    }

    await _menuKey.currentState?.hide();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Color get _borderColor
  {
    if (widget.errorText != null)
    {
      return AppTheme.danger;
    }

    return _isHovered ? AppTheme.primary : AppTheme.slate200;
  }

  Color get _valueColor
  {
    if (_isDisabled)
    {
      return _disabledText;
    }

    return widget.value != null ? _strongTextColor : AppTheme.hint;
  }

  Widget _buildErrorBadge(String message)
  {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: message,
        textStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final errorText = widget.errorText;

    return MouseRegion(
      cursor: _isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _isDisabled ? null : _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 200),
          height: 50,
          padding: EdgeInsets.only(left: 16, right: errorText != null ? 8 : 16),
          decoration: BoxDecoration(
            color: _isDisabled ? _subtleBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: OverflowTooltipText(
                  text: widget.value ?? widget.hint,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: widget.value != null ? FontWeight.w600 : FontWeight.w500,
                    color: _valueColor,
                  ),
                ),
              ),
              if (errorText != null) _buildErrorBadge(errorText),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _isDisabled
                    ? _disabledText
                    : (_isHovered ? AppTheme.primary : AppTheme.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormOverlayContent extends StatefulWidget
{
  final String? currentValue;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final double width;

  const _FormOverlayContent({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.width,
  });

  @override
  State<_FormOverlayContent> createState() => _FormOverlayContentState();
}

class _FormOverlayContentState extends State<_FormOverlayContent>
{
  // The same value drives the AnimatedSize and the delay awaited by hide(): they
  // must stay in sync or the overlay is torn down mid animation.
  static const Duration _expandDuration = Duration(milliseconds: 180);

  bool _expanded = false;

  @override
  void initState()
  {
    super.initState();

    // Expanding on the next frame is what makes the opening animation visible.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(() => _expanded = true);
      }
    });
  }

  Future<void> hide() async
  {
    if (mounted)
    {
      setState(() => _expanded = false);
    }

    await Future.delayed(_expandDuration);
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.width,
        // Long lists scroll instead of running past the bottom of the dialog.
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: AnimatedSize(
          duration: _expandDuration,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.options.map((option)
                      {
                        return _FormOverlayMenuItem(
                          text: option,
                          isSelected: widget.currentValue == option,
                          onTap: () => widget.onSelected(option),
                        );
                      }).toList(),
                    ),
                  ),
                )
              : SizedBox(width: widget.width, height: 0),
        ),
      ),
    );
  }
}

class _FormOverlayMenuItem extends StatefulWidget
{
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormOverlayMenuItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FormOverlayMenuItem> createState() => _FormOverlayMenuItemState();
}

class _FormOverlayMenuItemState extends State<_FormOverlayMenuItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final isHighlighted = _hover || widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: isHighlighted ? 16 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                    color: AppTheme.primary,
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