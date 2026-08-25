import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_today_button.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/opening_day_item.dart';
import '../../association/models/room_item.dart';
import '../../association/models/study_program_item.dart';
import '../../association/tabs/opening_hours/calendar_bounds.dart';
import '../../people/models/person_item.dart';
import '../models/availability_item.dart';
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/calendar_publication_item.dart';
import '../models/lesson_item.dart';
import '../models/person_option_item.dart';
import '../models/presence_item.dart';
import '../models/room_day_plan.dart';
import '../models/schedulable_booking.dart';
import '../models/teacher_room_assignment_item.dart';
import '../export/calendar_pdf_export.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import '../widgets/calendar_booking_panel.dart';
import '../widgets/calendar_day_agenda.dart';
import '../widgets/calendar_lesson_block.dart';
import '../widgets/calendar_lesson_board.dart';
import '../widgets/calendar_publish_dialogs.dart';
import '../widgets/calendar_timeline.dart';
import '../widgets/lesson_details_dialog.dart';
import '../widgets/lesson_plan_wizard.dart';
import '../widgets/lessons_closed_day.dart';
import '../widgets/room_assignment_wizard.dart';

const double kCalendarSideBySideMin = 1040;

const double kCalendarTimelineMin = 620;

const double kCalendarDayNavMin = 470;

enum _CalendarShape
{
  sideBySide,

  stacked,

  compact,
}

_CalendarShape _shapeFor(double width)
{
  if (width >= kCalendarSideBySideMin)
  {
    return _CalendarShape.sideBySide;
  }

  return width >= kCalendarTimelineMin ? _CalendarShape.stacked : _CalendarShape.compact;
}

enum CalendarCompactView
{
  toPlan,
  planned,
}

const double _panelGap = 28;

// The three sentences leaving a bozza says. Held here and not spread through
// the method: they are the only three this screen says about it, and they are
// read as one thing.
const String _kDraftPillTooltip = 'Le modifiche saranno inviate una volta confermate.';

const String _kDraftDiscarded = 'Modifiche annullate.';

// Where an hour could not be put back at all: the availability it stood on was
// withdrawn, or the request it taught was cancelled, while the bozza was open.
// The rest of the band did go back — but a calendar that came back short is not
// something to report as a success.
const String _kDraftRestoreFailed = 'Errore durante il ripristino del calendario.';

const double _actionButtonHeight = 48;
const double _actionButtonFontSize = 14;

const double _actionButtonWidth = 288;

const double _dayLabelWidth = 250;

const double _settingMenuWidth = 210;

const double _filterGap = 12;

const double _searchWidth = 560;

const double _filtersOneRowMin = 900;

const double _pillLabelMaxWidth = double.infinity;

class CalendarTab extends StatefulWidget
{
  final List<DateTime> availableDays;

  final List<LessonItem> lessons;
  final List<AvailabilityItem> availabilities;
  final List<PresenceItem> presences;
  final List<OpeningDayItem> openingDays;

  final List<MinistrySubjectItem> ministrySubjects;

  final List<PersonItem> people;
  final List<AssociationSubjectItem> associationSubjects;

  final List<StudyProgramItem> studyPrograms;

  final Future<LessonItem?> Function({
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
  })? onCreateLesson;

  final Future<LessonItem?> Function({
    required LessonItem existing,
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
  })? onUpdateLesson;

  final Future<bool> Function(int id, Function(String) onError)? onDeleteLesson;

  final Future<LessonItem?> Function({
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
  })? onSplitLesson;

  final Future<bool> Function({
    required BookingSummaryItem booking,
    required int presenceId,
    required Function(String) onError,
  })? onMoveBooking;

  final List<CalendarPublicationItem> publications;

  final Future<List<String>?> Function({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  })? onPublishBand;

  final Future<bool> Function({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  })? onReopenBand;

  final Future<bool?> Function({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  })? onCloseDraft;

  // Leaves the bozza without publishing, undoing the work in it. Answers how
  // many hours could not be put back, or null where the server refused.
  final Future<int?> Function({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  })? onDiscardDraft;

  final DateTime? today;

  final Future<bool> Function(DateTime day, Function(String) onError)? onLoadDay;

  final List<RoomItem> rooms;

  final Future<RoomDayPlan?> Function(
    DateTime day,
    Function(String) onError,
  )? onLoadRoomPlan;

  final Future<bool> Function({
    required DateTime day,
    required List<TeacherRoomAssignmentItem> assignments,
    required Map<String, int?> rooms,
    required List<PlannedShift> shifts,
    required Function(String) onError,
  })? onSaveRoomPlan;

  const CalendarTab({
    super.key,
    required this.availableDays,
    required this.lessons,
    required this.availabilities,
    required this.presences,
    required this.openingDays,
    required this.ministrySubjects,
    required this.people,
    required this.associationSubjects,
    this.studyPrograms = const [],
    this.rooms = const [],
    this.publications = const [],
    this.onPublishBand,
    this.onReopenBand,
    this.onCloseDraft,
    this.onDiscardDraft,
    this.onCreateLesson,
    this.onUpdateLesson,
    this.onDeleteLesson,
    this.onSplitLesson,
    this.onMoveBooking,
    this.onLoadDay,
    this.onLoadRoomPlan,
    this.onSaveRoomPlan,
    this.today,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab>
{
  late DateTime _day = _initialDay();

  TimeBucket _band = TimeBucket.afternoon;

  CalendarView _view = CalendarView.byTeacher;

  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  CalendarSort _sort = CalendarSort.room;

  CalendarLayout _layout = CalendarLayout.byHour;

  CalendarCompactView _compactView = CalendarCompactView.toPlan;
  bool _panelExpanded = true;

  final ScrollController _trackController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  final Map<int, int> _subLaneMemory = {};

  final Map<int, (int, int)> _shrunkFrom = {};

  final ValueNotifier<CarriedRequest?> _carried = ValueNotifier(null);

  final ValueNotifier<CarriedPlacement> _carriedAt = ValueNotifier(CarriedPlacement.idle);

  String? _carriedRefusal;

  @override
  void initState()
  {
    super.initState();
    _carriedAt.addListener(_sayWhatIsWrong);

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (!mounted)
      {
        return;
      }

      setState(_syncClock);
      _ensureRoomPlan();
    });
  }

  static const Duration _closingWatch = Duration(hours: 12);

  bool get _waitingForBookingsToClose
  {
    if (_isPublished || _bookingsClosed)
    {
      return false;
    }

    return bookingsCloseAt(_day, _band).difference(_now) <= _closingWatch;
  }

  static const Duration _clockPeriod = Duration(seconds: 30);

  void _syncClock()
  {
    final wanted =
        widget.today == null && ((_isSettled && _isToday) || _waitingForBookingsToClose);

    if (wanted == (_clock != null))
    {
      return;
    }

    _clock?.cancel();
    _clock = wanted ? Timer.periodic(_clockPeriod, (_) => _tick()) : null;

    if (wanted)
    {
      _now = DateTime.now();
    }
  }

  void _tick()
  {
    if (!mounted)
    {
      return;
    }

    setState(() => _now = DateTime.now());
  }

  @override
  void didUpdateWidget(CalendarTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!identical(widget.lessons, oldWidget.lessons) && !_hasRoomPlan)
    {
      _ensureRoomPlan();
    }

    _syncClock();
  }

