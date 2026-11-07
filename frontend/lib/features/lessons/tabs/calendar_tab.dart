import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_floating_panel.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/opening_day_item.dart';
import '../../association/models/room_item.dart';
import '../../association/models/study_program_item.dart';
import '../../calendar/utils/calendar_strings.dart';
import '../../people/models/person_face.dart';
import '../../people/models/person_item.dart';
import '../models/activity_item.dart';
import '../models/availability_item.dart';
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/calendar_lock_item.dart';
import '../models/calendar_publication_item.dart';
import '../models/lesson_item.dart';
import '../models/presence_item.dart';
import '../models/room_day_plan.dart';
import '../models/schedulable_booking.dart';
import '../export/calendar_pdf_export.dart';
import '../utils/calendar_search.dart';
import '../utils/excluded_teachers.dart';
import '../utils/lesson_placement.dart';
import '../utils/online_only.dart';
import '../utils/new_members.dart';
import '../utils/opening_window.dart';
import '../utils/study_program_lookup.dart';
import '../utils/timeline_geometry.dart';
import '../widgets/activity_dialog.dart';
import '../widgets/activity_details_dialog.dart';
import '../widgets/calendar_activity_block.dart';
import '../widgets/calendar_booking_panel.dart';
import '../widgets/calendar_day_agenda.dart';
import '../widgets/calendar_lesson_block.dart';
import '../widgets/calendar_lesson_board.dart';
import '../widgets/calendar_publish_dialogs.dart';
import '../widgets/calendar_request_details.dart';
import '../widgets/calendar_timeline.dart';
import '../widgets/lesson_captions.dart';
import '../widgets/lesson_details_dialog.dart';
import '../widgets/lesson_plan_wizard.dart';
import '../widgets/lessons_closed_day.dart';
import '../widgets/room_assignment_wizard.dart';

// Under this width the half-hour blocks are slivers: the agenda takes over.
const double kCalendarTimelineMin = 900;

enum _CalendarShape
{
  // The track across the page, the requests floating over it.
  timeline,

  compact,
}

_CalendarShape _shapeFor(double width) => width >= kCalendarTimelineMin ? _CalendarShape.timeline : _CalendarShape.compact;

// The requests start along the right edge, full height; the cards need the narrower width.
const double _panelWidth = 360;
const double _densePanelWidth = 340;

// Docked at the top or the bottom: one whole request and the top of the next row; never less than the request alone.
const double _panelDockHeight = 300;
const double _panelLeastHeight = 260;

// Tests that move or dock the requests put them back for the next test.
@visibleForTesting
void debugForgetCalendarPanelPlace() => _CalendarTabState._panelPlace = null;

enum CalendarCompactView
{
  toPlan,
  planned,
}

const String _kDraftPillTooltip = 'Le modifiche saranno inviate una volta confermate.';

const String _kDraftDiscarded = 'Modifiche annullate.';

const String kLockedBandNotice =
    'Puoi seguire il lavoro mentre procede, ma non modificarlo. Quando avrà '
    'finito, il calendario tornerà disponibile.';

// Shown when discard cannot restore hours: availability withdrawn or request cancelled meanwhile.
const String _kDraftRestoreFailed = 'Errore durante il ripristino del calendario.';

// The actions sit in the header, as tall as its other controls.
const double _actionButtonHeight = 44;
const double _actionButtonFontSize = 13.5;

const double _denseActionHeight = 36;
const double _denseActionFontSize = 12.5;
const double _denseActionPadding = 14;
const double _denseSearchWidth = 300;
const double _composingSearchWidth = 360;

// Narrower than this, the search takes the whole line.
const double _denseSearchAlone = 560;

const double _lockNoticeMaxWidth = 576;

// The band's actions, the way back to composing and the way out on paper weigh the same.
const double _publishedActionWidth = 280;

const double _settingMenuWidth = 210;

const double _filterGap = 12;

const double _searchWidth = 560;

const double _filtersOneRowMin = 900;

const double _pillLabelMaxWidth = double.infinity;

class CalendarTab extends StatefulWidget
{
  // Chosen outside the calendar: it shows one band of one day.
  final DateTime day;
  final TimeBucket band;

  // The page's back button and title, first on the header's line.
  final Widget? leading;

  // Where the title in [leading] starts: the summary under it lines up with it.
  final double leadingIndent;

  final List<LessonItem> lessons;

