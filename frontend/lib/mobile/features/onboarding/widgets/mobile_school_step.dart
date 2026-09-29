import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/error_message.dart';
import '../../../../features/association/models/school_item.dart';
import '../../../../features/association/models/study_program_item.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/models/school_enrollment_item.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart';
import '../../../../features/people/widgets/person_row_models.dart';
import '../../../../features/people/widgets/school_enrollment_edit_row.dart';
import '../../../../features/people/widgets/school_year_wizard.dart';
import '../../../../services/api_service.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_confirm_sheet.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../profile/widgets/mobile_card_grid.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import 'mobile_card_deck.dart';
import 'mobile_school_year_sheet.dart';

const double _cardRadius = 22;

const String _saved = 'Anni scolastici aggiornati con successo!';
const String _atLeastOne = 'Lo studente deve avere almeno un anno scolastico.';
const String _loadFailed = 'Non è stato possibile caricare le scuole. Riprova più tardi.';

// Each change saves as its sheet closes, so the step has nothing left to save.
class MobileSchoolStep extends StatefulWidget
{
  final PersonItem person;

  // Fetches the person again once the years are saved.
  final Future<void> Function() onChanged;

  final bool tablet;
  final double margin;

  const MobileSchoolStep({
    super.key,
    required this.person,
    required this.onChanged,
    required this.tablet,
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

  List<SchoolEnrollmentItem> get _years
  {
    return [...?widget.person.schoolEnrollments]..sort((a, b) => b.startYear.compareTo(a.startYear));
  }

  // As the desktop wizard reads them, most recent first.
  List<SchoolEnrollmentRowData> _rowsOf(List<SchoolItem> schools, List<StudyProgramItem> programs)
  {
    final List<SchoolEnrollmentRowData> rows = [
      for (final year in _years)
        SchoolEnrollmentRowData(
          yearCtrl: TextEditingController(text: year.startYear.toString()),
          school: schools.where((school) => school.id == year.schoolId).firstOrNull,
          program: programs.where((program) => program.id == year.studyProgramId).firstOrNull,
          grade: kGradeLabels[year.grade],
        ),
    ];

    sortSchoolYearRows(rows);

    return rows;
  }

  // Called by the page's «Aggiungi anno»; ignored while a save is under way.
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
      );

      if (outcome == null || !mounted)
      {
        return;
      }

      if (outcome.removed)
      {
        await _remove(rows, index);

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

  // The confirmation replaces the sheet, never stacks over it.
  Future<void> _remove(List<SchoolEnrollmentRowData> rows, int index)
  {
    if (rows.length == 1)
    {
      MobileNotice.show(context, _atLeastOne, error: true);

      return Future<void>.value();
    }

    final int start = int.parse(rows[index].yearCtrl.text);

    return showMobileConfirmSheet(
      context: context,
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
    ).then((confirmed) async
    {
      if (confirmed && mounted)
      {
        await _save([...rows]..removeAt(index));
      }
    });
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
              'school_id': row.school!.id,
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

  Widget _buildYear(SchoolEnrollmentItem year, List<SchoolEnrollmentItem> all)
  {
    final bool current = year.startYear == currentSchoolYearStart();
    final bool repeating = isRepeatingYear(year, all);

    final Widget card = MobileDetailCard(
      icon: current ? Icons.school_rounded : Icons.history_rounded,
      eyebrow: current ? 'Anno scolastico attuale' : 'Anno scolastico passato',
      title: 'Anno scolastico ${year.startYear}/${year.startYear + 1}',
      rows: [
        DetailRowData('Scuola', year.schoolName),
        DetailRowData('Livello', year.educationLevel),
        DetailRowData('Percorso', year.studyProgramNameOnly),
        DetailRowData('Classe', gradeLabel(year.grade)),
        DetailRowData('Ripetente', repeating ? 'Sì' : 'No'),
      ],
      onEdit: ()
      {
        if (!_busy)
        {
          _open(year: year);
        }
      },
      editLabel: 'Modifica anno scolastico',
    );

    if (!current)
    {
      return card;
    }

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: MobilePalette.currentRim, width: MobilePalette.currentRimWidth),
      ),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<SchoolEnrollmentItem> years = _years;

    if (years.isEmpty)
    {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.margin, vertical: 12),
        child: Text(
          'Nessun anno scolastico registrato.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.84),
          ),
        ),
      );
    }

    final List<Widget> cards = [for (final year in years) _buildYear(year, years)];

    if (widget.tablet)
    {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.margin),
        child: MobileCardGrid(tablet: true, cards: cards),
      );
    }

    return MobileCardDeck(
      // Keyed by count so adding or removing a year restarts the deck.
      key: ValueKey(years.length),
      pages: cards,
      margin: widget.margin,
    );
  }
}
