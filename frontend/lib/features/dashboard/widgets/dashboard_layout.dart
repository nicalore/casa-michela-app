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
import '../../auth/models/me_response.dart';
import '../../people/models/current_totals_item.dart';
import '../../people/models/person_item.dart';
import 'dashboard_birthdays_section.dart';
import 'dashboard_greeting.dart';
import 'dashboard_section_card.dart';
import 'dashboard_stats_section.dart';

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

  // Room between the greeting and the first section, and between sections.
  static const double _greetingBottomGap = 24;
  static const double _sectionGap = 22;

  // How wide the home page may grow: beyond this, a line of text runs longer
  // than the eye follows.
  static const double _maxContentWidth = 1240;

  // The two widths at which the grid changes shape: three cards in a row, two,
  // or everything in a column. The first is what it takes to fit the four
  // figures in a row at the top with a wide enough "today" beside them.
  static const double _minTodayWidth = 330;
  static const double _threeColumnsFrom =
      DashboardStatsSection.fourInARowFrom + _minTodayWidth + _sectionGap;
  static const double _twoColumnsFrom = 700;

  // How tall the sections still to come are: the size they will have once
  // filled, so the home page does not resettle the day they arrive.
  static const double _todayHeight = 226;
  static const double _listHeight = 286;

  final ApiService _apiService = ApiService();

  bool _loadingUser = true;
  MeResponse? _currentUser;

  // What the home page really shows: the association's totals and the week's
  // birthdays. The other sections are still to come.
  bool _loadingHome = true;
  CurrentTotalsItem? _totals;
  CurrentTotalsItem? _teacherTotals;
  CurrentTotalsItem? _studentTotals;
  List<DashboardBirthday> _birthdays = [];

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
  }

  // The home page is no longer torn down when left, and both the birthdays and
  // the totals change while away. It asks for them again on return without
  // clearing what it is already showing: the two functions below never switch
  // the spinner back on, they only switch it off.
  @override
  void onDestinationShown()
  {
    _loadCurrentUser();
    _loadHomeData();
  }

  // The four requests go out together and the page draws with whatever comes
  // back: the statistics are restricted, and whoever cannot see them must still
  // be left with a page rather than an error.
  Future<void> _loadHomeData() async
  {
    final results = await Future.wait([
      _apiService.getCurrentTotals().then<Object?>((value) => value).catchError((_) => null),
      _apiService.getRoleCurrentTotals('teacher').then<Object?>((value) => value).catchError((_) => null),
      _apiService.getRoleCurrentTotals('student').then<Object?>((value) => value).catchError((_) => null),
      _apiService.getPeople().then<Object?>((value) => value).catchError((_) => null),
    ]);

    if (!mounted)
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
      card: DashboardSectionCard(
        eyebrow: 'Oggi',
        title: 'Orari e presenze',
        minHeight: inRow ? _todayHeight : 0,
        fill: inRow,
        child: const DashboardComingSoon(
          icon: Icons.today_rounded,
          description: '',
        ),
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

  Widget _statsCard({required bool inRow, required double cardWidth, required int slot})
  {
    return _staggered(
      slot: slot,
      card: DashboardStatsSection(
        general: _totals,
        teachers: _teacherTotals,
        students: _studentTotals,
        isLoading: _loadingHome,
        columns: DashboardStatsSection.columnsForWidth(cardWidth),
        minHeight: inRow ? _todayHeight : 0,
        fill: inRow,
      ),
    );
  }

  Widget _birthdaysCard({required bool inRow, required int slot, double minHeight = 0})
  {
    return _staggered(
      slot: slot,
      card: DashboardBirthdaysSection(
        birthdays: _birthdays,
        isLoading: _loadingHome,
        onTap: (person) => context.go('/people/${person.fiscalCode}'),
        minHeight: inRow ? minHeight : 0,
        fill: inRow,
      ),
    );
  }

  // The home grid, decided on the width the page really has.
  //
  // Wide: today and the figures on top, the three lists below — five sections in
  // two rows, which is what it takes to see them all without scrolling.
  // Narrow: two rows of two with the figures last, where they get a whole row.
  // Narrowest: a single column, the only shape that holds on a phone.
  Widget _buildHome(double width)
  {
    if (width < _twoColumnsFrom)
    {
      return _column([
        _todayCard(inRow: false, slot: 0),
        _noticesCard(inRow: false, slot: 1),
        _tasksCard(inRow: false, slot: 2),
        _statsCard(inRow: false, cardWidth: width, slot: 3),
        _birthdaysCard(inRow: false, slot: 4),
      ]);
    }

    // Two columns: the figures move last, where they get a whole row and the
    // four tiles stay in line. Broken into two rows of two they would make a
    // card taller than what it says is worth.
    if (width < _threeColumnsFrom)
    {
      return _column([
        _CardRow(
          children: [
            _todayCard(inRow: true, slot: 0),
            _birthdaysCard(inRow: true, minHeight: _todayHeight, slot: 1),
          ],
        ),
        _CardRow(
          children: [
            _noticesCard(inRow: true, slot: 2),
            _tasksCard(inRow: true, slot: 3),
          ],
        ),
        _statsCard(inRow: false, cardWidth: width, slot: 4),
      ]);
    }

    // The figures need more width than "today" asks for: four tiles in a row,
    // whose labels would clip if squeezed. They never go below that size, and
    // whatever is left over goes to "today".
    final double available = width - _sectionGap;
    final double statsWidth = (available * 3 / 5)
        .clamp(DashboardStatsSection.fourInARowFrom, available - _minTodayWidth);

    return _column([
      _CardRow(
        widths: [null, statsWidth],
        children: [
          _todayCard(inRow: true, slot: 0),
          _statsCard(inRow: true, cardWidth: statsWidth, slot: 1),
        ],
      ),
      _CardRow(
        children: [
          _noticesCard(inRow: true, slot: 2),
          _tasksCard(inRow: true, slot: 3),
          _birthdaysCard(inRow: true, minHeight: _listHeight, slot: 4),
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

// A row of cards, all the same height: two side by side at different heights
// read as crooked at once, and the taller of the two sets the height.
class _CardRow extends StatelessWidget
{
  final List<Widget> children;

  // A card's width, where that is a decided size and not a share of the row:
  // null means whatever is left, split with the others.
  final List<double?>? widths;

  const _CardRow({required this.children, this.widths});

  @override
  Widget build(BuildContext context)
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: _DashboardLayoutState._sectionGap),
            if (widths?[i] == null)
              Expanded(child: children[i])
            else
              SizedBox(width: widths![i], child: children[i]),
          ],
        ],
      ),
    );
  }
}
