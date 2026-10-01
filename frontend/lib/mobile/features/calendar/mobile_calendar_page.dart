import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/ministry_subject_item.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/association/tabs/opening_hours/calendar_bounds.dart';
import '../../../features/calendar/utils/calendar_strings.dart';
import '../../../features/calendar/utils/day_marks_loader.dart';
import '../../../features/calendar/utils/teacher_band_call.dart';
import '../../../features/lessons/models/activity_item.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/models/room_supervision_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/people/models/person_item.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_date_capsule.dart';
import '../../shared/widgets/mobile_month_picker.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import 'mobile_calendar_day.dart';
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

// Never past today: only published days are shown.
class MobileCalendarPage extends StatefulWidget
{
  // The time now; a probe fixes it.
  final DateTime Function() clock;

  const MobileCalendarPage({super.key, this.clock = DateTime.now});

  @override
  State<MobileCalendarPage> createState() => _MobileCalendarPageState();
}

class _MobileCalendarPageState extends State<MobileCalendarPage>
{
  final ApiService _apiService = ApiService();

  // Only the timelines listen: the present moves without rebuilding the page.
  late final ValueNotifier<DateTime> _clock = ValueNotifier(widget.clock());

  Timer? _timer;

  late final PageController _pageController = PageController(initialPage: _bandNow.index);

  late DateTime _day = _today;

  bool _loading = true;
  bool _failed = false;

  MobileCalendarDay? _data;

  List<MinistrySubjectItem> _ministrySubjects = const [];

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

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

  bool get _feminine => _apiService.lastKnownIdentity?.gender == 'F';

  @override
  void initState()
  {
    super.initState();

    _tick();
    _load().whenComplete(MobileHoldScope.hold(context));
  }

  @override
  void dispose()
  {
    _timer?.cancel();
    _clock.dispose();
    _pageController.dispose();

    super.dispose();
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
        if (_ministrySubjects.isEmpty) _apiService.getMinistrySubjects(),
      ]);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        if (results.length > 6)
        {
          _ministrySubjects = results[6] as List<MinistrySubjectItem>;
        }

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
          teacherTaxCode: _apiService.lastKnownIdentity?.taxCode,
        );

        _loading = false;
        _failed = false;
      });

      if (!quiet)
      {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealNow());
      }
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

    if (target.isAfter(_today))
    {
      target = _today;
    }

    if (target.isBefore(oldestKeptDay(_today)))
    {
      target = oldestKeptDay(_today);
    }

    if (isSameDate(target, _day))
    {
      return;
    }

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

    _opening = true;

    // Read before the sheet opens, so it rises at its full height.
    PersonItem? person;

    try
    {
      person = await _apiService.getPerson(student.taxCode);
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
    );
  }

  List<MobileCalendarEntry> _entriesOf(TeacherBandCall call)
  {
    return [
      for (final lesson in call.lessons)
        MobileCalendarEntry.lesson(lesson, _ministrySubjects, onTap: () => _openLesson(lesson)),
      for (final activity in call.activities)
        MobileCalendarEntry.activity(
          activity,
          onTap: () => showMobileActivitySheet(context: context, activity: activity.activity),
        ),
    ];
  }

  String get _dayLabel
  {
    final String label = formatWeekdayColumnLabel(_day);

    return _day.year == _today.year ? label : '$label ${_day.year}';
  }

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
      last: _today,
      loadMarks: (from, to) => loadDayMarks(
        from,
        to,
        lessons: true,
        teacherTaxCode: _apiService.lastKnownIdentity?.taxCode,
      ),
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
        title: shown.inBuilding ? notConvenedTitle(feminine: _feminine) : kNoLessonsTitle,
        message: noOwnLessonsMessage(band),
      );
    }

    final List<MobileCalendarEntry> entries = _entriesOf(shown.call);
    final bool pastDay = _day.isBefore(_today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileConvocationCard(call: shown.call, feminine: _feminine, tablet: tablet, stretched: wide),
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
                entries: entries,
                nowMinutes: nowMinutes,
                pastDay: pastDay,
                nowKey: nowKey,
              );
            }

            return MobileCalendarTimeline(
              window: window,
              entries: entries,
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
          MobileDateCapsule(
            label: _dayLabel,
            current: _isToday,
            tablet: tablet,
            onBack: !_isFirstDay && !_loading ? () => _goToDay(addDays(_day, -1)) : null,
            onForward: !_isToday && !_loading ? () => _goToDay(addDays(_day, 1)) : null,
            onPick: _pickDay,
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
                MobilePageStrip(
                  labels: [for (final band in TimeBucket.values) bandLabel(band)],
                  controller: _pageController,
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
            child: MobileLoadSwitcher(
              waiting: child is MobileWaiting,
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
