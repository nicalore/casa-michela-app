import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/rome_clock.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_filter_pill.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../../shared/widgets/filter_menu.dart';
import '../../shared/widgets/page_transition.dart';
import '../association/models/ministry_subject_item.dart';
import '../association/models/opening_day_item.dart';
import '../association/tabs/opening_hours/calendar_bounds.dart';
import '../lessons/models/calendar_day.dart';
import '../lessons/models/calendar_publication_item.dart';
import '../lessons/models/lesson_item.dart';
import '../lessons/models/presence_item.dart';
import '../lessons/utils/calendar_jump.dart';
import '../lessons/utils/opening_window.dart';
import '../lessons/utils/timeline_geometry.dart';
import '../lessons/widgets/calendar_lesson_block.dart' show isLessonPast, isLessonRunning;
import '../notifications/calendar_seen.dart';
import '../people/models/person_face.dart';
import 'calendar_tour.dart';
import 'pupil_calendar_tour.dart';
import 'utils/calendar_strings.dart';
import 'utils/pupil_band_presence.dart';
import 'utils/viewable_days.dart';
import 'widgets/band_summary_card.dart';
import 'widgets/calendar_page_shell.dart';
import 'widgets/own_day_timeline.dart';
import 'widgets/own_lesson_block.dart';
import 'widgets/own_lesson_dialog.dart';
import 'widgets/own_lesson_list.dart';
import 'widgets/presence_card.dart';

const Duration _tick = Duration(minutes: 1);

const String _parentRole = 'PARENT';

const String _pupilRole = 'Studente';

const double _cardGap = 16;

const double _stackGap = 36;
const double _denseStackGap = 20;
const double _denseCardGap = 10;

const double _listMaxWidth = 640;

const double _listNameGap = 10;

const double _layoutMenuWidth = 210;

typedef _Pupil = ({String taxCode, String firstName, String? gender});

// Never past today: only published days are shown.
class PupilCalendarPage extends StatefulWidget
{
  final String role;

  const PupilCalendarPage({super.key, required this.role});

  @override
  State<PupilCalendarPage> createState() => _PupilCalendarPageState();
}

class _PupilCalendarPageState extends State<PupilCalendarPage> with DestinationRefresh
{
  final ApiService _apiService = ApiService();

  DateTime _now = romeNow();

  Timer? _clock;

  late DateTime _day = _today;

  // Today, or tomorrow once one of its bands is published.
  late DateTime _lastDay = _today;

  late TimeBucket _band = bucketFor(TimeOfDay.fromDateTime(_now)) ?? TimeBucket.afternoon;

  CalendarLayout _layout = CalendarLayout.byHour;

  bool _isLoading = true;
  bool _failed = false;

  // The person is read before the dialog opens; a second click meanwhile is dropped.
  bool _isOpeningLesson = false;

  int _request = 0;

  List<OpeningDayItem> _openingDays = [];
  List<CalendarPublicationItem> _publications = [];

  // Closed with nobody booked: never to be published.
  List<(DateTime, TimeBucket)> _unbooked = [];
  List<LessonItem> _lessons = [];
  List<PresenceItem> _presences = [];

  List<MinistrySubjectItem> _ministrySubjects = [];

  List<_Pupil>? _pupils;

  bool get _isParent => widget.role == _parentRole;

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  bool get _isToday => isSameDate(_day, _today);

  bool get _isFirstDay => !_day.isAfter(oldestKeptDay(_now));

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
    final CalendarJump? jump = CalendarJumps.role.take(role: widget.role);

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
    final CalendarJump? jump = CalendarJumps.role.take(role: widget.role);

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

