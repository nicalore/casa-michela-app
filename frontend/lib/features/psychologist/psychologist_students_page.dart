import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alphabetical_order.dart';
import '../../core/utils/error_message.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_empty_card.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_section_tabs.dart' show AppTitleMenu;
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../../shared/widgets/dialog_components.dart';
import '../../shared/widgets/page_density.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import '../people/edit/person_edit_form.dart' show kBornInItalyNation;
import '../people/models/people_filter_state.dart';
import '../people/models/person_face.dart';
import '../people/models/person_item.dart';
import '../people/models/student_note_item.dart';
import '../people/utils/people_filter_matching.dart';
import '../people/widgets/people_filter_dialog.dart';
import '../people/widgets/person_detail_header.dart'
    show kPersonHeadingFace, kPersonHeadingFaceGap, kPersonHeadingNameSize, personHeadingFace;
import '../people/widgets/student_note_dialog.dart';
import 'psychologist_strings.dart';
import 'psychologist_tour.dart';
import 'widgets/certifications_dialog.dart';
import 'widgets/student_list_panel.dart';
import 'widgets/student_sheet.dart';

const String _psychologistRole = 'PSYCHOLOGIST';

const List<String> _listedRoles = ['Studente'];

const double _listWidth = 400;
const double _denseListWidth = 300;

// Below 1000 px the pupil's face and name head the page and open the list as a menu.
const double _headingFactsGap = 28;
const double _headingBottom = 10;
const double _headingLineGap = 16;
const double _menuWidth = 340;
const double _menuTallest = 460;
const double _menuLeast = 220;
const double _menuGap = 8;
const double _menuWindowRoom = 16;

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

  // Moved, not rebuilt, between side by side and one at a time: the list keeps its offset and its field.
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _sheetKey = GlobalKey();

  bool _isLoading = true;

  List<PersonItem> _students = [];

  String _searchText = '';
  PeopleFilterState _filterState = const PeopleFilterState();

  String? _selectedCode;

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

      students.sort(compareByName);

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

      _startTour(psychologistStudentsTour());
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

    result.sort(compareAlphabetically);

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
        enrollmentFilter: false,
        earlyExitFilter: false,
        methodologicalNotesFilter: true,
        onApply: (state) => setState(() => _filterState = state),
      ),
    );
  }

  void _select(PersonItem student) => setState(() => _selectedCode = student.fiscalCode);

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
      // Note tour due: clicks stay held through the reload, so the note can't be left first.
      final DesktopTourHold? hold = note == null && mounted && !await _seen(psychologistNoteTour())
          ? (mounted ? DesktopTourHold.over(context) : null)
          : null;

      _confirm(note == null ? kNoteCreated : kNoteEdited);
      await _reload(student.fiscalCode);

      if (note == null)
      {
        _startTour(psychologistNoteTour(), hold: hold);
      }
    }
  }

  Future<bool> _seen(DesktopTour tour) async
  {
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    return taxCode == null || await isDesktopTourSeen(taxCode: taxCode, tour: tour);
  }

  // Runs after the frame building the lit parts; [hold]: held clicks the tour releases.
  void _startTour(DesktopTour tour, {DesktopTourHold? hold})
  {
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    if (taxCode == null)
    {
      hold?.release();

      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        startDesktopTourOnce(context, taxCode: taxCode, tour: tour, hold: hold);
      }
      else
      {
        hold?.release();
      }
    });

    WidgetsBinding.instance.scheduleFrame();
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

  // [close]: the heading's menu holding the list, shut once a pupil is chosen.
  Widget _buildList(List<PersonItem> students, {VoidCallback? close})
  {
    return StudentListPanel(
      key: close == null ? _listKey : null,
      students: students,
      selectedCode: _selectedCode,
      searchController: _searchController,
      onSearchChanged: (value) => setState(() => _searchText = value),
      filtersCount: _filterState.activeFiltersCount,
      onOpenFilters: _openFilters,
      onClearFilters: () => setState(() => _filterState = const PeopleFilterState()),
      onSelected: (student)
      {
        _select(student);
        close?.call();
      },
      inMenu: close != null,
    );
  }

  Widget _buildMenu(AppWindowSize size, VoidCallback close)
  {
    final Size window = MediaQuery.sizeOf(context);
    final double margin = AppBreakpoints.pageMargin(size);

    // From under the heading to near the window's bottom.
    final double below = AppTopBar.contentTopInsetFor(size) + kPersonHeadingFace + _headingBottom + _menuGap;
    final double height = (window.height - below - _menuWindowRoom).clamp(_menuLeast, _menuTallest);

    return SizedBox(
      width: _menuWidth.clamp(0, window.width - 2 * margin),
      height: height,
      child: _buildList(_filteredStudents, close: close),
    );
  }

  Widget _buildHeading(AppWindowSize size, PersonItem student)
  {
    final Widget who = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        personHeadingFace(context, student),
        const SizedBox(width: kPersonHeadingFaceGap),
        Flexible(
          child: Text(
            '${student.firstName} ${student.lastName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: kPersonHeadingNameSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.closedLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: _headingBottom),
        // The facts go under the name when they no longer fit beside it.
        child: Wrap(
          spacing: _headingFactsGap,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppTitleMenu(menu: (context, close) => _buildMenu(size, close), child: who),
            StudentFacts(student: student),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet({bool identity = true})
  {
    final PersonItem? student = _selected;

    if (student == null)
    {
      return const SizedBox.shrink();
    }

    return PageSections(
      key: _sheetKey,
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
          identity: identity,
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

    const Widget none = Center(
      child: PageTransitionItem(
        slot: PageTransitionItem.list,
        child: AppEmptyCard(icon: Icons.school_rounded, message: kNoStudents),
      ),
    );

    final List<PersonItem> students = _filteredStudents;

    if (size.isNarrow)
    {
      final PersonItem? student = _selected;

      if (student == null)
      {
        return none;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeading(size, student),
          const SizedBox(height: _headingLineGap),
          Expanded(child: _buildSheet(identity: false)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(
          slot: PageTransitionItem.frame,
          child: SizedBox(
            width: size.isDense ? _denseListWidth : _listWidth,
            child: _buildList(students),
          ),
        ),
        const SizedBox(width: AppSectionRail.gap),
        Expanded(child: _students.isEmpty ? none : _buildSheet()),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        // Below the wide window the page is the window: the list and the sheet scroll, not the page.
        minHeight: AppBreakpoints.of(context).isDense ? 0 : AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.of(context);
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
                    child: AppPageDensity(dense: size.isDense, child: _buildBody(size)),
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
