import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_today_button.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
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
import '../models/lesson_item.dart';
import '../models/presence_item.dart';
import '../models/room_day_plan.dart';
import '../models/schedulable_booking.dart';
import '../models/teacher_room_assignment_item.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import '../widgets/calendar_booking_panel.dart';
import '../widgets/calendar_day_agenda.dart';
import '../widgets/calendar_lesson_block.dart';
import '../widgets/calendar_timeline.dart';
import '../widgets/lesson_plan_wizard.dart';
import '../widgets/lessons_closed_day.dart';
import '../widgets/room_assignment_wizard.dart';

// Where the calendar is composed: what the pupils asked for, over what the
// teachers offered. One day and one band at a time — the band is the unit the
// server publishes in, so the axis is exactly what can be written on.

// The panel of bookings stands beside the timeline where there is room for
// both, and above it where there is not. Measured on the tab's own constraint
// and not on the window: the rail on the left has already taken its width.
const double kCalendarSideBySideMin = 1040;

// Below this there is no track left to aim at, and the calendar gives it up for
// a list. Sized on the afternoon at kMinPixelsPerMinute plus the fixed
// kTimelineLeadingWidth, and deliberately not on the longer morning: the track
// already falls back to its own content where the axis is too dense, so taking
// it off a window that could still use it is the worse failure.
const double kCalendarTimelineMin = 620;

// Below this the day row cannot hold itself on one line: everything in it is a
// fixed width, and under this the Row overflows in stripes rather than
// ellipsising. Answered apart from the width above, or the row would change
// shape at a width where it still had room.
const double kCalendarDayNavMin = 440;

// The three shapes the calendar takes, in the order the width runs out.
enum _CalendarShape
{
  // The track with the panel standing beside it.
  sideBySide,

  // The panel above the track, the pupils running across it.
  stacked,

  // No track at all: the requests and the hours already planned, both as lists,
  // one at a time, and nothing that has to be carried anywhere.
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

// Which half of the day is on screen, where there is room for one of them.
enum CalendarCompactView
{
  toPlan,
  planned,
}

// The air between the track and the panel beside it.
const double _panelGap = 28;

// The one action standing under the track. Shorter and quieter than the buttons
// at the foot of a dialog: this one is on a page and not in a window, under a
// track it must not weigh more than.
const double _actionButtonHeight = 48;
const double _actionButtonFontSize = 14;

// Room for the longest label a day can take — "Mercoledì 22 settembre 2026" —
// held fixed so the arrows either side of it never move.
const double _dayLabelWidth = 250;

class CalendarTab extends StatefulWidget
{
  // The days the booking window has open — the same the rail shows, so that the
  // calendar and the two lists are talking about the same stretch of time.
  final List<DateTime> availableDays;

  final List<LessonItem> lessons;
  final List<AvailabilityItem> availabilities;
  final List<PresenceItem> presences;
  final List<OpeningDayItem> openingDays;

  // Only to name a request by the subject it was asked under: the panel writes
  // "Matematica" over the disciplines, and the booking carries the id alone.
  final List<MinistrySubjectItem> ministrySubjects;

  // What every teacher may teach, and what the disciplines are called. The
  // competences arrive as names and the lessons speak in ids, so the two lists
  // are needed together to know whether a drop is legal.
  final List<PersonItem> people;
  final List<AssociationSubjectItem> associationSubjects;

  // Which disciplines each programme teaches, so that the (discipline,
  // programme) pair is only applied where the discipline is part of the pupil's
  // programme at all.
  final List<StudyProgramItem> studyPrograms;

  // Answers with the lesson the server wrote, or null where it refused. The
  // warnings ride on the answer, which is the only place they exist.
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

  // An hour shortened and the minutes it gave back written as a second one. One
  // call because the order is forced — the second part has no room until the
  // first has shrunk — and because both halves have to appear together.
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

