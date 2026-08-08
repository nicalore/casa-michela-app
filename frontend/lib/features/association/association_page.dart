import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import 'models/association_subject_item.dart';
import 'models/ministry_subject_item.dart';
import 'models/school_item.dart';
import 'models/service_item.dart';
import 'models/study_program_item.dart';
import 'models/weekly_template_item.dart';
import 'tabs/association_subjects_tab.dart';
import 'tabs/ministry_subjects_tab.dart';
import 'tabs/presence_hours_tab.dart';
import 'tabs/online_hours_tab.dart';
import 'tabs/schools_tab.dart';
import 'tabs/services_tab.dart';
import 'tabs/study_programs_tab.dart';

const int _servicesContentIndex = 0;
const int _associationSubjectsContentIndex = 1;
const int _ministrySubjectsContentIndex = 2;
const int _studyProgramsContentIndex = 3;
const int _schoolsContentIndex = 4;
const int _presenceHoursContentIndex = 5;
const int _onlineHoursContentIndex = 6;

// The order here is the order of the IndexedStack below, and the constants
// above are the indices into both.
const List<RailGroup> _sections = [
  // The schools sit with the teaching, after the study programmes: a school is
  // made of programmes, and looking for them on their own at the top found
  // nobody.
  RailGroup(
    title: 'Didattica',
    entries: [
      'Servizi',
      'Discipline interne',
      'Materie ministeriali',
      'Percorsi di studio',
      'Scuole',
    ],
  ),
  RailGroup(title: 'Orari', entries: ['In presenza', 'Online']),
];

class AssociationPage extends StatefulWidget
{
  const AssociationPage({super.key});

  @override
  State<AssociationPage> createState() => _AssociationPageState();
}

class _AssociationPageState extends State<AssociationPage> with DestinationRefresh
{
  final ApiService _apiService = ApiService();

  // The page opens on the first entry of the rail, which is now the services.
  int _selectedSection = _servicesContentIndex;

  // Records which sections have been opened: once visited a section stays
  // mounted in the IndexedStack. Reset only when GoRouter destroys this page.
  final Set<int> _visitedSections = {};

  // Single source of truth for the entities shared across tabs, loaded once
  // when the page opens. Every setState here propagates to the frozen tabs in
  // the IndexedStack through their didUpdateWidget.
  bool _isLoading = true;
  List<SchoolItem> _schools = [];
  List<StudyProgramItem> _studyPrograms = [];
  List<MinistrySubjectItem> _ministrySubjects = [];
  List<AssociationSubjectItem> _associationSubjects = [];
  List<ServiceItem> _services = [];
  List<WeeklyTemplateItem> _weeklyTemplates = [];

  @override
  void initState()
  {
    super.initState();
    _visitedSections.add(_selectedSection);
    _loadAllData();
  }

  // The page is not taken down when you walk away from it, so it asks for its
  // data again on the way back. Under its breath: what is on screen stays on
  // screen until the answer arrives.
  @override
  void onDestinationShown() => _loadAllData(quiet: true);

