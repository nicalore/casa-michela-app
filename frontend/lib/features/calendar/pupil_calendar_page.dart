import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/error_message.dart';
import '../../core/utils/rome_clock.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_filter_pill.dart';
import '../../shared/widgets/filter_menu.dart';
import '../../shared/widgets/page_transition.dart';
import '../association/models/ministry_subject_item.dart';
import '../association/models/opening_day_item.dart';
import '../association/tabs/opening_hours/calendar_bounds.dart';
import '../lessons/models/calendar_day.dart';
import '../lessons/models/calendar_publication_item.dart';
import '../lessons/models/lesson_item.dart';
import '../lessons/models/presence_item.dart';
import '../lessons/utils/opening_window.dart';
import '../lessons/utils/timeline_geometry.dart';
import '../lessons/widgets/calendar_lesson_block.dart' show isLessonPast, isLessonRunning;
import '../people/models/person_face.dart';
import 'utils/calendar_strings.dart';
import 'utils/pupil_band_presence.dart';
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

const double _listMaxWidth = 640;

const double _listNameGap = 10;

const double _layoutMenuWidth = 210;

typedef _Pupil = ({String taxCode, String firstName});

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

    _loadDay();
  }

  @override
  void dispose()
  {
    _clock?.cancel();
    super.dispose();
  }

  @override
  void onDestinationShown()
  {
    setState(() => _now = romeNow());

    _loadDay(quiet: true);
  }

  Future<List<_Pupil>> _readPupils() async
  {
    final me = _apiService.lastKnownIdentity ?? await _apiService.me();

    if (!_isParent)
    {
      return [(taxCode: me.taxCode, firstName: me.firstName)];
    }

    final reader = await _apiService.getPerson(me.taxCode);

    final children = await Future.wait([
      for (final child in reader.children ?? const []) _apiService.getPerson(child.fiscalCode),
    ]);

    return [
      for (final child in children.where((child) => child.roles.contains(_pupilRole)).toList()..sort(compareByName))
        (taxCode: child.fiscalCode, firstName: child.firstName),
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

        if (results.length > 6)
        {
          _ministrySubjects = results[6] as List<MinistrySubjectItem>;
        }

        _pupils = pupils;

        _isLoading = false;
        _failed = false;
      });
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
    final DateTime target = normalised.isAfter(_today)
        ? _today
        : (normalised.isBefore(oldest) ? oldest : normalised);

    if (isSameDate(target, _day))
    {
      return;
    }

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

  List<TimelineEntry> _entriesOf(PupilBandPresence presence, {required bool onTimeline})
  {
    return [
      for (final lesson in presence.lessons)
        (
          startMinutes: lesson.startMinutes,
          endMinutes: lesson.endMinutes,
          block: OwnLessonBlock(
            key: ValueKey('lesson-${lesson.id}'),
            lesson: lesson,
            ministrySubjects: _ministrySubjects,
            view: CalendarView.byStudent,
            isPast: isLessonPast(lesson, _now),
            isCurrent: !onTimeline && isLessonRunning(lesson, _now),
            onTimeline: onTimeline,
            onTap: () => _openLesson(lesson),
          ),
        ),
    ];
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
          constraints: const BoxConstraints(maxWidth: _listMaxWidth),
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

  Widget _buildNamedList(_Pupil pupil, PupilBandPresence presence)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimelineLaneName(name: pupil.firstName),
        const SizedBox(height: _listNameGap),
        OwnLessonList(entries: _entriesOf(presence, onTimeline: false), nowMinutes: _nowMinutes),
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

    if (named && isNarrow)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < pupils.length; index++) ...[
            if (index > 0) const SizedBox(height: _stackGap),
            _buildCard(pupils[index], presences[index], named: true),
            if (!presences[index].isEmpty) ...[
              const SizedBox(height: _cardGap),
              _buildNamedList(pupils[index], presences[index]),
            ],
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (named)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < pupils.length; index++) ...[
                  if (index > 0) const SizedBox(width: _cardGap),
                  Expanded(child: _buildCard(pupils[index], presences[index], named: true)),
                ],
              ],
            ),
          )
        else
          _buildCard(pupils.single, presences.single, named: false),
        const SizedBox(height: kCalendarCardGap),
        if (isNarrow || _layout == CalendarLayout.byLesson)
          _buildLists(pupils, presences)
        else
          OwnDayTimeline(
            window: window,
            lanes: [
              for (var index = 0; index < pupils.length; index++)
                if (!presences[index].isEmpty) _laneOf(pupils[index], presences[index], named: named),
            ],
            nowMinutes: _nowMinutes,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return CalendarPageShell(
      currentRoute: '${homeForRole(widget.role)}/calendar',
      band: _band,
      onBand: (band) => setState(() => _band = band),
      day: _day,
      isToday: _isToday,
      isFirstDay: _isFirstDay,
      isBusy: _isLoading,
      onDay: _goToDay,
      isClosed: !_isLoading && !_failed && _isDayClosed,
      closureNote: _closureNote,
      tools: (isNarrow) => isNarrow ? const [] : [_buildLayoutPicker()],
      intro: lessonDetailsHint(verb: 'clicca'),
      body: _buildBody,
    );
  }
}
