import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/rome_clock.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../../shared/widgets/page_transition.dart';
import '../association/models/ministry_subject_item.dart';
import '../association/models/opening_day_item.dart';
import '../association/tabs/opening_hours/calendar_bounds.dart';
import '../lessons/models/activity_item.dart';
import '../lessons/models/availability_item.dart';
import '../lessons/models/calendar_day.dart';
import '../lessons/models/calendar_publication_item.dart';
import '../lessons/models/lesson_item.dart';
import '../lessons/models/room_supervision_item.dart';
import '../lessons/utils/calendar_jump.dart';
import '../lessons/utils/opening_window.dart';
import '../lessons/utils/timeline_geometry.dart';
import '../lessons/widgets/activity_details_dialog.dart';
import '../lessons/widgets/calendar_lesson_block.dart' show isLessonPast, isLessonRunning;
import '../notifications/calendar_seen.dart';
import 'calendar_tour.dart';
import 'utils/calendar_strings.dart';
import 'utils/teacher_band_call.dart';
import 'utils/viewable_days.dart';
import 'widgets/calendar_page_shell.dart';
import 'widgets/convocation_card.dart';
import 'widgets/own_day_timeline.dart';
import 'widgets/own_lesson_block.dart';
import 'widgets/own_lesson_dialog.dart';
import 'widgets/own_lesson_list.dart';
import 'widgets/teacher_note_dialog.dart' show lessonHasBegun;

const Duration _tick = Duration(minutes: 1);

const String _teacherRole = 'TEACHER';

const double _listMaxWidth = 640;

// Never past today: only published days are shown.
class TeacherCalendarPage extends StatefulWidget
{
  const TeacherCalendarPage({super.key});

  @override
  State<TeacherCalendarPage> createState() => _TeacherCalendarPageState();
}

class _TeacherCalendarPageState extends State<TeacherCalendarPage> with DestinationRefresh
{
  final ApiService _apiService = ApiService();

  DateTime _now = romeNow();

  Timer? _clock;

  late DateTime _day = _today;

  // Today, or tomorrow once one of its bands is published.
  late DateTime _lastDay = _today;

  late TimeBucket _band = bucketFor(TimeOfDay.fromDateTime(_now)) ?? TimeBucket.afternoon;

  bool _isLoading = true;
  bool _failed = false;

  // The person is read before the dialog opens; a second click meanwhile is dropped.
  bool _isOpeningLesson = false;

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  List<OpeningDayItem> _openingDays = [];
  List<CalendarPublicationItem> _publications = [];

  // Closed with nobody booked: never to be published.
  List<(DateTime, TimeBucket)> _unbooked = [];
  List<LessonItem> _lessons = [];
  List<ActivityItem> _activities = [];
  List<RoomSupervisionItem> _supervisions = [];
  List<AvailabilityItem> _availabilities = [];

  List<MinistrySubjectItem> _ministrySubjects = [];

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  bool get _isToday => isSameDate(_day, _today);

  bool get _isPastDay => _day.isBefore(_today);

  bool get _isFirstDay => !_day.isAfter(oldestKeptDay(_now));

  String? get _meTaxCode => _apiService.lastKnownIdentity?.taxCode;

  bool get _isFeminine => _apiService.lastKnownIdentity?.gender == 'F';

  @override
  void initState()
  {
    super.initState();

    _clock = Timer.periodic(_tick, (_)
    {
      // Offstage the tick is skipped; onDestinationShown realigns the clock.
      if (destinationShown)
      {
        setState(() => _now = romeNow());
      }
    });

    // Opened from a notification: straight to its day and band.
    final CalendarJump? jump = CalendarJumps.role.take(role: _teacherRole);

    if (jump != null)
    {
      _day = jump.day;
      _band = jump.band;
    }

    CalendarJumps.role.asked.addListener(_jump);
    _loadDay();
  }

  @override
  void dispose()
  {
    CalendarJumps.role.asked.removeListener(_jump);
    _clock?.cancel();
    super.dispose();
  }

  void _jump()
  {
    final CalendarJump? jump = CalendarJumps.role.take(role: _teacherRole);

    if (jump == null || !mounted)
    {
      return;
    }

    setState(() => _band = jump.band);
    _reload(jump.day);
  }

