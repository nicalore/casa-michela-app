import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/state/entity_writes.dart';
import '../../core/theme/app_theme.dart';
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
import 'models/room_item.dart';
import 'models/school_item.dart';
import 'models/service_item.dart';
import 'models/study_program_item.dart';
import 'models/weekly_template_item.dart';
import 'tabs/association_subjects_tab.dart';
import 'tabs/ministry_subjects_tab.dart';
import 'tabs/online_hours_tab.dart';
import 'tabs/presence_hours_tab.dart';
import 'tabs/rooms_tab.dart';
import 'tabs/schools_tab.dart';
import 'tabs/services_tab.dart';
import 'tabs/study_programs_tab.dart';

const int _servicesContentIndex = 0;
const int _associationSubjectsContentIndex = 1;
const int _ministrySubjectsContentIndex = 2;
const int _studyProgramsContentIndex = 3;
const int _schoolsContentIndex = 4;
const int _roomsContentIndex = 5;
const int _presenceHoursContentIndex = 6;
const int _onlineHoursContentIndex = 7;

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
  // On its own between the teaching and the hours: a room is neither, and one
  // entry does not need a heading over it to say what it is.
  RailGroup(entries: ['Stanze']),
  RailGroup(title: 'Orari', entries: ['In presenza', 'Online']),
];

class AssociationPage extends StatefulWidget
{
  const AssociationPage({super.key});

  @override
  State<AssociationPage> createState() => _AssociationPageState();
}