  // Files a request under another of the pupil's stretches of hours: the server
  // checks a lesson against the presence the request is filed under, so planning
  // it elsewhere moves it first. Allowed only while nothing is planned out.
  final Future<bool> Function({
    required BookingSummaryItem booking,
    required int presenceId,
    required Function(String) onError,
  })? onMoveBooking;

  // Which day is "today", for the calendar to open on. Left out it is the
  // clock's answer, which is what the app wants and what a test cannot have:
  // a screen that opens on a different day depending on when the suite is run
  // is a screen nobody can write an assertion about.
  final DateTime? today;

  // Fetches one day the page did not load, for the calendar walking past the
  // booking window. Answers false where the fetch failed, and the day then
  // stays unknown rather than pretending to be empty.
  final Future<bool> Function(DateTime day, Function(String) onError)? onLoadDay;

  // Every place in the building, as the catalogue has them. The whole list and
  // not the free ones: a room already holding somebody is still a room a second
  // teacher can be put in, and which of them are full is what the window draws.
  final List<RoomItem> rooms;

  // Fetched when the window is opened rather than kept, since a copy held on
  // the page would go stale under every other tab. Null where the fetch failed,
  // which is not the same as "nobody has a room".
  final Future<RoomDayPlan?> Function(
    DateTime day,
    Function(String) onError,
  )? onLoadRoomPlan;

  // The whole plan at once, against the assignments that were there when the
  // window opened.
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
  // Held here and not by the page, whose lists have a day of their own. Not
  // bound to the booking window either: that is what can still be booked, and a
  // calendar is looked at further out than that.
  late DateTime _day = _initialDay();

  TimeBucket _band = TimeBucket.afternoon;

  // Which of the two lists the narrow calendar is showing, and whether the strip
  // above the track is open. Held here rather than inside the panel: they are
  // answers about the screen, and the screen is this widget.
  CalendarCompactView _compactView = CalendarCompactView.toPlan;
  bool _panelExpanded = true;

  // The track scrolls on its own, and the drag has to be able to move it: the
  // controller is held here rather than left to TabContent, which owns one but
  // does not hand it out. The key measures the visible height, which is what
  // says whether the pointer has reached an edge.
  final ScrollController _trackController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  // Where each lesson was drawn last time, by id. Recomputed from scratch the
  // greedy pass renumbers freely, and moving one block would slide an untouched
  // one with it.
  final Map<int, int> _subLaneMemory = {};

  // How far each hour reached before being shortened, by id: it is what makes
  // two reductions of a quarter hour add up to one piece of half an hour.
  final Map<int, (int, int)> _shrunkFrom = {};

  // What is being carried, owned here because the panel that starts a drag and
  // the track that shows where it could go are siblings: otherwise the track
  // hears about it only once the pointer arrives.
  final ValueNotifier<CarriedRequest?> _carried = ValueNotifier(null);

  // And where it would land, which the track works out and both it and the panel
  // draw. Owned here for the same reason: the two feedbacks are the same
  // sentence said in two widgets, and one value is how they cannot disagree.
  final ValueNotifier<CarriedPlacement> _carriedAt = ValueNotifier(CarriedPlacement.idle);

  // The sentence a gesture in flight is raising, while it is still raising it.
  // Null when there is nothing wrong with where the pointer is — and that is the
  // state that takes the banner down again.
  String? _carriedRefusal;

  @override
  void initState()
  {
    super.initState();
    _carriedAt.addListener(_sayWhatIsWrong);

    // After the first frame and not during it: the ask sets state before it
    // awaits anything, and a setState inside initState is an error.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureRoomPlan());
  }

  // The page loads its lists after this tab is built, so the first ask above
  // regularly finds a day with nobody in it yet. This is the second chance, and
  // it costs nothing on the days that already have their answer.
  @override
  void didUpdateWidget(CalendarTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!identical(widget.lessons, oldWidget.lessons) && !_hasRoomPlan)
    {
      _ensureRoomPlan();
    }
  }

