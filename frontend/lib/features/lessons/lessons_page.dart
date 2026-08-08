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
import '../association/models/association_subject_item.dart';
import '../association/models/ministry_subject_item.dart';
import '../association/models/service_item.dart';
import '../association/models/opening_day_item.dart';
import '../association/models/study_program_item.dart';
import '../people/models/person_item.dart';
import 'models/availability_item.dart';
import 'models/booking_summary_item.dart';
import 'models/presence_item.dart';
import 'tabs/availability_tab.dart';
import 'tabs/bookings_tab.dart';
import 'tabs/calendar_tab.dart';
import 'utils/booking_window.dart';
import 'utils/opening_window.dart';
import 'widgets/lessons_day_header.dart';
import 'widgets/lessons_toolbar.dart';

// The order here is the order of the IndexedStack below.
const int _availabilityContentIndex = 0;
const int _bookingsContentIndex = 1;
const int _calendarContentIndex = 2;

// Both lists are worked one day at a time, and neither of them means much
// without the other: they are one day seen from two sides. So the rail asks for
// the day — a heading with the open days of the booking window under it, the
// way Didattica stands over its own sections in Associazione — and the side is
// chosen by a switch over the content. The chips that used to carry the days
// above the search bar go with it: the rail is where this app asks where you
// want to be.
List<RailGroup> _buildSections(List<DateTime> days)
{
  return [
    // Not "Disponibilità e prenotazioni": at the size the rail sets a heading
    // that would be cut short of its own last word. What stands under it are
    // days, and the switch below says which side of them you are on.
    RailGroup(title: 'Giornate', entries: days.map(formatAvailableDayLabel).toList()),
    const RailGroup(entries: ['Calendario']),
  ];
}

const String _teacherRoleLabel = 'Docente';
const String _studentRoleLabel = 'Studente';

