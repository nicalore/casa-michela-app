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

// The layout the browser build shows, and the one every change of the last
// months has been made to. A widget test runs with kIsWeb false and would
// otherwise only ever be shown the phone scaffold below, which is reachable
// only from the Android and iOS builds.
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

  // Room between the greeting and the first section, and between sections. The
  // last is between the two that share the side column, which stand closer.
  static const double _greetingBottomGap = 24;
  static const double _sectionGap = 22;
  static const double _sideColumnGap = 16;

  // How wide the home page may grow: beyond this, a line of text runs longer
  // than the eye follows.
  static const double _maxContentWidth = 1240;

  // How the top row is divided: the day takes the greater part of it, and the
  // two cards that stand one over the other take the rest.
  static const int _dayFlex = 3;
  static const int _sideFlex = 2;

  // The two widths at which the grid changes shape. The first is where the side
  // column stops being one: under [twoInARowFrom] the four figures fall into a
  // single file, and a card of four rows over the birthdays is a column nobody
  // can read the bottom of.
  static const double _sideColumnFrom =
      DashboardStatsSection.twoInARowFrom * (_dayFlex + _sideFlex) / _sideFlex + _sectionGap;
  static const double _twoColumnsFrom = 700;

  // The floors of the two rows. Neither is a ceiling: a card with more to say
  // grows, and the row grows with it — what these hold is the shape of the page
  // on a quiet day, so the home does not resettle as the figures arrive.
  static const double _dayRowHeight = 300;
  static const double _listHeight = 286;

  final ApiService _apiService = ApiService();

  bool _loadingUser = true;
  MeResponse? _currentUser;

  // What the home page really shows: today, the association's totals and the
  // week's birthdays. The other sections are still to come.
  bool _loadingHome = true;
  CurrentTotalsItem? _totals;
  CurrentTotalsItem? _teacherTotals;
  CurrentTotalsItem? _studentTotals;
  List<DashboardBirthday> _birthdays = [];

  // Today's own data, asked for apart from the rest: it takes six requests of
  // its own, and the figures beside it have no reason to wait on them.
  bool _loadingToday = true;
  List<DashboardBandStatus>? _bands;

  // Bumped on every fetch, so an answer that is no longer the current one is
  // dropped instead of overwriting fresher data.
  //
  // The home asks again every time it is come back to, and the hours are
  // regularly changed in Associazione and looked at here a second later: two
  // rounds can be in the air at once, and the older of them landing last would
  // put the hours back the way they were until the next visit.
  int _homeRequest = 0;
  int _todayRequest = 0;

  @override
  void initState()
  {
    super.initState();

    // The last identity the app saw, if any. The home page has no page until
    // it knows who is looking at it, and arriving from another destination with
    // a spinner in place of the bar would be the bar going dark exactly when the
    // transition wants it still.
    _currentUser = _apiService.lastKnownIdentity;
    _loadingUser = _currentUser == null;

    _loadCurrentUser();
    _loadHomeData();
    _loadTodayData();
  }

  // The home page is no longer torn down when left, and the birthdays, the
  // totals and the day itself all change while away. It asks for them again on
  // return without clearing what it is already showing: the three functions
  // below never switch the spinner back on, they only switch it off.
  @override
  void onDestinationShown()
  {
    _loadCurrentUser();
    _loadHomeData();
    _loadTodayData();
  }

  // The four requests go out together and the page draws with whatever comes
  // back: the statistics are restricted, and whoever cannot see them must still
  // be left with a page rather than an error.
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

  // The day the page opens on, band by band. The six requests go out together
  // and every one of them is an administrator's: where the hours come back
  // refused the card is left with no bands at all, which is not the same as a
  // day with none — it says the hours could not be read rather than drawing an
  // association that never opened.
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

    // Both openings or neither: with one of the two missing the bands would be
    // drawn as open one way only, which is a stronger claim than "we do not
    // know" and the wrong one to make on a request that was refused.
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

  // Logout of the native layout only: on the web the same job belongs to the
  // menu inside AppTopBar. The local logout (session cleanup plus the redirect
  // to /login driven by authState) happens only if the server call succeeds. On
  // failure the user stays authenticated on the dashboard and is told what
  // happened, rather than being left in a half logged out state (TC-IAM-012 /
  // RF-IAM-018).
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


  // kIsWeb is true in every browser, phones included, so this is not a
  // desktop-versus-mobile switch: on the web build the absolute layout always
  // wins, and index.html scales it down for touch devices. The native layout is
  // reached only by the Android and iOS builds.
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
      // The same sections as the wide layout, in a column: there is one home
      // page, only the room it has changes.
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

  // The five sections of the home page. Each can sit in a row alongside others,
  // where the tallest decides the height and the rest fill it, or alone in a
  // column, where it takes the height it needs.

  // The card's place in the reading order, which is what decides when it leaves
  // and when it returns on a page change. It is not the same across the three
  // grids below, since the cards reorder as the page narrows, so it is told by
  // whoever lines them up rather than by the card.
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
        // In the side column it takes the height its four tiles need and no
        // more: what is left of the row is the birthdays' to have.
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

  // The two that stand one over the other beside the day: the figures, in their
  // short form, and under them the birthdays taking whatever height the day
  // leaves. Together they come to the height of the day itself, which is what
  // makes the top row a row and not two columns that happen to be next to each
  // other.
  Widget _sideColumn(double cardWidth)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statsCard(inRow: true, cardWidth: cardWidth, compact: true, slot: 1),
        // Closer to each other than to anything else on the page: the two read
        // as the one column they are, and every pixel not spent between them is
        // a pixel the day beside them does not have to stretch to cover.
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

  // The home grid, decided on the width the page really has.
  //
  // Two rows wherever there is room for two, and the same two everywhere: the
  // day and the birthdays on top — the two sections that are read — the figures
  // and the two still to come below. The rows are not the same height, and are
  // not meant to be: what the day has to say is a list of bands, and what the
  // figures have is four tiles.
  //
  // Narrowest: a single column, the only shape that holds on a phone. The order
  // is the reading order of the wide grid, which is also the order the sections
  // arrive in on a change of page.
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

    // Not wide enough for a column beside the day: the four figures and the
    // birthdays share a row of their own under it, each with the width they
    // would have had one above the other.
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

    // The day down the left of the top row, and beside it the two small cards
    // one over the other. The day is the tallest of the three and the other two
    // divide its height between them.
    final double sideWidth = (width - _sectionGap) * _sideFlex / (_dayFlex + _sideFlex);

    return _column([
      _CardRow(
        flexes: const [_dayFlex, _sideFlex],
        children: [
          _todayCard(inRow: true, slot: 0),
          _sideColumn(sideWidth),
        ],
      ),
      // Two and not three: what is left of the page goes to the sections still
      // to come, which had a third of a row each and read as columns of a table
      // rather than as cards.
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
    // The page's width and not the window's: on the wide layout the two do not
    // coincide, and the grid is centred on the page it is drawn in rather than
    // on the window it is looked at from.
    final AppWindowSize size = AppBreakpoints.fromWidth(widget.width);
    final double margin = AppBreakpoints.pageMargin(size);

    // The bar is shorter on a narrow window, and so is the rule under it: the
    // page starts higher instead of opening on a band of empty paper.
    final double topInset = AppTopBar.contentTopInsetFor(size);
    final double greetingFontSize = size.isCompact ? 34.0 : 50.0;

    // How wide the grid really is: measured by the page, the only one that
    // knows, and handed to whoever decides how many cards fit in a row.
    final double contentWidth =
        math.min(widget.width - 2 * margin, _maxContentWidth);

    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.trialPaper,
      child: Stack(
        children: [
          // The two ends of the brand ramp, split between the corners.
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
          // The greeting belongs to the column and the grid scrolls below it,
          // not behind it: resting on the page, the cards used to slide
          // underneath it along with what it says.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, topInset, margin, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The greeting opens the page, so on a change it is the
                  // first to leave and the first to come back.
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

// A row of cards, all of the same width and all of the same height: two side by
// side at different heights read as crooked at once, and the tallest of them
// sets the height. Which is why what shares a row is chosen among the cards
// that want the same height to begin with.
class _CardRow extends StatelessWidget
{
  final List<Widget> children;

  // The share of the row each card takes, where they do not take equal ones.
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
