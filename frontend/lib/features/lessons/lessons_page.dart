import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/language/app_language.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/state/entity_writes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/rome_clock.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_load_failed.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import '../association/models/association_subject_item.dart';
import '../association/models/ministry_subject_item.dart';
import '../association/models/opening_day_item.dart';
import '../association/models/room_item.dart';
import '../association/models/service_item.dart';
import '../association/models/study_program_item.dart';
import '../bookings/utils/booking_replacement.dart' show withLeftOut;
import '../calendar/utils/day_marks_loader.dart';
import '../people/models/person_item.dart';
import 'models/activity_item.dart';
import 'models/availability_item.dart';
import 'models/booking_summary_item.dart';
import 'models/calendar_lock_item.dart';
import 'models/calendar_publication_item.dart';
import 'models/lesson_item.dart';
import 'models/presence_item.dart';
import 'models/room_day_plan.dart';
import 'models/room_supervision_item.dart';
import 'models/schedulable_booking.dart';
import 'utils/excluded_teachers.dart';
import 'utils/online_only.dart';
import 'models/teacher_room_assignment_item.dart';
import 'tabs/availability_tab.dart';
import 'tabs/bookings_tab.dart';
import 'tabs/calendar_tab.dart';
import 'utils/band_watch.dart';
import 'utils/booking_window.dart';
import 'utils/calendar_route.dart';
import 'utils/opening_window.dart';
import 'widgets/calendar_booking_panel.dart' show openPanelCount;
import 'widgets/lessons_day_bar.dart';
import 'widgets/lessons_day_header.dart';
import 'widgets/lessons_toolbar.dart';
import 'widgets/room_assignment_wizard.dart' show PlannedRooms, PlannedShift;

// The Lezioni page alive under the calendar screen: the screen draws from its data and writes through it.
// Set and cleared after a frame, so that nothing listening rebuilds in the middle of another build.
final ValueNotifier<_LessonsPageState?> _host = ValueNotifier(null);

// Role values as the server sends them, not display text.
const String _teacherRoleLabel = 'Docente';
const String _studentRoleLabel = 'Studente';

String get _loadFailed => tr('Non è stato possibile caricare le lezioni.', "Couldn't load the lessons.");

enum _WindowPart
{
  people,
  ministrySubjects,
  studyPrograms,
  availabilities,
  presences,
  openingDays,
  associationSubjects,
  services,
  lessons,
  rooms,
  publications,
  activities,
}