  // Quiet means asked for again rather than asked for the first time: the page
  // is already showing what it loaded when it was opened, so a failure leaves it
  // standing and says nothing instead of raising an error over a page that is
  // perfectly readable.
  Future<void> _loadAllData({bool quiet = false}) async
  {
    try
    {
      final results = await Future.wait([
        _apiService.getSchools(),
        _apiService.getStudyPrograms(),
        _apiService.getMinistrySubjects(),
        _apiService.getAssociationSubjects(),
        _apiService.getServices(),
        _apiService.getWeeklyTemplates(),
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
        _services = results[4] as List<ServiceItem>;
        _weeklyTemplates = results[5] as List<WeeklyTemplateItem>;
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

      if (!quiet)
      {
        CustomSnackBar.show(context: context, message: 'Impossibile caricare i dati dal server.', isError: true);
      }
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

  Future<void> _refreshWeeklyTemplates() async
  {
    try
    {
      final refreshed = await _apiService.getWeeklyTemplates();

      if (mounted)
      {
        setState(() => _weeklyTemplates = refreshed);
      }
    }
    catch (e)
    {
      // Intentionally ignored, see the note above.
    }
  }

  // --- Services ----------------------------------------------------------
  // Nothing is denormalized onto a service and nothing hangs off one yet, so
  // none of these trigger a cascade refresh.

  Future<bool> _executeCreateService(String name, String description, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createService(name, description);

      if (!mounted)
      {
        return true;
      }

      setState(() => _services = [..._services, created]);
      CustomSnackBar.show(context: context, message: 'Servizio creato con successo!', isError: false);

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  // A service is identified by its name, so an edit changing it replaces the row
  // whose name was the previous one: originalName is the key, name is the new
  // value.
  Future<bool> _executeEditService(String originalName, String name, String description, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateService(originalName, name, description);

      if (!mounted)
      {
        return true;
      }

      setState(() => _services = _services.map((s) => s.name == originalName ? updated : s).toList());
      CustomSnackBar.show(context: context, message: 'Servizio modificato con successo!', isError: false);

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<void> _executeDeleteService(ServiceItem item) async
  {
    try
    {
      await _apiService.deleteService(item.name);

      if (!mounted)
      {
        return;
      }

      setState(() => _services = _services.where((s) => s.name != item.name).toList());
      CustomSnackBar.show(context: context, message: 'Servizio eliminato con successo!', isError: false);
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  // --- Association subjects ----------------------------------------------

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

  // --- Ministry subjects -------------------------------------------------

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

  // --- Study programs ----------------------------------------------------

  Future<bool> _executeCreateStudyProgram(String name, String? sector, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createStudyProgram(
        name: name,
        sector: sector,
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

  Future<bool> _executeEditStudyProgram(int id, String name, String? sector, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateStudyProgram(
        id: id,
        name: name,
        sector: sector,
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

  // --- Schools -----------------------------------------------------------
  // The school sits at the top of the denormalization chain, so its edit and
  // delete do not trigger any cascade refresh.

  Future<bool> _executeCreateSchool(String? code, String name, String city, String provinceCode, List<int> programIds, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createSchool(
        code: code,
        name: name,
        city: city,
        province: provinceCode,
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

  Future<bool> _executeEditSchool(int id, String? code, String name, String city, String provinceCode, List<int> programIds, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateSchool(
        id: id,
        code: code,
        name: name,
        city: city,
        province: provinceCode,
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

  // IndexedStack keeps the state of already visited sections alive: the
  // placeholder is replaced only on first visit, after which the section stays
  // mounted and does not reload until the whole page is closed. Shared data
  // arrives from above through the widget properties, so a setState here
  // propagates to the mounted sections through their didUpdateWidget, without
  // disposing and recreating their internal state (scroll, filters, search).
  Widget _buildSectionContent()
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    return PageSections(
      index: _selectedSection,
      children: [
        _visitedSections.contains(_servicesContentIndex)
            ? ServicesTab(
                services: _services,
                onCreate: _executeCreateService,
                onEdit: _executeEditService,
                onDelete: _executeDeleteService,
              )
            : const SizedBox.shrink(),
        _visitedSections.contains(_associationSubjectsContentIndex)
            ? AssociationSubjectsTab(
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateAssociationSubject,
                onEdit: _executeEditAssociationSubject,
                onDelete: _executeDeleteAssociationSubject,
              )
            : const SizedBox.shrink(),
        _visitedSections.contains(_ministrySubjectsContentIndex)
            ? MinistrySubjectsTab(
                ministrySubjects: _ministrySubjects,
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateMinistrySubject,
                onEdit: _executeEditMinistrySubject,
                onDelete: _executeDeleteMinistrySubject,
              )
            : const SizedBox.shrink(),
        _visitedSections.contains(_studyProgramsContentIndex)
            ? StudyProgramsTab(
                studyPrograms: _studyPrograms,
                ministrySubjects: _ministrySubjects,
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateStudyProgram,
                onEdit: _executeEditStudyProgram,
                onDelete: _executeDeleteStudyProgram,
              )
            : const SizedBox.shrink(),
        _visitedSections.contains(_schoolsContentIndex)
            ? SchoolsTab(
                schools: _schools,
                studyPrograms: _studyPrograms,
                ministrySubjects: _ministrySubjects,
                onCreate: _executeCreateSchool,
                onEdit: _executeEditSchool,
                onDelete: _executeDeleteSchool,
              )
            : const SizedBox.shrink(),
        _visitedSections.contains(_presenceHoursContentIndex)
            ? PresenceHoursTab(weeklyTemplates: _weeklyTemplates, onWeeklyTemplatesChanged: _refreshWeeklyTemplates)
            : const SizedBox.shrink(),
        _visitedSections.contains(_onlineHoursContentIndex)
            ? OnlineHoursTab(weeklyTemplates: _weeklyTemplates, onWeeklyTemplatesChanged: _refreshWeeklyTemplates)
            : const SizedBox.shrink(),
      ],
    );
  }

  void _selectSection(int index)
  {
    setState(()
    {
      _selectedSection = index;
      _visitedSections.add(index);
    });
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
          final size = AppBreakpoints.fromWidth(width);
          final margin = AppBreakpoints.pageMargin(size);

          return Container(
            width: width,
            height: height,
            color: AppTheme.trialPaper,
            child: Stack(
              children: [
                // Same pair of glows the dashboard wears, on the same paper: the
                // two ends of the mockup's background ramp, split between the
                // corners. See the note in DashboardLayout for why they both
                // fade towards a blue.
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                  animated: true,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                  animated: true,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    // The top inset clears the bar floating above the page: it
                    // is laid over the content rather than in the column with
                    // it, so the room it needs has to be left here.
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: AppTopBar.contentTopInsetFor(size),
                      bottom: 24,
                    ),
                    // Stretched, so the content keeps being handed the full
                    // height it was given when it sat in a column; the rail is
                    // pinned back to its own height inside that.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The rail steps aside below the breakpoint. Two hundred
                        // and seventy pixels of a phone cannot go to a column of
                        // section names, and the drawer behind the bar is
                        // already holding them.
                        if (size.hasRail) ...[
                          Align(
                            alignment: Alignment.topLeft,
                            // First out and first back in on a change of page:
                            // the rail is what frames the content beside it.
                            child: PageTransitionItem(
                              slot: PageTransitionItem.frame,
                              child: AppSectionRail(
                                title: 'Associazione',
                                groups: _sections,
                                selectedIndex: _selectedSection,
                                onSelected: _selectSection,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSectionRail.gap),
                        ],
                        Expanded(
                          child: size.isCompact
                              // What the rail was saying about where you are has
                              // to keep being said: the module quietly, over the
                              // section you are in.
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    PageTransitionItem(
                                      slot: PageTransitionItem.frame,
                                      child: AppSectionHeading(
                                        module: 'Associazione',
                                        section: railEntryAt(_sections, _selectedSection),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Expanded(child: _buildSectionContent()),
                                  ],
                                )
                              : _buildSectionContent(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Last in the stack, so the bar and the menu it opens stay above
                // the page.
                AppTopBar(
                  currentRoute: '/association',
                  sectionTitle: 'Associazione',
                  sectionGroups: _sections,
                  selectedSection: _selectedSection,
                  onSectionSelected: _selectSection,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}