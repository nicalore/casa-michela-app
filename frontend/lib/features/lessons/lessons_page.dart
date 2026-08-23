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
import 'models/calendar_publication_item.dart';
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

const int _availabilityContentIndex = 0;
const int _bookingsContentIndex = 1;
const int _calendarContentIndex = 2;

const int _daySectionIndex = 0;
const int _calendarSectionIndex = 1;

List<RailGroup> _buildSections(List<DateTime> days)
{
  return [
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

  late final List<DateTime> _availableDays = computeAvailableDays(DateTime.now());

  late final List<RailGroup> _sections = _buildSections(_availableDays);

  int _selectedSection = 0;

  int _selectedDayIndex = 0;

  LessonsDayView _dayView = LessonsDayView.availability;

  final Set<int> _visitedSections = {};

  bool _isLoading = true;
  List<PersonItem> _people = [];
  List<MinistrySubjectItem> _ministrySubjects = [];

  List<AssociationSubjectItem> _associationSubjects = [];
  List<ServiceItem> _services = [];
  List<StudyProgramItem> _studyPrograms = [];
  List<AvailabilityItem> _availabilities = [];
  List<PresenceItem> _presences = [];

  List<LessonItem> _lessons = [];

  List<CalendarPublicationItem> _publications = [];

  List<OpeningDayItem> _openingDays = [];

  List<RoomItem> _rooms = [];

  List<PersonItem> get _teachers => _people.where((person) => person.roles.contains(_teacherRoleLabel)).toList();

  List<PersonItem> get _students => _people.where((person) => person.roles.contains(_studentRoleLabel)).toList();

  bool get _isCalendarSelected => _selectedSection >= _availableDays.length;

  int get _dayViewIndex
  {
    return _dayView == LessonsDayView.availability
        ? _availabilityContentIndex
        : _bookingsContentIndex;
  }

  int get _contentIndex => _isCalendarSelected ? _calendarContentIndex : _dayViewIndex;

  int get _sectionIndex => _isCalendarSelected ? _calendarSectionIndex : _daySectionIndex;

  DateTime get _selectedDay => _availableDays[_selectedDayIndex];

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
    _visitedSections.add(_contentIndex);
    _loadAllData();
  }

  @override
  void onDestinationShown() => _loadAllData(quiet: true);

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
        _apiService.getCalendarPublications(
          dateFrom: _availableDays.first,
          dateTo: _availableDays.last,
        ),
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
        _publications = _keepingDaysOutsideWindow(
          _publications,
          results[11] as List<CalendarPublicationItem>,
          (item) => item.date,
        );
        _isLoading = false;
      });
    }
    catch (e, stackTrace)
    {
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
      cascade: () => _refreshDay(date),
      onError: onError,
    );
  }

  Future<bool> _executeDeletePresenceQuietly(PresenceItem item, Function(String) onError)
  {
    return erase(
      call: () => _apiService.deletePresence(item.id),
      apply: () => _presences = _presences.where((p) => p.id != item.id).toList(),
      onError: onError,
      cascade: () => _refreshDay(item.date),
    );
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
      cascade: () => _refreshDay(slots.first.date),
    );
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

    return true;
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
        _apiService.getCalendarPublications(dateFrom: day, dateTo: day),
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
      });

      return true;
    }
    catch (e)
    {
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
    required List<TeacherRoomAssignmentItem> assignments,
    required Map<String, int?> rooms,
    required List<PlannedShift> shifts,
    required Function(String) onError,
  }) async
  {
    String? failure;

    void report(Object e) => failure ??= readableApiError(e);

    await _writeRoomAssignments(day, assignments, rooms, report);

    await _writeRoomSupervisions(day, shifts, report);

    // Both, and in one go: the rooms are on the hours and the shifts are part
    // of what the families were shown, so a room moved changes what is drawn
    // and whether the bozza has anything in it. Asking for one without the
    // other is how a page comes out half-answered.
    await _refreshDay(day);

    if (failure != null)
    {
      onError(failure!);

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

  // Leaving the bozza without publishing. Answers how many hours could not be
  // put back, or null where the server refused: it is worth saying, and it is
  // not the same sentence as an ordinary undo.
  Future<int?> _executeDiscardDraft({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  }) async
  {
    int? lost;

    final undone = await write(
      call: () => _apiService.discardDraft(day: day, band: band),
      // Only the count. The band is deliberately not moved out of bozza here,
      // the way the other two writes move it: what the calendar looks like has
      // just been undone on the server, and saying "published" before the hours
      // that went back have arrived is how the changes flashed up and vanished.
      // The reload below is the one change anybody sees.
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

  List<CalendarPublicationItem> _withoutBand(DateTime day, TimeBucket band)
  {
    return [
      for (final row in _publications)
        if (!(isSameDate(row.date, day) && row.band == band)) row,
    ];
  }

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

  // Both lists of a day, asked together and written together.
  //
  // Together and not one after the other, which is what this used to do: the
  // hours and the state of the band are two halves of one answer, and between
  // two setStates there is a frame showing half of it. Leaving a bozza is where
  // that showed — the band said "published" while the hours were still the ones
  // being undone, so the calendar appeared with the changes in it and dropped
  // them a moment later.
  Future<void> _refreshDay(DateTime day) async
  {
    try
    {
      final results = await Future.wait([
        _apiService.getLessons(dateFrom: day, dateTo: day),
        _apiService.getCalendarPublications(dateFrom: day, dateTo: day),
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
      });
    }
    catch (e, stackTrace)
    {
      // Said to the log and not to the screen: whatever asked for this has
      // already answered for itself, and what is drawn is a day old at worst.
      reportCaughtError(e, stackTrace, during: 'il ricaricamento del calendario');
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
  }) async
  {
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

      await _refreshPublications(created.date);

      return created;
    }
    catch (e)
    {
      if (provisional != null && mounted)
      {
        setState(() => _lessons = _lessons.where((lesson) => lesson.id != provisional.id).toList());
      }

      onError(readableApiError(e));

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
  }) async
  {
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

      await _refreshPublications(updated.date);

      return updated;
    }
    catch (e)
    {
      if (optimistic != null && mounted)
      {
        setState(() => _lessons = _lessons.map((lesson) => lesson.id == existing.id ? existing : lesson).toList());
      }

      onError(readableApiError(e));

      return null;
    }
  }

  int _nextProvisionalLessonId = -1;

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

  Widget _buildSectionContent(AppWindowSize size)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    return _buildTabs(size);
  }

  Widget _buildDaySection(AppWindowSize size)
  {
    final Widget lists = IndexedStack(
      index: _dayViewIndex,
      children: [
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
      ],
    );

    if (_isSelectedDayClosed)
    {
      return lists;
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
        Expanded(child: lists),
      ],
    );
  }

  Widget _buildTabs(AppWindowSize size)
  {
    return PageSections(
      index: _sectionIndex,
      step: _selectedSection,
      children: [
        _buildDaySection(size),
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
                publications: _publications,
                onLoadDay: _executeLoadDay,
                onPublishBand: _executePublishBand,
                onReopenBand: _executeReopenBand,
                onCloseDraft: _executeCloseDraft,
                onDiscardDraft: _executeDiscardDraft,
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
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: AppTopBar.contentTopInsetFor(size),
                      bottom: 24,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (size.hasRail) ...[
                          Align(
                            alignment: Alignment.topLeft,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (size.isCompact) ...[
                                PageTransitionItem(
                                  slot: PageTransitionItem.frame,
                                  child: AppSectionHeading(
                                    module: 'Lezioni',
                                    section: railEntryAt(_sections, _selectedSection),
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              Expanded(
                                key: const ValueKey('lessons-sections'),
                                child: _buildSectionContent(size),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
