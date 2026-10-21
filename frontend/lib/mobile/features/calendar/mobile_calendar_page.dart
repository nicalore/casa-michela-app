import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/ministry_subject_item.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/association/tabs/opening_hours/calendar_bounds.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/calendar/utils/calendar_strings.dart';
import '../../../features/calendar/utils/day_marks_loader.dart';
import '../../../features/calendar/utils/teacher_band_call.dart';
import '../../../features/calendar/utils/viewable_days.dart';
import '../../../features/calendar/widgets/teacher_note_dialog.dart' show lessonHasBegun;
import '../../../features/lessons/models/activity_item.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/models/room_supervision_item.dart';
import '../../../features/lessons/utils/calendar_jump.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/notifications/calendar_seen.dart';
import '../../../features/people/models/person_item.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_date_capsule.dart';
import '../../shared/widgets/mobile_month_picker.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_calendar_day.dart';
import 'mobile_calendar_tour.dart';
import 'widgets/mobile_calendar_notice.dart';
import 'widgets/mobile_calendar_timeline.dart';
import 'widgets/mobile_convocation_card.dart';
import 'widgets/mobile_lesson_card.dart';
import 'widgets/mobile_lesson_sheet.dart';

const String _title = 'Calendario';

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _headerGap = 12;
const double _stripGap = 14;
const double _cardGap = 14;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

// Room between the strip's rule and the card.
const double _topRoom = 16;

// Fraction down the visible area where the present lands on open.
const double _nowAlignment = 0.4;

const Duration _pageTurn = Duration(milliseconds: 320);

const String _teacherRole = 'TEACHER';

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

const EdgeInsets _tourBandsInflate = EdgeInsets.fromLTRB(10, 2, 10, 0);
const double _tourBandsRadius = 22;
const EdgeInsets _tourDayInflate = EdgeInsets.all(5);
const double _tourDayRadius = 30;
const EdgeInsets _tourCardInflate = EdgeInsets.all(5);
const double _tourCardRadius = 27;

// Never past today: only published days are shown.
class MobileCalendarPage extends StatefulWidget
{
  // Kept past sign-out: the shell clears the identity before the page leaves.
  final MeResponse user;

  // The time now; a probe fixes it.
  final DateTime Function() clock;

  const MobileCalendarPage({super.key, required this.user, this.clock = romeNow});

  @override
  State<MobileCalendarPage> createState() => _MobileCalendarPageState();
}

class _MobileCalendarPageState extends State<MobileCalendarPage>
{
  final ApiService _apiService = ApiService();

  // Only the timelines listen: the present moves without rebuilding the page.
  late final ValueNotifier<DateTime> _clock = ValueNotifier(widget.clock());

  Timer? _timer;

  // Opened from a notification: its day and band instead of the clock's.
  final CalendarJump? _openedFor = CalendarJumps.role.take(role: _teacherRole);

  late final PageController _pageController = PageController(initialPage: (_openedFor?.band ?? _bandNow).index);

  late DateTime _day = _openedFor?.day ?? _today;

  // Today, or tomorrow once one of its bands is published.
  late DateTime _lastDay = _today;

  List<CalendarPublicationItem> _publications = const [];

  bool _loading = true;
  bool _failed = false;

  MobileCalendarDay? _data;

  List<MinistrySubjectItem> _ministrySubjects = const [];

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  bool _revealed = false;

  // Set once the page is in place; then every load, band change and closed sheet looks for a tour.
  bool _toured = false;
  int? _pageSeen;

  // Not disposed: a sheet closing after the page still tells it.
  final LessonSheetTourLink _sheetLink = LessonSheetTourLink();

  // Drops taps while a lesson's student is being fetched.
  bool _opening = false;

  final GlobalKey _nowKey = GlobalKey();
  final GlobalKey<NestedScrollViewState> _nestedKey = GlobalKey();

  DateTime get _today
  {
    final DateTime now = _clock.value;

    return DateTime(now.year, now.month, now.day);
  }

  TimeBucket get _bandNow => bucketFor(TimeOfDay.fromDateTime(_clock.value)) ?? TimeBucket.afternoon;

  bool get _isToday => isSameDate(_day, _today);

  bool get _isFirstDay => !_day.isAfter(oldestKeptDay(_today));

