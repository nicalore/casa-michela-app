import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/dialog_components.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import '../people/edit/person_edit_form.dart' show kBornInItalyNation;
import '../people/models/people_filter_state.dart';
import '../people/models/person_item.dart';
import '../people/models/student_note_item.dart';
import '../people/utils/people_filter_matching.dart';
import '../people/widgets/people_filter_dialog.dart';
import '../people/widgets/student_note_dialog.dart';
import 'psychologist_strings.dart';
import 'widgets/certifications_dialog.dart';
import 'widgets/student_list_panel.dart';
import 'widgets/student_sheet.dart';

const String _psychologistRole = 'PSYCHOLOGIST';

const List<String> _listedRoles = ['Studente'];

const double _listWidth = 400;
const double _narrowListWidth = 340;

class PsychologistStudentsPage extends StatefulWidget
{
  const PsychologistStudentsPage({super.key});

  @override
  State<PsychologistStudentsPage> createState() => _PsychologistStudentsPageState();
}

class _PsychologistStudentsPageState extends State<PsychologistStudentsPage> with DestinationRefresh
{
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;

  List<PersonItem> _students = [];

  String _searchText = '';
  PeopleFilterState _filterState = const PeopleFilterState();

  String? _selectedCode;

  bool _showingSheet = false;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  @override
  void onDestinationShown() => _load(quiet: true);

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async
  {
    try
    {
      final List<PersonItem> students = await _apiService.getFollowedStudents();

      students.sort((a, b)
      {
        final int byName = a.firstName.compareTo(b.firstName);

        return byName != 0 ? byName : a.lastName.compareTo(b.lastName);
      });

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _students = students;
        _isLoading = false;

        if (!students.any((student) => student.fiscalCode == _selectedCode))
        {
          _selectedCode = students.firstOrNull?.fiscalCode;
        }
      });
    }
    catch (error, stackTrace)
    {
      reportCaughtError(error, stackTrace, during: 'il caricamento degli studenti');

      if (!mounted)
      {
        return;
      }

      setState(() => _isLoading = false);

      if (!quiet)
      {
        CustomSnackBar.show(context: context, message: kLoadFailed, isError: true);
      }
    }
  }

  Future<void> _reload(String code) async
  {
    try
    {
      final PersonItem fresh = await _apiService.getPerson(code);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _students = [
          for (final student in _students) student.fiscalCode == code ? fresh : student,
        ];
      });
    }
    catch (_)
    {
      await _load(quiet: true);
    }
  }

  List<String> _distinctSorted(Iterable<String?> values)
  {
    final List<String> result = values
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    result.sort();

    return result;
  }

  List<PersonItem> get _filteredStudents
  {
    final String wanted = _searchText.toLowerCase();

    return _students.where((student)
    {
      final String fullName = '${student.firstName} ${student.lastName}'.toLowerCase();

      return fullName.contains(wanted) && matchesPeopleFilter(student, _filterState);
    }).toList();
  }

  PersonItem? get _selected =>
      _students.where((student) => student.fiscalCode == _selectedCode).firstOrNull;

  void _openFilters()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'StudentsFilter',
      builder: (context) => PeopleFilterDialog(
        initialState: _filterState,
        availableBirthNations: _distinctSorted(_students
            .map((student) => student.birthNation)
            .where((nation) => nation?.toLowerCase() != kBornInItalyNation.toLowerCase())),
        availableBirthCities: _distinctSorted(_students.map((student) => student.birthCity)),
        availableCities: _distinctSorted(_students.map((student) => student.city)),
        availableSchools: _distinctSorted(_students.map((student) => student.schoolName)),
        availableStudyPrograms: _distinctSorted(_students.map((student) => student.studyProgram)),
        availableSubjects: const [],
        fixedRoles: _listedRoles,
        eyebrow: kStudentsModule,
        earlyExitFilter: false,
        methodologicalNotesFilter: true,
        onApply: (state) => setState(() => _filterState = state),
      ),
    );
  }

  void _select(PersonItem student)
  {
    setState(()
    {
      _selectedCode = student.fiscalCode;
      _showingSheet = true;
    });
  }

  void _confirm(String message)
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message);
    }
  }

  Future<void> _editCertifications(PersonItem student) async
  {
    if (await showCertificationsDialog(context, student))
    {
      _confirm(kCertificationsSaved);
      await _reload(student.fiscalCode);
    }
  }

  Future<void> _writeNote(PersonItem student, {StudentNoteItem? note}) async
  {
    if (await showStudentNoteDialog(context, student, StudentNoteKind.methodological, note: note))
    {
      _confirm(note == null ? kNoteCreated : kNoteEdited);
      await _reload(student.fiscalCode);
    }
  }

  Future<void> _deleteNote(PersonItem student, StudentNoteItem note) async
  {
    if (!await confirmNoteDeletion(context))
    {
      return;
    }

    try
    {
      await _apiService.deleteStudentNote(student.fiscalCode, StudentNoteKind.methodological, note.id);
      _confirm(kNoteDeletedDone);
      await _reload(student.fiscalCode);
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
  }

  Widget _buildList(List<PersonItem> students)
  {
    return StudentListPanel(
      students: students,
      selectedCode: _selectedCode,
      searchController: _searchController,
      onSearchChanged: (value) => setState(() => _searchText = value),
      filtersCount: _filterState.activeFiltersCount,
      onOpenFilters: _openFilters,
      onClearFilters: () => setState(() => _filterState = const PeopleFilterState()),
      onSelected: _select,
    );
  }

  Widget _buildSheet()
  {
    final PersonItem? student = _selected;

    if (student == null)
    {
      return const SizedBox.shrink();
    }

    return PageSections(
      index: 0,
      step: student.fiscalCode,
      children: [
        StudentSheet(
          key: ValueKey<String>(student.fiscalCode),
          student: student,
          ownTaxCode: _apiService.lastKnownIdentity?.taxCode,
          onEditCertifications: () => _editCertifications(student),
          onAddNote: () => _writeNote(student),
          onEditNote: (note) => _writeNote(student, note: note),
          onDeleteNote: (note) => _deleteNote(student, note),
        ),
      ],
    );
  }

  Widget _buildBody(AppWindowSize size)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    final List<PersonItem> students = _filteredStudents;

    if (size.isCompact)
    {
      if (_showingSheet && _selected != null)
      {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBackButton(
              tooltip: 'Torna indietro',
              onTap: () => setState(() => _showingSheet = false),
            ),
            const SizedBox(height: 18),
            Expanded(child: _buildSheet()),
          ],
        );
      }

      return _buildList(students);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(
          slot: PageTransitionItem.frame,
          child: SizedBox(
            width: size == AppWindowSize.expanded ? _listWidth : _narrowListWidth,
            child: _buildList(students),
          ),
        ),
        const SizedBox(width: AppSectionRail.gap),
        Expanded(child: _buildSheet()),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.fromWidth(width);
          final double margin = AppBreakpoints.pageMargin(size);

          return Container(
            width: width,
            height: height,
            color: AppTheme.trialPaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: AppTopBar.contentTopInsetFor(size),
                      bottom: 24,
                    ),
                    child: _buildBody(size),
                  ),
                ),
                AppTopBar(currentRoute: '${homeForRole(_psychologistRole)}/students'),
              ],
            ),
          );
        },
      ),
    );
  }
}