  // A published band on screen takes its notification away.
  void _noteSeen()
  {
    if (!mounted || _isLoading || _failed || !_isPublished || !destinationShown)
    {
      return;
    }

    unawaited(markCalendarSeen(_day, _band));
  }

  void _chooseBand(TimeBucket band)
  {
    setState(() => _band = band);
    _noteSeen();
    _startTours();
  }

  bool get _canTour
  {
    return mounted && !_isLoading && !_failed && !isDesktopTourShown && isDesktopTourTargetShown(kTourCalendarBands);
  }

  // One tour for the page, the call and the lesson's window, on an open day.
  // [follow]: turn to the band of an untold call; a band picked by the user stays.
  Future<void> _startTours({bool follow = false}) async
  {
    await WidgetsBinding.instance.endOfFrame;

    if (!_canTour)
    {
      return;
    }

    if (follow && _firstLessonIn(_band) == null && await isCalendarCallDue())
    {
      final TimeBucket? called = TimeBucket.values.where((band) => _firstLessonIn(band) != null).firstOrNull;

      if (called != null && _canTour)
      {
        setState(() => _band = called);
        _noteSeen();
        await WidgetsBinding.instance.endOfFrame;
      }
    }

    if (!_canTour)
    {
      return;
    }

    final LessonItem? lesson = _firstLessonIn(_band);
    final DesktopTour? tour = await calendarPageTour(
      student: lesson != null && !lesson.date.isBefore(_today),
      note: lesson != null && lessonHasBegun(lesson, _now),
    );

    if (tour != null && mounted)
    {
      startCalendarTour(context, tour);
    }
  }

  void _onPickerOpen(BuildContext context, bool open)
  {
    calendarPickerOpen.value = open;

    if (open)
    {
      startCalendarTour(context, calendarPickerTour);
    }
  }

  @override
  void onDestinationShown()
  {
    setState(() => _now = romeNow());

    // A full read under way, as a notification asks for, is fresh enough.
    if (!_isLoading)
    {
      _loadDay(quiet: true);
    }
  }