class _AssociationPageState extends State<AssociationPage>
    with SectionVisits, DestinationRefresh, EntityWrites
{
  final ApiService _apiService = ApiService();

  // The page opens on the first entry of the rail, which is now the services.
  int _selectedSection = _servicesContentIndex;

  // Single source of truth for the entities shared across tabs, loaded once
  // when the page opens. Every setState here propagates to the frozen tabs in
  // the IndexedStack through their didUpdateWidget.
  bool _isLoading = true;
  List<SchoolItem> _schools = [];
  List<StudyProgramItem> _studyPrograms = [];
  List<MinistrySubjectItem> _ministrySubjects = [];
  List<AssociationSubjectItem> _associationSubjects = [];
  List<ServiceItem> _services = [];
  List<RoomItem> _rooms = [];
  List<WeeklyTemplateItem> _weeklyTemplates = [];

  @override
  void initState()
  {
    super.initState();
    visitedSections.add(_selectedSection);
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
        _apiService.getRooms(),
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
        _rooms = results[5] as List<RoomItem>;
        _weeklyTemplates = results[6] as List<WeeklyTemplateItem>;
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
  // copy fresh again.

  // Refetches one level of the catalogue.
  //
  // The failure is swallowed on purpose: the write that made this necessary has
  // already gone through, and a stale nested copy is no reason to tell whoever
  // asked that their operation failed.
  Future<void> _refresh<T>(Future<List<T>> Function() fetch, void Function(List<T>) apply) async
  {
    try
    {
      final refreshed = await fetch();

      if (mounted)
      {
        setState(() => apply(refreshed));
      }
    }
    catch (_)
    {
      // See above.
    }
  }

  Future<void> _refreshMinistrySubjects()
  {
    return _refresh(_apiService.getMinistrySubjects, (rows) => _ministrySubjects = rows);
  }

  Future<void> _refreshStudyPrograms()
  {
    return _refresh(_apiService.getStudyPrograms, (rows) => _studyPrograms = rows);
  }

  Future<void> _refreshSchools()
  {
    return _refresh(_apiService.getSchools, (rows) => _schools = rows);
  }

  Future<void> _refreshWeeklyTemplates()
  {
    return _refresh(_apiService.getWeeklyTemplates, (rows) => _weeklyTemplates = rows);
  }

  // --- Services ----------------------------------------------------------
  // Nothing is denormalized onto a service and nothing hangs off one yet, so
  // none of these trigger a cascade refresh.

  Future<bool> _executeCreateService(String name, String description, Function(String) onError)
  {
    return write(
      call: () => _apiService.createService(name, description),
      apply: (created) => _services = [..._services, created],
      done: 'Servizio creato con successo!',
      onError: onError,
    );
  }

  // A service is identified by its name, so an edit changing it replaces the row
  // whose name was the previous one: originalName is the key, name is the new
  // value.
  Future<bool> _executeEditService(String originalName, String name, String description, Function(String) onError)
  {
    return write(
      call: () => _apiService.updateService(originalName, name, description),
      apply: (updated) => _services = _services.map((s) => s.name == originalName ? updated : s).toList(),
      done: 'Servizio modificato con successo!',
      onError: onError,
    );
  }

  Future<void> _executeDeleteService(ServiceItem item)
  {
    return erase(
      call: () => _apiService.deleteService(item.name),
      apply: () => _services = _services.where((s) => s.name != item.name).toList(),
      done: 'Servizio eliminato con successo!',
    );
  }

  // --- Association subjects ----------------------------------------------

  Future<bool> _executeCreateAssociationSubject(String name, String area, String description, Function(String) onError)
  {
    return write(
      call: () => _apiService.createAssociationSubject(name, area, description),
      apply: (created) => _associationSubjects = [..._associationSubjects, created],
      done: 'Disciplina interna creata con successo!',
      onError: onError,
    );
  }

  Future<bool> _executeEditAssociationSubject(int id, String name, String area, String description, Function(String) onError)
  {
    return write(
      call: () => _apiService.updateAssociationSubject(id, name, area, description),
      apply: (updated) => _associationSubjects = _associationSubjects.map((s) => s.id == id ? updated : s).toList(),
      done: 'Disciplina interna modificata con successo!',
      onError: onError,
      cascade: _refreshMinistrySubjects,
    );
  }

  Future<void> _executeDeleteAssociationSubject(AssociationSubjectItem item)
  {
    return erase(
      call: () => _apiService.deleteAssociationSubject(item.id),
      apply: () => _associationSubjects = _associationSubjects.where((s) => s.id != item.id).toList(),
      done: 'Disciplina interna eliminata con successo!',
      cascade: _refreshMinistrySubjects,
    );
  }

  // --- Ministry subjects -------------------------------------------------

  Future<bool> _executeCreateMinistrySubject(String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError)
  {
    return write(
      call: () => _apiService.createMinistrySubject(
        name: name,
        level: level,
        areas: areas,
        description: description,
        associationSubjectIds: associationIds,
      ),
      apply: (created) => _ministrySubjects = [..._ministrySubjects, created],
      done: 'Materia ministeriale creata con successo!',
      onError: onError,
    );
  }

  Future<bool> _executeEditMinistrySubject(int id, String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError)
  {
    return write(
      call: () => _apiService.updateMinistrySubject(
        id: id,
        name: name,
        level: level,
        areas: areas,
        description: description,
        associationSubjectIds: associationIds,
      ),
      apply: (updated) => _ministrySubjects = _ministrySubjects.map((s) => s.id == id ? updated : s).toList(),
      done: 'Materia ministeriale modificata con successo!',
      onError: onError,
      cascade: _refreshStudyPrograms,
    );
  }

  Future<void> _executeDeleteMinistrySubject(MinistrySubjectItem item)
  {
    return erase(
      call: () => _apiService.deleteMinistrySubject(item.id),
      apply: () => _ministrySubjects = _ministrySubjects.where((s) => s.id != item.id).toList(),
      done: 'Materia ministeriale eliminata con successo!',
      cascade: _refreshStudyPrograms,
    );
  }

  // --- Study programs ----------------------------------------------------

  Future<bool> _executeCreateStudyProgram(String name, String? sector, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError)
  {
    return write(
      call: () => _apiService.createStudyProgram(
        name: name,
        sector: sector,
        level: level,
        minYear: minYear,
        maxYear: maxYear,
        description: description,
        ministrySubjectIds: subjectIds,
      ),
      apply: (created) => _studyPrograms = [..._studyPrograms, created],
      done: 'Percorso creato con successo!',
      onError: onError,
    );
  }

  Future<bool> _executeEditStudyProgram(int id, String name, String? sector, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError)
  {
    return write(
      call: () => _apiService.updateStudyProgram(
        id: id,
        name: name,
        sector: sector,
        level: level,
        minYear: minYear,
        maxYear: maxYear,
        description: description,
        ministrySubjectIds: subjectIds,
      ),
      apply: (updated) => _studyPrograms = _studyPrograms.map((p) => p.id == id ? updated : p).toList(),
      done: 'Percorso modificato con successo!',
      onError: onError,
      cascade: _refreshSchools,
    );
  }

  Future<void> _executeDeleteStudyProgram(StudyProgramItem item)
  {
    return erase(
      call: () => _apiService.deleteStudyProgram(item.id),
      apply: () => _studyPrograms = _studyPrograms.where((p) => p.id != item.id).toList(),
      done: 'Percorso eliminato con successo!',
      cascade: _refreshSchools,
    );
  }

  // --- Schools -----------------------------------------------------------
  // The school sits at the top of the denormalization chain, so its edit and
  // delete do not trigger any cascade refresh.

  Future<bool> _executeCreateSchool(String? code, String name, String city, String provinceCode, List<int> programIds, Function(String) onError)
  {
    return write(
      call: () => _apiService.createSchool(
        code: code,
        name: name,
        city: city,
        province: provinceCode,
        studyProgramIds: programIds,
      ),
      apply: (created) => _schools = [..._schools, created],
      done: 'Scuola creata con successo!',
      onError: onError,
    );
  }

  Future<bool> _executeEditSchool(int id, String? code, String name, String city, String provinceCode, List<int> programIds, Function(String) onError)
  {
    return write(
      call: () => _apiService.updateSchool(
        id: id,
        code: code,
        name: name,
        city: city,
        province: provinceCode,
        studyProgramIds: programIds,
      ),
      apply: (updated) => _schools = _schools.map((s) => s.id == id ? updated : s).toList(),
      done: 'Scuola modificata con successo!',
      onError: onError,
    );
  }

  Future<void> _executeDeleteSchool(SchoolItem item)
  {
    return erase(
      call: () => _apiService.deleteSchool(item.id),
      apply: () => _schools = _schools.where((s) => s.id != item.id).toList(),
      done: 'Scuola eliminata con successo!',
    );
  }

  // --- Rooms -------------------------------------------------------------
  // Nothing is denormalized onto a room, and what hangs off one — the days it
  // has been assigned for — is what stops it from being deleted rather than
  // something to refresh afterwards. So none of these trigger a cascade.

  Future<bool> _executeCreateRoom(String name, int? capacity, String description, Function(String) onError)
  {
    return write(
      call: () => _apiService.createRoom(name: name, description: description, capacity: capacity),
      apply: (created) => _rooms = [..._rooms, created],
      done: 'Stanza creata con successo!',
      onError: onError,
    );
  }

  Future<bool> _executeEditRoom(int id, String name, int? capacity, String description, Function(String) onError)
  {
    return write(
      call: () => _apiService.updateRoom(id: id, name: name, description: description, capacity: capacity),
      apply: (updated) => _rooms = _rooms.map((r) => r.id == id ? updated : r).toList(),
      done: 'Stanza modificata con successo!',
      onError: onError,
    );
  }

  Future<void> _executeDeleteRoom(RoomItem item)
  {
    return erase(
      call: () => _apiService.deleteRoom(item.id),
      apply: () => _rooms = _rooms.where((r) => r.id != item.id).toList(),
      done: 'Stanza eliminata con successo!',
    );
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
        visitedSections.contains(_servicesContentIndex)
            ? ServicesTab(
                services: _services,
                onCreate: _executeCreateService,
                onEdit: _executeEditService,
                onDelete: _executeDeleteService,
              )
            : const SizedBox.shrink(),
        visitedSections.contains(_associationSubjectsContentIndex)
            ? AssociationSubjectsTab(
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateAssociationSubject,
                onEdit: _executeEditAssociationSubject,
                onDelete: _executeDeleteAssociationSubject,
              )
            : const SizedBox.shrink(),
        visitedSections.contains(_ministrySubjectsContentIndex)
            ? MinistrySubjectsTab(
                ministrySubjects: _ministrySubjects,
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateMinistrySubject,
                onEdit: _executeEditMinistrySubject,
                onDelete: _executeDeleteMinistrySubject,
              )
            : const SizedBox.shrink(),
        visitedSections.contains(_studyProgramsContentIndex)
            ? StudyProgramsTab(
                studyPrograms: _studyPrograms,
                ministrySubjects: _ministrySubjects,
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateStudyProgram,
                onEdit: _executeEditStudyProgram,
                onDelete: _executeDeleteStudyProgram,
              )
            : const SizedBox.shrink(),
        visitedSections.contains(_schoolsContentIndex)
            ? SchoolsTab(
                schools: _schools,
                studyPrograms: _studyPrograms,
                ministrySubjects: _ministrySubjects,
                onCreate: _executeCreateSchool,
                onEdit: _executeEditSchool,
                onDelete: _executeDeleteSchool,
              )
            : const SizedBox.shrink(),
        visitedSections.contains(_roomsContentIndex)
            ? RoomsTab(
                rooms: _rooms,
                onCreate: _executeCreateRoom,
                onEdit: _executeEditRoom,
                onDelete: _executeDeleteRoom,
              )
            : const SizedBox.shrink(),
        visitedSections.contains(_presenceHoursContentIndex)
            ? PresenceHoursTab(weeklyTemplates: _weeklyTemplates, onWeeklyTemplatesChanged: _refreshWeeklyTemplates)
            : const SizedBox.shrink(),
        visitedSections.contains(_onlineHoursContentIndex)
            ? OnlineHoursTab(weeklyTemplates: _weeklyTemplates, onWeeklyTemplatesChanged: _refreshWeeklyTemplates)
            : const SizedBox.shrink(),
      ],
    );
  }

  void _selectSection(int index)
  {
    openSection(index, () => _selectedSection = index);
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