  @override
  void dispose()
  {
    _carriedAt.removeListener(_sayWhatIsWrong);

    // A banner that belongs to a gesture must not outlive the screen the gesture
    // was on.
    if (_carriedRefusal != null)
    {
      CustomSnackBar.dismiss();
    }

    _trackController.dispose();
    _carried.dispose();
    _carriedAt.dispose();
    super.dispose();
  }

  // Up while the place under the pointer will not do. It stays as long as the
  // problem does: somebody holding a block over a teacher who cannot teach it is
  // reading the reason. Only changes are acted on, or the animation restarts
  // under the eye trying to read it.
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

  // Today where the window holds it, which it does whenever the association is
  // open today, and the first day of the window otherwise.
  DateTime _initialDay()
  {
    final now = widget.today ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return widget.availableDays.any((day) => isSameDate(day, today)) ? today : widget.availableDays.first;
  }

  // Which days beyond the booking window have been fetched, so that walking back
  // over one does not ask again. Keyed by the date itself, at midnight.
  final Set<String> _fetchedDays = {};

  bool _isFetchingDay = false;

  // The day's rooms as the server holds them, kept because the calendar has to
  // answer whether the day is settled without opening the window. Keyed by day.
  //
  // Never invalidated by an edit to the hours: this is what the server holds,
  // and an edit changes whether it is still enough. See _buildBandAction.
  RoomDayPlan? _roomPlan;
  String? _roomPlanDay;

  // While it is being asked for, so the button turns its ring instead of opening
  // a second window on the second click.
  bool _isLoadingRoomPlan = false;

  bool get _hasRoomPlan => _roomPlanDay == _keyOf(_day);

  bool _isInsideWindow(DateTime day) => widget.availableDays.any((other) => isSameDate(other, day));

  static String _keyOf(DateTime day) => '${day.year}-${day.month}-${day.day}';

