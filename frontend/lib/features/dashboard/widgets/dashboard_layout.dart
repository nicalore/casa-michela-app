import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/opening_day_item.dart';
import '../../auth/models/me_response.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/models/calendar_publication_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../people/models/current_totals_item.dart';
import '../../people/models/person_item.dart';
import 'dashboard_birthdays_section.dart';
import 'dashboard_greeting.dart';
import 'dashboard_section_card.dart';
import 'dashboard_stats_section.dart';
import 'dashboard_today_section.dart';

// Widget tests run with kIsWeb false and would otherwise only see the native
// phone scaffold; this forces the web layout they target.
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

  static const double _greetingBottomGap = 24;
  static const double _sectionGap = 22;
  static const double _sideColumnGap = 16;

  static const double _maxContentWidth = 1240;

  static const int _dayFlex = 3;
  static const int _sideFlex = 2;

  // Below this width the stats in the side column would drop under
  // DashboardStatsSection.twoInARowFrom and collapse to a single file.
  static const double _sideColumnFrom =
      DashboardStatsSection.twoInARowFrom * (_dayFlex + _sideFlex) / _sideFlex + _sectionGap;
  static const double _twoColumnsFrom = 700;

  // Row minimums, not maximums: cards can grow, these keep the page shape
  // stable while data loads.
  static const double _dayRowHeight = 300;
  static const double _listHeight = 286;

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

  // Bumped on every fetch so a stale response is dropped instead of
  // overwriting fresher data (two rounds can be in flight at once).
  int _homeRequest = 0;
  int _todayRequest = 0;

  @override
  void initState()
  {
    super.initState();

    // Seed from the last known identity so returning here does not swap the
    // top bar for a spinner mid page transition.
    _currentUser = _apiService.lastKnownIdentity;
    _loadingUser = _currentUser == null;

    _loadCurrentUser();
    _loadHomeData();
    _loadTodayData();
  }

  // Refreshes on return without clearing what is shown: the loaders below
  // only ever switch the spinner off, never back on.
  @override
  void onDestinationShown()
  {
    _loadCurrentUser();
    _loadHomeData();
    _loadTodayData();
  }

  // The statistics endpoints are restricted: failures render as missing data,
  // not an error page.
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
      _birthdays = upcomingBirthdays((results[3] as List<PersonItem>?) ?? const []);
      _loadingHome = false;
    });
  }

  // If the opening hours cannot be read, _bands stays null ("unknown"), which
  // is distinct from an empty day with no openings.
  Future<void> _loadTodayData() async
  {
    final int request = ++_todayRequest;

    final DateTime now = DateTime.now();
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
    ]);

    if (!mounted || request != _todayRequest)
    {
      return;
    }

    // Both opening modes or neither: one missing would misreport the day as
    // open one way only.
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
              publications: (results[5] as List<CalendarPublicationItem>?) ?? const [],
            );
      _loadingToday = false;
    });
  }

  Future<void> _loadCurrentUser() async
  {
    try
    {
      final user = await _apiService.me();

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

  // Native layout only; the web logout lives in AppTopBar. Local session
  // cleanup happens only if the server call succeeds (TC-IAM-012 / RF-IAM-018).
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

  // kIsWeb is true in every browser, phones included: the web build always
  // gets the absolute layout (index.html scales it for touch devices); the
  // native layout is Android/iOS only.
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
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildHome(constraints.maxWidth - 32),
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

  // The transition slot is the card's reading-order position, which differs
  // across the three grids below, so the caller assigns it.
  Widget _staggered({required int slot, required Widget card})
  {
    return PageTransitionItem(slot: PageTransitionItem.header + slot, child: card);
  }

  Widget _todayCard({required bool inRow, required int slot})
  {
    return _staggered(
      slot: slot,
      card: DashboardTodaySection(
        bands: _bands,
        isLoading: _loadingToday,
        minHeight: inRow ? _dayRowHeight : 0,
        fill: inRow,
      ),
    );
  }

  Widget _noticesCard({required bool inRow, required int slot})
  {
    return _staggered(
      slot: slot,
      card: DashboardSectionCard(
        eyebrow: 'Messaggi',
        title: 'Comunicazioni e avvisi',
        minHeight: inRow ? _listHeight : 0,
        fill: inRow,
        child: const DashboardComingSoon(
          icon: Icons.campaign_rounded,
          description: '',
        ),
      ),
    );
  }

  Widget _tasksCard({required bool inRow, required int slot})
  {
    return _staggered(
      slot: slot,
      card: DashboardSectionCard(
        eyebrow: 'Cose da fare',
        title: 'Attività e notifiche',
        minHeight: inRow ? _listHeight : 0,
        fill: inRow,
        child: const DashboardComingSoon(
          icon: Icons.checklist_rounded,
          description: '',
        ),
      ),
    );
  }

  Widget _statsCard({
    required bool inRow,
    required double cardWidth,
    required int slot,
    bool compact = false,
  })
  {
    return _staggered(
      slot: slot,
      card: DashboardStatsSection(
        general: _totals,
        teachers: _teacherTotals,
        students: _studentTotals,
        isLoading: _loadingHome,
        columns: DashboardStatsSection.columnsForWidth(cardWidth),
        compact: compact,
        minHeight: inRow && !compact ? _dayRowHeight : 0,
        fill: inRow && !compact,
      ),
    );
  }

  Widget _birthdaysCard({
    required bool inRow,
    required double cardWidth,
    required int slot,
    bool compact = false,
  })
  {
    return _staggered(
      slot: slot,
      card: DashboardBirthdaysSection(
        birthdays: _birthdays,
        isLoading: _loadingHome,
        onTap: (person) => context.go('/people/${person.fiscalCode}'),
        columns: DashboardBirthdaysSection.columnsForWidth(cardWidth),
        compact: compact,
        minHeight: inRow && !compact ? _listHeight : 0,
        fill: inRow,
      ),
    );
  }

  Widget _sideColumn(double cardWidth)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statsCard(inRow: true, cardWidth: cardWidth, compact: true, slot: 1),
        const SizedBox(height: _sideColumnGap),
        Expanded(
          child: _birthdaysCard(
            inRow: true,
            cardWidth: cardWidth,
            compact: true,
            slot: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildHome(double width)
  {
    if (width < _twoColumnsFrom)
    {
      return _column([
        _todayCard(inRow: false, slot: 0),
        _statsCard(inRow: false, cardWidth: width, slot: 1),
        _birthdaysCard(inRow: false, cardWidth: width, slot: 2),
        _noticesCard(inRow: false, slot: 3),
        _tasksCard(inRow: false, slot: 4),
      ]);
    }

    if (width < _sideColumnFrom)
    {
      return _column([
        _todayCard(inRow: false, slot: 0),
        _CardRow(
          children: [
            _statsCard(inRow: true, cardWidth: (width - _sectionGap) / 2, slot: 1),
            _birthdaysCard(inRow: true, cardWidth: (width - _sectionGap) / 2, slot: 2),
          ],
        ),
        _CardRow(
          children: [
            _noticesCard(inRow: true, slot: 3),
            _tasksCard(inRow: true, slot: 4),
          ],
        ),
      ]);
    }

    final double sideWidth = (width - _sectionGap) * _sideFlex / (_dayFlex + _sideFlex);

    return _column([
      _CardRow(
        flexes: const [_dayFlex, _sideFlex],
        children: [
          _todayCard(inRow: true, slot: 0),
          _sideColumn(sideWidth),
        ],
      ),
      _CardRow(
        children: [
          _noticesCard(inRow: true, slot: 3),
          _tasksCard(inRow: true, slot: 4),
        ],
      ),
    ]);
  }

  Widget _column(List<Widget> rows)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: _sectionGap),
          rows[i],
        ],
      ],
    );
  }

  Widget _buildWebLayout(BuildContext context)
  {
    // Page width, not window width: the grid is centred on the page it is
    // drawn in.
    final AppWindowSize size = AppBreakpoints.fromWidth(widget.width);
    final double margin = AppBreakpoints.pageMargin(size);

    final double topInset = AppTopBar.contentTopInsetFor(size);
    final double greetingFontSize = size.isCompact ? 34.0 : 50.0;

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
            animated: true,
          ),
          const CornerGlow(
            corner: GlowCorner.bottomLeft,
            tint: AppTheme.trialSeaGreen,
            edgeTint: AppTheme.trialTealDeep,
            animated: true,
          ),
          const PageWatermark(),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, topInset, margin, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.frame,
                    child: DashboardGreeting(
                      firstName: _currentUser?.firstName ?? '',
                      fontSize: greetingFontSize,
                    ),
                  ),
                  const SizedBox(height: _greetingBottomGap),
                  Expanded(
                    child: PageTransitionScrollView(
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: _buildHome(contentWidth),
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

class _CardRow extends StatelessWidget
{
  final List<Widget> children;

  final List<int>? flexes;

  const _CardRow({required this.children, this.flexes});

  @override
  Widget build(BuildContext context)
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: _DashboardLayoutState._sectionGap),
            Expanded(flex: flexes?[i] ?? 1, child: children[i]),
          ],
        ],
      ),
    );
  }
}