  Future<void> _loadDay({bool quiet = false}) async
  {
    final int request = ++_request;
    final DateTime day = _day;

    try
    {
      final results = await Future.wait([
        _apiService.getOpeningDays(dateFrom: day, dateTo: day, mode: kPresenceMode),
        _apiService.getOpeningDays(dateFrom: day, dateTo: day, mode: kOnlineMode),
        _apiService.getCalendarPublications(dateFrom: day, dateTo: day),
        _apiService.getLessons(dateFrom: day, dateTo: day),
        _apiService.getCalendarActivities(dateFrom: day, dateTo: day),
        _apiService.getRoomSupervisions(day),
        _apiService.getAvailabilities(dateFrom: day, dateTo: day),
        _apiService.getUnbookedBands(dateFrom: day, dateTo: day),
        _apiService.getCalendarPublications(dateFrom: addDays(_today, 1), dateTo: addDays(_today, 1)),
        if (_ministrySubjects.isEmpty) _apiService.getMinistrySubjects(),
      ]);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _openingDays = [
          ...results[0] as List<OpeningDayItem>,
          ...results[1] as List<OpeningDayItem>,
        ];
        _publications = results[2] as List<CalendarPublicationItem>;
        _lessons = results[3] as List<LessonItem>;
        _activities = results[4] as List<ActivityItem>;
        _supervisions = results[5] as List<RoomSupervisionItem>;
        _availabilities = results[6] as List<AvailabilityItem>;
        _unbooked = results[7] as List<(DateTime, TimeBucket)>;
        _lastDay = lastViewableDay(_today, results[8] as List<CalendarPublicationItem>);

        if (results.length > 9)
        {
          _ministrySubjects = results[9] as List<MinistrySubjectItem>;
        }

        _isLoading = false;
        _failed = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _noteSeen());
      _startTours(follow: true);
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento del calendario');

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _isLoading = false;
        _failed = !quiet || _failed;
      });
    }
  }

  void _goToDay(DateTime day)
  {
    final DateTime normalised = DateTime(day.year, day.month, day.day);
    final DateTime oldest = oldestKeptDay(_now);

    _showDay(
      normalised.isAfter(_lastDay)
          ? _lastDay
          : (normalised.isBefore(oldest) ? oldest : normalised),
    );
  }

  // The same day read again quietly, another one in full.
  void _showDay(DateTime target)
  {
    if (isSameDate(target, _day))
    {
      _loadDay(quiet: true);

      return;
    }

    _reload(target);
  }

  // Also what a notification's tap does: nothing on screen from before its news.
  void _reload(DateTime target)
  {
    setState(()
    {
      _day = target;
      _isLoading = true;
      _failed = false;
    });

    _loadDay();
  }

  bool get _isDayClosed
  {
    return !isOpenOn(_openingDays, _day, kPresenceMode) && !isOpenOn(_openingDays, _day, kOnlineMode);
  }

  String? get _closureNote
  {
    for (final row in _openingDays)
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

  bool get _isPublished
  {
    return _publications.any((row) => isSameDate(row.date, _day) && row.band == _band);
  }

  bool get _isSettled
  {
    return _isPublished || _unbooked.any((row) => isSameDate(row.$1, _day) && row.$2 == _band);
  }

  // The earliest lesson of a published band: the one a tour lights.
  LessonItem? _firstLessonIn(TimeBucket band)
  {
    if (!_publications.any((row) => isSameDate(row.date, _day) && row.band == band))
    {
      return null;
    }

    final List<LessonItem> lessons = teacherBandCall(
      day: _day,
      band: band,
      lessons: _lessons,
      activities: _activities,
      supervisions: _supervisions,
      teacherTaxCode: _meTaxCode,
    ).lessons;

    return lessons.isEmpty ? null : lessons.reduce((a, b) => b.startMinutes < a.startMinutes ? b : a);
  }

  TeacherBandCall get _call
  {
    return teacherBandCall(
      day: _day,
      band: _band,
      lessons: _lessons,
      activities: _activities,
      supervisions: _supervisions,
      teacherTaxCode: _meTaxCode,
    );
  }

  List<AvailabilityItem> get _offered
  {
    return availabilitiesIn(
      day: _day,
      band: _band,
      availabilities: _availabilities,
      teacherTaxCode: _meTaxCode,
    );
  }

  (int, int)? _windowFor(TeacherBandCall call, List<AvailabilityItem> offered)
  {
    final opening = unionOpeningWindow(_openingDays, _day, _band);

    return timelineWindow(
      bandStartMinutes: bandStartMinutes(_band),
      bandEndMinutes: bandEndMinutes(_band),
      opening: opening == null ? null : (opening.startMinutes, opening.endMinutes),
      content: [
        ...call.spans,
        for (final slot in offered) (minutesOfTimeOfDay(slot.startTime), minutesOfTimeOfDay(slot.endTime)),
      ],
    );
  }

  int? get _nowMinutes => _isToday ? minutesOfTimeOfDay(TimeOfDay.fromDateTime(_now)) : null;

  bool _isOver(int endMinutes)
  {
    final clock = _nowMinutes;

    return _isPastDay || (clock != null && endMinutes <= clock);
  }

  bool _isRunning(int startMinutes, int endMinutes)
  {
    final clock = _nowMinutes;

    return clock != null && startMinutes <= clock && clock < endMinutes;
  }

  Future<void> _openLesson(LessonItem lesson) async
  {
    final student = lesson.bookings.firstOrNull?.presence.student;

    if (student == null)
    {
      return;
    }

    if (_isOpeningLesson)
    {
      return;
    }

    _isOpeningLesson = true;

    try
    {
      await showOwnLessonDialog(
        context: context,
        lesson: lesson,
        ministrySubjects: _ministrySubjects,
        view: CalendarView.byTeacher,
        other: lesson.date.isBefore(_today) ? null : _apiService.getPerson(student.taxCode),
      );
    }
    finally
    {
      _isOpeningLesson = false;
    }
  }

  Future<void> _openActivity(ActivityItem activity) async
  {
    await showActivityDetailsDialog(context: context, activity: activity);
  }

  // The earliest lesson is the one a tour lights.
  TimelineEntry _lessonEntry(
    LessonItem lesson, {
    required bool onTimeline,
    required bool lit,
    required bool showsRoom,
  })
  {
    final TimelineEntry entry = OwnLessonBlock(
      key: ValueKey('lesson-${lesson.id}'),
      lesson: lesson,
      ministrySubjects: _ministrySubjects,
      view: CalendarView.byTeacher,
      isPast: isLessonPast(lesson, _now),
      isCurrent: !onTimeline && isLessonRunning(lesson, _now),
      onTap: () => _openLesson(lesson),
      showsRoom: showsRoom,
    ).asEntry(context);

    return (
      startMinutes: entry.startMinutes,
      endMinutes: entry.endMinutes,
      width: entry.width,
      heightAt: entry.heightAt,
      block: DesktopTourTarget(id: lit ? kTourCalendarLesson : null, child: entry.block),
    );
  }

  List<TimelineEntry> _entriesOf(TeacherBandCall call, {required bool onTimeline})
  {
    final LessonItem? first = _firstLessonIn(_band);

    return [
      for (final lesson in call.lessons)
        _lessonEntry(lesson, onTimeline: onTimeline, lit: lesson.id == first?.id, showsRoom: call.changesRoom),
      for (final activity in call.activities)
        OwnActivityBlock(
          key: ValueKey('activity-${activity.id}'),
          activity: activity,
          isPast: _isOver(activity.endMinutes),
          isCurrent: !onTimeline && _isRunning(activity.startMinutes, activity.endMinutes),
          onTap: () => _openActivity(activity.activity),
        ).asEntry(context),
    ];
  }

  Widget _buildBody(bool isNarrow)
  {
    if (_isLoading)
    {
      return const CalendarLoading();
    }

    if (_failed)
    {
      return const CalendarNote(kCalendarLoadFailed);
    }

    if (unionOpeningWindow(_openingDays, _day, _band) == null)
    {
      return const CalendarClosedBand();
    }

    if (!_isSettled)
    {
      return CalendarUnpublishedBand(band: _band);
    }

    final call = _call;
    final offered = _offered;
    final window = _windowFor(call, offered);

    if (call.isEmpty || window == null)
    {
      return CalendarEmptyBand(
        icon: Icons.free_cancellation_rounded,
        title: kCalendarUnavailableTitle,
        message: offered.isEmpty ? kNoAvailabilityGiven : notConvenedSentence(feminine: _isFeminine),
      );
    }

    return CalendarSplitBody(
      top: DesktopTourTarget(
        id: kTourCalendarCard,
        child: ConvocationCard(call: call, isFeminine: _isFeminine),
      ),
      day: isNarrow
          ? Center(
              child: ConstrainedBox(
                // Below the wide window the rows take the whole width.
                constraints: BoxConstraints(maxWidth: AppBreakpoints.of(context).isDense ? double.infinity : _listMaxWidth),
                child: OwnLessonList(entries: _entriesOf(call, onTimeline: false), nowMinutes: _nowMinutes),
              ),
            )
          : OwnDayTimeline(
              window: window,
              lanes: [
                (
                  name: null,
                  stretches: [
                    for (final slot in offered)
                      (
                        mode: slot.mode,
                        startMinutes: minutesOfTimeOfDay(slot.startTime),
                        endMinutes: minutesOfTimeOfDay(slot.endTime),
                      ),
                  ],
                  entries: _entriesOf(call, onTimeline: true),
                ),
              ],
              nowMinutes: _nowMinutes,
            ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return CalendarPageShell(
      currentRoute: '${homeForRole(_teacherRole)}/calendar',
      band: _band,
      onBand: _chooseBand,
      day: _day,
      lastDay: _lastDay,
      isFirstDay: _isFirstDay,
      isBusy: _isLoading,
      onDay: _goToDay,
      isClosed: !_isLoading && !_failed && _isDayClosed,
      closureNote: _closureNote,
      onPickerOpen: _onPickerOpen,
      body: _buildBody,
    );
  }
}
