import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/pill_tab_bar.dart';
import '../../shared/widgets/snackbar.dart';
import 'models/association_subject_item.dart';
import 'models/ministry_subject_item.dart';
import 'models/school_item.dart';
import 'models/study_program_item.dart';
import 'tabs/association_subjects_tab.dart';
import 'tabs/ministry_subjects_tab.dart';
import 'tabs/schools_tab.dart';
import 'tabs/study_programs_tab.dart';

const int _schoolsContentIndex = 0;
const int _associationSubjectsContentIndex = 1;
const int _ministrySubjectsContentIndex = 2;
const int _studyProgramsContentIndex = 3;

class AssociationPage extends StatefulWidget
{
  const AssociationPage({super.key});

  @override
  State<AssociationPage> createState() => _AssociationPageState();
}

class _AssociationPageState extends State<AssociationPage>
{
  final ApiService _apiService = ApiService();

  int _mainSelectedTab = 0;
  int _didatticaSelectedTab = 0;

  // Records which tabs have been opened: once visited a tab stays mounted in
  // the IndexedStack. Reset only when GoRouter destroys this page.
  final Set<int> _visitedTabs = {};

  final List<String> _mainTabs = ['Scuole', 'Didattica'];

  final List<String> _didatticaTabs = [
    'Discipline interne',
    'Materie ministeriali',
    'Percorsi di studio',
  ];

  // Single source of truth for the entities shared across tabs, loaded once
  // when the page opens. Every setState here propagates to the frozen tabs in
  // the IndexedStack through their didUpdateWidget.
  bool _isLoading = true;
  List<SchoolItem> _schools = [];
  List<StudyProgramItem> _studyPrograms = [];
  List<MinistrySubjectItem> _ministrySubjects = [];
  List<AssociationSubjectItem> _associationSubjects = [];

  @override
  void initState()
  {
    super.initState();
    _visitedTabs.add(_computeContentIndex());
    _loadAllData();
  }