  // Moves to another day, fetching what the page never loaded. The day changes
  // at once and the fetch follows, or every arrow feels like a missed click.
  Future<void> _goToDay(DateTime day) async
  {
    final normalised = DateTime(day.year, day.month, day.day);

    setState(() => _day = normalised);

    final load = widget.onLoadDay;

    if (load == null || _isInsideWindow(normalised) || _fetchedDays.contains(_keyOf(normalised)))
    {
      return;
    }

    setState(() => _isFetchingDay = true);

    final loaded = await load(normalised, (message)
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
        _fetchedDays.add(_keyOf(normalised));
      }
    });
  }

  bool get _isDayClosed
  {
    return !isOpenOn(widget.openingDays, _day, kPresenceMode) &&
        !isOpenOn(widget.openingDays, _day, kOnlineMode);
  }

  // Why the day was shut, where whoever shut it wrote it down. Only a variation
  // carries one: an ordinary closed day comes off the weekly hours and has
  // nothing to say beyond being closed, and then nothing is said.
  String? get _closureNote
  {
    for (final row in widget.openingDays)
    {
      // A closure is the row with no hours on it, the way the association's own
      // table writes one.
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

  // Everything a rule needs to read, indexed once for the day and the band on
  // screen. Built in the build and not on every pointer move: resolving a drop
  // walks the teacher's hours, the pupils' hours and the competences, and
  // doing that sixty times a second off the raw lists is a stuttering drag.
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

  // Opens the window of the request the hour is part of and not one of its own:
  // the division it belongs to is the only view in which changing it means
  // anything. Every hour has exactly one request in it.
  Future<void> _openLesson(LessonItem lesson, CalendarDayIndex index) async
  {
    final booking = lesson.bookings.map((entry) => index.bookingsById[entry.id]).whereType<SchedulableBooking>().firstOrNull;

    if (booking == null)
    {
      return;
    }

    await _planBooking(booking, index);
  }

  // Where the thing under the pointer would land, judged before it is let go. A
  // request always asks for an hour of its own: joining the hour it lands on
  // reads as the two having been swallowed into one card.
  LessonPlacement _plan(CalendarDayIndex index, CalendarDragPayload payload, String teacherTaxCode, int startMinutes)
  {
    return switch (payload)
    {
      BookingDragPayload() => planDrop(index, payload, teacherTaxCode, startMinutes),
      LessonDragPayload(:final lesson) => _planLessonDrop(index, lesson, teacherTaxCode, startMinutes),
    };
  }

  // A move, unless it lands on the other part of its own request, and then it
  // is a merge: read as a move it could only be refused for the pupil being in
  // two lessons at once, which is exactly what says they belong together.
  LessonPlacement _planLessonDrop(
    CalendarDayIndex index,
    LessonItem lesson,
    String teacherTaxCode,
    int startMinutes,
  )
  {
    // Every hour the block lands on top of, not merely the one its left edge
    // reached: a merge from the moment the two rectangles meet, or the gesture
    // has to be aimed. Most-covered first.
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

  // The hours already written under a stretch of the track, the one the stretch
  // covers most of first. More than one where the teacher has two pupils at
  // once, and then the order is what decides which the gesture means.
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

  // Something picked up, or put down. Both notifiers reset together, since a
  // gesture ending away from the track leaves it stale. Who could teach it is
  // worked out once here: the track has no index to answer it with.
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

  // Whether a request on this hour already has both the parts it is allowed.
  bool _hasBothParts(CalendarDayIndex index, LessonItem lesson)
  {
    return lesson.bookings.any((entry) => (index.bookingsById[entry.id]?.parts.length ?? 0) >= kMaxLessonParts);
  }

  // The widest an hour has been, which is what says how many minutes a
  // shortening has freed in total across successive gestures.
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

  // The request refiled before the hour is written. False where that was
  // refused, and then nothing is written: the server would refuse the lesson
  // too, and the second sentence would be the confusing one.
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
    // The move is a round trip of its own, and the page reads both stretches back
    // after it: by the time it answers this tab may be gone.
    if (payload case BookingDragPayload(:final entry))
    {
      if (!await _fileWhereItIsPlanned(entry) || !mounted)
      {
        return;
      }
    }

    // A merge is two calls in a fixed order, and it has its own method.
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

      // Worked out before the write, because it is the hour as it still is that
      // says how many minutes the edge gave back — and once the answer comes the
      // lesson in hand is already the shorter one.
      final remainder = placement.kind == LessonPlacementKind.resize
          ? planSplitRemainder(
              index,
              existing,
              placement.startMinutes,
              placement.endMinutes,
              reached: _reachOf(existing, placement),
            )
          : null;

      // Shortened, and the freed minutes cannot become an hour because the
      // request already has its two parts. Said out loud, since nothing appears
      // beside it and the reason is a rule rather than a mistake.
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

  // The server's own warnings, which exist only on the answer to a write.
  //
  // Said once here; the amber dot on the block is worked out from the data and
  // survives the reload this sentence does not.
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

  // An hour carried off the track, done rather than asked about: the pointer
  // has to leave the track and be let go, which no hand does by accident.
  Future<void> _removeLesson(LessonItem lesson) async
  {
    final delete = widget.onDeleteLesson;

    if (delete == null || lesson.isPublished)
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

  // A gesture let go somewhere it may not be. The banner is already up, so it
  // is left where it is and simply given the ordinary five seconds.
  //
  // Clearing [_carriedRefusal] hands it over: from here it is a banner like any
  // other, and the reset that follows must not take it down.
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

  // The window on one request, wherever it was opened from: the card in the
  // panel and an hour already on the track are two views of the same materia,
  // and there is one window for it.
  Future<void> _planBooking(SchedulableBooking entry, CalendarDayIndex index) async
  {
    // Nothing can be written today and nothing is written yet, so the window
    // would open empty with one sentence in it. Only while nothing is planned:
    // once there is an hour, the window is where it is looked at.
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
      // The written-out way in, and the same rule as the drag: the request is
      // filed under the stretch it is being planned in before the hour is
      // written, and a refused move writes nothing.
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

  // The order is not free: the second part goes first, or the survivor grows
  // into an overlap that is still there. If the delete passes and the update
  // does not, what is left is coherent but not what was asked, and the message
  // says exactly that.
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

  // Recomputed from the bookings and not kept from the server's answer, whose
  // warnings are gone by the next reload while the reason is in the data all
  // along. The preference has no warning at all, so this is the only place it
  // shows. Both sets can hold the same lesson.
  ({Set<int> warned, Set<int> preferred}) _markedLessons(List<TeacherLane> lanes)
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

  // Every teacher by tax code, so a request can name the people it prefers and
  // the people it would rather avoid. Read off the anagrafica and not off the
  // lanes: a pupil can name somebody who is not available in this band at all,
  // and that is exactly worth knowing before the hour is placed.
  Map<String, String> get _teacherNames
  {
    return {
      for (final person in widget.people) person.fiscalCode: '${person.firstName} ${person.lastName}',
    };
  }

  int get _bandStart => bandStartMinutes(_band);

  int get _bandEnd => bandEndMinutes(_band);

  // The stretch of the day the axis covers, or null where there is nothing to
  // draw it over. See [timelineWindow] for why it is neither the opening alone
  // nor the content alone.
  (int, int)? _window(List<TeacherLane> lanes)
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

  // The same row of controls the weekly hours are walked with, rather than a
  // chip per day: chips could only offer the days the booking window has open.
  //
  // Nothing stops it going forward — those days simply have to be fetched.
  // Backwards it stops at the founding.
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
        // A fixed width, so the arrows do not shift as the day names change
        // length: "Lunedì 1 marzo" and "Mercoledì 22 settembre" are the two ends
        // of it, and a row that moves under the pointer is a row you misclick.
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

  // The same four controls with nowhere to put them side by side. Pinning the
  // arrows to the ends of a full-width row keeps _dayLabelWidth's promise —
  // arrows that do not move as the day names change — without the fixed width.
  //
  // Nothing is dropped: there is no second place to reach a day from.
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
      // With the year, the way the weekly hours write theirs: the calendar can
      // be walked as far forward as anybody likes, and "Mercoledì 12 agosto"
      // alone would stop saying which one.
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
      onSelected: (index) => setState(() => _band = TimeBucket.values[index]),
      padding: EdgeInsets.zero,
      // Only as wide as its three words: the summary of the day stands beside
      // it in the same row, and a control stretched to the page would push it
      // off the end.
      hugContent: true,
    );
  }

  // Only teachers with an hour on them, which is not the number of lanes: a
  // lane is drawn for everybody who offered, and offering is not convocato.
  Widget _buildSummary(List<TeacherLane> lanes)
  {
    final called = lanes.where((lane) => lane.lessons.isNotEmpty).length;
    final lessons = lanes.expand((lane) => lane.lessons).toList();

    // By person and not by seat: an hour given to two of them is one lesson with
    // two pupils in it, and the same pupil taught twice in a band is one pupil.
    final pupils = lessons.expand((lesson) => lesson.studentTaxCodes).toSet();

    final parts = [
      _count(called, 'docente convocato', 'docenti convocati'),
      _count(pupils.length, 'studente', 'studenti'),
      _count(lessons.length, 'lezione', 'lezioni'),
    ];

    return Text(
      parts.join(' · '),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppTheme.trialMutedText,
      ),
    );
  }

  static String _count(int value, String singular, String plural)
  {
    return '$value ${value == 1 ? singular : plural}';
  }

  // A band the association is shut in, on a day it opens in another. Said in
  // the small: the day itself is fine, and LessonsClosedDay's full-page notice
  // would be answering a question nobody asked.
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

  // The band opens but nobody offered anything in it. Different from the one
  // above, and worth saying differently: here there is something to be done
  // about it, and it is done in the Disponibilità tab.
  Widget _buildEmptyBand()
  {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          const Icon(Icons.person_off_outlined, size: 44, color: AppTheme.trialMutedText),
          const SizedBox(height: 16),
          Text(
            'Nessun docente disponibile',
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

  // Worked out here and handed down: heights and positions have to agree, and
  // cannot if two places compute the stacking from two memories of it.
  //
  // Only the track comes through here, so on a narrow window the two maps stop
  // being pruned. Not a leak: nothing writes to either without a track.
  ({Map<int, int> subLaneOf, List<double> rowHeights}) _stackLanes(List<TeacherLane> lanes)
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

      rowHeights.add(timelineRowHeight(stacking.laneCount));
    }

    // Remembered for the next build, and pruned to what is still on screen so
    // the map does not grow with every day walked through.
    _subLaneMemory
      ..clear()
      ..addAll(subLaneOf);

    _shrunkFrom.removeWhere((id, _) => !subLaneOf.containsKey(id));

    return (subLaneOf: subLaneOf, rowHeights: rowHeights);
  }

  Widget _buildTrack(List<TeacherLane> lanes, CalendarDayIndex index, (int, int) window, double width)
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

    // Too dense to aim at. The axis falls back to the content alone, which is
    // narrower and never hides a legal position: every drop the server would
    // accept is inside an availability, and the content holds all of them.
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

    return CalendarTimeline(
      lanes: lanes,
      metrics: metrics,
      bandStart: _bandStart,
      bandEnd: _bandEnd,
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

  // The requests of the day whose hours reach into this band. A presence that
  // falls entirely in another band is left out: there is nowhere on this track
  // to put it, and a card that can only be refused is noise.
  List<PresenceBookingGroup> get _bookingGroups
  {
    return groupSchedulable(
      presences: widget.presences,
      lessons: widget.lessons,
      day: _day,
    ).where((group) => group.touches(_bandStart, _bandEnd)).toList();
  }

  // The sentences that are not a calendar at all, asked once for both shapes: a
  // shut band is shut whether it is drawn as a track or read as a list.
  Widget? _buildBandNotice(List<TeacherLane> lanes)
  {
    if (unionOpeningWindow(widget.openingDays, _day, _band) == null && lanes.isEmpty)
    {
      return _buildClosedBand();
    }

    if (lanes.isEmpty)
    {
      return _buildEmptyBand();
    }

    return null;
  }

  Widget _buildTimelineArea(List<TeacherLane> lanes, CalendarDayIndex index)
  {
    final notice = _buildBandNotice(lanes);

    if (notice != null)
    {
      return notice;
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

  // The day and not the band on screen: a room is one per teacher per day, so
  // drawing from the band alone would leave out the morning's teachers, whose
  // seats the afternoon is fitted around. Which button appears is still the
  // band's answer — see [_buildBandAction].
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

        // The lessons cannot repeat — a lesson belongs to one band — but a
        // stretch of hours that crosses noon reaches into two, and is offered by
        // each of them. Kept by id so the merged row does not hold it twice.
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

    // By name, which is the only order that means anything here: the track's own
    // left-to-right is a band's order, and this list is the day's.
    inBuilding.sort((a, b) => a.teacher.fullName.toLowerCase().compareTo(b.teacher.fullName.toLowerCase()));

    return inBuilding;
  }

  // Asks for the day's rooms unless they are here. Kept, because whether the
  // day is settled decides what stands under the track on every build.
  Future<void> _ensureRoomPlan({bool force = false}) async
  {
    final load = widget.onLoadRoomPlan;

    if (load == null || _isLoadingRoomPlan || (!force && _hasRoomPlan))
    {
      return;
    }

    // Nobody in the building is nobody to give a room to. Asked unconditionally
    // this would be a pair of requests for every day walked past, for an answer
    // that is always the same empty one.
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

      // Only where the day has not moved on under the request: an answer about
      // Tuesday arriving after the arrows have reached Wednesday is an answer
      // about a day nobody is looking at.
      if (plan != null && isSameDate(day, _day))
      {
        _roomPlan = plan;
        _roomPlanDay = _keyOf(day);
      }
    });
  }

  // Opens the room board onto what the server holds, never onto an empty board
  // to be corrected under the hand: an ask that failed opens nothing.
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

    // Said here and not inside the window: the window is gone by now, and a
    // banner raised by something on its way out is a banner over a page nobody
    // is looking at yet. What went wrong is said the same way, while the window
    // is still open and can be put right.
    CustomSnackBar.show(context: context, message: 'Stanze e responsabili salvati.');

    // And asked again, because what stands under the track next depends on it:
    // the day that has just been settled is the day that grows a second button.
    await _ensureRoomPlan(force: true);
  }

  // The one thing left to do once the band adds up, or null while it does not.
  // Three answers: a band nobody asked anything of has nothing to finish, one
  // with something still to place is not finished, and past both it is either
  // the rooms or the publishing.
  //
  // The band's own teachers decide which, since it is this band that has just
  // been finished. What the rooms window then shows is the day.
  Widget? _buildBandAction(List<TeacherLane> lanes)
  {
    final groups = _bookingGroups;

    if (groups.isEmpty || openBookingCount(groups) > 0)
    {
      return null;
    }

    if (teachersInBuilding(lanes).isEmpty)
    {
      return AppGradientButton(
        label: 'PUBBLICA CALENDARIO',
        icon: Icons.send_rounded,
        height: _actionButtonHeight,
        fontSize: _actionButtonFontSize,
        onPressed: () {},
      );
    }

    final plan = _roomPlan;
    final hasRooms = _hasRoomPlan && plan!.assignments.isNotEmpty;

    // Settled: everybody in the building has a room, and each is watched for
    // all the hours it is taught in. An hour moved takes the day back out of
    // that state, and the offer to publish goes with it.
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
      height: _actionButtonHeight,
      fontSize: _actionButtonFontSize,
      onPressed: _openRoomAssignment,
    );

    if (!settled)
    {
      return rooms;
    }

    // Neither is quietened for standing beside the other: at rest both are
    // outlines, and they are the two halves of one thing — go back and change
    // it, or send it — so a quieter one would read as the lesser errand.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        rooms,
        const SizedBox(width: 14),
        AppGradientButton(
          label: 'PUBBLICA CALENDARIO',
          icon: Icons.send_rounded,
          height: _actionButtonHeight,
          fontSize: _actionButtonFontSize,
          onPressed: () {},
        ),
      ],
    );
  }

  // Under the track and not the whole body: on a wide screen the panel stands
  // to the right, and what the button finishes is the track.
  //
  // [slot] is the beat the track is given on a change of page, and the button
  // under it follows on the next one. Handed down rather than fixed here: which
  // of the track and the panel is read first is the shape's answer, not this
  // one's.
  Widget _buildTimelineColumn(List<TeacherLane> lanes, CalendarDayIndex index, {required int slot})
  {
    final action = _buildBandAction(lanes);

    // Around the whole area and not inside it: the track scrolls, and a viewport
    // clips what is in it — an element let go from inside one walks off the page
    // by vanishing at the edge of its own column.
    final Widget area = PageTransitionItem(slot: slot, child: _buildTimelineArea(lanes, index));

    if (action == null)
    {
      return area;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: area),
        const SizedBox(height: 18),
        Center(child: PageTransitionItem(slot: slot + 1, child: action)),
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

  // The band as a list, for the widths that cannot hold a track. No notices:
  // they were asked before the switch that leads here was drawn, and a list has
  // no axis to size.
  Widget _buildAgendaArea(List<TeacherLane> lanes, CalendarDayIndex index)
  {
    final marked = _markedLessons(lanes);

    return CalendarDayAgenda(
      lanes: lanes,
      bandStart: _bandStart,
      bandEnd: _bandEnd,
      warnedLessonIds: marked.warned,
      preferredLessonIds: marked.preferred,
      // The same way in as the track's own blocks, ending at the same window:
      // see _openLesson.
      onLessonTap: (lesson) => _openLesson(lesson, index),
    );
  }

  // A switch and not one page holding both: stacked, the hours already planned
  // would sit under a screenful of cards and be the half nobody scrolls to.
  // Each list also keeps a height of its own, so both go on scrolling.
  Widget _buildCompactBody(List<TeacherLane> lanes, CalendarDayIndex index)
  {
    // The whole body and not one half: with nothing on this day to put them on,
    // every card in the panel is inert. Behind the switch, the sentence saying
    // why was on the side nobody had opened.
    final notice = _buildBandNotice(lanes);

    if (notice != null)
    {
      return PageTransitionItem(slot: PageTransitionItem.list, child: notice);
    }

    final open = openBookingCount(_bookingGroups);
    final planned = lanes.fold<int>(0, (total, lane) => total + lane.lessons.length);

    // Under both halves and not only under the list of hours. There is no track
    // on this screen for it to stand under, and what it finishes is the day
    // rather than either of the two lists: hidden behind the switch it would be
    // a button you have to know to go looking for.
    final action = _buildBandAction(lanes);

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

  Widget _buildBody(List<TeacherLane> lanes, CalendarDayIndex index, _CalendarShape shape)
  {
    // The beats run in the order the shape is read: across the row on a wide
    // window, down the column on a narrow one, so the day comes apart and back
    // together the way it is looked at rather than the way it is built.
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

  // [summary] is null while there is nothing true to say: on a day still on its
  // way, "Nessun docente convocato" is a sentence about the network dressed up
  // as a sentence about the day.
  Widget _buildHeader(Widget dayNav, {Widget? summary})
  {
    return PageTransitionItem(
      slot: PageTransitionItem.header,
      // Stretched so the Wrap below is handed the whole width: with the
      // children left to hug, there is no free space between them for
      // spaceBetween to put anywhere, and the day would sit against the bands
      // instead of against the far edge.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day and band on one line: the two coordinates of what is on screen,
          // and apart they made the head taller than what it heads.
          //
          // The Wrap needs no width answer of its own: the narrow nav's Row has
          // an Expanded and so fills the bounded maximum, which puts it on a run
          // of its own under the bands.
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPage(_CalendarShape shape, bool navFits)
  {
    final Widget dayNav = navFits ? _buildDayNav() : _buildNarrowDayNav();

    // A day not yet fetched has no opening rows, which is indistinguishable
    // from a day the association is shut on: every arrow used to flash the
    // closed-day notice for the length of the round trip. The spinner is the
    // honest answer, and it is asked once per day since fetches are remembered.
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
          // Where the open day puts it, so walking onto a shut one does not move
          // the arrows. The bands are dropped and not moved: a shut day has no
          // band to pick. Only the wide nav, which hugs its controls, needs
          // telling which end to hug.
          PageTransitionItem(
            slot: PageTransitionItem.header,
            child: Align(alignment: Alignment.centerRight, child: dayNav),
          ),
          const SizedBox(height: 20),
          Expanded(
            // Neither the date nor a sentence about the calendar: the row of
            // arrows overhead already says which day this is, and that a shut
            // day has no calendar to compose is what the heading says. What is
            // left worth reading is the reason the day was shut — and where
            // there is none, nothing stands under the heading at all.
            child: LessonsClosedDay(message: _closureNote),
          ),
        ],
      );
    }

    final lanes = _lanes;
    final index = _buildIndex(lanes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(dayNav, summary: _buildSummary(lanes)),
        Expanded(child: _buildBody(lanes, index, shape)),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // Over the whole screen, so the head and what it heads cannot end up on
    // different answers about the same width. Outside the PageTransitionItem:
    // nesting them makes the header quietly stop arriving, with no error.
    return LayoutBuilder(
      builder: (context, constraints)
      {
        // Measured on what the tab was given and not on the window, which still
        // holds the rail: asking the window would put the panel beside a track
        // with no room left, and keep a track nobody can aim at.
        final shape = _shapeFor(constraints.maxWidth);

        // A separate answer, and see kCalendarDayNavMin for why: the row of the
        // day gives up four hundred and forty and the track gives up at six
        // hundred and twenty, so one flag for the two would take the header
        // apart at a width where it still fitted.
        final navFits = constraints.maxWidth >= kCalendarDayNavMin;

        return _buildPage(shape, navFits);
      },
    );
  }
}