  // One tour for the page, the published band and the lesson's window, on an open day.
  // [follow]: turn to a published band with a lesson if the shown one has none.
  Future<void> _startTours({bool follow = false}) async
  {
    await WidgetsBinding.instance.endOfFrame;

    if (!_canTour)
    {
      return;
    }

    if (follow && _firstLessonIn(_band) == null && await isPupilCalendarBandDue())
    {
      final TimeBucket? published = TimeBucket.values.where((band) => _firstLessonIn(band) != null).firstOrNull;

      if (published != null && _canTour)
      {
        setState(() => _band = published);
        _noteSeen();
        await WidgetsBinding.instance.endOfFrame;
      }
    }

    if (!_canTour)
    {
      return;
    }

    final List<_Pupil> pupils = _pupils ?? const [];
    final List<PupilBandPresence> presences = [for (final pupil in pupils) _presenceOf(pupil)];
    final LessonItem? lesson = _firstLessonIn(_band);

    pupilCalendarLessonFor = _lessonFor(lesson);

    final DesktopTour? tour = await pupilCalendarPageTour(
      genders: [for (final pupil in pupils) pupil.gender],
      online: presences.expand((presence) => presence.presences).every((row) => row.mode == kOnlineMode) &&
          presences.any((presence) => presence.presences.isNotEmpty),
    );

    if (tour != null && mounted)
    {
      startPupilCalendarTour(context, tour);
    }
  }

  // The pupil a lesson is for, as the window's tour names them.
  ({bool self, String? gender}) _lessonFor(LessonItem? lesson)
  {
    final String? code = lesson?.bookings.firstOrNull?.presence.student.taxCode;
    final _Pupil? pupil = (_pupils ?? const <_Pupil>[]).where((pupil) => pupil.taxCode == code).firstOrNull;

    return (self: !_isParent, gender: pupil?.gender);
  }

  // The earliest lesson of a published band, among every pupil's: the one a tour lights.
  LessonItem? _firstLessonIn(TimeBucket band)
  {
    if (!_publications.any((row) => isSameDate(row.date, _day) && row.band == band))
    {
      return null;
    }

    final List<LessonItem> lessons = [
      for (final pupil in _pupils ?? const <_Pupil>[])
        ...pupilBandPresence(day: _day, band: band, pupilTaxCode: pupil.taxCode, presences: _presences, lessons: _lessons)
            .lessons,
    ];

    return lessons.isEmpty ? null : lessons.reduce((a, b) => b.startMinutes < a.startMinutes ? b : a);
  }