  @override
  void dispose()
  {
    _carriedAt.removeListener(_sayWhatIsWrong);

    if (_carriedRefusal != null)
    {
      CustomSnackBar.dismiss();
    }

    _clock?.cancel();
    _searchController.dispose();
    _trackController.dispose();
    _carried.dispose();
    _carriedAt.dispose();
    super.dispose();
  }

  void _sayWhatIsWrong()
  {
    final refusal = _carriedAt.value.refusal;

    if (refusal == _carriedRefusal || !mounted)
    {
      return;
    }

    _carriedRefusal = refusal;

    if (refusal == null)
    {
      CustomSnackBar.dismiss();

      return;
    }

    CustomSnackBar.show(
      context: context,
      message: refusal,
      isError: true,
      duration: kUntilDismissed,
    );
  }

  DateTime _initialDay()
  {
    final now = widget.today ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return widget.availableDays.any((day) => isSameDate(day, today)) ? today : widget.availableDays.first;
  }

  final Set<String> _fetchedDays = {};

  bool _isFetchingDay = false;

  RoomDayPlan? _roomPlan;
  String? _roomPlanDay;

  bool _isLoadingRoomPlan = false;

  bool _isPublishing = false;

  bool _isExporting = false;

  bool get _hasRoomPlan => _roomPlanDay == _keyOf(_day);

  late DateTime _now = widget.today ?? DateTime.now();

  Timer? _clock;

  CalendarPublicationItem? get _publication
  {
    return widget.publications
        .where((row) => isSameDate(row.date, _day) && row.band == _band)
        .firstOrNull;
  }

  bool get _isPublished => _publication != null;

  bool get _isDraft => _publication?.isDraft ?? false;

  bool get _isSettled => _isPublished && !_isDraft;

  bool get _isToday => isSameDate(_day, _now);

  bool get _showsBoard => _isSettled && _layout == CalendarLayout.byLesson;

  bool get _bookingsClosed => haveBookingsClosed(_day, _band, _now);

  String? get _tooEarlyReason
  {
    if (_bookingsClosed)
    {
      return null;
    }

    return 'Il calendario potrà essere pubblicato alla chiusura delle prenotazioni, '
        'che avverrà alle ${bookingsCloseLabel(_day, _band)}.';
  }

  Map<String, LaneRoomLabel> _roomLabelsFor(List<CalendarLane> lanes)
  {
    return laneRoomLabels(
      lanes: lanes.whereType<TeacherLane>().toList(),
      plan: _hasRoomPlan ? _roomPlan : null,
    );
  }

  int? get _nowMinutes
  {
    return _isSettled && _isToday ? minutesOfTimeOfDay(TimeOfDay.fromDateTime(_now)) : null;
  }

  Set<int> _pastLessons(List<CalendarLane> lanes)
  {
    if (!_isSettled)
    {
      return const {};
    }

    return {
      for (final lane in lanes)
        for (final lesson in lane.lessons)
          if (isLessonPast(lesson, _now)) lesson.id,
    };
  }

  bool _isInsideWindow(DateTime day) => widget.availableDays.any((other) => isSameDate(other, day));

  static String _keyOf(DateTime day) => '${day.year}-${day.month}-${day.day}';

  Future<void> _goToDay(DateTime day) async
  {
    final normalised = DateTime(day.year, day.month, day.day);

    setState(()
    {
      _day = normalised;
      _syncClock();
    });

    await _fetchDay(normalised);

    if (mounted)
    {
      await _ensureRoomPlan();
    }
  }

  Future<void> _fetchDay(DateTime day) async
  {
    final load = widget.onLoadDay;

    if (load == null || _isInsideWindow(day) || _fetchedDays.contains(_keyOf(day)))
    {
      return;
    }

    setState(() => _isFetchingDay = true);

    final loaded = await load(day, (message)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    });

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _isFetchingDay = false;