class LessonsPage extends StatefulWidget
{
  const LessonsPage({super.key});

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage>
    with DestinationRefresh, EntityWrites
{
  final ApiService _apiService = ApiService();

  // The days that can still change; the others are shown as they were.
  late final List<DateTime> _availableDays = computeAvailableDays(romeNow());

  late DateTime _day = _availableDays.first;

  // Set while the band's calendar screen is open over the page.
  TimeBucket? _calendarBand;

  // The latest calendar screen to open: one closing late must not shut a newer one.
  int _calendarTicket = 0;

  // Tells the calendar screen above that the page changed.
  final ValueNotifier<int> _changes = ValueNotifier(0);

  // A day outside the window, being read.
  bool _isLoadingDay = false;

  final Set<String> _readDays = {};

  LessonsDayView _dayView = LessonsDayView.availability;

  bool _isLoading = true;

  final Set<_WindowPart> _heldParts = {};

  // Parts never read whose last read failed: the page cannot be shown without them.
  Set<_WindowPart> _missingParts = {};

  Object? _loadFailure;

  // A day outside the window whose read failed, and why.
  DateTime? _failedDay;
  Object? _dayFailure;

  bool get _isShortOfData => _missingParts.isNotEmpty || (_failedDay != null && isSameDate(_failedDay!, _day));

  Object? get _shortageReason => _missingParts.isNotEmpty ? _loadFailure : _dayFailure;

  List<PersonItem> _people = [];
  List<MinistrySubjectItem> _ministrySubjects = [];

  List<AssociationSubjectItem> _associationSubjects = [];
  List<ServiceItem> _services = [];
  List<StudyProgramItem> _studyPrograms = [];
  List<AvailabilityItem> _availabilities = [];
  List<PresenceItem> _presences = [];

  List<LessonItem> _lessons = [];

  List<ActivityItem> _activities = [];

  List<CalendarPublicationItem> _publications = [];

  // Only live locks arrive: a row here means somebody is at the screen.
  List<CalendarLockItem> _locks = [];

  String? _meTaxCode;

  DateTime? _shownDay;
  TimeBucket? _shownBand;

  // Exclusions for the shown band only; re-fetched on every band change.
  Set<String> _excludedTeachers = const {};

  late final CalendarBandWatch _watch = CalendarBandWatch(
    beat: _beat,
    poll: _pollShownDay,
    glance: _glanceAtTheLocks,
    releasedElsewhere: _apiService.calendarLocksReleasedElsewhere,
  );

  List<OpeningDayItem> _openingDays = [];

  List<RoomItem> _rooms = [];

  List<PersonItem> get _teachers => _people.where((person) => person.roles.contains(_teacherRoleLabel)).toList();

  List<PersonItem> get _students => _people.where((person) => person.roles.contains(_studentRoleLabel)).toList();

  bool get _isCalendarOpen => _calendarBand != null;

  bool get _isDayEditable => _availableDays.any((day) => isSameDate(day, _day));

  DateTime get _selectedDay => _day;

  bool get _isSelectedDayClosed
  {
    return !isOpenOn(_openingDays, _selectedDay, kPresenceMode) &&
        !isOpenOn(_openingDays, _selectedDay, kOnlineMode);
  }

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

    _watch.start();
    _loadAllData();

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        _host.value = this;
      }
    });
  }

  @override
  void dispose()
  {
    _watch.dispose();
    _changes.dispose();

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (identical(_host.value, this))
      {
        _host.value = null;
      }
    });

    super.dispose();
  }

  @override
  void setState(VoidCallback fn)
  {
    super.setState(fn);
    _changes.value++;
  }

  static String _keyOf(DateTime day) => '${day.year}-${day.month}-${day.day}';

  Future<void> _goToDay(DateTime day) async
  {
    setState(() => _day = DateTime(day.year, day.month, day.day));

    await _readDay(_day);
  }

  // Days in the window come with the page; another is read once, or again when [fresh].
  Future<void> _readDay(DateTime day, {bool fresh = false}) async
  {
    final bool inside = _availableDays.any((other) => isSameDate(other, day));

    if (!fresh && (inside || _readDays.contains(_keyOf(day))))
    {
      return;
    }

    // A day never read shows the failure in its place; one on show keeps it and is told.
    final bool held = inside || _readDays.contains(_keyOf(day));
    Object? failure;

    setState(() => _isLoadingDay = true);

    final loaded = await _executeLoadDay(
      day,
      (message)
      {
        if (mounted && held)
        {
          CustomSnackBar.show(context: context, message: message, isError: true);
        }
      },
      onFailure: (e) => failure = e,
    );

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _isLoadingDay = false;

      if (loaded)
      {
        _readDays.add(_keyOf(day));
      }

      if (loaded || held)
      {
        if (_failedDay != null && isSameDate(_failedDay!, day))
        {
          _failedDay = null;
          _dayFailure = null;
        }
      }
      else
      {
        _failedDay = day;
        _dayFailure = failure;
      }
    });
  }

  void _openCalendar(TimeBucket band)
  {
    context.go(lessonsCalendarLocation(_day, band));
  }

  // The screen's day becomes the page's, so that going back lands on it.
  int _attachCalendar(LessonsCalendarTarget target)
  {
    final int ticket = ++_calendarTicket;

    setState(()
    {
      _day = target.day;
      _calendarBand = target.band;
    });

    _watchTheShownSection();
    unawaited(_readForTheCalendar(target));

    return ticket;
  }

  // The page under the screen never polls: its day may be old, and so may the band's locks.
  Future<void> _readForTheCalendar(LessonsCalendarTarget target) async
  {
    final DateTime day = target.day;

    // A band shown before raises no view change: its locks are read here.
    if (_isShowing(day, target.band))
    {
      unawaited(_readTheLocks(day));
    }

    final bool held = _availableDays.any((other) => isSameDate(other, day)) || _readDays.contains(_keyOf(day));

    if (target.fresh || !held)
    {
      await _readDay(day, fresh: target.fresh);

      return;
    }

    // Already on show: read again without the spinner.
    await _executeLoadDay(day, (_) {});
  }

  void _detachCalendar(int ticket)
  {
    if (!mounted || ticket != _calendarTicket)
    {
      return;
    }

    setState(() => _calendarBand = null);
    _watchTheShownSection();
  }

  @override
  void onDestinationShown() => _loadAllData();

  List<T> _keepingDaysOutsideWindow<T>(
    List<T> held,
    List<T> loaded,
    DateTime Function(T item) dateOf,
  )
  {
    final from = _availableDays.first;
    final to = _availableDays.last;

    return [
      for (final item in held)
        if (dateOf(item).isBefore(from) || dateOf(item).isAfter(to)) item,
      ...loaded,
    ];
  }

  Future<void> _readWhoIAm() async
  {
    try
    {
      final me = _apiService.lastKnownIdentity ?? await _apiService.me();

      if (mounted)
      {
        setState(() => _meTaxCode = me.taxCode);
      }
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'la lettura del profilo');
    }
  }

  // Reads one part of the window; the returned call stores it.
  Future<VoidCallback> _readPart(_WindowPart part) async
  {
    final DateTime from = _availableDays.first;
    final DateTime to = _availableDays.last;

    switch (part)
    {
      case _WindowPart.people:
        final people = await _apiService.getPeople();

        return () => _people = people;
      case _WindowPart.ministrySubjects:
        final subjects = await _apiService.getMinistrySubjects();

        return () => _ministrySubjects = subjects;
      case _WindowPart.studyPrograms:
        final programs = await _apiService.getStudyPrograms();

        return () => _studyPrograms = programs;
      case _WindowPart.availabilities:
        final availabilities = await _apiService.getAvailabilities(dateFrom: from, dateTo: to);

        return () => _availabilities = _keepingDaysOutsideWindow(_availabilities, availabilities, (item) => item.date);
      case _WindowPart.presences:
        final presences = await _apiService.getPresences(dateFrom: from, dateTo: to);

        return () => _presences = _keepingDaysOutsideWindow(_presences, presences, (item) => item.date);
      case _WindowPart.openingDays:
        final modes = await Future.wait([
          _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kPresenceMode),
          _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kOnlineMode),
        ]);

        return () => _openingDays = _keepingDaysOutsideWindow(
          _openingDays,
          [...modes[0], ...modes[1]],
          (item) => item.date,
        );
      case _WindowPart.associationSubjects:
        final subjects = await _apiService.getAssociationSubjects();

        return () => _associationSubjects = subjects;
      case _WindowPart.services:
        final services = await _apiService.getServices();

        return () => _services = services;
      case _WindowPart.lessons:
        final lessons = await _apiService.getLessons(dateFrom: from, dateTo: to);

        return () => _lessons = _keepingDaysOutsideWindow(_lessons, lessons, (item) => item.date);
      case _WindowPart.rooms:
        final rooms = await _apiService.getRooms();

        return () => _rooms = rooms;
      case _WindowPart.publications:
        final publications = await _apiService.getCalendarPublications(dateFrom: from, dateTo: to);

        return () => _publications = _keepingDaysOutsideWindow(_publications, publications, (item) => item.date);
      case _WindowPart.activities:
        final activities = await _apiService.getCalendarActivities(dateFrom: from, dateTo: to);

        return () => _activities = _keepingDaysOutsideWindow(_activities, activities, (item) => item.date);
    }
  }

  // Every part is read on its own: one failing keeps the others, and a retry reads only the missing.
  Future<void> _loadAllData({Set<_WindowPart>? only}) async
  {
    unawaited(_readWhoIAm());

    final Set<_WindowPart> parts = only ?? _WindowPart.values.toSet();
    final List<VoidCallback> stores = [];
    final Set<_WindowPart> failed = {};
    Object? failure;

    await Future.wait([
      for (final part in parts)
        _readPart(part).then(stores.add).catchError((Object e, StackTrace stackTrace)
        {
          reportCaughtError(e, stackTrace, during: 'il caricamento di Lezioni');
          failed.add(part);
          failure ??= e;
        }),
    ]);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      for (final store in stores)
      {
        store();
      }

      _heldParts.addAll(parts.difference(failed));
      // A part held from before keeps what it had: only one never read leaves the page short.
      _missingParts = {..._missingParts.difference(parts), ...failed.difference(_heldParts)};
      _loadFailure = _missingParts.isEmpty ? null : failure ?? _loadFailure;
      _isLoading = false;
    });
  }

  Future<void> _retryLoad() async
  {
    final DateTime? failedDay = _failedDay;

    await Future.wait([
      if (_missingParts.isNotEmpty) _loadAllData(only: {..._missingParts}),
      if (failedDay != null) _retryDay(failedDay),
    ]);
  }

  Future<void> _retryDay(DateTime day) async
  {
    Object? failure;

    final loaded = await _executeLoadDay(day, (_) {}, onFailure: (e) => failure = e);

    if (!mounted || _failedDay == null || !isSameDate(_failedDay!, day))
    {
      return;
    }

    setState(()
    {
      if (loaded)
      {
        _readDays.add(_keyOf(day));
        _failedDay = null;
        _dayFailure = null;
      }
      else
      {
        _dayFailure = failure;
      }
    });
  }

  Future<bool> _executeCreateAvailability(String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError)
  {
    return write(
      call: () => _apiService.createAvailability(
        teacherTaxCode: teacherTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
      ),
      apply: (created) => _availabilities = [..._availabilities, created],
      onError: onError,
    );
  }

  Future<bool> _executeEditAvailability(AvailabilityItem existing, String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError)
  {
    return write(
      call: () => _apiService.updateAvailability(
        id: existing.id,
        teacherTaxCode: teacherTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
      ),
      apply: (updated) => _availabilities = _availabilities.map((a) => a.id == existing.id ? updated : a).toList(),
      onError: onError,
      cascade: () => _refreshDay(date),
    );
  }

  Future<void> _executeDeleteAvailabilityGroup(List<AvailabilityItem> slots) async
  {
    final removed = slots.map((slot) => slot.id).toSet();

    // Earliest first: a stretch begun is refused before any other goes.
    final ordered = [...slots]..sort((a, b) => minutesOfTimeOfDay(a.startTime).compareTo(minutesOfTimeOfDay(b.startTime)));

    await erase(
      call: () async
      {
        for (final slot in ordered)
        {
          await _apiService.deleteAvailability(slot.id);
        }
      },
      apply: () => _availabilities = _availabilities.where((a) => !removed.contains(a.id)).toList(),
      done: tr('Disponibilità eliminata con successo!', 'Availability deleted successfully!'),
      cascade: () => _refreshDay(slots.first.date),
    );
  }

  Future<bool> _executeDeleteAvailabilitySlot(AvailabilityItem item, Function(String) onError)
  {
    return erase(
      call: () => _apiService.deleteAvailability(item.id),
      apply: () => _availabilities = _availabilities.where((a) => a.id != item.id).toList(),
      onError: onError,
      cascade: () => _refreshDay(item.date),
    );
  }

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

  Future<bool> _executeWriteBandNotes(
    String studentTaxCode,
    DateTime date,
    TimeBucket band,
    String? notes,
    Function(String) onError,
  ) async
  {
    try
    {
      final List<PresenceItem> day = await _apiService.writeBandNotes(
        studentTaxCode: studentTaxCode,
        date: date,
        band: band,
        notes: notes,
      );

      if (mounted)
      {
        setState(() => _presences = [
              for (final presence in _presences)
                if (presence.studentTaxCode != studentTaxCode || !isSameDate(presence.date, date)) presence,
              ...day,
            ]);
      }

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));
      await _refreshDay(date);

      return false;
    }
  }

  Future<bool> _executeReplaceLessonRequest(
    String studentTaxCode,
    DateTime date,
    List<Map<String, dynamic>> modes,
    Function(String) onError,
  ) async
  {
    try
    {
      final List<PresenceItem> day = await _apiService.replaceLessonRequest(
        studentTaxCode: studentTaxCode,
        date: date,
        modes: modes,
      );

      if (mounted)
      {
        setState(() => _presences = [
              for (final presence in _presences)
                if (presence.studentTaxCode != studentTaxCode || !isSameDate(presence.date, date)) presence,
              ...day,
            ]);
      }
    }
    catch (e)
    {
      onError(readableApiError(e));
      // A refused write may mean the day changed elsewhere.
      await _refreshDay(date);

      return false;
    }

    await _refreshDay(date);

    return true;
  }

  Future<bool> _executeDeleteBookingQuietly(BookingSummaryItem booking, int presenceId, Function(String) onError) async
  {
    final day = _presences
        .where((presence) => presence.id == presenceId)
        .map((presence) => presence.date)
        .firstOrNull;

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

    if (day != null)
    {
      await _refreshDay(day);
    }

    return true;
  }

  Future<void> _executeDeleteRequestGroup(List<PresenceItem> slots) async
  {
    final PresenceItem first = slots.first;

    final bool deleted = await _executeReplaceLessonRequest(
      first.studentTaxCode,
      first.date,
      withLeftOut([
        for (final mode in const [kPresenceMode, kOnlineMode]) {'mode': mode, 'slots': const [], 'subjects': const []},
      ], slots),
      (message) => CustomSnackBar.show(context: context, message: message, isError: true),
    );

    if (deleted && mounted)
    {
      CustomSnackBar.show(context: context, message: tr('Richiesta eliminata con successo!', 'Request deleted successfully!'), isError: false);
    }
  }

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
      reportCaughtError(e, stackTrace, during: 'la rilettura di una giornata');
    }
  }

  Future<bool> _executeEditBooking(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError) async
  {
    final day = _presences
        .where((presence) => presence.id == presenceId)
        .map((presence) => presence.date)
        .firstOrNull;

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

    if (day != null)
    {
      await _refreshDay(day);
    }

    return true;
  }

  Future<bool> _executeLoadDay(DateTime day, Function(String) onError, {void Function(Object error)? onFailure}) async
  {
    // The band on show re-reads who is left out too: another administrator may have changed it.
    final shown = _shownBand;
    final band = shown != null && _isShowing(day, shown) ? shown : null;

    try
    {
      final results = await Future.wait([
        _apiService.getAvailabilities(dateFrom: day, dateTo: day),
        _apiService.getPresences(dateFrom: day, dateTo: day),
        _apiService.getOpeningDays(dateFrom: day, dateTo: day, mode: kPresenceMode),
        _apiService.getOpeningDays(dateFrom: day, dateTo: day, mode: kOnlineMode),
        _apiService.getLessons(dateFrom: day, dateTo: day),
        _apiService.getCalendarPublications(dateFrom: day, dateTo: day),
        _apiService.getCalendarActivities(dateFrom: day, dateTo: day),
        if (band != null) _apiService.getExcludedTeachers(day: day, band: band),
      ]);

      if (!mounted)
      {
        return true;
      }

      setState(()
      {
        _availabilities = [
          ..._availabilities.where((item) => !isSameDate(item.date, day)),
          ...results[0] as List<AvailabilityItem>,
        ];
        _presences = [
          ..._presences.where((item) => !isSameDate(item.date, day)),
          ...results[1] as List<PresenceItem>,
        ];
        _openingDays = [
          ..._openingDays.where((item) => !isSameDate(item.date, day)),
          ...results[2] as List<OpeningDayItem>,
          ...results[3] as List<OpeningDayItem>,
        ];
        _lessons = [
          ..._lessons.where((item) => !isSameDate(item.date, day)),
          ...results[4] as List<LessonItem>,
        ];
        _publications = [
          ..._publications.where((item) => !isSameDate(item.date, day)),
          ...results[5] as List<CalendarPublicationItem>,
        ];
        _activities = [
          ..._activities.where((item) => !isSameDate(item.date, day)),
          ...results[6] as List<ActivityItem>,
        ];

        if (band != null && _isShowing(day, band))
        {
          _excludedTeachers = results[7] as Set<String>;
        }
      });

      return true;
    }
    catch (e)
    {
      onFailure?.call(e);
      onError(readableApiError(e));

      return false;
    }
  }

  Future<RoomDayPlan?> _executeLoadRoomPlan(DateTime day, Function(String) onError) async
  {
    try
    {
      final results = await Future.wait([
        _apiService.getTeacherRoomAssignments(day),
        _apiService.getRoomSupervisions(day),
      ]);

      return RoomDayPlan(
        assignments: results[0] as List<TeacherRoomAssignmentItem>,
        supervisions: results[1] as List<RoomSupervisionItem>,
      );
    }
    catch (e)
    {
      onError(readableApiError(e));

      return null;
    }
  }

  Future<bool> _executeSaveRoomPlan({
    required DateTime day,
    required PlannedRooms rooms,
    required List<PlannedShift> shifts,
    required Function(String) onError,
  }) async
  {
    String? failure;

    try
    {
      await _apiService.saveRoomPlan(
        day: day,
        rooms: rooms,
        shifts: [
          for (final shift in shifts)
            (
              teacherTaxCode: shift.teacherTaxCode,
              roomId: shift.roomId,
              startTime: shift.startTime,
              endTime: shift.endTime,
            ),
        ],
      );
    }
    catch (e)
    {
      failure = readableApiError(e);
    }

    await _refreshDay(day);

    if (failure != null)
    {
      onError(failure);

      return false;
    }

    return true;
  }

  Future<List<String>?> _executePublishBand({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  }) async
  {
    CalendarPublicationItem? written;

    final sent = await write(
      call: () => _apiService.publishBand(day: day, band: band),
      apply: (row)
      {
        written = row;
        _publications = [..._withoutBand(day, band), row];
      },
      onError: onError,
      cascade: () => _refreshDay(day),
    );

    return sent ? written?.warnings ?? const [] : null;
  }

  Future<bool> _executeReopenBand({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  }) async
  {
    return write(
      call: () => _apiService.reopenBand(day: day, band: band),
      apply: (row) => _publications = [..._withoutBand(day, band), row],
      onError: onError,
      cascade: () => _refreshDay(day),
    );
  }

  // Returns how many hours could not be restored, or null if the server refused.
  Future<int?> _executeDiscardDraft({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  }) async
  {
    int? lost;

    final undone = await write(
      call: () => _apiService.discardDraft(day: day, band: band),
      // Band stays in draft until the restored hours arrive; flipping early flashes stale changes.
      apply: (answer) => lost = answer.lost,
      onError: onError,
      cascade: () => _refreshDay(day),
    );

    return undone ? lost ?? 0 : null;
  }

  Future<bool?> _executeCloseDraft({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  }) async
  {
    bool? resent;

    final closed = await write(
      call: () => _apiService.closeDraft(day: day, band: band),
      apply: (answer)
      {
        resent = answer.resent;
        _publications = [..._withoutBand(day, band), answer.publication];
      },
      onError: onError,
      cascade: () => _refreshDay(day),
    );

    return closed ? resent ?? false : null;
  }

  CalendarLockItem? get _shownLock
  {
    final day = _shownDay;
    final band = _shownBand;

    if (day == null || band == null)
    {
      return null;
    }

    for (final lock in _locks)
    {
      if (isSameDate(lock.date, day) && lock.band == band)
      {
        return lock;
      }
    }

    return null;
  }

  bool get _isCalendarReadOnly
  {
    final lock = _shownLock;

    return lock != null && lock.holderTaxCode != _meTaxCode;
  }

  // Its hours confirmed in the daily summary: nobody changes the band any more.
  bool get _isShownBandConfirmed
  {
    final day = _shownDay;
    final band = _shownBand;

    return day != null &&
        band != null &&
        _publications.any((item) => isSameDate(item.date, day) && item.band == band && item.hoursConfirmed);
  }

  bool get _isCalendarShut => _isCalendarReadOnly || _isShownBandConfirmed;

  bool get _holdsTheShownBand
  {
    final lock = _shownLock;

    return lock != null && _meTaxCode != null && lock.holderTaxCode == _meTaxCode;
  }

  void _syncTheBand()
  {
    _watch.says(holding: _holdsTheShownBand, watching: _isCalendarReadOnly);
  }

  // Releases any held lock immediately rather than waiting for the 90s expiry.
  void _onCalendarViewChanged({required DateTime day, required TimeBucket band})
  {
    final wasDay = _shownDay;
    final wasBand = _shownBand;

    if (wasDay != null && isSameDate(wasDay, day) && wasBand == band)
    {
      return;
    }

    if (wasDay != null && wasBand != null && _watch.holdsTheBand)
    {
      _letTheBandGo(wasDay, wasBand);
    }

    setState(()
    {
      _shownDay = day;
      _shownBand = band;
      _excludedTeachers = const {};
    });

    _syncTheBand();
    unawaited(_readTheLocks(day));
    unawaited(_readTheExclusions(day, band));
  }

  // Failure is silent: an unanswered read leaves the safe default (nobody excluded).
  Future<void> _readTheExclusions(DateTime day, TimeBucket band) async
  {
    try
    {
      final excluded = await _apiService.getExcludedTeachers(day: day, band: band);

      if (!mounted || !_isShowing(day, band))
      {
        return;
      }

      setState(() => _excludedTeachers = excluded);
    }
    catch (_)
    {
      // Keep the empty default: everybody in.
    }
  }

  // The checks here mirror the server's: a refusal they let through means this window shows a
  // stale day, so it reads the day again rather than wait for the next poll.
  void _catchUpAfterRefusal()
  {
    final day = _shownDay;

    if (day != null)
    {
      unawaited(_executeLoadDay(day, (_) {}));
    }
  }

  bool _isShowing(DateTime day, TimeBucket band)
  {
    final shown = _shownDay;

    return shown != null && isSameDate(shown, day) && _shownBand == band;
  }

  // Applied locally, reloaded only if counts differ: a read-back cleared the row before its hours.
  // Publications are always re-fetched: excluding can turn the band into a draft with changes.
  Future<HandedBack?> _executeExcludeTeacher({
    required DateTime day,
    required TimeBucket band,
    required String teacherTaxCode,
    required Function(String) onError,
  }) async
  {
    try
    {
      final back = await _apiService.excludeTeacher(
        day: day,
        band: band,
        teacherTaxCode: teacherTaxCode,
      );

      final off = takeTheRowOff(
        lessons: _lessons,
        activities: _activities,
        day: day,
        band: band,
        teacherTaxCode: teacherTaxCode,
      );

      if (mounted)
      {
        setState(()
        {
          _lessons = off.lessons;
          _activities = off.activities;

          if (_isShowing(day, band))
          {
            _excludedTeachers = {..._excludedTeachers, teacherTaxCode};
          }
        });
      }

      // Counts disagree only if this side was looking at a stale day.
      if (off.back != back)
      {
        await _executeLoadDay(day, onError);
      }
      else if (back.lessons > 0 || back.activities > 0)
      {
        await _refreshPublications(day);
      }

      return back;
    }
    catch (e)
    {
      onError(readableApiError(e));

      return null;
    }
  }

  Future<bool> _executeReadmitTeacher({
    required DateTime day,
    required TimeBucket band,
    required String teacherTaxCode,
    required Function(String) onError,
  }) async
  {
    try
    {
      await _apiService.readmitTeacher(
        day: day,
        band: band,
        teacherTaxCode: teacherTaxCode,
      );

      if (mounted && _isShowing(day, band))
      {
        setState(() => _excludedTeachers = {..._excludedTeachers}..remove(teacherTaxCode));
      }

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }
  }

  void _letTheBandGo(DateTime day, TimeBucket band)
  {
    _foldLock(day, band, null);

    // Best effort: the 90s expiry covers a window closed without releasing.
    unawaited(
      _apiService
          .releaseCalendarLock(day: day, band: band)
          .catchError((Object _) {}),
    );
  }

  Future<void> _beat() async
  {
    final day = _shownDay;
    final band = _shownBand;

    if (day == null || band == null)
    {
      return;
    }

    try
    {
      final state = await _apiService.heartbeatCalendarLock(day: day, band: band);

      if (!mounted)
      {
        return;
      }

      _foldLock(day, band, state.lock);
    }
    catch (e, stackTrace)
    {
      // Log only: two more beats follow before the lock expires.
      reportCaughtError(e, stackTrace, during: 'il battito del calendario');
    }
  }

  void _foldLock(DateTime day, TimeBucket band, CalendarLockItem? lock)
  {
    setState(()
    {
      _locks = [
        for (final row in _locks)
          if (!(isSameDate(row.date, day) && row.band == band)) row,
        ?lock,
      ];
    });

    _syncTheBand();
  }

  Future<void> _readTheLocks(DateTime day) async
  {
    try
    {
      final rows = await _apiService.getCalendarLocks(dateFrom: day, dateTo: day);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _locks = [
          for (final row in _locks)
            if (!isSameDate(row.date, day)) row,
          ...rows,
        ];
      });

      _syncTheBand();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'la lettura dei calendari in uso');
    }
  }

  Set<int> _lessonIdsOn(DateTime day, TimeBucket band)
  {
    return {
      for (final lesson in _lessons)
        if (isSameDate(lesson.date, day) && lesson.band == band) lesson.id,
    };
  }

  Set<int> _requestIdsOn(DateTime day)
  {
    return {
      for (final presence in _presences)
        if (isSameDate(presence.date, day))
          for (final booking in presence.bookings) booking.id,
    };
  }

  // Somebody began building since the last look: their hours are read at once.
  Future<void> _glanceAtTheLocks() async
  {
    final day = _shownDay;

    if (day == null)
    {
      return;
    }

    final bool wasWatching = _isCalendarReadOnly;

    await _readTheLocks(day);

    if (mounted && !wasWatching && _isCalendarReadOnly)
    {
      await _executeLoadDay(day, (_) {});
    }
  }

  Future<void> _pollShownDay() async
  {
    final day = _shownDay;
    final band = _shownBand;

    if (day == null || band == null)
    {
      return;
    }

    final held = _watch.holdsTheBand;
    final hours = held ? _lessonIdsOn(day, band) : const <int>{};
    final requests = held ? _requestIdsOn(day) : const <int>{};

    await Future.wait([
      _executeLoadDay(day, (_) {}),
      _readTheLocks(day),
    ]);

    if (!mounted || !held)
    {
      return;
    }

    _sayWhatMovedUnderneath(hours, requests, day, band);
  }

  // Reports lessons lost to withdrawn hours and requests arrived since the calendar was built.
  void _sayWhatMovedUnderneath(
    Set<int> hours,
    Set<int> requests,
    DateTime day,
    TimeBucket band,
  )
  {
    final gone = hours.difference(_lessonIdsOn(day, band)).length;
    final arrived = _requestIdsOn(day).difference(requests).length;

    final said = [
      if (gone == 1)
        tr(
          'Un\'ora è uscita dal calendario: la disponibilità o la prenotazione su '
              'cui stava non c\'è più.',
          'An hour has left the calendar: the availability or booking it was on is gone.',
        ),
      if (gone > 1)
        tr(
          '$gone ore sono uscite dal calendario: le disponibilità o le '
              'prenotazioni su cui stavano non ci sono più.',
          '$gone hours have left the calendar: the availability or bookings they were on are gone.',
        ),
      if (arrived == 1) tr('È arrivata una nuova prenotazione per questa giornata.', 'A new booking has arrived for this day.'),
      if (arrived > 1) tr('Sono arrivate $arrived nuove prenotazioni per questa giornata.', '$arrived new bookings have arrived for this day.'),
    ];

    if (said.isEmpty)
    {
      return;
    }

    CustomSnackBar.show(
      context: context,
      message: said.join(' '),
      tone: SnackBarTone.warning,
      isError: false,
    );
  }

  List<CalendarPublicationItem> _withoutBand(DateTime day, TimeBucket band)
  {
    return [
      for (final row in _publications)
        if (!(isSameDate(row.date, day) && row.band == band)) row,
    ];
  }

  // One setState for lessons, publications and activities: two would show a half-updated frame.
  Future<void> _refreshDay(DateTime day) async
  {
    try
    {
      final results = await Future.wait([
        _apiService.getLessons(dateFrom: day, dateTo: day),
        _apiService.getCalendarPublications(dateFrom: day, dateTo: day),
        _apiService.getCalendarActivities(dateFrom: day, dateTo: day),
      ]);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _lessons = [
          ..._lessons.where((item) => !isSameDate(item.date, day)),
          ...results[0] as List<LessonItem>,
        ];
        _publications = [
          ..._publications.where((item) => !isSameDate(item.date, day)),
          ...results[1] as List<CalendarPublicationItem>,
        ];
        _activities = [
          ..._activities.where((item) => !isSameDate(item.date, day)),
          ...results[2] as List<ActivityItem>,
        ];
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il ricaricamento del calendario');
    }

    // A write takes the band; re-reading the locks is how this window learns it now holds it.
    await _readTheLocks(day);
  }

  Future<bool> _executeCreateActivity({
    required DateTime day,
    required TimeBucket band,
    required String name,
    required String? description,
    required Function(String) onError,
  })
  {
    return write(
      call: () => _apiService.createCalendarActivity(
        day: day,
        band: band,
        name: name,
        description: description,
      ),
      apply: (created) => _activities = [..._activities, created],
      onError: onError,
      cascade: () => _refreshPublications(day),
    );
  }

  // Optimistic placement; the server's answer replaces it and a refusal puts it back.
  ActivityItem _optimisticActivity({
    required ActivityItem existing,
    required String name,
    required String? description,
    required int? availabilityId,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
  })
  {
    final availability = _availabilities.where((slot) => slot.id == availabilityId).firstOrNull;

    final placement = availability == null || startTime == null || endTime == null
        ? null
        : ActivityPlacementItem(
            availabilityId: availability.id,
            teacherTaxCode: availability.teacherTaxCode,
            teacher: availability.teacher,
            teacherMode: availability.mode,
            startTime: startTime,
            endTime: endTime,
          );

    return existing.asWritten(
      name: name,
      description: description,
      placement: placement,
    );
  }

  void _drawActivity(ActivityItem activity)
  {
    setState(()
    {
      _activities = [
        for (final row in _activities)
          if (row.id != activity.id) row,
        activity,
      ];
    });
  }

  Future<bool> _executeUpdateActivity({
    required ActivityItem existing,
    required String name,
    required String? description,
    required int? availabilityId,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required Function(String) onError,
  }) async
  {
    final before = _onlineOnlyOn(_shownDay);

    if (mounted)
    {
      _drawActivity(_optimisticActivity(
        existing: existing,
        name: name,
        description: description,
        availabilityId: availabilityId,
        startTime: startTime,
        endTime: endTime,
      ));
    }

    try
    {
      final written = await _apiService.updateCalendarActivity(
        id: existing.id,
        name: name,
        description: description,
        availabilityId: availabilityId,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
      );

      if (mounted)
      {
        _drawActivity(written);
      }

      await _refreshPublications(existing.date);
      await _rereadMovedLessons(existing.date, {?existing.placement?.teacherTaxCode, ?written.placement?.teacherTaxCode});
      _sayWhoComesForOnlineOnly(before);

      return true;
    }
    catch (e)
    {
      if (mounted)
      {
        _drawActivity(existing);
      }

      onError(readableApiError(e));
      _catchUpAfterRefusal();

      return false;
    }
  }

  Future<bool> _executeDeleteActivity(int id, Function(String) onError) async
  {
    final before = _onlineOnlyOn(_shownDay);
    final removed = _activities.where((activity) => activity.id == id).firstOrNull;

    return erase(
      call: () => _apiService.deleteCalendarActivity(id),
      apply: () => _activities = _activities.where((activity) => activity.id != id).toList(),
      onError: onError,
      cascade: removed == null
          ? null
          : () async
          {
            await _refreshPublications(removed.date);
            await _rereadMovedLessons(removed.date, {?removed.placement?.teacherTaxCode});
            _sayWhoComesForOnlineOnly(before);
          },
    );
  }

  // Every band and teacher of [day] that comes in for online lessons only.
  Set<(TimeBucket, String)> _onlineOnlyOn(DateTime? day)
  {
    if (day == null)
    {
      return const {};
    }

    return onlineOnlyBands(
      _lessons.where((lesson) => isSameDate(lesson.date, day)),
      _activities.where((activity) => isSameDate(activity.date, day)),
    );
  }

  // Said once, as the write makes it so: who now comes in only to connect from here.
  void _sayWhoComesForOnlineOnly(Set<(TimeBucket, String)> before)
  {
    if (!mounted)
    {
      return;
    }

    final arrived = _onlineOnlyOn(_shownDay).difference(before).map((pair) => pair.$2).toSet();

    if (arrived.isEmpty)
    {
      return;
    }

    final names = [
      for (final teacher in arrived)
        ?_lessons.where((lesson) => lesson.teacherTaxCode == teacher).firstOrNull?.teacher.fullName,
    ];

    CustomSnackBar.show(
      context: context,
      message: names.map(onlineOnlyWarning).join(' '),
      tone: SnackBarTone.warning,
      isError: false,
    );
  }

  // The server settles where each teacher gives online lessons from, a whole band at a
  // time: after a lesson or activity write their online lessons may sit on other hours.
  Future<void> _rereadMovedLessons(DateTime day, Set<String> teachers, {int? written}) async
  {
    final moved = _lessons.any((lesson) =>
        lesson.id != written &&
        isSameDate(lesson.date, day) &&
        teachers.contains(lesson.teacherTaxCode) &&
        lesson.mode == kOnlineMode);

    if (!moved)
    {
      return;
    }

    try
    {
      final lessons = await _apiService.getLessons(dateFrom: day, dateTo: day);

      if (mounted)
      {
        setState(() => _lessons = [..._lessons.where((item) => !isSameDate(item.date, day)), ...lessons]);
      }
    }
    catch (e, stackTrace)
    {
      // Log only: the next poll reads them anyway.
      reportCaughtError(e, stackTrace, during: 'la rilettura delle lezioni');
    }
  }

  Future<void> _refreshPublications(DateTime day) async
  {
    try
    {
      final rows = await _apiService.getCalendarPublications(
        dateFrom: day,
        dateTo: day,
      );

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _publications = [
          ..._publications.where((item) => !isSameDate(item.date, day)),
          ...rows,
        ];
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il ricaricamento del calendario');
    }
  }

  LessonItem? _provisionalLesson({
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  })
  {
    final availability = _availabilities.where((slot) => slot.id == availabilityId).firstOrNull;
    final band = bucketFor(startTime);

    if (availability == null || band == null || bookingIds.isEmpty)
    {
      return null;
    }

    final bookings = <LessonBookingItem>[];
    var mode = availability.mode;

    for (final id in bookingIds)
    {
      PresenceItem? host;
      BookingSummaryItem? booking;

      for (final presence in _presences)
      {
        for (final entry in presence.bookings)
        {
          if (entry.id == id)
          {
            host = presence;
            booking = entry;
          }
        }
      }

      if (host == null || booking == null)
      {
        return null;
      }

      mode = host.mode;

      bookings.add(LessonBookingItem(
        booking: booking,
        presenceId: host.id,
        presence: LessonPresenceRef(
          id: host.id,
          date: host.date,
          startTime: host.startTime,
          endTime: host.endTime,
          student: host.student,
        ),
      ));
    }

    final now = DateTime.now();

    return LessonItem(
      id: _nextProvisionalLessonId--,
      availabilityId: availabilityId,
      teacherTaxCode: availability.teacherTaxCode,
      teacher: availability.teacher,
      date: availability.date,
      teacherMode: availability.mode,
      mode: mode,
      band: band,
      startTime: startTime,
      endTime: endTime,
      disciplines: [
        for (final subject in _associationSubjects)
          if (associationSubjectIds.contains(subject.id))
            AssociationSubjectOption(id: subject.id, name: subject.name, description: subject.description),
      ],
      bookings: bookings,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<LessonItem?> _executeCreateLesson({
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
    bool waiveCompetence = false,
  }) async
  {
    final before = _onlineOnlyOn(_shownDay);

    final provisional = _provisionalLesson(
      availabilityId: availabilityId,
      bookingIds: bookingIds,
      associationSubjectIds: associationSubjectIds,
      startTime: startTime,
      endTime: endTime,
    );

    if (provisional != null && mounted)
    {
      setState(() => _lessons = [..._lessons, provisional]);
    }

    try
    {
      final created = await _apiService.createLesson(
        availabilityId: availabilityId,
        bookingIds: bookingIds,
        associationSubjectIds: associationSubjectIds,
        startTime: startTime,
        endTime: endTime,
        waiveCompetence: waiveCompetence,
      );

      if (mounted)
      {
        setState(()
        {
          _lessons = [
            for (final lesson in _lessons)
              if (lesson.id != provisional?.id) lesson,
            created,
          ];

          if (waiveCompetence)
          {
            _rememberWaiver(bookingIds, created.teacherTaxCode);
          }
        });
      }

      await _refreshPublications(created.date);
      await _rereadMovedLessons(created.date, {created.teacherTaxCode}, written: created.id);
      _sayWhoComesForOnlineOnly(before);

      return created;
    }
    catch (e)
    {
      if (provisional != null && mounted)
      {
        setState(() => _lessons = _lessons.where((lesson) => lesson.id != provisional.id).toList());
      }

      onError(readableApiError(e));
      _catchUpAfterRefusal();

      return null;
    }
  }

  LessonItem? _optimisticUpdate({
    required LessonItem existing,
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  })
  {
    final samePupils = bookingIds.length == existing.bookingIds.length &&
        existing.bookingIds.containsAll(bookingIds);

    if (!samePupils)
    {
      return null;
    }

    final availability = _availabilities.where((slot) => slot.id == availabilityId).firstOrNull;

    if (availability == null)
    {
      return null;
    }

    return existing.copyWith(
      availabilityId: availabilityId,
      teacherTaxCode: availability.teacherTaxCode,
      teacher: availability.teacher,
      teacherMode: availability.mode,
      startTime: startTime,
      endTime: endTime,
      disciplines: [
        for (final subject in _associationSubjects)
          if (associationSubjectIds.contains(subject.id))
            AssociationSubjectOption(id: subject.id, name: subject.name, description: subject.description),
      ],
    );
  }

  Future<LessonItem?> _executeUpdateLesson({
    required LessonItem existing,
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
    bool waiveCompetence = false,
  }) async
  {
    final before = _onlineOnlyOn(_shownDay);

    final optimistic = _optimisticUpdate(
      existing: existing,
      availabilityId: availabilityId,
      bookingIds: bookingIds,
      associationSubjectIds: associationSubjectIds,
      startTime: startTime,
      endTime: endTime,
    );

    if (optimistic != null && mounted)
    {
      setState(() => _lessons = _lessons.map((lesson) => lesson.id == existing.id ? optimistic : lesson).toList());
    }

    try
    {
      final updated = await _apiService.updateLesson(
        id: existing.id,
        availabilityId: availabilityId,
        bookingIds: bookingIds,
        associationSubjectIds: associationSubjectIds,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
        waiveCompetence: waiveCompetence,
      );

      if (mounted)
      {
        setState(()
        {
          _lessons = _lessons.map((lesson) => lesson.id == existing.id ? updated : lesson).toList();

          if (waiveCompetence)
          {
            _rememberWaiver(bookingIds, updated.teacherTaxCode);
          }
        });
      }

      await _refreshPublications(updated.date);
      await _rereadMovedLessons(
        updated.date,
        {existing.teacherTaxCode, updated.teacherTaxCode},
        written: updated.id,
      );
      _sayWhoComesForOnlineOnly(before);

      return updated;
    }
    catch (e)
    {
      if (optimistic != null && mounted)
      {
        setState(() => _lessons = _lessons.map((lesson) => lesson.id == existing.id ? existing : lesson).toList());
      }

      onError(readableApiError(e));
      _catchUpAfterRefusal();

      return null;
    }
  }

  int _nextProvisionalLessonId = -1;

  // The server now holds a waiver for these bookings and this teacher: later moves ask nothing.
  void _rememberWaiver(List<int> bookingIds, String teacherTaxCode)
  {
    _presences = [for (final presence in _presences) presence.waiving(bookingIds, teacherTaxCode)];
  }

  Future<LessonItem?> _executeSplitLesson({
    required LessonItem existing,
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required int secondAvailabilityId,
    required List<int> secondAssociationSubjectIds,
    required TimeOfDay secondStartTime,
    required TimeOfDay secondEndTime,
    required Function(String) onError,
    bool waiveCompetence = false,
  }) async
  {
    final before = _onlineOnlyOn(_shownDay);

    final shrunk = _optimisticUpdate(
      existing: existing,
      availabilityId: availabilityId,
      bookingIds: bookingIds,
      associationSubjectIds: associationSubjectIds,
      startTime: startTime,
      endTime: endTime,
    );

    final second = shrunk == null
        ? null
        : _optimisticUpdate(
            existing: existing,
            availabilityId: secondAvailabilityId,
            bookingIds: bookingIds,
            associationSubjectIds: secondAssociationSubjectIds,
            startTime: secondStartTime,
            endTime: secondEndTime,
          )?.copyWith(id: _nextProvisionalLessonId--);

    void draw(List<LessonItem> lessons)
    {
      if (mounted)
      {
        setState(() => _lessons = lessons);
      }
    }

    if (shrunk != null && second != null)
    {
      draw([
        for (final lesson in _lessons) lesson.id == existing.id ? shrunk : lesson,
        second,
      ]);
    }

    final LessonItem updated;

    try
    {
      // The remainder was judged on its own, so the waiver stays with this part.
      updated = await _apiService.updateLesson(
        id: existing.id,
        availabilityId: availabilityId,
        bookingIds: bookingIds,
        associationSubjectIds: associationSubjectIds,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
        waiveCompetence: waiveCompetence,
      );
    }
    catch (e)
    {
      draw([
        for (final lesson in _lessons)
          if (lesson.id != second?.id) lesson.id == existing.id ? existing : lesson,
      ]);

      onError(readableApiError(e));
      _catchUpAfterRefusal();

      return null;
    }

    if (waiveCompetence && mounted)
    {
      setState(() => _rememberWaiver(bookingIds, updated.teacherTaxCode));
    }

    draw([for (final lesson in _lessons) lesson.id == existing.id ? updated : lesson]);

    try
    {
      final created = await _apiService.createLesson(
        availabilityId: secondAvailabilityId,
        bookingIds: bookingIds,
        associationSubjectIds: secondAssociationSubjectIds,
        startTime: secondStartTime,
        endTime: secondEndTime,
      );

      draw([
        for (final lesson in _lessons)
          if (lesson.id != second?.id) lesson,
        created,
      ]);
    }
    catch (e)
    {
      draw([
        for (final lesson in _lessons)
          if (lesson.id != second?.id) lesson,
      ]);

      onError(readableApiError(e));
      _catchUpAfterRefusal();
    }

    await _rereadMovedLessons(updated.date, {existing.teacherTaxCode, updated.teacherTaxCode});
    _sayWhoComesForOnlineOnly(before);

    return updated;
  }

  Future<bool> _executeDeleteLesson(int id, Function(String) onError) async
  {
    final before = _onlineOnlyOn(_shownDay);
    final removed = _lessons.where((lesson) => lesson.id == id).firstOrNull;

    if (removed != null && mounted)
    {
      setState(() => _lessons = _lessons.where((lesson) => lesson.id != id).toList());
    }

    try
    {
      await _apiService.deleteLesson(id);

      if (removed != null)
      {
        await _refreshPublications(removed.date);
        await _rereadMovedLessons(removed.date, {removed.teacherTaxCode});
        _sayWhoComesForOnlineOnly(before);
      }

      return true;
    }
    catch (e)
    {
      if (removed != null && mounted)
      {
        setState(() => _lessons = [..._lessons, removed]);
      }

      onError(readableApiError(e));

      return false;
    }
  }

  Widget _buildLists()
  {
    final bool readOnly = !_isDayEditable;

    return IndexedStack(
      index: _dayView.index,
      children: [
        AvailabilityTab(
          view: _dayView,
          availabilities: _availabilities,
          teachers: _teachers,
          availableDays: _availableDays,
          selectedDay: _selectedDay,
          openingDays: _openingDays,
          readOnly: readOnly,
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
          readOnly: readOnly,
          begunBookingIds: _begunBookingIds,
          onViewSelected: _selectView,
          onCreateLessonRequest: _executeCreateLessonRequest,
          onReplaceLessonRequest: _executeReplaceLessonRequest,
          onDeleteBookingQuietly: _executeDeleteBookingQuietly,
          onDeleteGroup: _executeDeleteRequestGroup,
          onEditBooking: _executeEditBooking,
          onWriteBandNotes: _executeWriteBandNotes,
        ),
      ],
    );
  }

  // Subjects whose lesson has begun: kept whole, as the server holds them.
  Set<int> get _begunBookingIds
  {
    final DateTime now = romeNow();

    return {
      for (final lesson in _lessons)
        if (hasBegun(lesson.date, lesson.startTime, now))
          for (final row in lesson.bookings) row.booking.id,
    };
  }

  // The band's requests, planned or not, each pupil's stretches cut to the band.
  List<PresenceBookingGroup> _bandGroups(TimeBucket band)
  {
    final int start = bandStartMinutes(band);
    final int end = bandEndMinutes(band);

    return [
      for (final group in groupSchedulable(presences: _presences, lessons: _lessons, day: _day))
        if (group.touches(start, end)) group.within(start, end),
    ];
  }

  // Requests of the band still to plan, as its calendar's drawer counts them.
  int _toPlan(TimeBucket band, List<PresenceBookingGroup> groups)
  {
    final activities = _activities
        .where((activity) => isSameDate(activity.date, _day) && activity.band == band && !activity.isAssigned)
        .toList();

    return openPanelCount(groups, activities);
  }

  LessonsBandEntry _bandEntry(TimeBucket band)
  {
    final window = unionOpeningWindow(_openingDays, _day, band);
    final publication = _publications.where((row) => isSameDate(row.date, _day) && row.band == band).firstOrNull;
    final groups = _bandGroups(band);

    // A band nobody asked anything of has no calendar to compose.
    final LessonsBandState state = switch ((window, publication))
    {
      (null, null) => LessonsBandState.closed,
      (_, null) when groups.isEmpty => LessonsBandState.empty,
      (_, null) => LessonsBandState.open,
      (_, final published?) => published.isDraft ? LessonsBandState.draft : LessonsBandState.published,
    };

    return (
      band: band,
      hours: window == null ? null : formatMinutesRange(window.startMinutes, window.endMinutes),
      state: state,
      toPlan: state == LessonsBandState.open ? _toPlan(band, groups) : 0,
    );
  }

  Widget _buildLockedNote()
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.trialMutedText),
        const SizedBox(width: 5),
        Text(
          tr('Non modificabile', 'Not editable'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }

  Widget _buildDayPage(AppWindowSize size)
  {
    final bool dense = size.isDense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(
          slot: PageTransitionItem.frame,
          child: LessonsDayBar(
            day: _day,
            today: romeNow(),
            note: _dayNote,
            onDay: _goToDay,
            loadMarks: (from, to) => loadDayMarks(from, to),
            busy: _isLoadingDay,
          ),
        ),
        SizedBox(height: dense ? 14 : 20),
        if (_isLoading || _isLoadingDay)
          Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)))
        else if (_isShortOfData)
          Expanded(child: _buildLoadFailed())
        else ...[
          // A closed day says so below: its bands have nothing to open.
          if (!_isSelectedDayClosed) ...[
            PageTransitionItem(
              slot: PageTransitionItem.header,
              child: LessonsBandButtons(
                bands: [for (final band in TimeBucket.values) _bandEntry(band)],
                onOpen: _openCalendar,
                trailing: _isDayEditable ? null : _buildLockedNote(),
              ),
            ),
            SizedBox(height: dense ? 14 : 22),
          ],
          Expanded(
            key: const ValueKey('lessons-lists'),
            child: _buildLists(),
          ),
        ],
      ],
    );
  }

  // The page's name and what it shows on one baseline, beside the way back.
  double _calendarTitleGap(AppWindowSize size) => size.isDense ? 14 : 20;

  // Where «Calendario» starts, after the back button.
  double _calendarTitleIndent(AppWindowSize size)
  {
    return (size.isDense ? AppBackButton.denseWidth : AppBackButton.width) + _calendarTitleGap(size);
  }

  // One paragraph: two would each be rounded to the pixel on their own and miss each other's baseline.
  Widget _buildCalendarLeading(BuildContext context, AppWindowSize size, LessonsCalendarTarget target)
  {
    final String shown = '${formatWeekdayColumnLabel(target.day)} ${target.day.year} · ${bandLabel(target.band)}';

    // Minimal windows: the day and the band under the name, whole.
    final Widget title = size.isMinimal
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Calendario', 'Calendar'), maxLines: 1, style: lessonsHeadingStyle),
              Text(shown, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: lessonsHeadingNoteStyle),
            ],
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: tr('Calendario', 'Calendar'), style: lessonsHeadingStyle),
                const WidgetSpan(alignment: PlaceholderAlignment.middle, child: SizedBox(width: 16)),
                TextSpan(text: shown, style: lessonsHeadingNoteStyle),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBackButton(tooltip: tr('Torna indietro', 'Go back'), onTap: () => context.go(kLessonsRoute), dense: size.isDense),
        SizedBox(width: _calendarTitleGap(size)),
        Flexible(child: title),
      ],
    );
  }

  Widget _buildLoadFailed()
  {
    return AppLoadFailedRoom(error: _shortageReason, message: _loadFailed, onRetry: _retryLoad);
  }

  Widget _buildCalendarPage(BuildContext context, AppWindowSize size, LessonsCalendarTarget target)
  {
    final Widget leading = _buildCalendarLeading(context, size, target);
    final bool waiting = _isLoading || _isLoadingDay || !isSameDate(_day, target.day);

    if (waiting || _isShortOfData)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: leading),
          Expanded(
            child: waiting
                ? Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise))
                : _buildLoadFailed(),
          ),
        ],
      );
    }

    return CalendarTab(
      day: target.day,
      band: target.band,
      leading: leading,
      leadingIndent: _calendarTitleIndent(size),
      lessons: _lessons,
      activities: _activities,
      availabilities: _availabilities,
      presences: _presences,
      openingDays: _openingDays,
      ministrySubjects: _ministrySubjects,
      people: _people,
      associationSubjects: _associationSubjects,
      studyPrograms: _studyPrograms,
      rooms: _rooms,
      publications: _publications,
      lock: _shownLock,
      isReadOnly: _isCalendarShut,
      onViewChanged: _onCalendarViewChanged,
      onLoadRoomPlan: _executeLoadRoomPlan,
      onPublishBand: _isCalendarShut ? null : _executePublishBand,
      onReopenBand: _isCalendarShut ? null : _executeReopenBand,
      onCloseDraft: _isCalendarShut ? null : _executeCloseDraft,
      onDiscardDraft: _isCalendarShut ? null : _executeDiscardDraft,
      onSaveRoomPlan: _isCalendarShut ? null : _executeSaveRoomPlan,
      excludedTeachers: _excludedTeachers,
      onExcludeTeacher: _isCalendarShut ? null : _executeExcludeTeacher,
      onReadmitTeacher: _isCalendarShut ? null : _executeReadmitTeacher,
      onOpenPerson: (taxCode) => _openRecord(taxCode, target),
      onCreateLesson: _isCalendarShut ? null : _executeCreateLesson,
      onUpdateLesson: _isCalendarShut ? null : _executeUpdateLesson,
      onDeleteLesson: _isCalendarShut ? null : _executeDeleteLesson,
      onSplitLesson: _isCalendarShut ? null : _executeSplitLesson,
      onCreateActivity: _isCalendarShut ? null : _executeCreateActivity,
      onUpdateActivity: _isCalendarShut ? null : _executeUpdateActivity,
      onDeleteActivity: _isCalendarShut ? null : _executeDeleteActivity,
    );
  }

  // Its way back leads to this calendar, day and band.
  void _openRecord(String taxCode, LessonsCalendarTarget target)
  {
    context.go(
      Uri(
        path: '/people/$taxCode',
        queryParameters: {'from': lessonsCalendarLocation(target.day, target.band)},
      ).toString(),
    );
  }

  void _selectView(LessonsDayView view)
  {
    setState(() => _dayView = view);
  }

  // Leaving stops the beat; coming back does not retake the lock (the first write does).
  void _watchTheShownSection()
  {
    final onTheCalendar = _isCalendarOpen;

    if (!onTheCalendar && _watch.holdsTheBand)
    {
      final day = _shownDay;
      final band = _shownBand;

      if (day != null && band != null)
      {
        _letTheBandGo(day, band);
      }
    }

    _watch.shows(onTheCalendar);
  }

  // The open day's figures beside the page's name; none while loading or on a closed day.
  String? get _dayNote
  {
    if (_isLoading || _isLoadingDay || _isShortOfData || _isSelectedDayClosed)
    {
      return null;
    }

    return lessonsDaySummary(availableTeachers: _availableTeachersToday, presentStudents: _presentStudentsToday);
  }

  @override
  Widget build(BuildContext context)
  {
    return LessonsBackdrop(
      // Below the wide window the page is the window: the cards scroll, not the page.
      minHeight: AppBreakpoints.of(context).isDense ? 0 : AppDimensions.minDashboardHeight,
      builder: (context, size, margin) => Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: margin, right: margin, top: AppTopBar.contentTopInsetFor(size), bottom: 24),
              child: _buildDayPage(size),
            ),
          ),
          AppTopBar(currentRoute: kLessonsRoute),
        ],
      ),
    );
  }
}