  bool get _feminine => widget.user.gender == 'F';

  @override
  void initState()
  {
    super.initState();

    _tick();
    _load().whenComplete(MobileHoldScope.hold(context));
    _pageController.addListener(_onPage);
    MobileNavSheet.hidden.addListener(_onSheets);
    MobileNavSheet.openness.addListener(_onSheets);
    mobileTourChanges.addListener(_tourLater);
    _sheetLink.addListener(_onLessonSheet);
    CalendarJumps.role.asked.addListener(_jump);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_toured && mobileTourSettled(context))
    {
      _toured = true;
      _tourLater();
    }
  }

  @override
  void dispose()
  {
    _timer?.cancel();
    CalendarJumps.role.asked.removeListener(_jump);
    _sheetLink.removeListener(_onLessonSheet);
    mobileTourChanges.removeListener(_tourLater);
    MobileNavSheet.openness.removeListener(_onSheets);
    MobileNavSheet.hidden.removeListener(_onSheets);
    _clock.dispose();
    _pageController.dispose();

    super.dispose();
  }

  // Asks for the frame too: the page may be still.
  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_)
      {
        _tourCheck();
        _noteSeen();
      })
      ..scheduleFrame();
  }

  // Already open: turned to the day and band a notification asks for.
  void _jump()
  {
    final CalendarJump? jump = CalendarJumps.role.take(role: _teacherRole);

    if (jump == null || !mounted)
    {
      return;
    }

    if (_pageController.hasClients)
    {
      _pageController.animateToPage(jump.band.index, duration: _pageTurn, curve: Curves.easeInOutCubic);
    }

    _reload(jump.day);
  }

  // A published band settled on screen, with no menu or sheet over it, takes its notification away.
  void _noteSeen()
  {
    if (!mounted ||
        !_toured ||
        _loading ||
        _failed ||
        MobileNavSheet.hidden.value ||
        MobileNavSheet.openness.value > 0 ||
        !_pageController.hasClients)
    {
      return;
    }

    final double page = _pageController.page ?? _pageController.initialPage.toDouble();
    final TimeBucket band = TimeBucket.values[page.round()];

    if ((page - page.round()).abs() >= _settled ||
        !_publications.any((row) => isSameDate(row.date, _day) && row.band == band))
    {
      return;
    }

    unawaited(markCalendarSeen(_day, band));
  }

  void _onPage()
  {
    final double page = _pageController.page ?? 0;

    if ((page - page.round()).abs() < _settled && page.round() != _pageSeen)
    {
      _pageSeen = page.round();
      _tourLater();
    }
  }

  void _onSheets()
  {
    if (!MobileNavSheet.hidden.value)
    {
      _tourLater();
    }
  }

  // The earliest lesson of a band the teacher is convened in, which a tour lights.
  LessonItem? _firstLessonOf(MobileCalendarBand band)
  {
    if (band.state != MobileCalendarBandState.convened || band.call.lessons.isEmpty)
    {
      return null;
    }

    return band.call.lessons.reduce((a, b) => b.startMinutes < a.startMinutes ? b : a);
  }

  // The band in sight if the teacher is convened there, else the first one with a lesson.
  TimeBucket? _calledBand(MobileCalendarDay data, int page)
  {
    final TimeBucket here = TimeBucket.values[page];

    if (_firstLessonOf(data.bandOf(here)) != null)
    {
      return here;
    }

    return TimeBucket.values.where((band) => _firstLessonOf(data.bandOf(band)) != null).firstOrNull;
  }

  // Bands and day picker on the first visit; the call and a lesson the first time one is shown.
  Future<void> _tourCheck() async
  {
    final MobileCalendarDay? data = _data;

    if (!mounted ||
        !_toured ||
        _loading ||
        _failed ||
        data == null ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value ||
        !_pageController.hasClients)
    {
      return;
    }

    final double page = _pageController.page ?? _pageController.initialPage.toDouble();

    if ((page - page.round()).abs() >= _settled)
    {
      return;
    }

    final String taxCode = widget.user.taxCode;
    final bool main = !await isCalendarMainTourSeen(taxCode);
    final bool call = !await isCalendarCallTourSeen(taxCode);
    final TimeBucket? band = call ? _calledBand(data, page.round()) : null;

    if (!mounted || (!main && band == null))
    {
      return;
    }

    // Shown where the call is.
    if (band != null && band.index != page.round())
    {
      _pageController.animateToPage(band.index, duration: _pageTurn, curve: Curves.easeInOutCubic);

      return;
    }

    final LessonItem? lesson = band == null ? null : _firstLessonOf(data.bandOf(band));

    await startMobileTourOnce(
      taxCode: taxCode,
      tour: calendarTour(
        main: main,
        band: band,
        sheetMarks: band == null ? const {} : await unseenLessonSheetMarks(taxCode),
        sheet: _sheetLink,
        student: !_day.isBefore(_today),
        note: lesson != null && lessonHasBegun(lesson, _clock.value),
      ),
    );
  }

  // A lesson's sheet up outside a tour: its parts never seen, the first time they show.
  void _onLessonSheet()
  {
    if (!_sheetLink.open)
    {
      return;
    }

    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _sheetTourCheck())
      ..scheduleFrame();
  }

  Future<void> _sheetTourCheck() async
  {
    if (!mounted || isMobileTourShown || !_sheetLink.open)
    {
      return;
    }

    final Set<LessonSheetMark> marks = await unseenLessonSheetMarks(widget.user.taxCode);

    if (!mounted || marks.isEmpty || isMobileTourShown || !_sheetLink.open)
    {
      return;
    }

    final MobileTour tour = calendarTour(
      main: false,
      band: null,
      sheetMarks: marks,
      sheet: _sheetLink,
      opened: true,
    );

    if (tour.steps.any((step) => step.isPresent))
    {
      await startMobileTourOnce(taxCode: widget.user.taxCode, tour: tour);
    }
  }

  // Wakes on the minute, not every 60 s from whenever the page opened.
  void _tick()
  {
    final DateTime now = widget.clock();
    final bool newDay = !isSameDate(now, _clock.value);

    _clock.value = now;

    if (newDay && mounted)
    {
      setState(() {});
    }

    _timer?.cancel();
    _timer = Timer(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond), _tick);
  }

  Future<void> _load({bool quiet = false}) async
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
        if (results.length > 9)
        {
          _ministrySubjects = results[9] as List<MinistrySubjectItem>;
        }

        _publications = results[2] as List<CalendarPublicationItem>;
        _lastDay = lastViewableDay(_today, results[8] as List<CalendarPublicationItem>);

        _data = calendarDayFrom(
          day: day,
          openingDays: [
            ...results[0] as List<OpeningDayItem>,
            ...results[1] as List<OpeningDayItem>,
          ],
          publications: results[2] as List<CalendarPublicationItem>,
          lessons: results[3] as List<LessonItem>,
          activities: results[4] as List<ActivityItem>,
          supervisions: results[5] as List<RoomSupervisionItem>,
          availabilities: results[6] as List<AvailabilityItem>,
          unbooked: results[7] as List<(DateTime, TimeBucket)>,
          teacherTaxCode: widget.user.taxCode,
        );

        _loading = false;
        _failed = false;
      });

      if (!_revealed)
      {
        _revealed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealNow());
      }

      _tourLater();
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
        _loading = false;
        _failed = !quiet || _failed;
      });
    }
  }

  // By hand: ensureVisible also scrolls the outer view, whose jump resets the page.
  void _revealNow()
  {
    final BuildContext? target = _nowKey.currentContext;
    final NestedScrollViewState? nested = _nestedKey.currentState;

    if (!mounted || target == null || nested == null)
    {
      return;
    }

    final RenderBox box = target.findRenderObject()! as RenderBox;
    final double top = box.localToGlobal(Offset.zero).dy;

    final double visibleTop = MediaQuery.paddingOf(context).top;
    final double visibleBottom = MediaQuery.sizeOf(context).height - MobileNavSheet.collapsedHeightFor(context);

    if (top + box.size.height <= visibleBottom - _handleClearance)
    {
      return;
    }

    final double wanted = visibleTop + (visibleBottom - visibleTop) * _nowAlignment - box.size.height / 2;

    // Scroll the header away first, then the page.
    final ScrollPosition outer = nested.outerController.position;
    final ScrollPosition inner = Scrollable.of(target).position;
    final double scrolled = outer.pixels + inner.pixels + top - wanted;

    if (scrolled <= outer.maxScrollExtent)
    {
      outer.jumpTo(scrolled);
    }
    else
    {
      inner.jumpTo(math.min(scrolled - outer.maxScrollExtent, inner.maxScrollExtent));
    }
  }

  void _goToDay(DateTime day)
  {
    DateTime target = DateTime(day.year, day.month, day.day);

    if (target.isAfter(_lastDay))
    {
      target = _lastDay;
    }

    if (target.isBefore(oldestKeptDay(_today)))
    {
      target = oldestKeptDay(_today);
    }

    _showDay(target);
  }

  // The same day read again quietly, another one in full.
  void _showDay(DateTime target)
  {
    if (isSameDate(target, _day))
    {
      _load(quiet: true);

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
      _loading = true;
      _failed = false;
    });

    _load();
  }

  Future<void> _openLesson(LessonItem lesson) async
  {
    final student = lesson.bookings.firstOrNull?.presence.student;

    if (student == null || _opening)
    {
      return;
    }

    // Past lessons show alone: the student is not fetched.
    final bool past = lesson.date.isBefore(_today);

    _opening = true;

    // Read before the sheet opens, so it rises at its full height.
    PersonItem? person;

    try
    {
      person = past ? null : await _apiService.getPerson(student.taxCode);
    }
    catch (_) {}

    _opening = false;

    if (!mounted)
    {
      return;
    }

    await showMobileLessonSheet(
      context: context,
      lesson: lesson,
      ministrySubjects: _ministrySubjects,
      student: person,
      withStudent: !past,
      tourLink: _sheetLink,
    );
  }

  List<MobileCalendarEntry> _entriesOf(MobileCalendarBand band)
  {
    final TeacherBandCall call = band.call;
    final LessonItem? first = _firstLessonOf(band);

    return [
      for (final lesson in call.lessons)
        MobileCalendarEntry.lesson(
          lesson,
          _ministrySubjects,
          onTap: () => _openLesson(lesson),
          tourId: identical(lesson, first) ? calendarTourLesson(band.band) : null,
          showsRoom: call.changesRoom,
        ),
      for (final activity in call.activities)
        MobileCalendarEntry.activity(
          activity,
          onTap: () => showMobileActivitySheet(context: context, activity: activity.activity),
        ),
    ];
  }

  String _withYear(String label) => _day.year == _today.year ? label : '$label ${_day.year}';

  String get _dayLabel => _withYear(formatWeekdayColumnLabel(_day));

  Widget _buildTitle({required bool tablet})
  {
    return Text(
      _title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 36 : 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: Colors.white,
      ),
    );
  }

  Future<void> _pickDay() async
  {
    final DateTime? picked = await showMobileMonthPicker(
      context: context,
      selected: _day,
      today: _today,
      first: oldestKeptDay(_today),
      last: _lastDay,
      loadMarks: (from, to) => loadDayMarks(from, to, published: true),
      tourDays: kCalendarTourPickerDays,
      onShown: () => startMobileTourOnce(taxCode: widget.user.taxCode, tour: calendarPickerTour()),
    );

    if (picked != null && mounted)
    {
      _goToDay(picked);
    }
  }

  Widget _buildBand(TimeBucket band, {required bool tablet, required bool wide})
  {
    if (_loading)
    {
      return const MobileWaiting();
    }

    final MobileCalendarDay? data = _data;

    if (_failed || data == null)
    {
      return const _Status(kCalendarLoadFailed);
    }

    if (data.closed)
    {
      return MobileCalendarNotice(
        icon: Icons.event_busy_rounded,
        title: kAssociationClosedTitle,
        message: data.closureNote,
      );
    }

    final MobileCalendarBand shown = data.bandOf(band);
    final (int, int)? window = shown.window;

    if (shown.state == MobileCalendarBandState.closed)
    {
      return const MobileCalendarNotice(icon: Icons.event_busy_rounded, title: kAssociationClosedTitle);
    }

    if (shown.state == MobileCalendarBandState.unpublished)
    {
      return MobileCalendarNotice(
        icon: Icons.pending_actions_rounded,
        title: kCalendarUnpublishedTitle,
        message: unpublishedBandMessage(band),
      );
    }

    if (shown.state == MobileCalendarBandState.empty || window == null)
    {
      return MobileCalendarNotice(
        icon: Icons.free_cancellation_rounded,
        title: kCalendarUnavailableTitle,
        message: shown.offered ? notConvenedSentence(feminine: _feminine) : kNoAvailabilityGiven,
      );
    }

    final List<MobileCalendarEntry> entries = _entriesOf(shown);
    final bool pastDay = _day.isBefore(_today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileTourTarget(
          id: calendarTourCard(band),
          inflate: _tourCardInflate,
          radius: _tourCardRadius,
          child: MobileConvocationCard(call: shown.call, feminine: _feminine, tablet: tablet, stretched: wide),
        ),
        const SizedBox(height: _cardGap),
        ValueListenableBuilder<DateTime>(
          valueListenable: _clock,
          builder: (context, now, _)
          {
            final bool today = isSameDate(now, _day);
            final int? nowMinutes = today ? now.hour * 60 + now.minute : null;

            // The GlobalKey may sit on one pill only: the running band's.
            final Key? nowKey = today && band == _bandNow ? _nowKey : null;

            if (wide)
            {
              return MobileCalendarTrack(
                window: window,
                lanes: [MobileCalendarColumn(entries: entries)],
                nowMinutes: nowMinutes,
                pastDay: pastDay,
                nowKey: nowKey,
              );
            }

            return MobileCalendarTimeline(
              window: window,
              columns: [MobileCalendarColumn(entries: entries)],
              nowMinutes: nowMinutes,
              pastDay: pastDay,
              tablet: tablet,
              nowKey: nowKey,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final bool wide = tablet && MediaQuery.orientationOf(context) == Orientation.landscape;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    final bool closed = !_loading && !_failed && (_data?.closed ?? false);

    // Ignores loading so the bands keep their last state while the next day loads.
    final bool folded = !_failed && (_data?.closed ?? false);

    final Widget header = Padding(
      padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitle(tablet: tablet),
          const SizedBox(height: _headerGap),
          MobileTourTarget(
            id: kCalendarTourDay,
            inflate: _tourDayInflate,
            radius: _tourDayRadius,
            child: MobileDateCapsule(
              label: _dayLabel,
              widestLabel: _withYear(kWidestDayLabel),
              current: _isToday,
              tablet: tablet,
              onBack: !_isFirstDay && !_loading ? () => _goToDay(addDays(_day, -1)) : null,
              onForward: _day.isBefore(_lastDay) && !_loading ? () => _goToDay(addDays(_day, 1)) : null,
              onPick: _pickDay,
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: folded ? 0 : 1),
            duration: mobileRiseDurationOf(context),
            curve: Curves.easeOutCubic,
            builder: (context, shown, strip) => ClipRect(
              clipBehavior: shown < 1 ? Clip.hardEdge : Clip.none,
              child: Align(alignment: Alignment.topCenter, heightFactor: shown, child: strip),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: _stripGap),
                // Lit with all it shows below, down to the screen's bottom.
                MobileTourTarget(
                  id: kCalendarTourBands,
                  inflate: _tourBandsInflate,
                  radius: _tourBandsRadius,
                  toBottom: true,
                  child: MobilePageStrip(
                    labels: [for (final band in TimeBucket.values) bandLabel(band)],
                    controller: _pageController,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        key: _nestedKey,
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        body: PageView(
          controller: _pageController,
          physics: closed ? const NeverScrollableScrollPhysics() : null,
          children: [
            for (final band in TimeBucket.values)
              _scrollable(_buildBand(band, tablet: tablet, wide: wide), side: margin, bottom: bottom),
          ],
        ),
      ),
    );
  }

  // Margin inside the scroll view so card shadows are not clipped while paging.
  Widget _scrollable(Widget child, {required double side, required double bottom})
  {
    final bool centred = child is MobileCalendarNotice || child is MobileWaiting;

    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: () => _load(quiet: true),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            clipBehavior: Clip.none,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, _topRoom, side, bottom),
            // No rise when a day comes in: the calendar is simply there.
            child: centred
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - _topRoom - bottom),
                    ),
                    child: Center(
                      child: SizedBox(width: MobileNavSheet.tabletWidth, child: child),
                    ),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget
{
  final String text;

  const _Status(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
