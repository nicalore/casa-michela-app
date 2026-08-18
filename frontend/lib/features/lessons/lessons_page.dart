import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/state/entity_writes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/time_bucket.dart';
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
import '../association/models/opening_day_item.dart';
import '../association/models/room_item.dart';
import '../association/models/service_item.dart';
import '../association/models/study_program_item.dart';
import '../people/models/person_item.dart';
import 'models/availability_item.dart';
import 'models/booking_summary_item.dart';
import 'models/lesson_item.dart';
import 'models/presence_item.dart';
import 'models/room_day_plan.dart';
import 'models/room_supervision_item.dart';
import 'models/subject_request.dart';
import 'models/teacher_room_assignment_item.dart';
import 'tabs/availability_tab.dart';
import 'tabs/bookings_tab.dart';
import 'tabs/calendar_tab.dart';
import 'utils/booking_window.dart';
import 'utils/opening_window.dart';
import 'widgets/lessons_day_header.dart';
import 'widgets/lessons_toolbar.dart';
import 'widgets/room_assignment_wizard.dart' show PlannedShift;

// The order here is the order of the sections below.
const int _availabilityContentIndex = 0;
const int _bookingsContentIndex = 1;
const int _calendarContentIndex = 2;

// Both lists are worked a day at a time and are one day seen from two sides, so
// the rail asks for the day and a switch over the content chooses the side.
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