  void _onPickerOpen(BuildContext context, bool open)
  {
    calendarPickerOpen.value = open;

    if (open)
    {
      startPupilCalendarTour(context, calendarPickerTour);
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

  Future<List<_Pupil>> _readPupils() async
  {
    final me = _apiService.lastKnownIdentity ?? await _apiService.me();

    if (!_isParent)
    {
      return [(taxCode: me.taxCode, firstName: me.firstName, gender: me.gender)];
    }

    final reader = await _apiService.getPerson(me.taxCode);

    final children = await Future.wait([
      for (final child in reader.children ?? const []) _apiService.getPerson(child.fiscalCode),
    ]);

    return [
      for (final child in children.where((child) => child.roles.contains(_pupilRole)).toList()..sort(compareByName))
        (taxCode: child.fiscalCode, firstName: child.firstName, gender: child.gender),
    ];
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
        _apiService.getPresences(dateFrom: day, dateTo: day),
        _apiService.getUnbookedBands(dateFrom: day, dateTo: day),
        _apiService.getCalendarPublications(dateFrom: addDays(_today, 1), dateTo: addDays(_today, 1)),
        if (_ministrySubjects.isEmpty) _apiService.getMinistrySubjects(),
      ]);

      final pupils = _pupils ?? await _readPupils();

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
        _presences = results[4] as List<PresenceItem>;
        _unbooked = results[5] as List<(DateTime, TimeBucket)>;
        _lastDay = lastViewableDay(_today, results[6] as List<CalendarPublicationItem>);

        if (results.length > 7)
        {
          _ministrySubjects = results[7] as List<MinistrySubjectItem>;
        }

        _pupils = pupils;

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

  int? get _nowMinutes => _isToday ? minutesOfTimeOfDay(TimeOfDay.fromDateTime(_now)) : null;

  String get _nothingTitle
  {
    return pupilNothingTitle(inBuilding: openingWindowFor(_openingDays, _day, kPresenceMode, _band) != null);
  }

  PupilBandPresence _presenceOf(_Pupil pupil)
  {
    return pupilBandPresence(
      day: _day,
      band: _band,
      pupilTaxCode: pupil.taxCode,
      presences: _presences,
      lessons: _lessons,
    );
  }

  (int, int)? _windowFor(List<PupilBandPresence> presences)
  {
    final opening = unionOpeningWindow(_openingDays, _day, _band);

    return timelineWindow(
      bandStartMinutes: bandStartMinutes(_band),
      bandEndMinutes: bandEndMinutes(_band),
      opening: opening == null ? null : (opening.startMinutes, opening.endMinutes),
      content: [
        for (final presence in presences) ...[
          for (final row in presence.presences) (row.startMinutes, row.endMinutes),
          ...presence.lessonSpans,
        ],
      ],
    );
  }

  Future<void> _openLesson(LessonItem lesson) async
  {
    if (_isOpeningLesson)
    {
      return;
    }

    _isOpeningLesson = true;
    pupilCalendarLessonFor = _lessonFor(lesson);

    try
    {
      await showOwnLessonDialog(
        context: context,
        lesson: lesson,
        ministrySubjects: _ministrySubjects,
        view: CalendarView.byStudent,
        other: _apiService.getPerson(lesson.teacherTaxCode),
      );
    }
    finally
    {
      _isOpeningLesson = false;
    }
  }

  // The earliest lesson is the one a tour lights.
  List<TimelineEntry> _entriesOf(PupilBandPresence presence, {required bool onTimeline})
  {
    final LessonItem? first = _firstLessonIn(_band);

    return [
      for (final lesson in presence.lessons)
        _lessonEntry(lesson, onTimeline: onTimeline, lit: lesson.id == first?.id),
    ];
  }

  TimelineEntry _lessonEntry(LessonItem lesson, {required bool onTimeline, required bool lit})
  {
    final TimelineEntry entry = OwnLessonBlock(
      key: ValueKey('lesson-${lesson.id}'),
      lesson: lesson,
      ministrySubjects: _ministrySubjects,
      view: CalendarView.byStudent,
      isPast: isLessonPast(lesson, _now),
      isCurrent: !onTimeline && isLessonRunning(lesson, _now),
      onTap: () => _openLesson(lesson),
    ).asEntry(context);

    return (
      startMinutes: entry.startMinutes,
      endMinutes: entry.endMinutes,
      width: entry.width,
      heightAt: entry.heightAt,
      block: DesktopTourTarget(id: lit ? kTourCalendarLesson : null, child: entry.block),
    );
  }

  TimelineLane _laneOf(_Pupil pupil, PupilBandPresence presence, {required bool named})
  {
    return (
      name: named ? TimelineLaneName(name: pupil.firstName) : null,
      stretches: [
        for (final row in presence.presences)
          (mode: row.mode, startMinutes: row.startMinutes, endMinutes: row.endMinutes),
      ],
      entries: _entriesOf(presence, onTimeline: true),
    );
  }

  Widget _buildLayoutPicker()
  {
    return DesktopTourTarget(
      id: kTourPupilCalendarLayout,
      child: _buildLayoutPill(),
    );
  }

  Widget _buildLayoutPill()
  {
    return AppFilterPill<CalendarLayout>.setting(
      prefix: 'Disposizione',
      hint: 'Disposizione',
      icon: Icons.view_agenda_outlined,
      value: _layout,
      maxLabelWidth: double.infinity,
      options: [
        for (final layout in CalendarLayout.values)
          FilterOption(value: layout, label: layout.label),
      ],
      onChanged: (layout) => setState(() => _layout = layout),
      menuWidth: _layoutMenuWidth,
    );
  }

  Widget _buildLists(List<_Pupil> pupils, List<PupilBandPresence> presences)
  {
    if (pupils.length == 1)
    {
      return Center(
        child: ConstrainedBox(
          // Below the wide window the rows take the whole width.
          constraints: BoxConstraints(maxWidth: AppBreakpoints.of(context).isDense ? double.infinity : _listMaxWidth),
          child: OwnLessonList(entries: _entriesOf(presences.single, onTimeline: false), nowMinutes: _nowMinutes),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < pupils.length; index++) ...[
          if (index > 0) const SizedBox(width: _cardGap),
          Expanded(
            child: presences[index].isEmpty ? const SizedBox.shrink() : _buildNamedList(pupils[index], presences[index]),
          ),
        ],
      ],
    );
  }

  // [named] false under the child's own strip, which names the child already.
  Widget _buildNamedList(_Pupil pupil, PupilBandPresence presence, {bool named = true})
  {
    final Widget list = OwnLessonList(entries: _entriesOf(presence, onTimeline: false), nowMinutes: _nowMinutes);

    if (!named)
    {
      return list;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimelineLaneName(name: pupil.firstName),
        const SizedBox(height: _listNameGap),
        list,
      ],
    );
  }

