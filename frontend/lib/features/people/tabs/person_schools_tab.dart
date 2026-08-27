import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/card_scroll_area.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/school_item.dart';
import '../../association/models/study_program_item.dart';
import '../models/person_item.dart';
import '../models/school_enrollment_item.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/person_row_models.dart';
import '../widgets/school_enrollment_edit_row.dart';

const double _cardsWidth = 1600;

class PersonSchoolsTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const PersonSchoolsTab({
    super.key,
    required this.person,
    required this.onUpdate,
  });

  // Same grade at the same education level as the year before: third of middle
  // school to third of high school is a progression, not a repeat.
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

  Widget _buildEnrollmentCard(
    SchoolEnrollmentItem item,
    List<SchoolEnrollmentItem> all, {
    required bool isCurrent,
  })
  {
    final bool repeating = _isRepeating(item, all);

    return AppCard(
      title: 'Anno scolastico ${item.startYear}/${item.startYear + 1}',
      compact: true,
      leading: AppCardBadge(
        icon: isCurrent ? Icons.school_rounded : Icons.history_rounded,
        compact: true,
      ),
      child: PersonFactsRow(
        facts: [
          PersonFact('Scuola', item.schoolName, flex: 4),
          PersonFact('Livello', item.educationLevel, flex: 3),
          PersonFact('Percorso', item.studyProgramName, flex: 4),
          PersonFact('Classe', gradeLabel(item.grade)),
          PersonFact('Ripetente', repeating ? 'Sì' : 'No', highlight: repeating),
        ],
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pageTransitionBlocks([
              if (current != null) ...[
                const PersonSectionTitle('Anno scolastico attuale'),
                const SizedBox(height: kPersonTitleGap),
                _buildEnrollmentCard(current, enrollments, isCurrent: true),
                const SizedBox(height: kPersonSectionGap),
              ],
              if (past.isNotEmpty) ...[
                const PersonSectionTitle('Anni scolastici passati'),
                const SizedBox(height: kPersonTitleGap),
                for (var i = 0; i < past.length; i++) ...[
                  if (i > 0) const SizedBox(height: kPersonCardGap),
                  _buildEnrollmentCard(past[i], enrollments, isCurrent: false),
                ],
              ],
              if (current == null && past.isEmpty)
                const PersonEmptyState(message: 'Nessun anno scolastico registrato.'),
              const SizedBox(height: kPersonSectionGap),
              Center(
                child: AppGradientButton(
                  label: 'MODIFICA ANNI SCOLASTICI',
                  icon: Icons.edit_rounded,
                  onPressed: () => _showEditDialog(context),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
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
  final List<SchoolEnrollmentRowData> _rows = [];
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

        _rows.add(SchoolEnrollmentRowData(
          yearCtrl: TextEditingController(text: enrollment.startYear.toString()),
          school: school,
          program: program,
          // Only meaningful once the programme is known.
          grade: program == null ? null : kGradeLabels[enrollment.grade],
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
      final year = int.tryParse(row.yearCtrl.text) ?? 0;

      if (year > latestYear)
      {
        latestYear = year;
      }
    }

    setState(()
    {
      // New rows go back in time: the year before the most recent one.
      _rows.add(SchoolEnrollmentRowData(
        yearCtrl: TextEditingController(text: (latestYear - 1).toString()),
      ));
    });
  }

  void _removeRow(int index)
  {
    setState(() => _rows.removeAt(index).dispose());
  }


  // Each row is checked independently so one bad year does not hide the rest.
  bool _validateRows()
  {
    _errors.clear();

    final seenYears = <int>{};
    final currentYear = currentSchoolYearStart();

    for (var i = 0; i < _rows.length; i++)
    {
      final row = _rows[i];
      final yearText = row.yearCtrl.text.trim();

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

      if (row.school == null)
      {
        _errors['school_$i'] = 'Obbligatorio';
      }

      if (row.program == null)
      {
        _errors['program_$i'] = 'Obbligatorio';
      }

      if (row.grade == null)
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
              'start_year': int.parse(row.yearCtrl.text.trim()),
              'school_id': row.school!.id,
              'study_program_id': row.program!.id,
              'grade': kGradeNumbers[row.grade!] ?? 1,
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
      // studentUpdatedAt is the optimistic concurrency token.
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

  Widget _buildRow(int index)
  {
    final row = _rows[index];

    return SchoolEnrollmentEditRow(
      row: row,
      allSchools: _allSchools,
      allPrograms: _allPrograms,
      errors: {
        'year': _errors['year_$index'],
        'school': _errors['school_$index'],
        'program': _errors['program_$index'],
        'grade': _errors['grade_$index'],
      },
      onChanged: () => setState(()
      {
        _errors.remove('year_$index');
        _errors.remove('school_$index');
        _errors.remove('program_$index');
        _errors.remove('grade_$index');
      }),
      onRemove: () => _removeRow(index),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Scuola',
      title: 'Modifica anni scolastici',
      maxWidth: 1100,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'SALVA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppFieldLabel('Anni scolastici'),
                    const SizedBox(height: 12),
                    CardScrollArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _rows.length; i++) _buildRow(i),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppAddRowButton(label: 'AGGIUNGI ANNO', onTap: _addEmptyRow),
                  ],
                ),
        ),
      ],
    );
  }
}