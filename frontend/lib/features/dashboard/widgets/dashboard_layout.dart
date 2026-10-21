import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/opening_day_item.dart';
import '../../association/notices/notice_item.dart';
import '../../association/notices/notice_reading.dart';
import '../../auth/models/me_response.dart';
import '../../home/widgets/home_notices_section.dart';
import '../../home/widgets/role_home_layout.dart' show homeBeside;
import '../../lessons/models/activity_item.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/models/calendar_publication_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../people/models/current_totals_item.dart';
import '../../people/models/person_item.dart';
import 'dashboard_birthdays_section.dart';
import 'dashboard_greeting.dart';
import '../../notifications/notification_board.dart';
import '../../notifications/widgets/desktop_notifications_offer.dart';
import '../../notifications/widgets/home_notifications_section.dart';
import 'dashboard_section_card.dart';
import 'dashboard_stats_section.dart';
import 'dashboard_today_section.dart';

// Widget tests run with kIsWeb false; this forces the web layout they target.
@visibleForTesting
bool debugAlwaysUseWebDashboard = false;

class DashboardLayout extends StatefulWidget
{
  final double width;
  final double height;

  const DashboardLayout({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> with DestinationRefresh
{
  static const double _tabletBreakpoint = 600.0;

  static const double _greetingBottomGap = 12;
  static const double _sectionGap = 16;

  // The greeting sits nearer the bar than other pages' content: the home must fit one screen.
  static const double _greetingTopGap = 16;

  static const double _maxContentWidth = 1600;

  // Below this width the cards stack.
  static const double _besideFrom = 1150;
  static const double _leftShare = 0.6;
  static const double _tasksFloor = 520;

  static const double _twoColumnsFrom = 700;

  // Two to a row under the notifications.
  static const int _birthdaysShown = 4;

  static const double _denseGreetingBottomGap = 8;
  static const double _denseSectionGap = 12;
  static const double _denseGreetingTopGap = 14;
  static const double _minimalGreetingTopGap = 12;

  static const double _narrowLeftShare = 0.52;

  // Where the page scrolls, the notifications show the newest few.
  static const int _cappedTasks = 4;

  // On a short laptop two rows of notices leave the rest of the left column room.
  static const int _compactNotices = 4;

  final ApiService _apiService = ApiService();

  bool _loadingUser = true;
  MeResponse? _currentUser;

  bool _loadingHome = true;
  CurrentTotalsItem? _totals;
  CurrentTotalsItem? _teacherTotals;
  CurrentTotalsItem? _studentTotals;
  List<DashboardBirthday> _birthdays = [];

  bool _loadingToday = true;
  List<DashboardBandStatus>? _bands;

  bool _loadingNotices = true;
  List<NoticeHeadlineItem>? _notices;

  // Bumped per fetch so a stale response cannot overwrite fresher data.
  int _homeRequest = 0;
  int _todayRequest = 0;
  int _noticesRequest = 0;

  @override
  void initState()
  {
    super.initState();

    // Seeded from the last known identity: no spinner in the top bar on return.
    _currentUser = _apiService.lastKnownIdentity;
    _loadingUser = _currentUser == null;

    _loadCurrentUser();
    _loadHomeData();
    _loadTodayData();
    _loadNotices();
    NotificationBoard.instance.load();

    WidgetsBinding.instance.addPostFrameCallback((_) => offerNotificationsOnce(context));
  }

  // Refreshes without clearing: the loaders only ever switch the spinner off.
  @override
  void onDestinationShown()
  {
    _loadCurrentUser();
    _loadHomeData();
    _loadTodayData();
    _loadNotices();
    NotificationBoard.instance.load();
    offerNotificationsOnce(context);
  }

  // Only those sent to the administrators.
  Future<void> _loadNotices() async
  {
    final int request = ++_noticesRequest;
    List<NoticeHeadlineItem>? notices;

    try
    {
      notices = await _apiService.getHomeNotices('ADMIN');
    }
    catch (_)
    {
      notices = null;
    }

    if (!mounted || request != _noticesRequest)
    {
      return;
    }

    setState(()
    {
      _notices = notices;
      _loadingNotices = false;
    });
  }

  // Restricted endpoints: a failure renders as missing data, not an error page.
  Future<void> _loadHomeData() async
  {
    final int request = ++_homeRequest;

    final results = await Future.wait([
      _apiService.getCurrentTotals().then<Object?>((value) => value).catchError((_) => null),
      _apiService.getRoleCurrentTotals('teacher').then<Object?>((value) => value).catchError((_) => null),
      _apiService.getRoleCurrentTotals('student').then<Object?>((value) => value).catchError((_) => null),
      _apiService.getPeople().then<Object?>((value) => value).catchError((_) => null),
    ]);

    if (!mounted || request != _homeRequest)
    {
      return;
    }

    setState(()
    {
      _totals = results[0] as CurrentTotalsItem?;
      _teacherTotals = results[1] as CurrentTotalsItem?;
      _studentTotals = results[2] as CurrentTotalsItem?;
      _birthdays = upcomingBirthdays(
        (results[3] as List<PersonItem>?) ?? const [],
        limit: _birthdaysShown,
      );
      _loadingHome = false;
    });
  }

  // _bands stays null ("unknown") when hours cannot be read, unlike an empty day.
  Future<void> _loadTodayData() async
  {
    final int request = ++_todayRequest;

    final DateTime now = romeNow();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      _apiService
          .getOpeningDays(dateFrom: today, dateTo: today, mode: kPresenceMode)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _apiService
          .getOpeningDays(dateFrom: today, dateTo: today, mode: kOnlineMode)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _apiService
          .getAvailabilities(dateFrom: today, dateTo: today)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _apiService
          .getPresences(dateFrom: today, dateTo: today)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _apiService
          .getLessons(dateFrom: today, dateTo: today)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _apiService
          .getCalendarPublications(dateFrom: today, dateTo: today)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _apiService
          .getCalendarActivities(dateFrom: today, dateTo: today)
          .then<Object?>((value) => value)
          .catchError((_) => null),
    ]);

    if (!mounted || request != _todayRequest)
    {
      return;
    }

    // Both opening modes or neither: one missing would misreport the day.
    final inBuilding = results[0] as List<OpeningDayItem>?;
    final onScreen = results[1] as List<OpeningDayItem>?;

    setState(()
    {
      _bands = inBuilding == null || onScreen == null
          ? null
          : openBands(
              day: today,
              openingDays: [...inBuilding, ...onScreen],
              availabilities: (results[2] as List<AvailabilityItem>?) ?? const [],
              presences: (results[3] as List<PresenceItem>?) ?? const [],
              lessons: (results[4] as List<LessonItem>?) ?? const [],
              activities: (results[6] as List<ActivityItem>?) ?? const [],
              publications: (results[5] as List<CalendarPublicationItem>?) ?? const [],
            );
      _loadingToday = false;
    });
  }

  Future<void> _loadCurrentUser() async
  {
    try
    {
      final user = _apiService.lastKnownIdentity ?? await _apiService.me();

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _currentUser = user;
        _loadingUser = false;
      });
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _loadingUser = false);
    }
  }

  // Native layout only; the web logout lives in AppTopBar.
  // Local session cleanup happens only if the server call succeeds.
  Future<void> _logout() async
  {
    try
    {
      await _apiService.logout();
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);

      return;
    }

    if (!mounted)
    {
      return;
    }

    context.go('/login');
  }

  // kIsWeb is true in phone browsers too: every web build gets the absolute layout.
  // index.html scales it for touch devices; the native layout is Android/iOS only.
  @override
  Widget build(BuildContext context)
  {
    if (_loadingUser)
    {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.trialTealDeep),
      );
    }

    return kIsWeb || debugAlwaysUseWebDashboard
        ? _buildWebLayout(context)
        : _buildNativeLayout(context);
  }

  Widget _buildNativeLayout(BuildContext context)
  {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > _tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.trialPaper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Ciao, ${_currentUser?.firstName ?? ''}',
          style: const TextStyle(
            color: AppTheme.trialOcean,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: AppTheme.trialTealDeep,
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => ScrollEdgeFade(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildHome(constraints.maxWidth - 32, AppBreakpoints.of(context)),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isTablet ? null : _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation()
  {
    return BottomNavigationBar(
      selectedItemColor: AppTheme.trialTealDeep,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Persone'),
      ],
      onTap: (index)
      {
        if (index == 1)
        {
          context.go('/people');
        }
      },
    );
  }

  // Slot is the card's reading-order position.
  Widget _staggered({required int slot, required Widget card})
  {
    return PageTransitionItem(slot: PageTransitionItem.header + slot, child: card);
  }

  Widget _todayCard()
  {
    final DateTime now = romeNow();

    return _staggered(
      slot: 0,
      card: DashboardTodaySection(
        bands: _bands,
        isLoading: _loadingToday,
        day: DateTime(now.year, now.month, now.day),
      ),
    );
  }

  Widget _noticesCard({required int columns, int shown = kHomeNoticesShown})
  {
    return _staggered(
      slot: 2,
      card: HomeNoticesSection(
        notices: _notices,
        isLoading: _loadingNotices,
        onOpen: (notice) => openNoticeReading(context, notice.id),
        columns: columns,
        shown: shown,
      ),
    );
  }

  // Tall: fills the room the column leaves, scrolling inside; capped: the newest few, where the page scrolls.
  Widget _tasksCard({bool tall = false, int? limit})
  {
    return _staggered(
      slot: 3,
      card: HomeNotificationsSection(fill: tall, limit: limit),
    );
  }

  Widget _statsCard({required double cardWidth})
  {
    return _staggered(
      slot: 1,
      card: DashboardStatsSection(
        general: _totals,
        teachers: _teacherTotals,
        students: _studentTotals,
        isLoading: _loadingHome,
        columns: DashboardStatsSection.stripColumnsForWidth(cardWidth),
        strip: true,
      ),
    );
  }

  Widget _birthdaysCard({required double cardWidth})
  {
    return _staggered(
      slot: 4,
      card: DashboardBirthdaysSection(
        birthdays: _birthdays,
        isLoading: _loadingHome,
        // from= sends the detail page's back button here.
        onTap: (person) => context.go('/people/${person.fiscalCode}?from=/dashboard'),
        columns: DashboardBirthdaysSection.columnsForWidth(cardWidth),
      ),
    );
  }

  Widget _buildHome(double width, AppWindowSize size)
  {
    final double inset = 2 * DashboardSectionCard.badgedPaddingOf(context).left;
    final double gap = size.isDense ? _denseSectionGap : _sectionGap;

    // The wide window as before; the compact one keeps its two columns at every width it has.
    if (size == AppWindowSize.compact || (size == AppWindowSize.wide && width >= _besideFrom))
    {
      final double left = ((width - gap) * _leftShare).floorToDouble();
      final double right = width - gap - left;
      final bool compact = size == AppWindowSize.compact;

      return homeBeside(
        left: _column([
          _todayCard(),
          _statsCard(cardWidth: left - inset),
          _noticesCard(columns: 2, shown: compact ? _compactNotices : kHomeNoticesShown),
        ], gap: gap),
        right: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _tasksCard(tall: true)),
            SizedBox(height: gap),
            _birthdaysCard(cardWidth: right - inset),
          ],
        ),
        leftWidth: left,
        gap: gap,
        floor: compact ? 0 : _tasksFloor,
      );
    }

    // Narrow: the day across, the rest in two columns; the page scrolls, nothing inside it.
    if (size == AppWindowSize.narrow)
    {
      final double left = ((width - gap) * _narrowLeftShare).floorToDouble();
      final double right = width - gap - left;

      return _column([
        _todayCard(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: left,
              child: _column([
                _statsCard(cardWidth: left - inset),
                _noticesCard(columns: 1),
              ], gap: gap),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _column([
                _tasksCard(limit: _cappedTasks),
                _birthdaysCard(cardWidth: right - inset),
              ], gap: gap),
            ),
          ],
        ),
      ], gap: gap);
    }

    final double cardWidth = width - inset;

    if (size == AppWindowSize.minimal)
    {
      return _column([
        _todayCard(),
        _tasksCard(limit: _cappedTasks),
        _statsCard(cardWidth: cardWidth),
        _noticesCard(columns: 1),
        _birthdaysCard(cardWidth: cardWidth),
      ], gap: gap);
    }

    return _column([
      _todayCard(),
      _statsCard(cardWidth: cardWidth),
      _tasksCard(limit: _cappedTasks),
      _noticesCard(columns: width >= _twoColumnsFrom ? 2 : 1),
      _birthdaysCard(cardWidth: cardWidth),
    ], gap: gap);
  }

  Widget _column(List<Widget> rows, {double gap = _sectionGap})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }

  Widget _buildWebLayout(BuildContext context)
  {
    final AppWindowSize size = AppBreakpoints.of(context);
    final double margin = AppBreakpoints.pageMargin(size);

    final double topInset = AppTopBar.bottomFor(size) + switch (size)
    {
      AppWindowSize.wide => _greetingTopGap,
      AppWindowSize.minimal => _minimalGreetingTopGap,
      _ => _denseGreetingTopGap,
    };

    final double greetingFontSize = switch (size)
    {
      AppWindowSize.wide => 42.0,
      AppWindowSize.minimal => 24.0,
      _ => 28.0,
    };

    final double contentWidth =
        math.min(widget.width - 2 * margin, _maxContentWidth);

    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.trialPaper,
      child: Stack(
        children: [
          const CornerGlow(
            corner: GlowCorner.topRight,
            tint: AppTheme.trialDeepWater,
            edgeTint: AppTheme.trialOcean,
            intensity: 1.25,
          ),
          const CornerGlow(
            corner: GlowCorner.bottomLeft,
            tint: AppTheme.trialSeaGreen,
            edgeTint: AppTheme.trialTealDeep,
          ),
          const PageWatermark(),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, topInset, margin, size.isDense ? 16 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.frame,
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: DashboardGreeting(
                          firstName: _currentUser?.firstName ?? '',
                          birthDate: _currentUser?.birthDate,
                          fontSize: greetingFontSize,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.isDense ? _denseGreetingBottomGap : _greetingBottomGap),
                  Expanded(
                    child: PageTransitionScrollView(
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: _buildHome(contentWidth, size),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppTopBar(currentRoute: '/dashboard', user: _currentUser),
        ],
      ),
    );
  }
}
