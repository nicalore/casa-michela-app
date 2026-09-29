import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/dashboard/widgets/dashboard_greeting.dart';
import '../../../features/home/models/month_summary_items.dart';
import '../../../features/lessons/models/activity_item.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import 'mobile_teacher_day.dart';
import 'widgets/mobile_day_timeline.dart';
import 'widgets/mobile_month_figures.dart';
import 'widgets/mobile_notices_list.dart';

const List<String> _pages = ['Oggi', 'Questo mese', 'Notifiche e avvisi'];

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _headerGap = 14;
const double _stripGap = 14;
const double _columnGap = 24;
const double _sectionGap = 26;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

// Room above the first card for its shadow.
const double _shadowRoom = 20;

// Height of one band of the day line.
const double _phoneBandHeight = 182;
const double _wideBandHeight = 196;

// Failures become null so one bad call does not fail the whole day.
Future<T?> _quiet<T>(Future<T> future)
{
  return future.then<T?>((value) => value).catchError((_) => null);
}

class MobileTeacherHomePage extends StatefulWidget
{
  const MobileTeacherHomePage({super.key});

  @override
  State<MobileTeacherHomePage> createState() => _MobileTeacherHomePageState();
}

class _MobileTeacherHomePageState extends State<MobileTeacherHomePage>
{
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  bool _loadingDay = true;
  MobileTeacherDay? _day;

  bool _loadingMonth = true;
  TeacherMonthSummaryItem? _month;

  // Bumped on every fetch so a stale response is dropped.
  int _dayRequest = 0;
  int _monthRequest = 0;

  @override
  void initState()
  {
    super.initState();
    _reload();
  }