  Future<void> _loadAllData() async
  {
    try
    {
      final results = await Future.wait([
        _apiService.getSchools(),
        _apiService.getStudyPrograms(),
        _apiService.getMinistrySubjects(),
        _apiService.getAssociationSubjects(),
      ]);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _schools = results[0] as List<SchoolItem>;
        _studyPrograms = results[1] as List<StudyProgramItem>;
        _ministrySubjects = results[2] as List<MinistrySubjectItem>;
        _associationSubjects = results[3] as List<AssociationSubjectItem>;
        _isLoading = false;
      });
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _isLoading = false);
      CustomSnackBar.show(context: context, message: 'Impossibile caricare i dati dal server.', isError: true);
    }
  }

  // Every entity embeds a denormalized copy of the entity below it (for
  // example MinistrySubjectItem.associationSubjects), received from the backend
  // at fetch time. That copy is not updated by a standalone edit or delete, so
  // after such an operation the level above is refetched to make the nested
  // copy fresh again. These refresh failures are swallowed on purpose: the
  // primary operation already succeeded and must not be reported as failed.

  Future<void> _refreshMinistrySubjects() async
  {
    try
    {
      final refreshed = await _apiService.getMinistrySubjects();

      if (mounted)
      {
        setState(() => _ministrySubjects = refreshed);
      }
    }
    catch (e)
    {
      // Intentionally ignored, see the note above.
    }
  }

  Future<void> _refreshStudyPrograms() async
  {
    try
    {
      final refreshed = await _apiService.getStudyPrograms();

      if (mounted)
      {
        setState(() => _studyPrograms = refreshed);
      }
    }
    catch (e)
    {
      // Intentionally ignored, see the note above.
    }
  }

  Future<void> _refreshSchools() async
  {
    try
    {
      final refreshed = await _apiService.getSchools();

      if (mounted)
      {
        setState(() => _schools = refreshed);
      }
    }
    catch (e)
    {
      // Intentionally ignored, see the note above.
    }
  }

  // --- Discipline interne (AssociationSubject) ---------------------------

  Future<bool> _executeCreateAssociationSubject(String name, String area, String description, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createAssociationSubject(name, area, description);

      if (!mounted)
      {
        return true;
      }

      setState(() => _associationSubjects = [..._associationSubjects, created]);
      CustomSnackBar.show(context: context, message: 'Disciplina interna creata con successo!', isError: false);

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<bool> _executeEditAssociationSubject(int id, String name, String area, String description, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateAssociationSubject(id, name, area, description);

      if (!mounted)
      {
        return true;
      }

      setState(() => _associationSubjects = _associationSubjects.map((s) => s.id == id ? updated : s).toList());
      CustomSnackBar.show(context: context, message: 'Disciplina interna modificata con successo!', isError: false);
      await _refreshMinistrySubjects();

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<void> _executeDeleteAssociationSubject(AssociationSubjectItem item) async
  {
    try
    {
      await _apiService.deleteAssociationSubject(item.id);

      if (!mounted)
      {
        return;
      }

      setState(() => _associationSubjects = _associationSubjects.where((s) => s.id != item.id).toList());
      CustomSnackBar.show(context: context, message: 'Disciplina interna eliminata con successo!', isError: false);
      await _refreshMinistrySubjects();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  // --- Materie ministeriali (MinistrySubject) ----------------------------

  Future<bool> _executeCreateMinistrySubject(String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createMinistrySubject(
        name: name,
        level: level,
        areas: areas,
        description: description,
        associationSubjectIds: associationIds,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _ministrySubjects = [..._ministrySubjects, created]);
      CustomSnackBar.show(context: context, message: 'Materia ministeriale creata con successo!', isError: false);

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<bool> _executeEditMinistrySubject(int id, String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateMinistrySubject(
        id: id,
        name: name,
        level: level,
        areas: areas,
        description: description,
        associationSubjectIds: associationIds,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _ministrySubjects = _ministrySubjects.map((s) => s.id == id ? updated : s).toList());
      CustomSnackBar.show(context: context, message: 'Materia ministeriale modificata con successo!', isError: false);
      await _refreshStudyPrograms();

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<void> _executeDeleteMinistrySubject(MinistrySubjectItem item) async
  {
    try
    {
      await _apiService.deleteMinistrySubject(item.id);

      if (!mounted)
      {
        return;
      }

      setState(() => _ministrySubjects = _ministrySubjects.where((s) => s.id != item.id).toList());
      CustomSnackBar.show(context: context, message: 'Materia ministeriale eliminata con successo!', isError: false);
      await _refreshStudyPrograms();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  // --- Percorsi di studio (StudyProgram) ---------------------------------

  Future<bool> _executeCreateStudyProgram(String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createStudyProgram(
        name: name,
        level: level,
        minYear: minYear,
        maxYear: maxYear,
        description: description,
        ministrySubjectIds: subjectIds,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _studyPrograms = [..._studyPrograms, created]);
      CustomSnackBar.show(context: context, message: 'Percorso creato con successo!', isError: false);

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<bool> _executeEditStudyProgram(int id, String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateStudyProgram(
        id: id,
        name: name,
        level: level,
        minYear: minYear,
        maxYear: maxYear,
        description: description,
        ministrySubjectIds: subjectIds,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _studyPrograms = _studyPrograms.map((p) => p.id == id ? updated : p).toList());
      CustomSnackBar.show(context: context, message: 'Percorso modificato con successo!', isError: false);
      await _refreshSchools();

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<void> _executeDeleteStudyProgram(StudyProgramItem item) async
  {
    try
    {
      await _apiService.deleteStudyProgram(item.id);

      if (!mounted)
      {
        return;
      }

      setState(() => _studyPrograms = _studyPrograms.where((p) => p.id != item.id).toList());
      CustomSnackBar.show(context: context, message: 'Percorso eliminato con successo!', isError: false);
      await _refreshSchools();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  // --- Scuole (School) ---------------------------------------------------
  // The school sits at the top of the denormalization chain, so its edit and
  // delete do not trigger any cascade refresh.

  Future<bool> _executeCreateSchool(String? code, String name, String city, String prov, List<int> programIds, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createSchool(
        code: code,
        name: name,
        city: city,
        province: prov,
        studyProgramIds: programIds,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _schools = [..._schools, created]);
      CustomSnackBar.show(context: context, message: 'Scuola creata con successo!', isError: false);

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<bool> _executeEditSchool(int id, String? code, String name, String city, String prov, List<int> programIds, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateSchool(
        id: id,
        code: code,
        name: name,
        city: city,
        province: prov,
        studyProgramIds: programIds,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _schools = _schools.map((s) => s.id == id ? updated : s).toList());
      CustomSnackBar.show(context: context, message: 'Scuola modificata con successo!', isError: false);

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<void> _executeDeleteSchool(SchoolItem item) async
  {
    try
    {
      await _apiService.deleteSchool(item.id);

      if (!mounted)
      {
        return;
      }

      setState(() => _schools = _schools.where((s) => s.id != item.id).toList());
      CustomSnackBar.show(context: context, message: 'Scuola eliminata con successo!', isError: false);
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  // Maps the (mainTab, didatticaTab) pair onto a single IndexedStack index.
  int _computeContentIndex()
  {
    if (_mainSelectedTab == 0)
    {
      return _schoolsContentIndex;
    }

    return 1 + _didatticaSelectedTab;
  }

  // IndexedStack keeps the state of already visited tabs alive: the
  // placeholder is replaced only on first visit, after which the tab stays
  // mounted and does not reload until the whole page is closed. Shared data
  // arrives from above through the widget properties, so a setState here
  // propagates to the mounted tabs through their didUpdateWidget, without
  // disposing and recreating their internal state (scroll, filters, search).
  Widget _buildTabContent()
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return IndexedStack(
      index: _computeContentIndex(),
      children: [
        _visitedTabs.contains(_schoolsContentIndex)
            ? SchoolsTab(
                schools: _schools,
                studyPrograms: _studyPrograms,
                ministrySubjects: _ministrySubjects,
                onCreate: _executeCreateSchool,
                onEdit: _executeEditSchool,
                onDelete: _executeDeleteSchool,
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(_associationSubjectsContentIndex)
            ? AssociationSubjectsTab(
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateAssociationSubject,
                onEdit: _executeEditAssociationSubject,
                onDelete: _executeDeleteAssociationSubject,
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(_ministrySubjectsContentIndex)
            ? MinistrySubjectsTab(
                ministrySubjects: _ministrySubjects,
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateMinistrySubject,
                onEdit: _executeEditMinistrySubject,
                onDelete: _executeDeleteMinistrySubject,
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(_studyProgramsContentIndex)
            ? StudyProgramsTab(
                studyPrograms: _studyPrograms,
                ministrySubjects: _ministrySubjects,
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateStudyProgram,
                onEdit: _executeEditStudyProgram,
                onDelete: _executeDeleteStudyProgram,
              )
            : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildHeaderPill({required Widget child, double? width, EdgeInsets? padding})
  {
    return Container(
      width: width,
      height: 54,
      padding: padding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(40)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildHeader(BuildContext context)
  {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            onTap: () => context.go('/dashboard'),
            child: _buildHeaderPill(
              width: 88,
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.primary,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildHeaderPill(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: Text(
              'Associazione',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
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
          final viewportWidth = MediaQuery.of(context).size.width;

          return Container(
            width: width,
            height: height,
            color: AppTheme.pageBackground,
            child: Stack(
              children: [
                const CornerGlow(corner: GlowCorner.topRight),
                const CornerGlow(corner: GlowCorner.bottomLeft),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 16),
                        AppCustomTabBar(
                          tabs: _mainTabs,
                          selectedIndex: _mainSelectedTab,
                          onTabSelected: (index)
                          {
                            setState(()
                            {
                              _mainSelectedTab = index;
                              _visitedTabs.add(_computeContentIndex());
                            });
                          },
                          maxWidth: viewportWidth - 80,
                        ),
                        _mainSelectedTab == 1
                            ? PillTabBar(
                                labels: _didatticaTabs,
                                selectedIndex: _didatticaSelectedTab,
                                padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
                                onSelected: (index) => setState(()
                                {
                                  _didatticaSelectedTab = index;
                                  _visitedTabs.add(_computeContentIndex());
                                }),
                              )
                            : const SizedBox(height: 24, width: double.infinity),
                        Expanded(child: _buildTabContent()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}