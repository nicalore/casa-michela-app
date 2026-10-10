import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/error_message.dart';
import '../../../../features/association/models/school_item.dart';
import '../../../../features/association/models/study_program_item.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/models/school_enrollment_item.dart';
import '../../../../features/people/widgets/person_row_models.dart';
import '../../../../features/people/widgets/school_enrollment_edit_row.dart';
import '../../../../features/people/widgets/school_year_wizard.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_confirm_sheet.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../profile/widgets/mobile_school_years.dart';
import 'mobile_school_year_sheet.dart';

const String _saved = 'Anni scolastici aggiornati con successo!';
const String _atLeastOne = 'Lo studente deve avere almeno un anno scolastico.';
const String _loadFailed = 'Non è stato possibile caricare le scuole. Riprova più tardi.';

// Each change saves as its sheet closes, so the step has nothing left to save.
class MobileSchoolStep extends StatefulWidget
{
  final PersonItem person;

  // Fetches the person again once the years are saved.
  final Future<void> Function() onChanged;

  final double margin;

  const MobileSchoolStep({
    super.key,
    required this.person,
    required this.onChanged,
    required this.margin,
  });

  @override
  State<MobileSchoolStep> createState() => MobileSchoolStepState();
}

class MobileSchoolStepState extends State<MobileSchoolStep>
{
  final ApiService _apiService = ApiService();

  List<SchoolItem>? _schools;
  List<StudyProgramItem>? _programs;

  bool _busy = false;

  @override
  void initState()
  {
    super.initState();
    _loadCatalogues();
  }

  Future<void> _loadCatalogues() async
  {
    try
    {
      final List<dynamic> results = await Future.wait([
        _apiService.getSchools(),
        _apiService.getStudyPrograms(),
      ]);

      if (mounted)
      {
        setState(()
        {
          _schools = results[0] as List<SchoolItem>;
          _programs = results[1] as List<StudyProgramItem>;
        });
      }
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle scuole');
    }
  }

  List<SchoolEnrollmentRowData> _rowsOf(List<SchoolItem> schools, List<StudyProgramItem> programs)
  {
    final List<SchoolEnrollmentRowData> rows = [
      for (final year in MobileSchoolYears.yearsOf(widget.person))
        SchoolEnrollmentRowData(
          yearCtrl: TextEditingController(text: year.startYear.toString()),
          school: schools.where((school) => school.id == year.schoolId).firstOrNull,
          homeschooling: year.homeschooling,
          program: programs.where((program) => program.id == year.studyProgramId).firstOrNull,
          grade: kGradeLabels[year.grade],
        ),
    ];

    sortSchoolYearRows(rows);

    return rows;
  }

  // Called by the page's "Aggiungi anno"; ignored while a save is under way.
  void add()
  {
    if (!_busy)
    {
      _open();
    }
  }

  Future<void> _open({SchoolEnrollmentItem? year}) async
  {
    final List<SchoolItem>? schools = _schools;
    final List<StudyProgramItem>? programs = _programs;

    if (schools == null || programs == null)
    {
      MobileNotice.show(context, _loadFailed, error: true);
      unawaited(_loadCatalogues());

      return;
    }

    final List<SchoolEnrollmentRowData> rows = _rowsOf(schools, programs);
    final int index = year == null ? -1 : rows.indexWhere((row) => row.yearCtrl.text == '${year.startYear}');

    try
    {
      final MobileSchoolYearOutcome? outcome = await showMobileSchoolYearSheet(
        context: context,
        schools: schools,
        programs: programs,
        takenYears: takenSchoolYears(rows, except: index < 0 ? null : index),
        initial: index < 0 ? previousSchoolYearOf(rows) : SchoolYearChoice.ofRow(rows[index]),
        editing: index >= 0,
        confirmRemoval: (sheet) => _confirmRemoval(sheet, rows, index),
      );

      if (outcome == null || !mounted)
      {
        return;
      }

      if (outcome.removed)
      {
        await _save([...rows]..removeAt(index));

        return;
      }

      if (index < 0)
      {
        rows.add(schoolEnrollmentRowOf(outcome.choice!));
      }
      else
      {
        applySchoolYearChoice(rows[index], outcome.choice!);
      }

      await _save(rows);
    }
    finally
    {
      for (final row in rows)
      {
        row.dispose();
      }
    }
  }

  // Refused at once for the only year.
  Future<bool> _confirmRemoval(BuildContext sheet, List<SchoolEnrollmentRowData> rows, int index)
  {
    if (rows.length == 1)
    {
      MobileNotice.show(context, _atLeastOne, error: true);

      return Future<bool>.value(false);
    }

    final int start = int.parse(rows[index].yearCtrl.text);

    return showMobileConfirmSheet(
      context: sheet,
      eyebrow: 'Rimozione',
      title: 'Confermi?',
      message: TextSpan(
        children: [
          const TextSpan(text: "L'anno scolastico "),
          TextSpan(
            text: '$start/${start + 1}',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          const TextSpan(text: ' verrà rimosso.'),
        ],
      ),
      confirmLabel: 'Rimuovi',
      confirmIcon: Icons.delete_outline_rounded,
    );
  }

  Future<void> _save(List<SchoolEnrollmentRowData> rows) async
  {
    setState(() => _busy = true);

    try
    {
      // The student's stamp guards against a concurrent change elsewhere.
      await _apiService.updatePersonSchoolEnrollments(
        widget.person.fiscalCode,
        [
          for (final row in rows)
            {
              'start_year': int.parse(row.yearCtrl.text.trim()),
              'school_id': row.school?.id,
              'homeschooling': row.homeschooling,
              'study_program_id': row.program!.id,
              'grade': kGradeNumbers[row.grade!] ?? 1,
            },
        ],
        widget.person.studentUpdatedAt,
      );

      await widget.onChanged();

      if (mounted)
      {
        MobileNotice.show(context, _saved);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.margin),
      child: MobileSchoolYears(
        person: widget.person,
        onEdit: (year)
        {
          if (!_busy)
          {
            _open(year: year);
          }
        },
      ),
    );
  }
}