class _LessonsPageState extends State<LessonsPage>
    with DestinationRefresh, EntityWrites
{
  final ApiService _apiService = ApiService();

  // The days the window has open, computed once per page lifetime: they are the
  // entries of the rail, and the tabs are handed the one it is on.
  late final List<DateTime> _availableDays = computeAvailableDays(DateTime.now());

  late final List<RailGroup> _sections = _buildSections(_availableDays);

  // Counted the way the rail counts — entries only, headings excluded — so it
  // is either one of the open days or, past the last of them, the calendar.
  int _selectedSection = 0;

  // Which of the open days the two lists are on. Kept apart from the section
  // because the calendar is a section too, and reading the day off the section
  // sent both lists back to the first day every time somebody looked at the
  // calendar — which ran their didUpdateWidget and, in AvailabilityTab, pruned
  // the subject filter against the wrong day's teachers.
  int _selectedDayIndex = 0;

  // Which side of the day is on screen. It survives a change of day on purpose:
  // filling a week's availabilities in means walking down the days with the
  // list you are working on staying put.
  LessonsDayView _dayView = LessonsDayView.availability;

  // Records which tabs have been opened: once visited a tab stays mounted among
  // the sections. Reset only when GoRouter destroys this page.
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

  // What has already been planned out of the two lists above. Loaded for the
  // whole window like they are, so the calendar can be walked day by day
  // without asking the server again.
  List<LessonItem> _lessons = [];

  // When the association is open, in the building and at a screen, across the
  // days the booking window has unlocked. A teacher can only be available where
  // the association is open, so this is what the wizard is bounded by.
  List<OpeningDayItem> _openingDays = [];

  // The places in the building, for the calendar to hand out once a band is
  // composed. A catalogue and not a state of the day: which of them are taken is
  // asked for the day the window is opened on, and lives nowhere else.
  List<RoomItem> _rooms = [];

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

  // The day the two lists are on. It stays where it was left while the calendar
  // is on screen: the calendar asks for a day of its own, and walking through
  // it is no reason for the lists behind to move.
  DateTime get _selectedDay => _availableDays[_selectedDayIndex];

  // A day the association opens in neither way. The tabs say so themselves, in
  // large, and the head of the day steps aside for them: counting nobody in a
  // day nobody can be in is a line saying nothing twice.
  bool get _isSelectedDayClosed
  {
    return !isOpenOn(_openingDays, _selectedDay, kPresenceMode) &&
        !isOpenOn(_openingDays, _selectedDay, kOnlineMode);
  }

  // What the day amounts to, counted before any search. People and not rows: a
  // teacher leaving two slots open is one teacher.
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

  // What was held for days the reload did not ask about, kept.
  //
  // Two calls below are bounded by the booking window and the calendar walks
  // past it, so a day out there is fetched on its own into these same lists. An
  // answer about the window may only replace the window: replacing wholesale
  // dropped those days, and a day with no opening rows reads as a closed day.
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
        _apiService.getLessons(
          dateFrom: _availableDays.first,
          dateTo: _availableDays.last,
        ),
        _apiService.getRooms(),
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
        _openingDays = _keepingDaysOutsideWindow(
          _openingDays,
          [
            ...results[5] as List<OpeningDayItem>,
            ...results[6] as List<OpeningDayItem>,
          ],
          (item) => item.date,
        );
        _associationSubjects = results[7] as List<AssociationSubjectItem>;
        _services = results[8] as List<ServiceItem>;
        _lessons = _keepingDaysOutsideWindow(
          _lessons,
          results[9] as List<LessonItem>,
          (item) => item.date,
        );
        _rooms = results[10] as List<RoomItem>;
        _isLoading = false;
      });
    }
    catch (e, stackTrace)
    {
      // Eleven calls in parallel and one sentence for all of them: which of the
      // eleven failed, and why, is only readable here.
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

  // Quiet: a day is written a stretch at a time, and a window that saved six of
  // them would say so six times over. What it did is announced once, by the
  // window, when it is done. The same goes for every write below that passes no
  // sentence of its own.
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
    );
  }

  // A day's availability is deleted whole: the card is a teacher on a day, and
  // the stretches of hours on it are the parts of one thing.
  Future<void> _executeDeleteAvailabilityGroup(List<AvailabilityItem> slots) async
  {
    final removed = slots.map((slot) => slot.id).toSet();

    await erase(
      call: () async
      {
        for (final slot in slots)
        {
          await _apiService.deleteAvailability(slot.id);
        }
      },
      apply: () => _availabilities = _availabilities.where((a) => !removed.contains(a.id)).toList(),
      done: 'Disponibilità eliminata con successo!',
    );
  }

  // One stretch dropped from a day that keeps the others. Quiet on purpose: it
  // is a step inside a save, and the window that asked for it says how the save
  // went when it is done.
  Future<bool> _executeDeleteAvailabilitySlot(AvailabilityItem item, Function(String) onError)
  {
    return erase(
      call: () => _apiService.deleteAvailability(item.id),
      apply: () => _availabilities = _availabilities.where((a) => a.id != item.id).toList(),
      onError: onError,
    );
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

  Future<bool> _executeEditPresence(PresenceItem existing, String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError)
  {
    return write(
      call: () => _apiService.updatePresence(
        id: existing.id,
        studentTaxCode: studentTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
      ),
      apply: (updated) => _presences = _presences.map((p) => p.id == existing.id ? updated : p).toList(),
      onError: onError,
    );
  }

  // One stretch taken off a day inside a save: a step, not an announcement.
  Future<bool> _executeDeletePresenceQuietly(PresenceItem item, Function(String) onError)
  {
    return erase(
      call: () => _apiService.deletePresence(item.id),
      apply: () => _presences = _presences.where((p) => p.id != item.id).toList(),
      onError: onError,
    );
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
    final removed = slots.map((slot) => slot.id).toSet();

    await erase(
      call: () async
      {
        for (final slot in slots)
        {
          await _apiService.deletePresence(slot.id);
        }
      },
      apply: () => _presences = _presences.where((p) => !removed.contains(p.id)).toList(),
      done: 'Richiesta eliminata con successo!',
    );
  }

  // Reading back the day just written to, without its outcome becoming the
  // outcome of the write: a subject written is written even if the read-back
  // never arrives, and counting that a failure stopped a save halfway and left a
  // superseded updated_at on screen, which took a 409 on the next one.
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

  // A request filed under another of the pupil's stretches of the same mode:
  // the row hangs off one presence and the lesson is checked against that one,
  // so planning it elsewhere moves it first.
  //
  // Written whole, like every edit of a booking — what does not reach the server
  // is cleared. Both stretches are read back, and neither read-back may turn a
  // write that went through into a failure.
  Future<bool> _executeMoveBooking({
    required BookingSummaryItem booking,
    required int presenceId,
    required Function(String) onError,
  }) async
  {
    final source = _presences
        .where((presence) => presence.bookings.any((item) => item.id == booking.id))
        .firstOrNull;

    try
    {
      await _apiService.updateBooking(
        id: booking.id,
        subject: {
          ...SubjectRequestDraft.fromBooking(booking).toJson(),
          'presence_id': presenceId,
        },
        expectedUpdatedAt: booking.updatedAt,
      );
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }

    await Future.wait([
      _refreshPresence(presenceId),
      if (source != null && source.id != presenceId) _refreshPresence(source.id),
    ]);

    return true;
  }

  // --- Lessons ------------------------------------------------------------

  // One day fetched on its own, for the calendar walking past the booking
  // window, where the day would look empty rather than unknown. It replaces only
  // that day, so walking back into the window loses nothing.
  Future<bool> _executeLoadDay(DateTime day, Function(String) onError) async
  {
    try
    {
      final results = await Future.wait([
        _apiService.getAvailabilities(dateFrom: day, dateTo: day),
        _apiService.getPresences(dateFrom: day, dateTo: day),
        _apiService.getOpeningDays(dateFrom: day, dateTo: day, mode: kPresenceMode),
        _apiService.getOpeningDays(dateFrom: day, dateTo: day, mode: kOnlineMode),
        _apiService.getLessons(dateFrom: day, dateTo: day),
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
      });

      return true;
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }
  }

  // --- Rooms --------------------------------------------------------------

  // Who already has which room on the day the calendar is on, and who answers
  // for each of them. Null where either ask failed, so the window that opens on
  // this can tell "nobody has one" from "we could not find out" and refuse to
  // open on the second.
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

  // The plan as the window left it, as the difference from what it opened on.
  //
  // Rooms first and shifts after: a shift's key points at the assignment, so one
  // written before its room has nothing to hang off. Everything that can be done
  // is done even where one fails, and the day is reloaded either way.
  Future<bool> _executeSaveRoomPlan({
    required DateTime day,
    required List<TeacherRoomAssignmentItem> assignments,
    required Map<String, int?> rooms,
    required List<PlannedShift> shifts,
    required Function(String) onError,
  }) async
  {
    String? failure;

    void report(Object e) => failure ??= readableApiError(e);

    final moved = await _writeRoomAssignments(day, assignments, rooms, report);

    await _writeRoomSupervisions(day, shifts, report);

    // The rooms are on the lessons, resolved by the server, and the calendar
    // draws them off there: without this the board would be right and the hours
    // under it would go on naming the room nobody is in any more.
    if (moved)
    {
      await _refreshLessons(day);
    }

    if (failure != null)
    {
      onError(failure!);

      return false;
    }

    return true;
  }

  // Answers whether anything about the rooms changed. A call per teacher: the
  // server keeps one assignment per teacher per day, and the three verbs mean
  // different things — a move carries the shifts across, an unassign removes
  // them. Removals go first, or a room freed and refilled asks the server to
  // hold two teachers at once.
  Future<bool> _writeRoomAssignments(
    DateTime day,
    List<TeacherRoomAssignmentItem> existing,
    Map<String, int?> desired,
    void Function(Object e) report,
  ) async
  {
    final before = {for (final row in existing) row.teacherTaxCode: row};

    final removals = <String>[];
    final writes = <String, int>{};

    desired.forEach((teacherTaxCode, roomId)
    {
      final was = before[teacherTaxCode];

      if (roomId == null)
      {
        if (was != null)
        {
          removals.add(teacherTaxCode);
        }

        return;
      }

      if (was == null || was.room.id != roomId)
      {
        writes[teacherTaxCode] = roomId;
      }
    });

    for (final teacherTaxCode in removals)
    {
      try
      {
        await _apiService.unassignTeacherRoom(day: day, teacherTaxCode: teacherTaxCode);
      }
      catch (e)
      {
        report(e);
      }
    }

    for (final entry in writes.entries)
    {
      final was = before[entry.key];

      try
      {
        if (was == null)
        {
          await _apiService.assignTeacherRoom(
            day: day,
            teacherTaxCode: entry.key,
            roomId: entry.value,
          );
        }
        else
        {
          await _apiService.moveTeacherRoom(
            day: day,
            teacherTaxCode: entry.key,
            roomId: entry.value,
            expectedUpdatedAt: was.updatedAt,
          );
        }
      }
      catch (e)
      {
        report(e);
      }
    }

    return removals.isNotEmpty || writes.isNotEmpty;
  }

  // The shifts, against what the day holds after the rooms are written. Asked
  // again and not diffed against what the window opened on, which is why this is
  // a second pass: moving or unassigning a teacher carries or removes their
  // shifts by cascade, out of sight of this client.
  //
  // Thrown away and rewritten: a shift is a stretch of hours and nothing else.
  Future<void> _writeRoomSupervisions(
    DateTime day,
    List<PlannedShift> desired,
    void Function(Object e) report,
  ) async
  {
    final List<RoomSupervisionItem> existing;

    try
    {
      existing = await _apiService.getRoomSupervisions(day);
    }
    catch (e)
    {
      report(e);

      return;
    }

    final stale = [
      for (final row in existing)
        if (!desired.any((shift) => shift.matches(row))) row,
    ];

    final missing = [
      for (final shift in desired)
        if (!existing.any(shift.matches)) shift,
    ];

    // Out before in, so a shift moved by a quarter of an hour does not have to
    // exist twice at once: the server refuses a teacher two overlapping turns.
    for (final row in stale)
    {
      try
      {
        await _apiService.deleteRoomSupervision(row.id);
      }
      catch (e)
      {
        report(e);
      }
    }

    for (final shift in missing)
    {
      try
      {
        await _apiService.createRoomSupervision(
          day: day,
          teacherTaxCode: shift.teacherTaxCode,
          roomId: shift.roomId,
          startTime: shift.startTime,
          endTime: shift.endTime,
        );
      }
      catch (e)
      {
        report(e);
      }
    }
  }

  Future<void> _refreshLessons(DateTime day) async
  {
    try
    {
      final lessons = await _apiService.getLessons(dateFrom: day, dateTo: day);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _lessons = [
          ..._lessons.where((item) => !isSameDate(item.date, day)),
          ...lessons,
        ];
      });
    }
    catch (e, stackTrace)
    {
      // Said to the log and not to the screen: whatever asked for this has
      // already answered for itself, and what is drawn is a day old at worst.
      reportCaughtError(e, stackTrace, during: 'il ricaricamento delle lezioni');
    }
  }

  // These answer with the lesson and not a bool: the server's answer carries
  // what the request could not know — the band, the room, and the warnings,
  // which have no column to live in.
  //
  // The hour as this client can already draw it, for putting on the calendar at
  // once. What is not known here is left out and arrives with the answer. Null
  // where any of it would have to be invented: a lesson drawn with the wrong
  // name is worse than one drawn a moment late.
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

      // What the hour is for the pupils, which is what the lesson's own mode
      // means: a teacher in the building can take either, so it is the presence
      // that decides.
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
  }) async
  {
    // Drawn first and asked afterwards: an hour let go has to be there at once,
    // and a gesture ending in a placeholder reads as one that has not finished.
    // The answer replaces the drawing whole and a refusal takes it away.
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
        });
      }

      return created;
    }
    catch (e)
    {
      // The hour that was already drawn has to go: what is on screen was this
      // client's guess, and the server has just said no.
      if (provisional != null && mounted)
      {
        setState(() => _lessons = _lessons.where((lesson) => lesson.id != provisional.id).toList());
      }

      onError(readableApiError(e));

      return null;
    }
  }

  // The lesson with the change already made, for showing it before the server
  // answers. Only where the pupils are the same: gaining or losing one needs
  // objects this page cannot invent, and those wait for the answer.
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
  }) async
  {
    // Moved on screen first and asked afterwards: a block sitting where it
    // started for the length of a round trip reads as a drop that missed. A
    // refusal puts the old one back.
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
      );

      if (mounted)
      {
        setState(() => _lessons = _lessons.map((lesson) => lesson.id == existing.id ? updated : lesson).toList());
      }

      return updated;
    }
    catch (e)
    {
      // The move that was already drawn has to be undone: what is on screen was
      // this client's guess, and the server has just said no.
      if (optimistic != null && mounted)
      {
        setState(() => _lessons = _lessons.map((lesson) => lesson.id == existing.id ? existing : lesson).toList());
      }

      onError(readableApiError(e));

      return null;
    }
  }

  // The id given to an hour this client has drawn and the server has not yet
  // seen. Negative, and further from zero every time: no row will ever have one,
  // so nothing can mistake a drawing for a lesson that exists.
  int _nextProvisionalLessonId = -1;

  // An hour shortened and the freed minutes written as a second one.
  //
  // Two calls in a forced order: the second part has no room until the first has
  // shrunk. Both halves are drawn before either goes out, which is the point —
  // awaited in turn, the new piece arrived a round trip after the block it came
  // out of, and one gesture has to look like one thing happening.
  //
  // A refused shortening takes the drawing back whole; a refused second part
  // leaves it standing, because it did go through.
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
  }) async
  {
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
      updated = await _apiService.updateLesson(
        id: existing.id,
        availabilityId: availabilityId,
        bookingIds: bookingIds,
        associationSubjectIds: associationSubjectIds,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
      );
    }
    catch (e)
    {
      draw([
        for (final lesson in _lessons)
          if (lesson.id != second?.id) lesson.id == existing.id ? existing : lesson,
      ]);

      onError(readableApiError(e));

      return null;
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
    }

    return updated;
  }

  Future<bool> _executeDeleteLesson(int id, Function(String) onError) async
  {
    // Taken off the calendar first and asked afterwards, like every other write
    // here: an hour carried clear has to go when the hand opens, and standing at
    // full strength for the length of the request ends the gesture in nothing
    // happening. Put back if the server will not have it.
    final removed = _lessons.where((lesson) => lesson.id == id).firstOrNull;

    if (removed != null && mounted)
    {
      setState(() => _lessons = _lessons.where((lesson) => lesson.id != id).toList());
    }

    try
    {
      await _apiService.deleteLesson(id);

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

  Widget _buildSectionContent(AppWindowSize size)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    return _buildTabs(size);
  }

  // The head of a day, over whichever of its two lists is on screen. Not over
  // the calendar, which counts nobody: it is a section of its own and says
  // which day it is on itself. Nor over a day nobody can be in — see
  // _isSelectedDayClosed.
  //
  // Inside the section rather than above it, so that it leaves and arrives with
  // the list it heads instead of standing still over a page being handed over.
  Widget _buildDaySection(AppWindowSize size, Widget tab)
  {
    if (_isSelectedDayClosed)
    {
      return tab;
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
        Expanded(child: tab),
      ],
    );
  }

  // The sections of the page, stepped between the way every other page steps
  // between its own: the one on screen empties itself upwards, one element
  // after the next, and the one arriving comes up from below in the same order.
  // Like the IndexedStack it stands in for, it keeps every visited section
  // mounted, so coming back to one finds its filters set and its list where it
  // was scrolled to.
  //
  // The rail here counts days and not sections, and the two lists are one pair
  // walking through the week rather than a pair per day: [PageSections.step] is
  // what tells the step apart from no step at all when the section stays put
  // and only the day under it changes.
  //
  // The two lists of a day are built together from the start: they are two ways
  // of looking at one day, and a switch built when it is first looked at opens
  // with its pill already on the answer. Neither asks anything of the network.
  Widget _buildTabs(AppWindowSize size)
  {
    return PageSections(
      index: _contentIndex,
      step: _selectedSection,
      children: [
        // Which side the page is on is passed to both of them rather than each
        // naming itself: the toolbar shows the answer, and the answer is held
        // here. Told it, the one being left slides its pill across as the one
        // arriving comes up wearing the same position.
        _buildDaySection(
          size,
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
        ),
        _buildDaySection(
          size,
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
        ),
        _visitedSections.contains(_calendarContentIndex)
            ? CalendarTab(
                availableDays: _availableDays,
                lessons: _lessons,
                availabilities: _availabilities,
                presences: _presences,
                openingDays: _openingDays,
                ministrySubjects: _ministrySubjects,
                people: _people,
                associationSubjects: _associationSubjects,
                studyPrograms: _studyPrograms,
                rooms: _rooms,
                onLoadDay: _executeLoadDay,
                onLoadRoomPlan: _executeLoadRoomPlan,
                onSaveRoomPlan: _executeSaveRoomPlan,
                onCreateLesson: _executeCreateLesson,
                onUpdateLesson: _executeUpdateLesson,
                onDeleteLesson: _executeDeleteLesson,
                onSplitLesson: _executeSplitLesson,
                onMoveBooking: _executeMoveBooking,
              )
            : const SizedBox.shrink(),
      ],
    );
  }

  void _selectSection(int index)
  {
    setState(()
    {
      _selectedSection = index;

      if (index < _availableDays.length)
      {
        _selectedDayIndex = index;
      }

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
