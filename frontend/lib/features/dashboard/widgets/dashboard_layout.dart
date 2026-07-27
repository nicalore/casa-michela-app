import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';
import '../dashboard_modules.dart';
import 'dashboard_greeting.dart';
import 'dashboard_module_card.dart';
import 'dashboard_placeholder_card.dart';

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

class _DashboardLayoutState extends State<DashboardLayout>
{
  static const double _pageHorizontalMargin = 40;
  static const double _tabletBreakpoint = 600.0;

  // Card footprint comes from the card itself, so the grid math and the
  // widget cannot disagree on the size.
  static const double _cardWidth = DashboardModuleCard.width;
  static const double _cardHeight = DashboardModuleCard.height;
  static const double _cardGap = 40;

  // Vertical space reserved above the module grid for header and greeting.
  static const double _gridTopOffset = 264;
  static const double _dashboardTopPadding = 25;

  static const double _bottomCardsGap = 70;
  static const double _bottomCardsTopGap = 30;
  static const double _bottomCardsBottomMargin = 0;
  static const double _maxBottomCardWidth = 645.0;
  static const double _bottomCardAspectRatio = 645.0 / 450.0;

  // Below this width the two bottom cards no longer fit side by side.
  static const double _bottomCardsStackBreakpoint = 1420;

  final ApiService _apiService = ApiService();

  bool _loadingUser = true;
  MeResponse? _currentUser;

  @override
  void initState()
  {
    super.initState();
    _loadCurrentUser();
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

  DashboardModuleCard _buildModuleCard(DashboardModule module)
  {
    final route = module.route;

    return DashboardModuleCard(
      title: module.title,
      subtitle: module.subtitle,
      icon: module.icon,
      imageAsset: module.imageAsset,
      onTap: route == null ? () {} : () => context.go(route),
    );
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

    return kIsWeb ? _buildWebLayout(context) : _buildNativeLayout(context);
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: isTablet ? 2 : 1,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            childAspectRatio: isTablet ? 1.4 : 1.2,
            children: dashboardModules.map(_buildModuleCard).toList(),
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

  Widget _buildWebLayout(BuildContext context)
  {
    final viewportWidth = MediaQuery.of(context).size.width;

    final cardsPerRow = ((viewportWidth - 2 * _pageHorizontalMargin + _cardGap) ~/
            (_cardWidth + _cardGap))
        .clamp(1, dashboardModules.length);

    final upperRows = (dashboardModules.length / cardsPerRow).ceil();

    // Every row is centred on its own width, so the last incomplete row does
    // not hang to the left of the ones above it.
    double cardLeft(int index)
    {
      final row = index ~/ cardsPerRow;
      final indexInRow = index % cardsPerRow;

      final cardsInThisRow = row == upperRows - 1
          ? dashboardModules.length - ((upperRows - 1) * cardsPerRow)
          : cardsPerRow;

      final rowWidth = cardsInThisRow * _cardWidth + (cardsInThisRow - 1) * _cardGap;
      final startX = (viewportWidth - rowWidth) / 2;

      return startX + indexInRow * (_cardWidth + _cardGap);
    }

    double cardTop(int index)
    {
      final row = index ~/ cardsPerRow;

      return _gridTopOffset + _dashboardTopPadding + row * (_cardHeight + _cardGap);
    }

    final bottomCardWidth = math.min(
      _maxBottomCardWidth,
      viewportWidth - _pageHorizontalMargin,
    );

    final bottomCardHeight = bottomCardWidth / _bottomCardAspectRatio;
    final stackBottomCards = viewportWidth < _bottomCardsStackBreakpoint;

    final bottomCardsTop = cardTop(dashboardModules.length - 1) + _cardHeight + _bottomCardsTopGap;

    final bottomCardsStartX = stackBottomCards
        ? (viewportWidth - bottomCardWidth) / 2
        : (viewportWidth - ((2 * bottomCardWidth) + _bottomCardsGap)) / 2;

    final contentHeight = stackBottomCards
        ? bottomCardsTop + (2 * bottomCardHeight) + _bottomCardsGap + _bottomCardsBottomMargin
        : bottomCardsTop + bottomCardHeight + _bottomCardsBottomMargin;

    // The canvas grows past the viewport when the content needs it, letting the
    // page scroll instead of clipping the bottom cards.
    final dashboardHeight = math.max(widget.height, contentHeight);

    return Container(
      width: widget.width,
      height: dashboardHeight,
      color: AppTheme.trialPaper,
      child: Stack(
        children: [
          // The two ends of the mockup's background ramp, split between the
          // corners. Both fade towards a blue rather than towards the green
          // end of the ramp, so the blue reads across the whole page instead
          // of only in the top corner: the top glow stays blue throughout,
          // and the bottom one starts on sea green and cools into teal.
          //
          // The mockup also lays a gold and a violet wash over that ramp, but
          // at the opacity it uses they only warm up a dark background and
          // would read as two foreign stains on a page this light, so those
          // two stay accents for the foreground.
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
          DashboardGreeting(firstName: _currentUser?.firstName ?? ''),
          for (var i = 0; i < dashboardModules.length; i++)
            Positioned(
              left: cardLeft(i),
              top: cardTop(i),
              child: _buildModuleCard(dashboardModules[i]),
            ),
          Positioned(
            left: bottomCardsStartX,
            top: bottomCardsTop,
            child: DashboardPlaceholderCard(
              title: 'Attività',
              width: bottomCardWidth,
              height: bottomCardHeight,
            ),
          ),
          Positioned(
            left: stackBottomCards
                ? bottomCardsStartX
                : bottomCardsStartX + bottomCardWidth + _bottomCardsGap,
            top: stackBottomCards
                ? bottomCardsTop + bottomCardHeight + _bottomCardsGap
                : bottomCardsTop,
            child: DashboardPlaceholderCard(
              title: 'Statistiche',
              width: bottomCardWidth,
              height: bottomCardHeight,
            ),
          ),
          AppTopBar(currentRoute: '/dashboard', user: _currentUser),
        ],
      ),
    );
  }
}