      if (loaded)
      {
        _fetchedDays.add(_keyOf(day));
      }
    });
  }

  bool get _isDayClosed
  {
    return !isOpenOn(widget.openingDays, _day, kPresenceMode) &&
        !isOpenOn(widget.openingDays, _day, kOnlineMode);
  }

  String? get _closureNote
  {
    for (final row in widget.openingDays)
    {
      if (!row.isOverride || row.startTime != null || !isSameDate(row.date, _day))
      {
        continue;
      }

      final note = row.note;

      if (note != null && note.isNotEmpty)
      {
        return note;
      }
    }

    return null;
  }

  List<TeacherLane> get _lanes
  {
    return buildTeacherLanes(
      availabilities: widget.availabilities,
      lessons: widget.lessons,
      day: _day,
      band: _band,
    );
  }

  List<StudentLane> get _studentLanes
  {
    return attendingStudents(buildStudentLanes(
      presences: widget.presences,
      lessons: widget.lessons,
      day: _day,
      band: _band,
    ));
  }

  CalendarSort get _shownSort
  {
    return _sort == CalendarSort.room && _view == CalendarView.byStudent
        ? CalendarSort.firstName
        : _sort;
  }

  bool get _isNarrowed => _search.trim().isNotEmpty;

  bool _rowNames(CalendarLane lane, String query)
  {
    bool says(PersonOptionItem person) => person.fullName.toLowerCase().contains(query);

    if (says(lane.person))
    {
      return true;
    }

    return lane.lessons.any((lesson) =>
        says(lesson.teacher) ||
        lesson.bookings.any((entry) => says(entry.presence.student)));
  }

  List<T> _narrow<T extends CalendarLane>(List<T> lanes)
  {
    final query = _search.trim().toLowerCase();

    return lanes
        .where((lane) => query.isEmpty || _rowNames(lane, query))
        .toList();
  }

  List<CalendarLane> _rowsFor(List<TeacherLane> lanes)
  {
    if (!_isSettled)
    {
      return lanes;
    }

    if (_view == CalendarView.byStudent)
    {
      return _ordered(_narrow(_studentLanes));
    }

    final called = _narrow(convokedTeachers(lanes));

    if (_shownSort == CalendarSort.room)
    {
      return orderByRoom(lanes: called, rooms: _roomLabelsFor(called));
    }

    return _ordered(called);
  }

  List<T> _ordered<T extends CalendarLane>(List<T> lanes)
  {
    return orderLanes(
      lanes: lanes,
      sort: _shownSort,
      bandStart: _bandStart,
      bandEnd: _bandEnd,
    );
  }

  CalendarDayIndex _buildIndex(List<TeacherLane> lanes)
  {
    return CalendarDayIndex.build(
      day: _day,
      band: _band,
      lanes: lanes,
      groups: _bookingGroups,
      lessons: widget.lessons,
      people: widget.people,
      associationSubjects: widget.associationSubjects,
      studyPrograms: widget.studyPrograms,
    );
  }

  Future<void> _openPublishedLesson(LessonItem lesson) async
  {
    await showLessonDetailsDialog(
      context: context,
      lesson: lesson,
      ministrySubjects: widget.ministrySubjects,
      view: _view,
    );
  }

  Future<void> _openLesson(LessonItem lesson, CalendarDayIndex index) async
  {
    final booking = lesson.bookings.map((entry) => index.bookingsById[entry.id]).whereType<SchedulableBooking>().firstOrNull;

    if (booking == null)
    {
      return;
    }

    await _planBooking(booking, index);
  }

  LessonPlacement _plan(CalendarDayIndex index, CalendarDragPayload payload, String teacherTaxCode, int startMinutes)
  {
    return switch (payload)
    {
      BookingDragPayload() => planDrop(index, payload, teacherTaxCode, startMinutes),
      LessonDragPayload(:final lesson) => _planLessonDrop(index, lesson, teacherTaxCode, startMinutes),
    };
  }

  LessonPlacement _planLessonDrop(
    CalendarDayIndex index,
    LessonItem lesson,
    String teacherTaxCode,
    int startMinutes,
  )
  {
    for (final host in _hoursUnder(index, teacherTaxCode, startMinutes, startMinutes + lesson.minutes))
    {
      if (host.id == lesson.id)
      {
        continue;
      }

      final shared = sharedSplitBooking(index, lesson, host);

      if (shared == null)
      {
        continue;
      }

      final merge = planMerge(index, shared, keepLessonId: host.id);

      if (merge != null)
      {
        return merge;
      }
    }

    return planMove(index, lesson, teacherTaxCode, startMinutes);
  }

  List<LessonItem> _hoursUnder(
    CalendarDayIndex index,
    String teacherTaxCode,
    int startMinutes,
    int endMinutes,
  )
  {
    final found = [
      for (final lesson in index.lanesByTeacher[teacherTaxCode]?.lessons ?? const <LessonItem>[])
        if (spansOverlap(startMinutes, endMinutes, lesson.startMinutes, lesson.endMinutes)) lesson,
    ];

    int shared(LessonItem lesson)
    {
      return math.min(endMinutes, lesson.endMinutes) - math.max(startMinutes, lesson.startMinutes);
    }

    found.sort((a, b) => shared(b).compareTo(shared(a)));

    return found;
  }

  void _carry(CalendarDragPayload? payload, CalendarDayIndex index)
  {
    _carried.value = payload == null
        ? null
        : CarriedRequest(payload: payload, competentTeachers: teachersWhoCouldTeach(index, payload));

    if (payload == null)
    {
      _carriedAt.value = CarriedPlacement.idle;
    }
  }

  bool _hasBothParts(CalendarDayIndex index, LessonItem lesson)
  {
    return lesson.bookings.any((entry) => (index.bookingsById[entry.id]?.parts.length ?? 0) >= kMaxLessonParts);
  }

  (int, int) _reachOf(LessonItem existing, LessonPlacement placement)
  {
    final was = _shrunkFrom[existing.id];

    final reach = (
      math.min(math.min(was?.$1 ?? existing.startMinutes, existing.startMinutes), placement.startMinutes),
      math.max(math.max(was?.$2 ?? existing.endMinutes, existing.endMinutes), placement.endMinutes),
    );

    _shrunkFrom[existing.id] = reach;

    return reach;
  }

  Future<bool> _fileWhereItIsPlanned(SchedulableBooking entry) async
  {
    final move = widget.onMoveBooking;

    if (!entry.isBorrowed || move == null)
    {
      return true;
    }

    return move(
      booking: entry.booking,
      presenceId: entry.presence.id,
      onError: _reportRefusal,
    );
  }

  Future<void> _applyDrop(
    CalendarDragPayload payload,
    LessonPlacement placement,
    CalendarDayIndex index,
  ) async
  {
    if (payload case BookingDragPayload(:final entry))
    {
      if (!await _fileWhereItIsPlanned(entry) || !mounted)
      {
        return;
      }
    }

    if (placement.deleteLessonId != null)
    {
      await _executeMerge(placement);

      return;
    }

    final create = widget.onCreateLesson;
    final update = widget.onUpdateLesson;

    void report(String message)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    }

    LessonItem? written;

    if (placement.lessonId == null)
    {
      if (create == null)
      {
        return;
      }

      written = await create(
        availabilityId: placement.availabilityId!,
        bookingIds: placement.bookingIds,
        associationSubjectIds: placement.associationSubjectIds,
        startTime: timeOfDayFromMinutes(placement.startMinutes),
        endTime: timeOfDayFromMinutes(placement.endMinutes),
        onError: report,
      );
    }
    else
    {
      final existing = widget.lessons.firstWhere((lesson) => lesson.id == placement.lessonId);

      final remainder = placement.kind == LessonPlacementKind.resize
          ? planSplitRemainder(
              index,
              existing,
              placement.startMinutes,
              placement.endMinutes,
              reached: _reachOf(existing, placement),
            )
          : null;

      if (remainder == null &&
          placement.kind == LessonPlacementKind.resize &&
          placement.minutes < existing.minutes &&
          _hasBothParts(index, existing))
      {
        CustomSnackBar.show(
          context: context,
          message: kFreedMinutesGoBackNotice,
          tone: SnackBarTone.warning,
        );
      }

      final split = widget.onSplitLesson;

      if (remainder != null && split != null)
      {
        written = await split(
          existing: existing,
          availabilityId: placement.availabilityId!,
          bookingIds: placement.bookingIds,
          associationSubjectIds: placement.associationSubjectIds,
          startTime: timeOfDayFromMinutes(placement.startMinutes),
          endTime: timeOfDayFromMinutes(placement.endMinutes),
          secondAvailabilityId: remainder.availabilityId!,
          secondAssociationSubjectIds: remainder.associationSubjectIds,
          secondStartTime: timeOfDayFromMinutes(remainder.startMinutes),
          secondEndTime: timeOfDayFromMinutes(remainder.endMinutes),
          onError: report,
        );

        if (!mounted || written == null)
        {
          return;
        }

        _reportWarnings(written);

        return;
      }

      if (update == null)
      {
        return;
      }

      written = await update(
        existing: existing,
        availabilityId: placement.availabilityId!,
        bookingIds: placement.bookingIds,
        associationSubjectIds: placement.associationSubjectIds,
        startTime: timeOfDayFromMinutes(placement.startMinutes),
        endTime: timeOfDayFromMinutes(placement.endMinutes),
        onError: report,
      );
    }

    if (!mounted || written == null)
    {
      return;
    }

    _reportWarnings(written);
  }

  void _reportWarnings(LessonItem written)
  {
    if (written.warnings.isEmpty)
    {
      return;
    }

    CustomSnackBar.show(
      context: context,
      message: written.warnings.length == 1
          ? written.warnings.single
          : 'Lezione salvata.',
      tone: SnackBarTone.warning,
    );
  }

  Future<void> _removeLesson(LessonItem lesson) async
  {
    final delete = widget.onDeleteLesson;

    if (delete == null || lesson.isLocked)
    {
      return;
    }

    final removed = await delete(lesson.id, _reportRefusal);

    if (removed && mounted)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Lezione tolta dal calendario.',
        isError: false,
      );
    }
  }

  void _reportRefusal(String refusal)
  {
    CustomSnackBar.show(context: context, message: refusal, isError: true);
  }

  void _reportCarriedRefusal(String refusal)
  {
    if (_carriedRefusal == refusal && CustomSnackBar.keepShowing())
    {
      _carriedRefusal = null;

      return;
    }

    _carriedRefusal = null;
    CustomSnackBar.show(context: context, message: refusal, isError: true);
  }

  Future<void> _planBooking(SchedulableBooking entry, CalendarDayIndex index) async
  {
    if (entry.parts.isEmpty && !canPlanSomething(index, entry))
    {
      _reportRefusal(noTeacherReason(index, entry, entry.requestedDisciplineIds));

      return;
    }

    final create = widget.onCreateLesson;

    await showLessonPlanWizard(
      context: context,
      entry: entry,
      index: index,
      ministrySubjects: widget.ministrySubjects,
      onCreate: create == null
          ? null
          : ({
              required availabilityId,
              required bookingIds,
              required associationSubjectIds,
              required startTime,
              required endTime,
              required onError,
            }) async
            {
              if (!await _fileWhereItIsPlanned(entry))
              {
                return null;
              }

              return create(
                availabilityId: availabilityId,
                bookingIds: bookingIds,
                associationSubjectIds: associationSubjectIds,
                startTime: startTime,
                endTime: endTime,
                onError: onError,
              );
            },
      onUpdate: widget.onUpdateLesson,
      onDelete: widget.onDeleteLesson,
    );
  }

  Future<void> _executeMerge(LessonPlacement placement) async
  {
    final update = widget.onUpdateLesson;
    final delete = widget.onDeleteLesson;

    if (update == null || delete == null)
    {
      return;
    }

    final survivor = widget.lessons.firstWhere((lesson) => lesson.id == placement.lessonId);

    String? failure;
    final separated = await delete(placement.deleteLessonId!, (message) => failure = message);

    if (!separated)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: failure ?? 'Non è stato possibile unire le lezioni.', isError: true);
      }

      return;
    }

    final merged = await update(
      existing: survivor,
      availabilityId: placement.availabilityId!,
      bookingIds: placement.bookingIds,
      associationSubjectIds: placement.associationSubjectIds,
      startTime: timeOfDayFromMinutes(placement.startMinutes),
      endTime: timeOfDayFromMinutes(placement.endMinutes),
      onError: (message) => failure = message,
    );

    if (!mounted)
    {
      return;
    }

    if (merged == null)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Le lezioni sono state separate ma non è stato possibile estendere la lezione: '
            '${failure ?? 'errore imprevisto'}.',
        isError: true,
      );

      return;
    }

    CustomSnackBar.show(context: context, message: 'Le due lezioni sono state unite.', isError: false);
  }

  ({Set<int> warned, Set<int> preferred}) _markedLessons(List<CalendarLane> lanes)
  {
    final warned = <int>{};
    final preferred = <int>{};

    for (final lane in lanes)
    {
      for (final lesson in lane.lessons)
      {
        for (final entry in lesson.bookings)
        {
          if (entry.booking.notPreferredTeacherTaxCodes.contains(lesson.teacherTaxCode))
          {
            warned.add(lesson.id);
          }

          if (entry.booking.preferredTeacherTaxCodes.contains(lesson.teacherTaxCode))
          {
            preferred.add(lesson.id);
          }
        }
      }
    }

    return (warned: warned, preferred: preferred);
  }

  Map<String, String> get _teacherNames
  {
    return {
      for (final person in widget.people) person.fiscalCode: '${person.firstName} ${person.lastName}',
    };
  }

  int get _bandStart => bandStartMinutes(_band);

  int get _bandEnd => bandEndMinutes(_band);

  (int, int)? _window(List<CalendarLane> lanes)
  {
    final opening = unionOpeningWindow(widget.openingDays, _day, _band);

    return timelineWindow(
      bandStartMinutes: _bandStart,
      bandEndMinutes: _bandEnd,
      opening: opening == null ? null : (opening.startMinutes, opening.endMinutes),
      content: [
        for (final lane in lanes) ...lane.contentSpans(_bandStart, _bandEnd),
      ],
    );
  }

  Widget _buildDayNav()
  {
    final isFirstDay = !_day.isAfter(kAssociationFoundedOn);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTodayButton(onTap: () => _goToDay(DateTime.now())),
        const SizedBox(width: 12),
        CarouselArrowButton(
          icon: Icons.chevron_left_rounded,
          isDisabled: isFirstDay || _isFetchingDay,
          onTap: () => _goToDay(addDays(_day, -1)),
        ),
        const SizedBox(width: 8),
        SizedBox(width: _dayLabelWidth, child: Center(child: _buildDayLabel())),
        const SizedBox(width: 8),
        CarouselArrowButton(
          icon: Icons.chevron_right_rounded,
          isDisabled: _isFetchingDay,
          onTap: () => _goToDay(addDays(_day, 1)),
        ),
      ],
    );
  }

  Widget _buildNarrowDayNav()
  {
    final isFirstDay = !_day.isAfter(kAssociationFoundedOn);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CarouselArrowButton(
              icon: Icons.chevron_left_rounded,
              isDisabled: isFirstDay || _isFetchingDay,
              onTap: () => _goToDay(addDays(_day, -1)),
            ),
            Expanded(child: Center(child: _buildDayLabel())),
            CarouselArrowButton(
              icon: Icons.chevron_right_rounded,
              isDisabled: _isFetchingDay,
              onTap: () => _goToDay(addDays(_day, 1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTodayButton(onTap: () => _goToDay(DateTime.now())),
      ],
    );
  }

  Widget _buildDayLabel()
  {
    return Text(
      '${formatWeekdayColumnLabel(_day)} ${_day.year}',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );
  }

  Widget _buildBandPicker()
  {
    return AppSegmentedTabs(
      labels: [for (final bucket in TimeBucket.values) bandLabel(bucket)],
      selectedIndex: _band.index,
      onSelected: (index) => setState(()
      {
        _band = TimeBucket.values[index];
        _syncClock();
      }),
      padding: EdgeInsets.zero,
      hugContent: true,
    );
  }

  Widget _buildSummary(List<CalendarLane> lanes)
  {
    final lessons = {
      for (final lane in lanes)
        for (final lesson in lane.lessons) lesson.id: lesson,
    }.values;

    final called = lessons.map((lesson) => lesson.teacherTaxCode).toSet();
    final pupils = lessons.expand((lesson) => lesson.studentTaxCodes).toSet();

    final parts = [
      _count(called.length, 'docente convocato', 'docenti convocati'),
      _count(pupils.length, 'studente', 'studenti'),
      _count(lessons.length, 'lezione', 'lezioni'),
    ];

    final Widget counts = Text(
      parts.join(' · '),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppTheme.trialMutedText,
      ),
    );

    final published = _publication;

    if (published == null)
    {
      return counts;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPublishedPill(published),
        const SizedBox(width: 12),
        Flexible(child: counts),
      ],
    );
  }

  Widget _buildFilters({required bool isNarrow})
  {
    final pills = <Widget>[
      _buildSortPicker(),
      const FilterGroupDivider(),
      _buildViewPicker(),
      if (!isNarrow) _buildLayoutPicker(),
    ];

    final Widget search = AppSearchField(
      controller: _searchController,
      onChanged: (value) => setState(() => _search = value),
      hintText: 'Cerca docente o studente...',
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _filtersOneRowMin)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: _filterGap),
              Wrap(
                spacing: _filterGap,
                runSpacing: _filterGap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: pills,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _searchWidth),
                  child: search,
                ),
              ),
            ),
            for (final pill in pills) ...[
              const SizedBox(width: _filterGap),
              pill,
            ],
          ],
        );
      },
    );
  }

  Widget _buildSortPicker()
  {
    return AppFilterPill<CalendarSort>.setting(
      prefix: 'Ordina',
      hint: 'Ordina per',
      icon: Icons.swap_vert_rounded,
      value: _shownSort,
      maxLabelWidth: _pillLabelMaxWidth,
      options: [
        for (final sort in CalendarSort.values)
          if (sort != CalendarSort.room || _view == CalendarView.byTeacher)
            FilterOption(value: sort, label: sort.label),
      ],
      onChanged: (sort) => setState(() => _sort = sort),
      menuWidth: _settingMenuWidth,
    );
  }

  Widget _buildLayoutPicker()
  {
    return AppFilterPill<CalendarLayout>.setting(
      prefix: 'Disposizione',
      hint: 'Disposizione',
      icon: Icons.view_agenda_outlined,
      value: _layout,
      maxLabelWidth: _pillLabelMaxWidth,
      options: [
        for (final layout in CalendarLayout.values)
          FilterOption(value: layout, label: layout.label),
      ],
      onChanged: (layout) => setState(() => _layout = layout),
      menuWidth: _settingMenuWidth,
    );
  }

  Widget _buildViewPicker()
  {
    return AppFilterPill<CalendarView>.setting(
      prefix: 'Vista',
      hint: 'Vista',
      icon: Icons.groups_outlined,
      value: _view,
      maxLabelWidth: _pillLabelMaxWidth,
      options: [
        for (final view in CalendarView.values)
          FilterOption(value: view, label: view.label),
      ],
      onChanged: (view) => setState(() => _view = view),
      menuWidth: _settingMenuWidth,
    );
  }

  Widget _buildPublishedPill(CalendarPublicationItem publication)
  {
    final draft = publication.isDraft;

    final accent = draft ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;
    final surface = draft ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface;

    final sent = publishedSentence(publication);

    return Tooltip(
      message: draft ? _kDraftPillTooltip : sent,
      decoration: AppTheme.tooltipDecoration,
      textStyle: AppTheme.tooltipTextStyle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              draft ? Icons.edit_outlined : Icons.check_circle_outline_rounded,
              size: 13,
              color: accent,
            ),
            const SizedBox(width: 5),
            Text(
              draft ? 'IN BOZZA' : 'PUBBLICATO',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
                letterSpacing: 1.4,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _count(int value, String singular, String plural)
  {
    return '$value ${value == 1 ? singular : plural}';
  }

  String get _emptyBandMessage
  {
    if (!_isSettled)
    {
      return 'Nessun docente disponibile';
    }

    if (_isNarrowed)
    {
      return _view == CalendarView.byStudent
          ? 'Nessuno studente corrisponde alla ricerca'
          : 'Nessun docente corrisponde alla ricerca';
    }

    return _view == CalendarView.byStudent
        ? 'Nessuno studente in calendario'
        : 'Nessun docente convocato';
  }

  Widget _buildClosedBand()
  {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, size: 44, color: AppTheme.trialMutedText),
          const SizedBox(height: 16),
          Text(
            "L'associazione è chiusa",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppTheme.trialOcean,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBand({required String message})
  {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(
            _isSettled && _isNarrowed ? Icons.search_off_rounded : Icons.person_off_outlined,
            size: 44,
            color: AppTheme.trialMutedText,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppTheme.trialOcean,
            ),
          ),
        ],
      ),
    );
  }

  ({Map<int, int> subLaneOf, List<double> rowHeights}) _stackLanes(List<CalendarLane> lanes)
  {
    final subLaneOf = <int, int>{};
    final rowHeights = <double>[];

    for (final lane in lanes)
    {
      final stacking = lane.subLanesWith(_subLaneMemory);

      for (var index = 0; index < lane.lessons.length; index++)
      {
        subLaneOf[lane.lessons[index].id] = stacking.laneOf[index];
      }

      rowHeights.add(timelineRowHeight(stacking.laneCount, _view));
    }

    _subLaneMemory
      ..clear()
      ..addAll(subLaneOf);

    _shrunkFrom.removeWhere((id, _) => !subLaneOf.containsKey(id));

    return (subLaneOf: subLaneOf, rowHeights: rowHeights);
  }

  Widget _buildTrack(List<CalendarLane> lanes, CalendarDayIndex index, (int, int) window, double width)
  {
    final trackWidth = width - kTimelineLeadingWidth;
    final stacking = _stackLanes(lanes);
    final marked = _markedLessons(lanes);
    final rowHeights = stacking.rowHeights;

    var metrics = TimelineMetrics(
      windowStartMinutes: window.$1,
      windowEndMinutes: window.$2,
      trackWidth: trackWidth,
      rowHeights: rowHeights,
    );

    if (metrics.pixelsPerMinute < kMinPixelsPerMinute)
    {
      final content = timelineWindow(
        bandStartMinutes: _bandStart,
        bandEndMinutes: _bandEnd,
        content: [for (final lane in lanes) ...lane.contentSpans(_bandStart, _bandEnd)],
      );

      if (content != null && content.$2 - content.$1 < window.$2 - window.$1)
      {
        metrics = TimelineMetrics(
          windowStartMinutes: content.$1,
          windowEndMinutes: content.$2,
          trackWidth: trackWidth,
          rowHeights: rowHeights,
        );
      }
    }

    final now = _nowMinutes;
    final showsNow = now != null && now >= metrics.windowStartMinutes && now <= metrics.windowEndMinutes;

    if (_isSettled)
    {
      return CalendarTimeline(
        lanes: lanes,
        metrics: metrics,
        bandStart: _bandStart,
        bandEnd: _bandEnd,
        view: _view,
        ministrySubjects: widget.ministrySubjects,
        subLaneOf: stacking.subLaneOf,
        warnedLessonIds: marked.warned,
        preferredLessonIds: marked.preferred,
        pastLessonIds: _pastLessons(lanes),
        roomByTeacher: _roomLabelsFor(lanes),
        nowMinutes: showsNow ? now : null,
        onLessonTap: _openPublishedLesson,
        scrollController: _trackController,
        viewportKey: _viewportKey,
      );
    }

    return CalendarTimeline(
      lanes: lanes,
      metrics: metrics,
      bandStart: _bandStart,
      bandEnd: _bandEnd,
      isComposing: true,
      ministrySubjects: widget.ministrySubjects,
      subLaneOf: stacking.subLaneOf,
      warnedLessonIds: marked.warned,
      preferredLessonIds: marked.preferred,
      onLessonTap: (lesson) => _openLesson(lesson, index),
      onPlan: (payload, teacherTaxCode, startMinutes) => _plan(index, payload, teacherTaxCode, startMinutes),
      onPlanResize: (lesson, startMinutes, endMinutes) => planResizeWithin(index, lesson, startMinutes, endMinutes),
      onDrop: (payload, placement) => _applyDrop(payload, placement, index),
      onRefused: _reportCarriedRefusal,
      carried: _carried,
      carriedAt: _carriedAt,
      onDroppedOutside: _removeLesson,
      onDragChanged: (payload) => _carry(payload, index),
      scrollController: _trackController,
      viewportKey: _viewportKey,
    );
  }

  List<PresenceBookingGroup> get _bookingGroups
  {
    return groupSchedulable(
      presences: widget.presences,
      lessons: widget.lessons,
      day: _day,
    ).where((group) => group.touches(_bandStart, _bandEnd)).toList();
  }

  Widget? _buildBandNotice(List<CalendarLane> lanes)
  {
    // A band with no hours has nothing to draw a timeline against, whatever is
    // left standing on it: hours offered before it shut, or a calendar taken
    // down with them. Those are read and taken away in Disponibilità, which is
    // where they can be acted on — here they would be a board of rows against
    // no hours at all, over the one thing there is to say about the band.
    if (unionOpeningWindow(widget.openingDays, _day, _band) == null)
    {
      return _buildClosedBand();
    }

    if (lanes.isEmpty)
    {
      return _buildEmptyBand(message: _emptyBandMessage);
    }

    return null;
  }

  Widget _buildBoard(List<CalendarLane> lanes)
  {
    final marked = _markedLessons(lanes);
    final now = _nowMinutes;

    return CalendarLessonBoard(
      lanes: lanes,
      bandStart: _bandStart,
      bandEnd: _bandEnd,
      nowMinutes: now != null && now >= _bandStart && now <= _bandEnd ? now : null,
      view: _view,
      ministrySubjects: widget.ministrySubjects,
      warnedLessonIds: marked.warned,
      preferredLessonIds: marked.preferred,
      pastLessonIds: _pastLessons(lanes),
      roomByTeacher: _roomLabelsFor(lanes),
      onLessonTap: _openPublishedLesson,
    );
  }

  Widget _buildTimelineArea(List<CalendarLane> lanes, CalendarDayIndex index)
  {
    final notice = _buildBandNotice(lanes);

    if (notice != null)
    {
      return notice;
    }

    if (_showsBoard)
    {
      return _buildBoard(lanes);
    }

    final window = _window(lanes);

    if (window == null)
    {
      return _buildClosedBand();
    }

    return LayoutBuilder(
      key: _viewportKey,
      builder: (context, constraints)
      {
        return Scrollbar(
          controller: _trackController,
          child: SingleChildScrollView(
            controller: _trackController,
            child: _buildTrack(lanes, index, window, constraints.maxWidth),
          ),
        );
      },
    );
  }

  List<TeacherLane> _dayLanesInBuilding()
  {
    final merged = <String, TeacherLane>{};

    for (final band in TimeBucket.values)
    {
      final lanes = buildTeacherLanes(
        availabilities: widget.availabilities,
        lessons: widget.lessons,
        day: _day,
        band: band,
      );

      for (final lane in lanes)
      {
        final was = merged[lane.teacherTaxCode];

        if (was == null)
        {
          merged[lane.teacherTaxCode] = lane;

          continue;
        }

        final seen = was.availabilities.map((slot) => slot.id).toSet();

        merged[lane.teacherTaxCode] = TeacherLane(
          teacherTaxCode: lane.teacherTaxCode,
          teacher: lane.teacher,
          availabilities: [
            ...was.availabilities,
            ...lane.availabilities.where((slot) => !seen.contains(slot.id)),
          ],
          lessons: [...was.lessons, ...lane.lessons],
        );
      }
    }

    final inBuilding = teachersInBuilding(merged.values.toList());

    inBuilding.sort((a, b) => a.teacher.fullName.toLowerCase().compareTo(b.teacher.fullName.toLowerCase()));

    return inBuilding;
  }

  Future<void> _ensureRoomPlan({bool force = false}) async
  {
    final load = widget.onLoadRoomPlan;

    if (load == null || _isLoadingRoomPlan || (!force && _hasRoomPlan))
    {
      return;
    }

    if (_dayLanesInBuilding().isEmpty)
    {
      return;
    }

    final day = _day;

    setState(() => _isLoadingRoomPlan = true);

    final plan = await load(day, (message)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    });

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _isLoadingRoomPlan = false;

      if (plan != null && isSameDate(day, _day))
      {
        _roomPlan = plan;
        _roomPlanDay = _keyOf(day);
      }
    });
  }

  Future<void> _openRoomAssignment() async
  {
    await _ensureRoomPlan();

    final plan = _roomPlan;

    if (!mounted || plan == null || !_hasRoomPlan)
    {
      return;
    }

    final saved = await showRoomAssignmentWizard(
      context: context,
      day: _day,
      lanes: _dayLanesInBuilding(),
      rooms: widget.rooms,
      assignments: plan.assignments,
      supervisions: plan.supervisions,
      onSave: widget.onSaveRoomPlan,
    );

    if (saved != true || !mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: 'Stanze e responsabili salvati.');

    await _ensureRoomPlan(force: true);
  }

  Future<void> _publish() async
  {
    final publish = widget.onPublishBand;

    if (publish == null || _isPublishing)
    {
      return;
    }

    final band = _band;
    final day = _day;

    final confirmed = await showPublishConfirmation(context: context);

    if (confirmed != true || !mounted)
    {
      return;
    }

    setState(() => _isPublishing = true);

    final warnings = await publish(day: day, band: band, onError: _reportRefusal);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _isPublishing = false;
      _syncClock();
    });

    if (warnings == null)
    {
      return;
    }

    CustomSnackBar.show(
      context: context,
      message: warnings.isEmpty ? 'Calendario pubblicato.' : warnings.join(' · '),
      tone: warnings.isEmpty ? SnackBarTone.info : SnackBarTone.warning,
      isError: false,
    );
  }

  Future<void> _returnToDraft() async
  {
    final reopen = widget.onReopenBand;

    if (reopen == null || _isPublishing)
    {
      return;
    }

    final band = _band;
    final day = _day;

    final confirmed = await showDraftConfirmation(context: context);

    if (confirmed != true || !mounted)
    {
      return;
    }

    setState(() => _isPublishing = true);

    final reopened = await reopen(day: day, band: band, onError: _reportRefusal);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _isPublishing = false;
      _syncClock();
    });

    if (reopened)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Calendario in bozza: le modifiche saranno inviate una volta confermate.',
        isError: false,
      );
    }
  }

  Future<void> _exportPdf() async
  {
    if (_isExporting)
    {
      return;
    }

    final teachers = teachersExport(
      availabilities: widget.availabilities,
      lessons: widget.lessons,
      openingDays: widget.openingDays,
      ministrySubjects: widget.ministrySubjects,
      roomPlan: _hasRoomPlan ? _roomPlan : null,
      publication: _publication,
      day: _day,
      band: _band,
    );

    final students = studentsExport(
      presences: widget.presences,
      lessons: widget.lessons,
      openingDays: widget.openingDays,
      ministrySubjects: widget.ministrySubjects,
      publication: _publication,
      day: _day,
      band: _band,
    );

    final tabs = openCalendarPdfTabs(teachers: teachers, students: students);

    if (tabs.isEmpty)
    {
      _reportRefusal('Il browser ha bloccato le nuove schede: consenti i popup '
          'per questo sito e riprova.');

      return;
    }

    setState(() => _isExporting = true);

    try
    {
      final outcome = await writeCalendarPdfs(
        teachers: teachers,
        students: students,
        tabs: tabs,
      );

      if (mounted && outcome == CalendarExportOutcome.downloaded)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Il browser ha bloccato una scheda: il PDF è stato scaricato.',
          isError: false,
        );
      }
    }
    catch (error)
    {
      failCalendarPdfTabs(tabs, 'Non è stato possibile creare il PDF.');

      if (mounted)
      {
        _reportRefusal('Non è stato possibile creare il PDF.');
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isExporting = false);
      }
    }
  }

  // Leaving the bozza without publishing, which undoes the work in it: the part
  // of the day goes back to what it was when it was opened. It asks first, since
  // what it throws away is somebody's afternoon of rearranging.
  Future<void> _discardDraft() async
  {
    final discard = widget.onDiscardDraft;

    if (discard == null || _isPublishing)
    {
      return;
    }

    final band = _band;
    final day = _day;
    final changed = _publication?.hasChanges ?? false;

    // Nothing was changed, so there is nothing to throw away and nothing to
    // ask about: the bozza simply closes.
    final confirmed = changed
        ? await showDiscardDraftConfirmation(context: context)
        : true;

    if (confirmed != true || !mounted)
    {
      return;
    }

    setState(() => _isPublishing = true);

    final lost = await discard(day: day, band: band, onError: _reportRefusal);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _isPublishing = false;
      _syncClock();
    });

    if (lost == null)
    {
      return;
    }

    CustomSnackBar.show(
      context: context,
      message: lost == 0 ? _kDraftDiscarded : _kDraftRestoreFailed,
      isError: lost != 0,
    );
  }

  Future<void> _closeDraft() async
  {
    final close = widget.onCloseDraft;

    if (close == null || _isPublishing)
    {
      return;
    }

    final band = _band;
    final day = _day;

    final confirmed = await showPublishChangesConfirmation(context: context);

    if (confirmed != true || !mounted)
    {
      return;
    }

    setState(() => _isPublishing = true);

    final resent = await close(day: day, band: band, onError: _reportRefusal);

    if (!mounted)
    {
      return;
    }

    setState(()
    {
      _isPublishing = false;
      _syncClock();
    });

    if (resent == null)
    {
      return;
    }

    CustomSnackBar.show(
      context: context,
      message: resent
          ? 'Modifiche inviate a docenti, genitori e studenti.'
          : 'Bozza chiusa senza modifiche.',
      isError: false,
    );
  }

  Widget? _buildBandAction()
  {
    if (_isDraft)
    {
      // The way out is always there, because a bozza somebody wants to abandon
      // is a bozza whether or not they changed anything in it. The way forward
      // appears beside it only where there is something to send: an afternoon
      // nobody touched has no modifiche to publish, and a button offering to
      // send them would be offering nothing.
      final changed = _publication?.hasChanges ?? false;

      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 12,
        children: [
          AppGradientButton(
            label: 'ESCI DALLA BOZZA',
            icon: Icons.undo_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            busy: _isPublishing,
            width: _actionButtonWidth,
            height: _actionButtonHeight,
            fontSize: _actionButtonFontSize,
            onPressed: _discardDraft,
          ),
          if (changed)
            AppGradientButton(
              label: 'PUBBLICA MODIFICHE',
              icon: Icons.send_rounded,
              busy: _isPublishing,
              width: _actionButtonWidth,
              height: _actionButtonHeight,
              fontSize: _actionButtonFontSize,
              onPressed: _closeDraft,
            ),
        ],
      );
    }

    if (_isPublished)
    {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 12,
        children: [
          AppGradientButton(
            label: 'MODIFICA CALENDARIO',
            icon: Icons.edit_outlined,
            busy: _isPublishing,
            width: _actionButtonWidth,
            height: _actionButtonHeight,
            fontSize: _actionButtonFontSize,
            onPressed: _returnToDraft,
          ),
          AppGradientButton(
            label: 'ESPORTA PDF',
            icon: Icons.picture_as_pdf_outlined,
            busy: _isExporting,
            width: _actionButtonWidth,
            height: _actionButtonHeight,
            fontSize: _actionButtonFontSize,
            onPressed: _exportPdf,
          ),
        ],
      );
    }

    final groups = _bookingGroups;

    if (groups.isEmpty || openBookingCount(groups) > 0)
    {
      return null;
    }

    if (teachersInBuilding(_lanes).isEmpty)
    {
      return AppGradientButton(
        label: 'PUBBLICA CALENDARIO',
        icon: Icons.send_rounded,
        busy: _isPublishing,
        disabledReason: _tooEarlyReason,
        width: _actionButtonWidth,
        height: _actionButtonHeight,
        fontSize: _actionButtonFontSize,
        onPressed: _publish,
      );
    }

    final plan = _roomPlan;
    final hasRooms = _hasRoomPlan && plan!.assignments.isNotEmpty;

    final settled = _hasRoomPlan &&
        isRoomPlanSettled(
          lanes: _dayLanesInBuilding(),
          assignments: plan!.assignments,
          supervisions: plan.supervisions,
        );

    final rooms = AppGradientButton(
      label: hasRooms ? 'MODIFICA STANZE' : 'ASSEGNA STANZE',
      icon: Icons.meeting_room_outlined,
      busy: _isLoadingRoomPlan,
      width: _actionButtonWidth,
      height: _actionButtonHeight,
      fontSize: _actionButtonFontSize,
      onPressed: _openRoomAssignment,
    );

    if (!settled)
    {
      return rooms;
    }

    return Wrap(
      spacing: 14,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        rooms,
        AppGradientButton(
          label: 'PUBBLICA CALENDARIO',
          icon: Icons.send_rounded,
          busy: _isPublishing,
          disabledReason: _tooEarlyReason,
          width: _actionButtonWidth,
          height: _actionButtonHeight,
          fontSize: _actionButtonFontSize,
          onPressed: _publish,
        ),
      ],
    );
  }

  Widget _buildTimelineColumn(List<CalendarLane> lanes, CalendarDayIndex index, {required int slot})
  {
    final action = _buildBandAction();

    final Widget area = PageTransitionItem(slot: slot, child: _buildTimelineArea(lanes, index));

    // The column stands whether there is an action under it or not. Returning
    // the bare area when there is none looks tidier and re-parents the track
    // the moment one appears — and the track is built inside a LayoutBuilder,
    // carries a GlobalKey, and has overlays under it, so being re-parented from
    // in there marks render objects outside the builder that is laying out.
    // Closing the last open request is what makes the button appear, which is
    // to say: it happened on a drop.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: area),
        if (action != null) ...[
          const SizedBox(height: 18),
          Center(child: PageTransitionItem(slot: slot + 1, child: action)),
        ],
      ],
    );
  }

  Widget _buildPanel({required BookingPanelShape shape, required CalendarDayIndex index})
  {
    return CalendarBookingPanel(
      groups: _bookingGroups,
      ministrySubjects: widget.ministrySubjects,
      teacherNames: _teacherNames,
      shape: shape,
      isExpanded: _panelExpanded,
      onExpandedChanged: (expanded) => setState(() => _panelExpanded = expanded),
      onPlanRequested: index.lanes.isEmpty ? null : (entry) => _planBooking(entry, index),
      carriedAt: _carriedAt,
      onDragChanged: (payload) => _carry(payload, index),
    );
  }

  Widget _buildAgendaArea(List<CalendarLane> lanes, CalendarDayIndex index)
  {
    if (_isSettled)
    {
      return _buildBoard(lanes);
    }

    final marked = _markedLessons(lanes);

    return CalendarDayAgenda(
      lanes: lanes,
      bandStart: _bandStart,
      bandEnd: _bandEnd,
      view: _view,
      isComposing: !_isSettled,
      ministrySubjects: widget.ministrySubjects,
      warnedLessonIds: marked.warned,
      preferredLessonIds: marked.preferred,
      pastLessonIds: _pastLessons(lanes),
      roomByTeacher: _isSettled ? _roomLabelsFor(lanes) : const {},
      onLessonTap: _isSettled ? _openPublishedLesson : (lesson) => _openLesson(lesson, index),
    );
  }

  Widget _buildCompactBody(List<CalendarLane> lanes, CalendarDayIndex index)
  {
    final notice = _buildBandNotice(lanes);

    if (notice != null)
    {
      return PageTransitionItem(slot: PageTransitionItem.list, child: notice);
    }

    final action = _buildBandAction();

    if (_isSettled)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PageTransitionItem(
              slot: PageTransitionItem.list,
              child: _buildAgendaArea(lanes, index),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            Center(child: PageTransitionItem(slot: PageTransitionItem.list + 1, child: action)),
          ],
        ],
      );
    }

    final open = openBookingCount(_bookingGroups);
    final planned = lanes.fold<int>(0, (total, lane) => total + lane.lessons.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(
          slot: PageTransitionItem.list,
          child: AppSegmentedTabs(
            labels: ['Da pianificare ($open)', 'In calendario ($planned)'],
            selectedIndex: _compactView.index,
            onSelected: (selected) => setState(() => _compactView = CalendarCompactView.values[selected]),
            height: 40,
            fontSize: 13,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: PageTransitionItem(
            slot: PageTransitionItem.list + 1,
            child: switch (_compactView)
            {
              CalendarCompactView.toPlan => _buildPanel(shape: BookingPanelShape.page, index: index),
              CalendarCompactView.planned => _buildAgendaArea(lanes, index),
            },
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          Center(child: PageTransitionItem(slot: PageTransitionItem.list + 2, child: action)),
        ],
      ],
    );
  }

  Widget _buildBody(List<CalendarLane> lanes, CalendarDayIndex index, _CalendarShape shape)
  {
    if (_isSettled && shape != _CalendarShape.compact)
    {
      return _buildTimelineColumn(lanes, index, slot: PageTransitionItem.list);
    }

    return switch (shape)
    {
      _CalendarShape.sideBySide => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildTimelineColumn(lanes, index, slot: PageTransitionItem.list)),
            const SizedBox(width: _panelGap),
            SizedBox(
              width: kBookingPanelWidth,
              child: PageTransitionItem(
                slot: PageTransitionItem.list + 2,
                child: _buildPanel(shape: BookingPanelShape.column, index: index),
              ),
            ),
          ],
        ),
      _CalendarShape.stacked => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageTransitionItem(
              slot: PageTransitionItem.list,
              child: _buildPanel(shape: BookingPanelShape.strip, index: index),
            ),
            const SizedBox(height: 24),
            Expanded(child: _buildTimelineColumn(lanes, index, slot: PageTransitionItem.list + 1)),
          ],
        ),
      _CalendarShape.compact => _buildCompactBody(lanes, index),
    };
  }

  Widget _buildHeader(Widget dayNav, {Widget? summary, Widget? filters})
  {
    return PageTransitionItem(
      slot: PageTransitionItem.header,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildBandPicker(),
              dayNav,
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 14),
            summary,
          ],
          if (filters != null) ...[
            const SizedBox(height: 16),
            filters,
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPage(_CalendarShape shape, bool navFits)
  {
    final Widget dayNav = navFits ? _buildDayNav() : _buildNarrowDayNav();

    if (_isFetchingDay)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(dayNav),
          const Expanded(
            child: PageTransitionItem(
              slot: PageTransitionItem.list,
              child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
            ),
          ),
        ],
      );
    }

    if (_isDayClosed)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTransitionItem(
            slot: PageTransitionItem.header,
            child: Align(alignment: Alignment.centerRight, child: dayNav),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LessonsClosedDay(message: _closureNote),
          ),
        ],
      );
    }

    final teacherLanes = _lanes;
    final lanes = _rowsFor(teacherLanes);
    final index = _buildIndex(teacherLanes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          dayNav,
          summary: _buildSummary(lanes),
          filters: _isSettled ? _buildFilters(isNarrow: shape == _CalendarShape.compact) : null,
        ),
        Expanded(child: _buildBody(lanes, index, shape)),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final shape = _shapeFor(constraints.maxWidth);

        final navFits = constraints.maxWidth >= kCalendarDayNavMin;

        return _buildPage(shape, navFits);
      },
    );
  }
}