class LessonsPage extends StatefulWidget
{
  const LessonsPage({super.key});

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> with DestinationRefresh
{
  final ApiService _apiService = ApiService();

  // The days the window has open, computed once per page lifetime: they are the
  // entries of the rail, and the tabs are handed the one it is on.
  late final List<DateTime> _availableDays = computeAvailableDays(DateTime.now());

  late final List<RailGroup> _sections = _buildSections(_availableDays);

  // Counted the way the rail counts — entries only, headings excluded — so it
  // is either one of the open days or, past the last of them, the calendar.
  int _selectedSection = 0;

  // Which side of the day is on screen. It survives a change of day on purpose:
  // filling a week's availabilities in means walking down the days with the
  // list you are working on staying put.
  LessonsDayView _dayView = LessonsDayView.availability;

  // Records which tabs have been opened: once visited a tab stays mounted in
  // the IndexedStack. Reset only when GoRouter destroys this page.
  final Set<int> _visitedSections = {};

  // Single source of truth for the entities shared across tabs, loaded once
  // when the page opens.
  bool _isLoading = true;
  List<PersonItem> _people = [];
  List<MinistrySubjectItem> _ministrySubjects = [];

  // Le altre due categorie fra cui si puo' chiedere un'ora.
  List<AssociationSubjectItem> _associationSubjects = [];
  List<ServiceItem> _services = [];
  List<StudyProgramItem> _studyPrograms = [];
  List<AvailabilityItem> _availabilities = [];
  List<PresenceItem> _presences = [];

  // When the association is open, in the building and at a screen, across the
  // days the booking window has unlocked. A teacher can only be available where
  // the association is open, so this is what the wizard is bounded by.
  List<OpeningDayItem> _openingDays = [];

  List<PersonItem> get _teachers => _people.where((person) => person.roles.contains(_teacherRoleLabel)).toList();

  List<PersonItem> get _students => _people.where((person) => person.roles.contains(_studentRoleLabel)).toList();

  // Past the last of the open days there is one entry left, and it is the
  // calendar.
  bool get _isCalendarSelected => _selectedSection >= _availableDays.length;

  // Which of the three tabs is on screen: the day the rail is on, seen from the
  // side the switch is on, or the calendar.
  int get _contentIndex
  {
    if (_isCalendarSelected)
    {
      return _calendarContentIndex;
    }

    return _dayView == LessonsDayView.availability
        ? _availabilityContentIndex
        : _bookingsContentIndex;
  }

  // The day the rail is on. The calendar has no day of its own and never asks
  // for one, so it falls back to the first, which is today.
  DateTime get _selectedDay
  {
    return _isCalendarSelected ? _availableDays.first : _availableDays[_selectedSection];
  }

  // A day the association opens in neither way. The tabs say so themselves, in
  // large, and the head of the day steps aside for them: counting nobody in a
  // day nobody can be in is a line saying nothing twice.
  bool get _isSelectedDayClosed
  {
    return !isOpenOn(_openingDays, _selectedDay, kPresenceMode) &&
        !isOpenOn(_openingDays, _selectedDay, kOnlineMode);
  }

  // What the day amounts to, counted before any search: the two lists are what
  // has to add up here, and each of them can only count itself.
  //
  // People on either side, not rows: a teacher leaving two slots open is one
  // teacher, and a pupil booked in twice is one pupil. The lists below are
  // where the rows are.
  int get _availableTeachersToday
  {
    return _availabilities
        .where((availability) => isSameDate(availability.date, _selectedDay))
        .map((availability) => availability.teacherTaxCode)
        .toSet()
        .length;
  }

  int get _presentStudentsToday
  {
    return _presences
        .where((presence) => isSameDate(presence.date, _selectedDay))
        .map((presence) => presence.studentTaxCode)
        .toSet()
        .length;
  }

  @override
  void initState()
  {
    super.initState();
    _visitedSections.add(_contentIndex);
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
        _apiService.getPeople(),
        _apiService.getMinistrySubjects(),
        _apiService.getStudyPrograms(),
        _apiService.getAvailabilities(),
        _apiService.getPresences(),
        _apiService.getOpeningDays(
          dateFrom: _availableDays.first,
          dateTo: _availableDays.last,
          mode: kPresenceMode,
        ),
        _apiService.getOpeningDays(
          dateFrom: _availableDays.first,
          dateTo: _availableDays.last,
          mode: kOnlineMode,
        ),
        _apiService.getAssociationSubjects(),
        _apiService.getServices(),
      ]);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _people = results[0] as List<PersonItem>;
        _ministrySubjects = results[1] as List<MinistrySubjectItem>;
        _studyPrograms = results[2] as List<StudyProgramItem>;
        _availabilities = results[3] as List<AvailabilityItem>;
        _presences = results[4] as List<PresenceItem>;
        _openingDays = [
          ...results[5] as List<OpeningDayItem>,
          ...results[6] as List<OpeningDayItem>,
        ];
        _associationSubjects = results[7] as List<AssociationSubjectItem>;
        _services = results[8] as List<ServiceItem>;
        _isLoading = false;
      });
    }
    catch (e, stackTrace)
    {
      // Nine calls in parallel and one sentence for all of them: which of the
      // nine failed, and why, is only readable here.
      reportCaughtError(e, stackTrace, during: 'il caricamento di Lezioni');

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

  // --- Availabilities -----------------------------------------------------

  Future<bool> _executeCreateAvailability(String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createAvailability(
        teacherTaxCode: teacherTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _availabilities = [..._availabilities, created]);

      // Quiet: a day is written a stretch at a time, and a window that saved
      // six of them would say so six times over. What it did is announced once,
      // by the window, when it is done.
      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<bool> _executeEditAvailability(AvailabilityItem existing, String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateAvailability(
        id: existing.id,
        teacherTaxCode: teacherTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _availabilities = _availabilities.map((a) => a.id == existing.id ? updated : a).toList());

      // Quiet, for the same reason as the creation above.
      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  // A day's availability is deleted whole: the card is a teacher on a day, and
  // the stretches of hours on it are the parts of one thing.
  Future<void> _executeDeleteAvailabilityGroup(List<AvailabilityItem> slots) async
  {
    try
    {
      for (final slot in slots)
      {
        await _apiService.deleteAvailability(slot.id);
      }

      if (!mounted)
      {
        return;
      }

      final removed = slots.map((slot) => slot.id).toSet();

      setState(() => _availabilities = _availabilities.where((a) => !removed.contains(a.id)).toList());
      CustomSnackBar.show(context: context, message: 'Disponibilità eliminata con successo!', isError: false);
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  // One stretch dropped from a day that keeps the others. Quiet on purpose: it
  // is a step inside a save, and the window that asked for it says how the save
  // went when it is done.
  Future<bool> _executeDeleteAvailabilitySlot(AvailabilityItem item, Function(String) onError) async
  {
    try
    {
      await _apiService.deleteAvailability(item.id);

      if (!mounted)
      {
        return true;
      }

      setState(() => _availabilities = _availabilities.where((a) => a.id != item.id).toList());

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  // --- Lesson requests (Presence + Booking) -----------------------------

  // A whole day written in one go: the bands and the lessons of every requested
  // mode, in one transaction. It either passes as a whole or not at all —
  // writing one presence and one lesson per call left a day on the server that
  // nobody had asked for that way.
  Future<bool> _executeCreateLessonRequest(
    String studentTaxCode,
    DateTime date,
    List<Map<String, dynamic>> modes,
    Function(String) onError,
  ) async
  {
    try
    {
      final created = await _apiService.createLessonRequest(
        studentTaxCode: studentTaxCode,
        date: date,
        modes: modes,
      );

      if (mounted)
      {
        setState(() => _presences = [..._presences, ...created]);
      }

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  Future<PresenceItem?> _executeCreatePresence(String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createPresence(
        studentTaxCode: studentTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
      );

      if (!mounted)
      {
        return created;
      }

      setState(() => _presences = [..._presences, created]);

      // Quiet: the wizard writes one presence per day and per slot, and says
      // once at the end how it went.
      return created;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return null;
    }
  }

  Future<bool> _executeEditPresence(PresenceItem existing, String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updatePresence(
        id: existing.id,
        studentTaxCode: studentTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
      );

      if (!mounted)
      {
        return true;
      }

      setState(() => _presences = _presences.map((p) => p.id == existing.id ? updated : p).toList());

      // Quiet, for the same reason as the creation above.
      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }
  }

  // One stretch taken off a day inside a save: a step, not an announcement.
  Future<bool> _executeDeletePresenceQuietly(PresenceItem item, Function(String) onError) async
  {
    try
    {
      await _apiService.deletePresence(item.id);

      if (!mounted)
      {
        return true;
      }

      setState(() => _presences = _presences.where((p) => p.id != item.id).toList());

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }
  }

  // And the same for a request taken off one.
  Future<bool> _executeDeleteBookingQuietly(BookingSummaryItem booking, int presenceId, Function(String) onError) async
  {
    try
    {
      await _apiService.deleteBooking(booking.id);
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }

    await _refreshPresence(presenceId);

    return true;
  }

  // A whole day's request: every stretch of it, both ways of being there. The
  // materie hanging from them go with them, by the cascade in the database.
  Future<void> _executeDeleteRequestGroup(List<PresenceItem> slots) async
  {
    try
    {
      for (final slot in slots)
      {
        await _apiService.deletePresence(slot.id);
      }

      if (!mounted)
      {
        return;
      }

      final removed = slots.map((slot) => slot.id).toSet();

      setState(() => _presences = _presences.where((p) => !removed.contains(p.id)).toList());
      CustomSnackBar.show(context: context, message: 'Richiesta eliminata con successo!', isError: false);
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  // Reading back the day just written to, without its outcome becoming the
  // outcome of the write.
  //
  // They are two different things and are kept different: a subject that was
  // written is written even if the read-back never arrives, and counting that as
  // a failure did two kinds of damage at once — it stopped a day's save halfway,
  // and left the old row on screen with an updated_at already superseded, which
  // took a 409 on the next save.
  Future<void> _refreshPresence(int presenceId) async
  {
    try
    {
      final refreshed = await _apiService.getPresence(presenceId);

      if (mounted)
      {
        setState(() => _presences = _presences.map((p) => p.id == presenceId ? refreshed : p).toList());
      }
    }
    catch (e, stackTrace)
    {
      // Nothing to say to whoever is writing: what they wanted went through,
      // and the page is read in full on the next opening. But a failed read-back
      // leaves an old row on screen, and that has to be seen.
      reportCaughtError(e, stackTrace, during: 'la rilettura di una giornata');
    }
  }

  Future<bool> _executeCreateBooking(int presenceId, Map<String, dynamic> subject, Function(String) onError) async
  {
    try
    {
      await _apiService.createBooking(presenceId: presenceId, subject: subject);
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }

    await _refreshPresence(presenceId);

    // Quiet: the presence wizard hangs the same booking on every presence it
    // has just created, and each window says once what it did.
    return true;
  }

  Future<bool> _executeEditBooking(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError) async
  {
    try
    {
      await _apiService.updateBooking(
        id: existing.id,
        subject: subject,
        expectedUpdatedAt: existing.updatedAt,
      );
    }
    catch (e)
    {
      onError(readableApiError(e));
      return false;
    }

    await _refreshPresence(presenceId);

    // Quiet, for the same reason as the creation above.
    return true;
  }

  Widget _buildSectionContent(AppWindowSize size)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    if (_isCalendarSelected || _isSelectedDayClosed)
    {
      return _buildTabs();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: LessonsDayHeader(
            day: _selectedDay,
            showDay: !size.isCompact,
            availableTeachers: _availableTeachersToday,
            presentStudents: _presentStudentsToday,
          ),
        ),
        Expanded(child: _buildTabs()),
      ],
    );
  }

  // IndexedStack keeps the state of already visited tabs alive: the
  // placeholder is replaced only on first visit, after which the tab stays
  // mounted and does not reload until the whole page is closed.
  //
  // The two lists of a day are the exception: they are built together from the
  // start. They are two ways of looking at one day rather than two places, the
  // switch that chooses between them stands on both, and a switch built at the
  // moment it is looked at has nowhere to slide from — it opens with its pill
  // already on the answer. Neither of them asks anything of the network; the
  // day is loaded once, by this page.
  Widget _buildTabs()
  {
    return IndexedStack(
      index: _contentIndex,
      children: [
        // Which side the page is on is passed to both of them rather than each
        // naming itself: the toolbar shows the answer, and the answer is held
        // here. Told it, the one being left slides its pill across as the one
        // arriving comes up wearing the same position.
        AvailabilityTab(
          view: _dayView,
          availabilities: _availabilities,
          teachers: _teachers,
          availableDays: _availableDays,
          selectedDay: _selectedDay,
          openingDays: _openingDays,
          onViewSelected: _selectView,
          onCreate: _executeCreateAvailability,
          onEdit: _executeEditAvailability,
          onDeleteSlot: _executeDeleteAvailabilitySlot,
          onDeleteGroup: _executeDeleteAvailabilityGroup,
        ),
        BookingsTab(
          view: _dayView,
          presences: _presences,
          students: _students,
          teachers: _teachers,
          ministrySubjects: _ministrySubjects,
          associationSubjects: _associationSubjects,
          services: _services,
          studyPrograms: _studyPrograms,
          availableDays: _availableDays,
          selectedDay: _selectedDay,
          openingDays: _openingDays,
          onViewSelected: _selectView,
          onCreateLessonRequest: _executeCreateLessonRequest,
          onCreatePresence: _executeCreatePresence,
          onEditPresence: _executeEditPresence,
          onDeletePresenceQuietly: _executeDeletePresenceQuietly,
          onDeleteBookingQuietly: _executeDeleteBookingQuietly,
          onDeleteGroup: _executeDeleteRequestGroup,
          onCreateBooking: _executeCreateBooking,
          onEditBooking: _executeEditBooking,
        ),
        _visitedSections.contains(_calendarContentIndex) ? const CalendarTab() : const SizedBox.shrink(),
      ],
    );
  }

  void _selectSection(int index)
  {
    setState(()
    {
      _selectedSection = index;
      _visitedSections.add(_contentIndex);
    });
  }

  void _selectView(LessonsDayView view)
  {
    setState(()
    {
      _dayView = view;
      _visitedSections.add(_contentIndex);
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
                // The same pair of glows the dashboard wears, on the same paper.
                // See the note in DashboardLayout for why they both fade towards
                // a blue.
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
                                title: 'Lezioni',
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
                                        module: 'Lezioni',
                                        section: railEntryAt(_sections, _selectedSection),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Expanded(child: _buildSectionContent(size)),
                                  ],
                                )
                              : _buildSectionContent(size),
                        ),
                      ],
                    ),
                  ),
                ),
                // Last in the stack, so the bar and the menu it opens stay above
                // the page.
                AppTopBar(
                  currentRoute: '/lessons',
                  sectionTitle: 'Lezioni',
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