// The sea behind Lezioni and its calendar screen.
class LessonsBackdrop extends StatelessWidget
{
  final double minHeight;

  final Widget Function(BuildContext context, AppWindowSize size, double margin) builder;

  const LessonsBackdrop({super.key, required this.minHeight, required this.builder});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: minHeight,
        builder: (context, width, height)
        {
          final size = AppBreakpoints.of(context);

          return Container(
            width: width,
            height: height,
            color: AppTheme.pagePaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                ),
                CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                Positioned.fill(child: builder(context, size, AppBreakpoints.pageMargin(size))),
              ],
            ),
          );
        },
      ),
    );
  }
}

// One band's calendar over the whole window, as a screen of its own; the Lezioni page under it holds the data.
class LessonsCalendarScreen extends StatefulWidget
{
  final LessonsCalendarTarget target;

  const LessonsCalendarScreen({super.key, required this.target});

  @override
  State<LessonsCalendarScreen> createState() => _LessonsCalendarScreenState();
}

class _LessonsCalendarScreenState extends State<LessonsCalendarScreen>
{
  _LessonsPageState? _attachedTo;

  int? _ticket;

  @override
  void initState()
  {
    super.initState();

    _host.addListener(_attachSoon);
    _attachSoon();
  }

  // After the frame: the page's setState must not land in the middle of a build.
  void _attachSoon()
  {
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      final host = _host.value;

      if (!mounted || host == null || identical(host, _attachedTo))
      {
        return;
      }

      _attachedTo = host;
      _ticket = host._attachCalendar(widget.target);
    });
  }

  @override
  void dispose()
  {
    _host.removeListener(_attachSoon);

    final host = _attachedTo;
    final ticket = _ticket;

    if (host != null && ticket != null)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => host._detachCalendar(ticket));
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return LessonsBackdrop(
      minHeight: 0,
      builder: (context, size, margin) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: margin, right: margin, top: size.isDense ? 16 : 24, bottom: 24),
          child: ValueListenableBuilder<_LessonsPageState?>(
            valueListenable: _host,
            builder: (context, host, _)
            {
              if (host == null)
              {
                return Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
              }

              return ValueListenableBuilder<int>(
                valueListenable: host._changes,
                builder: (context, _, _) => host._buildCalendarPage(context, size, widget.target),
              );
            },
          ),
        ),
      ),
    );
  }
}
