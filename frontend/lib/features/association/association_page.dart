import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import 'models/association_subject_item.dart';
import 'models/ministry_subject_item.dart';
import 'models/school_item.dart';
import 'models/study_program_item.dart';
import 'models/weekly_template_item.dart';
import 'tabs/association_subjects_tab.dart';
import 'tabs/ministry_subjects_tab.dart';
import 'tabs/orari_in_presenza_tab.dart';
import 'tabs/orari_online_tab.dart';
import 'tabs/schools_tab.dart';
import 'tabs/study_programs_tab.dart';

const int _schoolsContentIndex = 0;
const int _associationSubjectsContentIndex = 1;
const int _ministrySubjectsContentIndex = 2;
const int _studyProgramsContentIndex = 3;
const int _orariInPresenzaContentIndex = 4;
const int _orariOnlineContentIndex = 5;

// The order here is the order of the IndexedStack below, and the constants
// above are the indices into both.
const List<RailGroup> _sections = [
  RailGroup(entries: ['Scuole']),
  RailGroup(
    title: 'Didattica',
    entries: ['Discipline interne', 'Materie ministeriali', 'Percorsi di studio'],
  ),
  RailGroup(title: 'Orari', entries: ['In presenza', 'Online']),
];

class AssociationPage extends StatefulWidget
{
  const AssociationPage({super.key});

  @override
  State<AssociationPage> createState() => _AssociationPageState();
}

class _AssociationPageState extends State<AssociationPage>
{
  final ApiService _apiService = ApiService();

  int _selectedSection = _schoolsContentIndex;

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
  List<WeeklyTemplateItem> _weeklyTemplates = [];

  @override
  void initState()
  {
    super.initState();
    _visitedSections.add(_selectedSection);
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
        _weeklyTemplates = results[4] as List<WeeklyTemplateItem>;
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return IndexedStack(
      index: _selectedSection,
      children: [
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
        _visitedSections.contains(_orariInPresenzaContentIndex)
            ? OrariInPresenzaTab(weeklyTemplates: _weeklyTemplates, onWeeklyTemplatesChanged: _refreshWeeklyTemplates)
            : const SizedBox.shrink(),
        _visitedSections.contains(_orariOnlineContentIndex)
            ? OrariOnlineTab(weeklyTemplates: _weeklyTemplates, onWeeklyTemplatesChanged: _refreshWeeklyTemplates)
            : const SizedBox.shrink(),
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
                    padding: const EdgeInsets.only(
                      left: 40,
                      right: 40,
                      top: AppTopBar.contentTopInset,
                      bottom: 24,
                    ),
                    // Stretched, so the content keeps being handed the full
                    // height it was given when it sat in a column; the rail is
                    // pinned back to its own height inside that.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: AppSectionRail(
                            title: 'Associazione',
                            groups: _sections,
                            selectedIndex: _selectedSection,
                            onSelected: (index) => setState(()
                            {
                              _selectedSection = index;
                              _visitedSections.add(index);
                            }),
                          ),
                        ),
                        const SizedBox(width: AppSectionRail.gap),
                        Expanded(child: _buildSectionContent()),
                      ],
                    ),
                  ),
                ),
                // Last in the stack, so the bar and the menu it opens stay above
                // the page.
                const AppTopBar(currentRoute: '/association'),
              ],
            ),
          );
        },
      ),
    );
  }
}