  Widget _buildCard(_Pupil pupil, PupilBandPresence presence, {required bool named})
  {
    if (presence.isEmpty)
    {
      return BandSummaryCard(eyebrow: named ? pupil.firstName : null, title: _nothingTitle, compact: named);
    }

    return PresenceCard(presence: presence, pupilName: named ? pupil.firstName : null, compact: named);
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

    final pupils = _pupils ?? const <_Pupil>[];
    final presences = [for (final pupil in pupils) _presenceOf(pupil)];
    final window = _windowFor(presences);

    if (presences.every((presence) => presence.isEmpty) || window == null)
    {
      return CalendarEmptyBand(
        icon: Icons.free_cancellation_rounded,
        title: kCalendarUnavailableTitle,
        message: kNoLessonsRequested,
      );
    }

    final named = pupils.length > 1;
    final bool dense = AppBreakpoints.of(context).isDense;

    if (named && isNarrow)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < pupils.length; index++) ...[
            if (index > 0) SizedBox(height: dense ? _denseStackGap : _stackGap),
            _buildCard(pupils[index], presences[index], named: true),
            if (!presences[index].isEmpty) ...[
              SizedBox(height: dense ? _denseCardGap : _cardGap),
              _buildNamedList(pupils[index], presences[index], named: !dense),
            ],
          ],
        ],
      );
    }

    return CalendarSplitBody(
      top: DesktopTourTarget(
        id: kTourPupilCalendarCards,
        child: named
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < pupils.length; index++) ...[
                      if (index > 0) SizedBox(width: dense ? _denseCardGap : _cardGap),
                      Expanded(child: _buildCard(pupils[index], presences[index], named: true)),
                    ],
                  ],
                ),
              )
            : _buildCard(pupils.single, presences.single, named: false),
      ),
      day: isNarrow || _layout == CalendarLayout.byLesson
          ? _buildLists(pupils, presences)
          : OwnDayTimeline(
              window: window,
              lanes: [
                for (var index = 0; index < pupils.length; index++)
                  if (!presences[index].isEmpty) _laneOf(pupils[index], presences[index], named: named),
              ],
              nowMinutes: _nowMinutes,
            ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return CalendarPageShell(
      currentRoute: '${homeForRole(widget.role)}/calendar',
      band: _band,
      onBand: _chooseBand,
      day: _day,
      lastDay: _lastDay,
      isFirstDay: _isFirstDay,
      isBusy: _isLoading,
      onDay: _goToDay,
      isClosed: !_isLoading && !_failed && _isDayClosed,
      closureNote: _closureNote,
      tools: (isNarrow) => isNarrow ? const [] : [_buildLayoutPicker()],
      onPickerOpen: _onPickerOpen,
      body: _buildBody,
    );
  }
}