  @override
  void dispose()
  {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _reload()
  {
    return Future.wait([_loadDay(), _loadMonth()]);
  }

  // Any failed reading leaves _day null ("unknown"), distinct from a closed day.
  Future<void> _loadDay() async
  {
    final int request = ++_dayRequest;

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final Future<List<OpeningDayItem>?> inBuildingFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kPresenceMode));
    final Future<List<OpeningDayItem>?> onScreenFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kOnlineMode));
    final Future<List<CalendarPublicationItem>?> publicationsFuture =
        _quiet(_apiService.getCalendarPublications(dateFrom: today, dateTo: today));
    final Future<List<AvailabilityItem>?> availabilitiesFuture =
        _quiet(_apiService.getAvailabilities(dateFrom: today, dateTo: today));
    final Future<List<LessonItem>?> lessonsFuture =
        _quiet(_apiService.getLessons(dateFrom: today, dateTo: today));
    final Future<List<ActivityItem>?> activitiesFuture =
        _quiet(_apiService.getCalendarActivities(dateFrom: today, dateTo: today));

    final inBuilding = await inBuildingFuture;
    final onScreen = await onScreenFuture;
    final publications = await publicationsFuture;
    final availabilities = await availabilitiesFuture;
    final lessons = await lessonsFuture;
    final activities = await activitiesFuture;

    if (!mounted || request != _dayRequest)
    {
      return;
    }

    MobileTeacherDay? day;

    if (inBuilding != null &&
        onScreen != null &&
        publications != null &&
        availabilities != null &&
        lessons != null &&
        activities != null)
    {
      day = teacherDayFrom(
        day: today,
        openingDays: [...inBuilding, ...onScreen],
        publications: publications,
        availabilities: availabilities,
        lessons: lessons,
        activities: activities,
        teacherTaxCode: _apiService.lastKnownIdentity?.taxCode,
      );
    }

    setState(()
    {
      _day = day;
      _loadingDay = false;
    });
  }

  Future<void> _loadMonth() async
  {
    final int request = ++_monthRequest;

    final TeacherMonthSummaryItem? month = await _quiet(_apiService.getTeacherMonth());

    if (!mounted || request != _monthRequest)
    {
      return;
    }

    setState(()
    {
      _month = month;
      _loadingMonth = false;
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final MeResponse? user = _apiService.lastKnownIdentity;

    return MobileTeacherHomeView(
      firstName: user?.firstName ?? '',
      birthDate: user?.birthDate,
      feminine: user?.gender == 'F',
      loadingDay: _loadingDay,
      day: _day,
      loadingMonth: _loadingMonth,
      month: _month,
      onRefresh: _reload,
      pageController: _pageController,
    );
  }
}

// Data-free so the simulator probe can feed it directly.
class MobileTeacherHomeView extends StatelessWidget
{
  final String firstName;
  final DateTime? birthDate;
  final bool feminine;

  final bool loadingDay;
  final MobileTeacherDay? day;

  final bool loadingMonth;
  final TeacherMonthSummaryItem? month;

  final Future<void> Function() onRefresh;
  final PageController pageController;

  const MobileTeacherHomeView({
    super.key,
    required this.firstName,
    required this.birthDate,
    required this.feminine,
    required this.loadingDay,
    required this.day,
    required this.loadingMonth,
    required this.month,
    required this.onRefresh,
    required this.pageController,
  });

  Widget _buildHeader({required bool tablet})
  {
    final DateTime now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatWeekdayColumnLabel(now).toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 12.5 : 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          greetingLineFor(firstName: firstName, birthDate: birthDate, now: now),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 36 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.05,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // fill stretches the last band so the line reaches the column's bottom.
  Widget _buildToday({required bool wide, bool fill = false})
  {
    if (loadingDay)
    {
      return const MobileWaiting();
    }

    final MobileTeacherDay? today = day;

    if (today == null)
    {
      return const _Status('Gli orari di oggi non sono disponibili.');
    }

    if (today.isClosed)
    {
      return const _Closed();
    }

    return MobileDayTimeline(
      day: today,
      feminine: feminine,
      minBandHeight: wide ? _wideBandHeight : _phoneBandHeight,
      fill: fill,
    );
  }

  Widget _buildMonth()
  {
    if (loadingMonth)
    {
      return const MobileWaiting();
    }

    final TeacherMonthSummaryItem? summary = month;

    if (summary == null)
    {
      return const _Status('Il riepilogo del mese non è disponibile.');
    }

    return MobileMonthFigures(month: summary);
  }

  // Margin inside the scroll view so card shadows are not clipped while paging.
  Widget _scrollable(Widget child, {required double side, required double bottom, Widget? head})
  {
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, head == null ? _shadowRoom : 0, side, bottom),
          child: head == null
              ? child
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    head,
                    const SizedBox(height: _shadowRoom),
                    child,
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final MobileFormFactor factor = MobileBreakpoints.of(context);
    final bool tablet = factor.isTablet;
    final bool wide = tablet && MediaQuery.orientationOf(context) == Orientation.landscape;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    if (tablet)
    {
      return SafeArea(
        bottom: false,
        child: _buildTabletBody(wide: wide, side: margin, bottom: bottom),
      );
    }

    final Widget head = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(tablet: false),
        const SizedBox(height: _headerGap),
        MobilePageStrip(labels: _pages, controller: pageController),
      ],
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, 4, margin, _stripGap),
              child: head,
            ),
          ),
        ],
        body: PageView(
          controller: pageController,
          children: [
            _scrollable(MobileLoadSwitcher(child: _buildToday(wide: false)), side: margin, bottom: bottom),
            _scrollable(MobileLoadSwitcher(child: _buildMonth()), side: margin, bottom: bottom),
            _scrollable(const MobileNoticesList(), side: margin, bottom: bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child, {bool fill = false})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobilePageLabel(text: title),
        const SizedBox(height: _stripGap),
        if (fill) Expanded(child: child) else child,
      ],
    );
  }

  Widget _buildTabletBody({required bool wide, required double side, required double bottom})
  {
    return _scrollable(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Columns end level: the day line stretches to the month's height.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: wide ? 11 : 10,
                  child: _buildSection(
                    _pages[0],
                    MobileLoadSwitcher(child: _buildToday(wide: wide, fill: true)),
                    fill: true,
                  ),
                ),
                const SizedBox(width: _columnGap),
                Expanded(
                  flex: 10,
                  child: _buildSection(_pages[1], MobileLoadSwitcher(child: _buildMonth())),
                ),
              ],
            ),
          ),
          const SizedBox(height: _sectionGap),
          _buildSection(_pages[2], const MobileNoticesList()),
        ],
      ),
      side: side,
      bottom: bottom,
      head: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildHeader(tablet: true),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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

class _Closed extends StatelessWidget
{
  const _Closed();

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy_rounded, size: 26, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "L'Associazione è chiusa",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Nessuna apertura prevista.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