  final List<ActivityItem> activities;

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
    bool waiveCompetence,
  })? onCreateLesson;

  final Future<LessonItem?> Function({
    required LessonItem existing,
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Function(String) onError,
    bool waiveCompetence,
  })? onUpdateLesson;

  final Future<bool> Function(int id, Function(String) onError)? onDeleteLesson;

  final Future<bool> Function({
    required DateTime day,
    required TimeBucket band,
    required String name,
    required String? description,
    required Function(String) onError,
  })? onCreateActivity;

  final Future<bool> Function({
    required ActivityItem existing,
    required String name,
    required String? description,
    required int? availabilityId,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required Function(String) onError,
  })? onUpdateActivity;

  final Future<bool> Function(int id, Function(String) onError)? onDeleteActivity;

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
    bool waiveCompetence,
  })? onSplitLesson;

  final List<CalendarPublicationItem> publications;

  // Only ever set for the band currently on screen.
  final CalendarLockItem? lock;

  final bool isReadOnly;

  final void Function({required DateTime day, required TimeBucket band})? onViewChanged;

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

  // Returns how many hours could not be restored, or null if the server refused.
  final Future<int?> Function({
    required DateTime day,
    required TimeBucket band,
    required Function(String) onError,
  })? onDiscardDraft;

  final DateTime? today;

  final List<RoomItem> rooms;

  final Future<RoomDayPlan?> Function(
    DateTime day,
    Function(String) onError,
  )? onLoadRoomPlan;

  final Future<bool> Function({
    required DateTime day,
    required PlannedRooms rooms,
    required List<PlannedShift> shifts,
    required Function(String) onError,
  })? onSaveRoomPlan;

  final Set<String> excludedTeachers;

  final Future<HandedBack?> Function({
    required DateTime day,
    required TimeBucket band,
    required String teacherTaxCode,
    required Function(String) onError,
  })? onExcludeTeacher;

  final Future<bool> Function({
    required DateTime day,
    required TimeBucket band,
    required String teacherTaxCode,
    required Function(String) onError,
  })? onReadmitTeacher;

  const CalendarTab({
    super.key,
    required this.day,
    required this.band,
    this.leading,
    this.leadingIndent = 0,
    required this.lessons,
    this.activities = const [],
    required this.availabilities,
    required this.presences,
    required this.openingDays,
    required this.ministrySubjects,
    required this.people,
    required this.associationSubjects,
    this.studyPrograms = const [],
    this.rooms = const [],
    this.publications = const [],
    this.lock,
    this.isReadOnly = false,
    this.onViewChanged,
    this.onPublishBand,
    this.onReopenBand,
    this.onCloseDraft,
    this.onDiscardDraft,
    this.onCreateLesson,
    this.onUpdateLesson,
    this.onDeleteLesson,
    this.onSplitLesson,
    this.onCreateActivity,
    this.onUpdateActivity,
    this.onDeleteActivity,
    this.onLoadRoomPlan,
    this.onSaveRoomPlan,
    this.excludedTeachers = const {},
    this.onExcludeTeacher,
    this.onReadmitTeacher,
    this.today,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab>
{
  DateTime get _day => widget.day;

  late TimeBucket _band = widget.band;

  // Exclusions the admin is waiting on: they move the rows, while exclusions read back redraw them.
  int _excluding = 0;

  int _redraws = 0;

  CalendarView _view = CalendarView.byTeacher;

  // Lights what it finds and narrows nothing, composing and published alike.
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<CalendarSearch?> _search = ValueNotifier(null);

  CalendarSort _sort = CalendarSort.room;

  CalendarLayout _layout = CalendarLayout.byHour;

  CalendarCompactView _compactView = CalendarCompactView.toPlan;

  // Open on a band with requests to plan; it stays open across drags, fading away while one is under way.
  // A notifier: opening and closing must not rebuild the day, or the fade is spent on that frame.
  late final ValueNotifier<bool> _panelOpen = ValueNotifier(_hasWorkToPlan);

  // Where the requests were left, for every band until the page reloads.
  static AppFloatingPlace? _panelPlace;

  bool get _hasWorkToPlan => !_isSettled && openPanelCount(_bookingGroups, _unassignedActivities) > 0;

  final ScrollController _trackController = ScrollController();
  final ScrollController _sidewaysController = ScrollController();

  // The rows keep their state and offset when the sideways bar comes or goes around them.
  final GlobalKey _trackViewKey = GlobalKey();
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
      _sayWhichBand();
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
      _now = romeNow();
    }
  }

  void _tick()
  {
    if (!mounted)
    {
      return;
    }

    setState(() => _now = romeNow());
  }

  @override
  void didUpdateWidget(CalendarTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // A notification's band, asked while the page is open.
    if (widget.band != oldWidget.band)
    {
      _band = widget.band;
      _panelOpen.value = _hasWorkToPlan;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sayWhichBand());
    }

    // The rooms come again with every refresh of the lessons: another administrator may have
    // changed them since they were read.
    if (!identical(widget.lessons, oldWidget.lessons))
    {
      _ensureRoomPlan(force: true, quietly: _hasRoomPlan);
    }

    if (_excluding == 0 && !setEquals(widget.excludedTeachers, oldWidget.excludedTeachers))
    {
      _redraws++;
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
    _search.dispose();
    _trackController.dispose();
    _sidewaysController.dispose();
    _carried.dispose();
    _panelOpen.dispose();
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

  // Below the wide window, read at every build: the controls shrink.
  bool _isDense = false;

  // On the wide window the band's actions weigh the same; below it each is as wide as its words.
  double? get _actionWidth => _isDense ? null : _publishedActionWidth;

  double get _actionHeight => _isDense ? _denseActionHeight : _actionButtonHeight;

  double get _actionFontSize => _isDense ? _denseActionFontSize : _actionButtonFontSize;

  double get _actionPadding => _isDense ? _denseActionPadding : 22;

  RoomDayPlan? _roomPlan;
  String? _roomPlanDay;

  bool _isLoadingRoomPlan = false;

  bool _isPublishing = false;

  bool _isExporting = false;

  bool get _hasRoomPlan => _roomPlanDay == _keyOf(_day);

  late DateTime _now = widget.today ?? romeNow();

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

  // Published by teacher: lanes changing room in the band write the room on each lesson.
  Set<String> _lanesChangingRoom(List<CalendarLane> lanes)
  {
    if (!_isSettled || _view != CalendarView.byTeacher)
    {
      return const {};
    }

    return {
      for (final MapEntry(key: taxCode, value: label) in _roomLabelsFor(lanes).entries)
        if (label.changesRoom) taxCode,
    };
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

  // Lessons under way, each with the share of its hours gone by.
  Map<int, double> _elapsedLessons(List<CalendarLane> lanes)
  {
    final now = _nowMinutes;

    if (!_isSettled || now == null)
    {
      return const {};
    }

    return {
      for (final lane in lanes)
        for (final lesson in lane.lessons)
          if (isLessonRunning(lesson, _now)) lesson.id: (now - lesson.startMinutes) / lesson.minutes,
    };
  }

  static String _keyOf(DateTime day) => '${day.year}-${day.month}-${day.day}';

  void _sayWhichBand()
  {
    widget.onViewChanged?.call(day: _day, band: _band);
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
      activities: widget.activities,
    );
  }

  List<ActivityItem> get _activities
  {
    return widget.activities
        .where((activity) => isSameDate(activity.date, _day) && activity.band == _band)
        .toList();
  }

  List<ActivityItem> get _unassignedActivities
  {
    return _activities.where((activity) => !activity.isAssigned).toList();
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

  List<CalendarLane> _rowsFor(List<TeacherLane> lanes)
  {
    if (!_isSettled)
    {
      return _excludedLast(lanes);
    }

    if (_view == CalendarView.byStudent)
    {
      return _ordered(_studentLanes);
    }

    final called = convokedTeachers(lanes);

    if (_shownSort == CalendarSort.room)
    {
      return orderByRoom(lanes: called, rooms: _roomLabelsFor(called));
    }

    return _ordered(called);
  }

  // Excluded teachers stay visible, moved to the bottom in their original order.
  List<CalendarLane> _excludedLast(List<TeacherLane> lanes)
  {
    final excluded = widget.excludedTeachers;

    if (excluded.isEmpty)
    {
      return lanes;
    }

    return [
      for (final lane in lanes) if (!excluded.contains(lane.teacherTaxCode)) lane,
      for (final lane in lanes) if (excluded.contains(lane.teacherTaxCode)) lane,
    ];
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
      excludedTeachers: widget.excludedTeachers,
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

  void Function(LessonItem) _lessonTap(CalendarDayIndex index)
  {
    if (widget.isReadOnly)
    {
      return _openPublishedLesson;
    }

    return (lesson) => _openLesson(lesson, index);
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

  LessonPlacement _plan(
    CalendarDayIndex index,
    CalendarDragPayload payload,
    String teacherTaxCode,
    int startMinutes,
    (int, int) window,
  )
  {
    return switch (payload)
    {
      BookingDragPayload() => planDrop(index, payload, teacherTaxCode, startMinutes, within: window),
      LessonDragPayload(:final lesson) => _planLessonDrop(index, lesson, teacherTaxCode, startMinutes, window),
      ActivityDragPayload() => planActivityDrop(index, payload, teacherTaxCode, startMinutes, within: window),
    };
  }

  LessonPlacement _planLessonDrop(
    CalendarDayIndex index,
    LessonItem lesson,
    String teacherTaxCode,
    int startMinutes,
    (int, int) window,
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

    return planMove(index, lesson, teacherTaxCode, startMinutes, within: window);
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
        : CarriedRequest(
            payload: payload,
            competentTeachers: teachersWhoCouldTeach(index, payload),
            windows: dragWindows(index, payload),
          );

    if (payload == null)
    {
      _carriedAt.value = CarriedPlacement.idle;

      // Back after the drop while requests are left; with none, it stays shut.
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted && openPanelCount(_bookingGroups, _unassignedActivities) == 0)
        {
          _panelOpen.value = false;
        }
      });
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

  Future<void> _applyDrop(
    CalendarDragPayload payload,
    LessonPlacement placement,
    CalendarDayIndex index,
  ) async
  {
    if (payload case ActivityDragPayload(:final activity))
    {
      await _giveActivity(
        activity,
        availabilityId: placement.availabilityId,
        startMinutes: placement.startMinutes,
        endMinutes: placement.endMinutes,
      );

      return;
    }

    if (placement.deleteLessonId != null)
    {
      await _executeMerge(placement);

      return;
    }

    // Checked before the write, against the board as it currently stands.
    final crowding = overlapsACertifiedStudent(index, placement)
        ? const [kCertifiedOverlapWarning]
        : const <String>[];

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
        waiveCompetence: placement.waivesCompetence,
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

      // A move squeezed against an end of the timeline shortens it as a resize does.
      if (remainder == null &&
          (placement.kind == LessonPlacementKind.resize || placement.kind == LessonPlacementKind.move) &&
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
          waiveCompetence: placement.waivesCompetence,
        );

        if (!mounted || written == null)
        {
          return;
        }

        _reportWarnings(written, also: crowding);

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
        waiveCompetence: placement.waivesCompetence,
      );
    }

    if (!mounted || written == null)
    {
      return;
    }

    _reportWarnings(written, also: crowding);
  }

  // [also] holds client-side warnings; the rest come from the server.
  void _reportWarnings(LessonItem written, {List<String> also = const []})
  {
    final said = <String>{...also, ...written.warnings};

    if (said.isEmpty)
    {
      return;
    }

    CustomSnackBar.show(
      context: context,
      message: said.length == 1 ? said.single : 'Lezione salvata.',
      tone: SnackBarTone.warning,
    );
  }

  Future<bool> _writeActivity({
    required ActivityItem existing,
    required String name,
    required String? description,
    required int? availabilityId,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required Function(String) onError,
  }) async
  {
    final write = widget.onUpdateActivity;

    if (write == null)
    {
      return false;
    }

    return write(
      existing: existing,
      name: name,
      description: description,
      availabilityId: availabilityId,
      startTime: startTime,
      endTime: endTime,
      onError: onError,
    );
  }

  Future<void> _giveActivity(
    ActivityItem activity, {
    required int? availabilityId,
    required int startMinutes,
    required int endMinutes,
  }) async
  {
    if (availabilityId == null)
    {
      return;
    }

    await _writeActivity(
      existing: activity,
      name: activity.name,
      description: activity.description,
      availabilityId: availabilityId,
      startTime: timeOfDayFromMinutes(startMinutes),
      endTime: timeOfDayFromMinutes(endMinutes),
      onError: _reportRefusal,
    );
  }

  // Unassigning returns the hours but keeps the activity on the calendar.
  Future<void> _takeActivityBack(ActivityItem activity) async
  {
    if (activity.isLocked)
    {
      return;
    }

    final taken = await _writeActivity(
      existing: activity,
      name: activity.name,
      description: activity.description,
      availabilityId: null,
      startTime: null,
      endTime: null,
      onError: _reportRefusal,
    );

    if (taken && mounted)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Attività da assegnare.',
        isError: false,
      );
    }
  }

  Future<void> _openActivity(ActivityItem activity, CalendarDayIndex index) async
  {
    await showActivityDialog(
      context: context,
      index: index,
      activity: activity,
      onSave: widget.isReadOnly ? null : _writeActivity,
      onDelete: widget.isReadOnly || widget.onDeleteActivity == null
          ? null
          : (row, onError) => widget.onDeleteActivity!(row.id, onError),
    );
  }

  // Published activities only show name and description; editing belongs to the draft.
  Future<void> _openPublishedActivity(ActivityItem activity) async
  {
    await showActivityDetailsDialog(context: context, activity: activity);
  }

  void Function(ActivityItem) _activityTap(CalendarDayIndex index)
  {
    if (widget.isReadOnly || _isSettled)
    {
      return _openPublishedActivity;
    }

    return (activity) => _openActivity(activity, index);
  }

  Future<void> _addActivity(CalendarDayIndex index) async
  {
    final create = widget.onCreateActivity;

    if (create == null)
    {
      return;
    }

    final day = _day;
    final band = _band;

    await showActivityDialog(
      context: context,
      index: index,
      onCreate: ({required name, required description, required onError}) => create(
        day: day,
        band: band,
        name: name,
        description: description,
        onError: onError,
      ),
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

  void _reportCarriedRefusal(String refusal, {VoidCallback? insertAnyway})
  {
    final button = insertAnyway == null
        ? null
        : SnackBarButton(
            label: 'Inserisci comunque',
            onPressed: ()
            {
              if (mounted)
              {
                insertAnyway();
              }
            },
          );

    if (_carriedRefusal == refusal && CustomSnackBar.keepShowing(button: button))
    {
      _carriedRefusal = null;

      return;
    }

    _carriedRefusal = null;
    CustomSnackBar.show(context: context, message: refusal, isError: true, button: button);
  }

  Future<void> _planBooking(SchedulableBooking entry, CalendarDayIndex index) async
  {
    if (entry.parts.isEmpty && !canPlanSomething(index, entry))
    {
      _reportRefusal(noTeacherReason(index, entry, entry.requestedDisciplineIds));

      return;
    }

    await showLessonPlanWizard(
      context: context,
      entry: entry,
      index: index,
      ministrySubjects: widget.ministrySubjects,
      onCreate: widget.onCreateLesson,
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
      waiveCompetence: placement.waivesCompetence,
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

  Widget _buildSummary(List<CalendarLane> lanes)
  {
    final lessons = {
      for (final lane in lanes)
        for (final lesson in lane.lessons) lesson.id: lesson,
    }.values;

    // From the band, not the rows: by-student rows are pupils, yet activities convoke teachers.
    final given = [
      for (final activity in _activities)
        if (activity.placement != null) activity.placement!,
    ];

    final called = {
      ...lessons.map((lesson) => lesson.teacherTaxCode),
      ...given.map((placement) => placement.teacherTaxCode),
    };

    final pupils = lessons.expand((lesson) => lesson.studentTaxCodes).toSet();

    final parts = [
      _count(called.length, 'docente convocato', 'docenti convocati'),
      _count(pupils.length, 'studente', 'studenti'),
      _count(lessons.length, 'lezione', 'lezioni'),
      if (given.isNotEmpty) _count(given.length, 'attività', 'attività'),
    ];

    final Widget counts = Text(
      parts.join(' · '),
      maxLines: _isDense ? 1 : null,
      overflow: _isDense ? TextOverflow.ellipsis : null,
      style: GoogleFonts.plusJakartaSans(
        fontSize: _isDense ? 13.5 : 15,
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

    final Widget search = _buildSearchField();

    return LayoutBuilder(
      builder: (context, constraints)
      {
        // Below the wide window: the search no wider than it needs, the pills beside it while they fit.
        if (_isDense)
        {
          final double width = constraints.maxWidth < _denseSearchAlone ? constraints.maxWidth : _denseSearchWidth;

          return Wrap(
            spacing: _filterGap,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: width, child: search),
              ...pills,
            ],
          );
        }

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

    return AppTooltip(
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

    return _view == CalendarView.byStudent
        ? 'Nessuno studente in calendario'
        : 'Nessun docente convocato';
  }

  Widget _buildClosedBand()
  {
    return const Center(child: AppEmptyCard(icon: Icons.event_busy_rounded, message: kAssociationClosedTitle));
  }

  Widget _buildEmptyBand({required String message})
  {
    return Center(child: AppEmptyCard(icon: Icons.person_off_outlined, message: message));
  }

  ({Map<int, int> subLaneOf, List<double> rowHeights, List<int> laneCounts}) _stackLanes(List<CalendarLane> lanes)
  {
    final subLaneOf = <int, int>{};
    final rowHeights = <double>[];
    final laneCounts = <int>[];

    for (final lane in lanes)
    {
      final stacking = lane.subLanesWith(_subLaneMemory);

      for (var index = 0; index < lane.lessons.length; index++)
      {
        subLaneOf[lane.lessons[index].id] = stacking.laneOf[index];
      }

      laneCounts.add(stacking.laneCount);
      rowHeights.add(
        timelineRowHeight(
          stacking.laneCount,
          _isSettled ? _view : CalendarView.byTeacher,
          composing: !_isSettled,
          dense: _isDense,
        ),
      );
    }

    _subLaneMemory
      ..clear()
      ..addAll(subLaneOf);

    _shrunkFrom.removeWhere((id, _) => !subLaneOf.containsKey(id));

    return (subLaneOf: subLaneOf, rowHeights: rowHeights, laneCounts: laneCounts);
  }

  // Published: each row's blocks as tall as the one whose long lines wrap the most.
  List<double> _blockHeightsFor(List<CalendarLane> lanes, TimelineMetrics metrics)
  {
    final moving = _lanesChangingRoom(lanes);

    return [
      for (final lane in lanes)
        lane.lessons.fold(
          lessonBlockHeight(_view, composing: false, dense: _isDense),
          (tallest, lesson) => math.max(
            tallest,
            publishedLessonBlockHeight(
              context,
              lesson,
              metrics.widthOf(lesson.startMinutes, lesson.endMinutes),
              view: _view,
              ministrySubjects: widget.ministrySubjects,
              showsRoom: moving.contains(lane.personTaxCode),
              dense: _isDense,
            ),
          ),
        ),
    ];
  }

  // Published: the scale gives each block the room to write its lines whole.
  TimelineMetrics _publishedMetrics(List<CalendarLane> lanes, (int, int) window, double trackWidth, List<double> rowHeights)
  {
    final marked = _markedLessons(lanes);
    final past = _pastLessons(lanes);
    final moving = _lanesChangingRoom(lanes);

    final scale = TimeScale.elastic(
      start: window.$1,
      end: window.$2,
      extent: trackWidth,
      minQuarter: kMinQuarterWidth,
      needs: [
        for (final lane in lanes) ...[
          for (final lesson in lane.lessons)
            (
              startMinutes: lesson.startMinutes,
              endMinutes: lesson.endMinutes,
              size: publishedLessonBlockWidth(
                context,
                lesson,
                view: _view,
                ministrySubjects: widget.ministrySubjects,
                past: past.contains(lesson.id),
                warned: marked.warned.contains(lesson.id),
                preferred: marked.preferred.contains(lesson.id),
                showsRoom: moving.contains(lane.personTaxCode),
                dense: _isDense,
              ),
            ),
          for (final activity in lane.activities)
            (
              startMinutes: activity.startMinutes,
              endMinutes: activity.endMinutes,
              size: activityBlockWidth(context, activity),
            ),
        ],
      ],
    );

    return TimelineMetrics.scaled(scale: scale, rowHeights: rowHeights);
  }

  // Composing: lessons whose block would cut its words write them on a line under the row.
  Map<String, Map<int, CaptionSpot>> _captionsFor(List<CalendarLane> lanes, TimelineMetrics metrics)
  {
    final marked = _markedLessons(lanes);

    return {
      for (final lane in lanes)
        lane.personTaxCode: placeLessonCaptions(
          [
            for (final lesson in lane.lessons)
              if (composingBlockCutsText(
                context,
                lesson,
                metrics.widthOf(lesson.startMinutes, lesson.endMinutes),
                ministrySubjects: widget.ministrySubjects,
                warned: marked.warned.contains(lesson.id),
                preferred: marked.preferred.contains(lesson.id),
              ))
                lesson,
          ],
          xOf: metrics.xOf,
          trackWidth: metrics.trackWidth,
          widthOf: (lesson) => lessonCaptionWidth(context, lesson, widget.ministrySubjects),
          linesOf: (lesson, width) => lessonCaptionLines(context, lesson, widget.ministrySubjects, width),
        ),
    };
  }

  // Composing: each row's blocks as tall as the one whose words wrap the most; captioned ones keep the usual.
  List<double> _composingBlockHeights(
    List<CalendarLane> lanes,
    TimelineMetrics metrics,
    Map<String, Map<int, CaptionSpot>> captions,
  )
  {
    return [
      for (final lane in lanes)
        lane.lessons.fold(
          kTeacherBlockHeight,
          (tallest, lesson) => captions[lane.personTaxCode]?.containsKey(lesson.id) ?? false
              ? tallest
              : math.max(
                  tallest,
                  composingLessonBlockHeight(
                    context,
                    lesson,
                    metrics.widthOf(lesson.startMinutes, lesson.endMinutes),
                    ministrySubjects: widget.ministrySubjects,
                  ),
                ),
        ),
    ];
  }

  CalendarTimeline _buildTrack(List<CalendarLane> lanes, CalendarDayIndex index, (int, int) window, double width)
  {
    final trackWidth = width - timelineLeadingWidth(context);
    final stacking = _stackLanes(lanes);
    final marked = _markedLessons(lanes);
    final rowHeights = stacking.rowHeights;

    var metrics = TimelineMetrics(
      windowStartMinutes: window.$1,
      windowEndMinutes: window.$2,
      trackWidth: trackWidth,
      rowHeights: rowHeights,
    );

    List<double>? blockHeights;

    if (_isSettled)
    {
      metrics = _publishedMetrics(lanes, window, trackWidth, rowHeights);

      final heights = blockHeights = _blockHeightsFor(lanes, metrics);

      // Only the published headers list the rooms, so only they may need the taller row.
      final rooms = _roomLabelsFor(lanes);

      metrics = metrics.withRowHeights([
        for (var i = 0; i < lanes.length; i++)
          math.max(
            timelineRowHeightOf(stacking.laneCounts[i], heights[i]),
            laneHeaderMinHeight(
              context,
              lanes[i],
              rooms[lanes[i].personTaxCode],
              bandStart: _bandStart,
              bandEnd: _bandEnd,
              view: _view,
            ),
          ),
      ]);
    }
    else if (metrics.pixelsPerMinute < kMinPixelsPerMinute)
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

    final captions = _isSettled ? const <String, Map<int, CaptionSpot>>{} : _captionsFor(lanes, metrics);

    if (!_isSettled)
    {
      final heights = blockHeights = _composingBlockHeights(lanes, metrics, captions);

      // A long name wraps whole: its row grows rather than cut it.
      metrics = metrics.withRowHeights([
        for (var i = 0; i < lanes.length; i++)
          math.max(
            timelineRowHeightOf(stacking.laneCounts[i], heights[i]) +
                captionsExtent(captionLinesOf(captions[lanes[i].personTaxCode])),
            laneHeaderMinHeight(context, lanes[i], null, bandStart: _bandStart, bandEnd: _bandEnd, view: _view),
          ),
      ]);
    }

    final now = _nowMinutes;
    final showsNow = now != null && now >= metrics.windowStartMinutes && now <= metrics.windowEndMinutes;

    // Another day, band or reading of it is drawn afresh: its rows never travel from where the old one had them.
    final drawing = ValueKey((_day, _band, _redraws, _isSettled));

    if (_isSettled)
    {
      return CalendarTimeline(
        key: drawing,
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
        elapsedLessons: _elapsedLessons(lanes),
        blockHeights: blockHeights,
        roomByTeacher: _roomLabelsFor(lanes),
        nowMinutes: showsNow ? now : null,
        onLessonTap: _openPublishedLesson,
        onActivityTap: _openPublishedActivity,
        search: _search,
        scrollController: _trackController,
        sidewaysController: _sidewaysController,
        viewportKey: _viewportKey,
      );
    }

    return CalendarTimeline(
      key: drawing,
      lanes: lanes,
      metrics: metrics,
      bandStart: _bandStart,
      bandEnd: _bandEnd,
      isComposing: true,
      search: _search,
      ministrySubjects: widget.ministrySubjects,
      subLaneOf: stacking.subLaneOf,
      warnedLessonIds: marked.warned,
      preferredLessonIds: marked.preferred,
      onLessonTap: _lessonTap(index),
      onActivityTap: _activityTap(index),
      onPlan: widget.isReadOnly
          ? null
          : (payload, teacherTaxCode, startMinutes, window) =>
              _plan(index, payload, teacherTaxCode, startMinutes, window),
      onPlanResize: (lesson, startMinutes, endMinutes) => planResizeWithin(index, lesson, startMinutes, endMinutes),
      onPlanActivityResize: (scheduled, startMinutes, endMinutes) =>
          planActivityResize(index, scheduled, startMinutes, endMinutes),
      onDrop: (payload, placement) => _applyDrop(payload, placement, index),
      onRefused: _reportCarriedRefusal,
      carried: _carried,
      carriedAt: _carriedAt,
      onDroppedOutside: widget.isReadOnly ? null : _removeLesson,
      onActivityDroppedOutside: widget.isReadOnly ? null : _takeActivityBack,
      onDragChanged: widget.isReadOnly ? null : (payload) => _carry(payload, index),
      excludedTeachers: widget.excludedTeachers,
      onExcludedChanged: widget.isReadOnly || widget.onExcludeTeacher == null ? null : _setExcluded,
      scrollController: _trackController,
      sidewaysController: _sidewaysController,
      lessonDetails: _lessonDetails,
      viewportKey: _viewportKey,
      blockHeights: blockHeights,
      captions: captions,
    );
  }

  List<PresenceBookingGroup> get _bookingGroups
  {
    return [
      for (final group in groupSchedulable(presences: widget.presences, lessons: widget.lessons, day: _day))
        if (group.touches(_bandStart, _bandEnd)) group.within(_bandStart, _bandEnd),
    ];
  }

  Widget? _buildBandNotice(List<CalendarLane> lanes)
  {
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
      elapsedLessons: _elapsedLessons(lanes),
      roomByTeacher: _roomLabelsFor(lanes),
      onLessonTap: _openPublishedLesson,
      onActivityTap: _openPublishedActivity,
      search: _search,
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

    // Widths are measured: rebuilt once the fonts arrive.
    return ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) => LayoutBuilder(
        key: _viewportKey,
        builder: (context, constraints)
        {
          final timeline = _buildTrack(lanes, index, window, constraints.maxWidth);
          final media = MediaQuery.of(context);

          final Widget view = KeyedSubtree(
            key: _trackViewKey,
            child: Scrollbar(
              controller: _trackController,
              child: ScrollEdgeFade(
                child: SingleChildScrollView(
                  controller: _trackController,
                  child: timeline,
                ),
              ),
            ),
          );

          // Only while there is something to scroll: a bar left without a position wakes under the pointer.
          if (!timelineScrollsSideways(context, timeline.metrics, constraints.maxWidth))
          {
            return view;
          }

          // The sideways bar runs along the bottom of the view, past the names, rather than
          // under the last row; Scrollbar takes its insets from MediaQuery, given back inside.
          return MediaQuery(
            data: media.copyWith(padding: EdgeInsets.only(left: timelineLeadingWidth(context))),
            child: Scrollbar(
              controller: _sidewaysController,
              thumbVisibility: true,
              notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
              child: MediaQuery(data: media, child: view),
            ),
          );
        },
      ),
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

    inBuilding.sort((a, b) => compareByName(a.teacher, b.teacher));

    return inBuilding;
  }

  // The load in flight, for whoever needs the rooms to wait for them.
  Future<void>? _roomPlanLoad;

  // [quietly]: a refresh behind the page, without the busy button or an error to show.
  Future<void> _ensureRoomPlan({bool force = false, bool quietly = false})
  {
    final pending = _roomPlanLoad;

    if (pending != null)
    {
      return pending;
    }

    final load = widget.onLoadRoomPlan;

    if (load == null || (!force && _hasRoomPlan) || _dayLanesInBuilding().isEmpty)
    {
      return Future.value();
    }

    return _roomPlanLoad = _loadRoomPlan(load, quietly: quietly).whenComplete(() => _roomPlanLoad = null);
  }

  Future<void> _loadRoomPlan(
    Future<RoomDayPlan?> Function(DateTime day, Function(String) onError) load, {
    required bool quietly,
  }) async
  {
    final day = _day;

    if (!quietly)
    {
      setState(() => _isLoadingRoomPlan = true);
    }

    final plan = await load(day, (message)
    {
      if (mounted && !quietly)
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

  // Excluding: the teacher's hours become unplanned requests, activities unassigned; unconfirmed.
  // Released after the next frame: the answer's rebuild comes after the await returns.
  Future<T> _awaitExclusion<T>(Future<T> answer) async
  {
    _excluding++;

    try
    {
      return await answer;
    }
    finally
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => _excluding--);
    }
  }

  Future<void> _setExcluded(CalendarLane lane, {required bool excluded}) async
  {
    final day = _day;
    final band = _band;
    final taxCode = lane.personTaxCode;

    if (!excluded)
    {
      final readmit = widget.onReadmitTeacher;

      if (readmit != null)
      {
        await _awaitExclusion(readmit(day: day, band: band, teacherTaxCode: taxCode, onError: _reportRefusal));
      }

      return;
    }

    final exclude = widget.onExcludeTeacher;

    if (exclude == null)
    {
      return;
    }

    final back = await _awaitExclusion(exclude(
      day: day,
      band: band,
      teacherTaxCode: taxCode,
      onError: _reportRefusal,
    ));

    if (!mounted || back == null || back.lessons + back.activities == 0)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: handedBackSentence(back));
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

  // Teachers with hours but no lesson, who joined under two weeks before the day being published.
  List<String> _uncalledNewTeachers()
  {
    return uncalledNewTeacherWarnings(
      lanes: _lanes,
      people: widget.people,
      day: _day,
    );
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

    final confirmed = await showPublishConfirmation(
      context: context,
      warnings: _uncalledNewTeachers(),
      onlineOnly: onlineOnlyTeachers(_lanes),
    );

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
      message: warnings.isEmpty ? 'Calendario pubblicato!' : warnings.join(' · '),
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

  CalendarExportData _teachersExport()
  {
    return teachersExport(
      availabilities: widget.availabilities,
      lessons: widget.lessons,
      activities: widget.activities,
      ministrySubjects: widget.ministrySubjects,
      roomPlan: _hasRoomPlan ? _roomPlan : null,
      publication: _publication,
      day: _day,
      band: _band,
    );
  }

  CalendarExportData _studentsExport()
  {
    return studentsExport(
      presences: widget.presences,
      lessons: widget.lessons,
      ministrySubjects: widget.ministrySubjects,
      publication: _publication,
      day: _day,
      band: _band,
    );
  }

  Future<void> _exportPdf() async
  {
    if (_isExporting)
    {
      return;
    }

    // Opened before any await: a tab opened later is a popup the browser blocks.
    final tabs = openCalendarPdfTabs(teachers: _teachersExport(), students: _studentsExport());

    if (tabs.isEmpty)
    {
      _reportRefusal('Il browser ha bloccato le nuove schede: consenti i popup '
          'per questo sito e riprova.');

      return;
    }

    setState(() => _isExporting = true);

    try
    {
      // The rooms as they are now, not as they were read: the document waits for them.
      await _ensureRoomPlan(force: true);

      await writeCalendarPdfs(
        teachers: _teachersExport(),
        students: _studentsExport(),
        tabs: tabs,
      );
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

    final confirmed = await showPublishChangesConfirmation(
      context: context,
      warnings: _uncalledNewTeachers(),
      onlineOnly: onlineOnlyTeachers(_lanes),
    );

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

  // Rendered in place of the action buttons.
  Widget _buildLockNotice(CalendarLockItem lock)
  {
    return Container(
      constraints: const BoxConstraints(maxWidth: _lockNoticeMaxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock_rounded, size: 20, color: AppTheme.modifiedAccent),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lockedSentence(lock),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kLockedBandNotice,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: AppTheme.trialInk.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBandAction()
  {
    final lock = widget.lock;

    if (widget.isReadOnly && lock != null)
    {
      return _buildLockNotice(lock);
    }

    if (_isDraft)
    {
      final changed = _publication?.hasChanges ?? false;

      final rooms = openBookingCount(_bookingGroups) == 0 && teachersInBuilding(_lanes).isNotEmpty;

      return Wrap(
        alignment: WrapAlignment.center,
        spacing: _isDense ? 8 : 14,
        runSpacing: _isDense ? 8 : 12,
        children: [
          AppGradientButton(
            label: 'ESCI DALLA BOZZA',
            icon: Icons.undo_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            busy: _isPublishing,
            width: _actionWidth,
            height: _actionHeight,
            fontSize: _actionFontSize,
            horizontalPadding: _actionPadding,
            onPressed: _discardDraft,
          ),
          if (rooms) _buildRoomsButton(),
          if (changed)
            AppGradientButton(
              label: 'PUBBLICA MODIFICHE',
              icon: Icons.send_rounded,
              busy: _isPublishing,
              width: _actionWidth,
              height: _actionHeight,
              fontSize: _actionFontSize,
              horizontalPadding: _actionPadding,
              onPressed: _closeDraft,
            ),
        ],
      );
    }

    if (_isPublished)
    {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: _isDense ? 8 : 14,
        runSpacing: _isDense ? 8 : 12,
        children: [
          AppGradientButton(
            label: 'MODIFICA CALENDARIO',
            icon: Icons.edit_outlined,
            busy: _isPublishing,
            width: _isDense ? null : _publishedActionWidth,
            height: _actionHeight,
            fontSize: _actionFontSize,
            horizontalPadding: _actionPadding,
            onPressed: _returnToDraft,
          ),
          AppGradientButton(
            label: 'ESPORTA PDF',
            icon: Icons.picture_as_pdf_outlined,
            busy: _isExporting,
            iconOnlyTooltip: _isDense ? 'Esporta PDF' : null,
            width: _isDense ? _actionHeight : _publishedActionWidth,
            height: _actionHeight,
            fontSize: _actionFontSize,
            horizontalPadding: _actionPadding,
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
        width: _actionWidth,
        height: _actionHeight,
        fontSize: _actionFontSize,
        horizontalPadding: _actionPadding,
        onPressed: _publish,
      );
    }

    final plan = _roomPlan;

    final settled = _hasRoomPlan &&
        isRoomPlanSettled(
          lanes: _dayLanesInBuilding(),
          assignments: plan!.assignments,
          supervisions: plan.supervisions,
        );

    final rooms = _buildRoomsButton();

    if (!settled)
    {
      return rooms;
    }

    return Wrap(
      spacing: _isDense ? 8 : 14,
      runSpacing: _isDense ? 8 : 12,
      alignment: WrapAlignment.center,
      children: [
        rooms,
        AppGradientButton(
          label: 'PUBBLICA CALENDARIO',
          icon: Icons.send_rounded,
          busy: _isPublishing,
          disabledReason: _tooEarlyReason,
          width: _actionWidth,
          height: _actionHeight,
          fontSize: _actionFontSize,
          horizontalPadding: _actionPadding,
          onPressed: _publish,
        ),
      ],
    );
  }

  Widget _buildRoomsButton()
  {
    final plan = _roomPlan;

    return AppGradientButton(
      label: _hasRoomPlan && plan!.assignments.isNotEmpty ? 'MODIFICA STANZE' : 'ASSEGNA STANZE',
      icon: Icons.meeting_room_outlined,
      busy: _isLoadingRoomPlan,
      width: _actionWidth,
      height: _actionHeight,
      fontSize: _actionFontSize,
      horizontalPadding: _actionPadding,
      onPressed: _openRoomAssignment,
    );
  }

  // The buttons are in the header: only a lock notice stays under the day.
  Widget? _buildBodyAction()
  {
    final lock = widget.lock;

    return widget.isReadOnly && lock != null ? _buildLockNotice(lock) : null;
  }

  Widget? get _headerActions
  {
    if (widget.isReadOnly && widget.lock != null)
    {
      return null;
    }

    return _buildBandAction();
  }

  Widget _buildSearchField()
  {
    return AppSearchField(
      controller: _searchController,
      onChanged: (value) => _search.value = CalendarSearch.of(value, widget.ministrySubjects),
      hintText: 'Cerca nel calendario...',
    );
  }

  Widget _buildComposingSearch()
  {
    return SizedBox(
      width: _isDense ? _denseSearchWidth : _composingSearchWidth,
      child: _buildSearchField(),
    );
  }

  Widget _buildPlanButton()
  {
    final open = openPanelCount(_bookingGroups, _unassignedActivities);

    return ValueListenableBuilder<bool>(
      valueListenable: _panelOpen,
      builder: (context, shown, child) => AppGradientButton(
        label: 'DA PIANIFICARE',
        icon: Icons.pending_actions_rounded,
        badge: '$open',
        selected: shown,
        height: _actionHeight,
        fontSize: _actionFontSize,
        horizontalPadding: _actionPadding,
        radius: _actionHeight / 2,
        onPressed: () => _panelOpen.value = !shown,
      ),
    );
  }

  // Kept in the tree while away: a request carried out of it must keep its drag.
  Widget _buildFloatingPanel(CalendarDayIndex index, Widget timeline)
  {
    final double width = _isDense ? _densePanelWidth : _panelWidth;

    final Widget panel = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: _buildPanel(shape: BookingPanelShape.floating, index: index),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_carried, _panelOpen]),
      builder: (context, child) => AppFloatingPanel(
        place: _panelPlace ?? AppFloatingPlace(width: width, stripHeight: _panelDockHeight),
        least: const Size(_densePanelWidth, _panelLeastHeight),
        open: _panelOpen.value,
        carrying: _carried.value != null,
        onPlaceChanged: (place) => _panelPlace = place,
        behind: timeline,
        child: child!,
      ),
      child: panel,
    );
  }

  Widget _buildTimelineColumn(List<CalendarLane> lanes, CalendarDayIndex index, {required int slot})
  {
    final action = _buildBodyAction();

    final Widget area = PageTransitionItem(slot: slot, child: _buildTimelineArea(lanes, index));

    // Always the Column: re-parenting the GlobalKey'd track mid-drop breaks its LayoutBuilder.
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

  // From the programme of the latest enrollment: the enrollment itself carries only the level's label.
  Map<String, String> get _levelByStudent
  {
    final levelOf = {for (final programme in widget.studyPrograms) programme.id: programme.level};

    return {
      for (final person in widget.people) person.fiscalCode: ?levelOf[currentStudyProgramId(person)],
    };
  }

  Widget _buildPanel({required BookingPanelShape shape, required CalendarDayIndex index})
  {
    return CalendarBookingPanel(
      groups: orderBySchoolLevel(_bookingGroups, _levelByStudent),
      activities: _unassignedActivities,
      ministrySubjects: widget.ministrySubjects,
      teacherNames: _teacherNames,
      shape: shape,
      onClose: () => _panelOpen.value = false,
      onPlanRequested: index.lanes.isEmpty || widget.isReadOnly
          ? null
          : (entry) => _planBooking(entry, index),
      carriedAt: _carriedAt,
      onDragChanged: widget.isReadOnly ? null : (payload) => _carry(payload, index),
      onAddActivity: widget.isReadOnly || widget.onCreateActivity == null
          ? null
          : () => _addActivity(index),
      onOpenActivity: _activityTap(index),
      requestDetails: (entry) => _requestDetails(entry.booking, entry.presence.student.taxCode),
      search: _search,
    );
  }

  // What a card or a lesson opens on a long hover, the teachers named as the day page names them.
  // Built only once it opens.
  WidgetBuilder _requestDetails(BookingSummaryItem booking, String studentTaxCode)
  {
    return (context) => CalendarRequestDetails(
      booking: booking,
      student: widget.people.where((person) => person.fiscalCode == studentTaxCode).firstOrNull,
      ministrySubjects: widget.ministrySubjects,
      teacherNames: _teacherNames,
    );
  }

  WidgetBuilder? _lessonDetails(LessonItem lesson)
  {
    final link = lesson.bookings.firstOrNull;

    return link == null ? null : _requestDetails(link.booking, link.studentTaxCode);
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
      ministrySubjects: widget.ministrySubjects,
      warnedLessonIds: marked.warned,
      preferredLessonIds: marked.preferred,
      pastLessonIds: _pastLessons(lanes),
      elapsedLessons: _elapsedLessons(lanes),
      roomByTeacher: _isSettled ? _roomLabelsFor(lanes) : const {},
      excludedTeachers: _isSettled ? const {} : widget.excludedTeachers,
      onExcludedChanged: _isSettled || widget.isReadOnly || widget.onExcludeTeacher == null
          ? null
          : _setExcluded,
      onLessonTap: _isSettled ? _openPublishedLesson : _lessonTap(index),
      onActivityTap: _activityTap(index),
    );
  }

  Widget _buildCompactBody(List<CalendarLane> lanes, CalendarDayIndex index)
  {
    final notice = _buildBandNotice(lanes);

    if (notice != null)
    {
      return PageTransitionItem(slot: PageTransitionItem.list, child: notice);
    }

    final action = _buildBodyAction();

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

    final open = openPanelCount(_bookingGroups, _unassignedActivities);
    final planned = lanes.fold<int>(
      0,
      (total, lane) => total + lane.lessons.length + lane.activities.length,
    );

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
    if (shape == _CalendarShape.compact)
    {
      return _buildCompactBody(lanes, index);
    }

    final Widget timeline = _buildTimelineColumn(lanes, index, slot: PageTransitionItem.list);

    if (_isSettled)
    {
      return timeline;
    }

    return _buildFloatingPanel(index, timeline);
  }

  // The page at the start, the requests button and the actions at the end; the end wraps under when short.
  Widget _buildHeader(
    _CalendarShape shape, {
    Widget? summary,
    Widget? filters,
    Widget? actions,
    Widget? plan,
    Widget? search,
  })
  {
    final Widget? leading = widget.leading;

    final Widget line = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 10,
      children: [
        ?leading,
        if (search != null || plan != null || actions != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [?search, ?plan, ?actions],
          ),
      ],
    );

    return PageTransitionItem(
      slot: PageTransitionItem.header,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line,
          if (summary != null) ...[
            SizedBox(height: _isDense ? 10 : 14),
            Padding(
              padding: EdgeInsets.only(left: widget.leadingIndent),
              child: Align(alignment: Alignment.centerLeft, child: summary),
            ),
          ],
          if (filters != null) ...[
            SizedBox(height: _isDense ? 10 : 16),
            filters,
          ],
          SizedBox(height: _isDense ? 12 : 18),
        ],
      ),
    );
  }

  Widget _buildPage(_CalendarShape shape)
  {
    if (_isDayClosed)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(shape),
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
          shape,
          summary: _buildSummary(lanes),
          filters: _isSettled ? _buildFilters(isNarrow: shape == _CalendarShape.compact) : null,
          actions: _headerActions,
          plan: _isSettled || shape == _CalendarShape.compact || lanes.isEmpty ? null : _buildPlanButton(),
          search: _isSettled || shape == _CalendarShape.compact || lanes.isEmpty ? null : _buildComposingSearch(),
        ),
        Expanded(child: _buildBody(lanes, index, shape)),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    _isDense = AppBreakpoints.of(context).isDense;

    return LayoutBuilder(
      builder: (context, constraints) => _buildPage(_shapeFor(constraints.maxWidth)),
    );
  }
}
