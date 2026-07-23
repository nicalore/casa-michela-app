import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';
import 'dashboard_greeting.dart';
import 'dashboard_header.dart';
import 'dashboard_module_card.dart';
import 'dashboard_placeholder_card.dart';
import 'user_menu.dart';

// Descriptor of a dashboard module, so the four entries are declared once and
// rendered by both the web and the native layout. A null route marks a module
// whose page does not exist yet.
class _DashboardModule
{
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? imageAsset;
  final String? route;

  const _DashboardModule({
    required this.title,
    required this.subtitle,
    this.icon,
    this.imageAsset,
    this.route,
  });
}

const List<_DashboardModule> _modules = [
  _DashboardModule(
    title: 'Persone',
    subtitle: 'Gestisci membri e profili',
    icon: Icons.groups_outlined,
    route: '/people',
  ),
  _DashboardModule(
    title: 'Calendario',
    subtitle: 'Organizza prenotazioni e lezioni',
    icon: Icons.calendar_month_rounded,
  ),
  _DashboardModule(
    title: 'Contabilità',
    subtitle: 'Monitora pagamenti e ore lavorate',
    icon: Icons.account_balance_wallet_outlined,
  ),
  _DashboardModule(
    title: 'Associazione',
    subtitle: 'Configura regole e parametri',
    imageAsset: 'assets/images/house_watermark_white.png',
    route: '/association',
  ),
];

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

  static const double _userMenuTop = 115;
  static const double _userMenuRight = 60;

  final ApiService _apiService = ApiService();

  bool _isMenuOpen = false;
  bool _loadingUser = true;
  MeResponse? _currentUser;

  @override
  void initState()
  {
    super.initState();
    _loadCurrentUser();
  }

  void _toggleMenu()
  {
    setState(() => _isMenuOpen = !_isMenuOpen);
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

  // The local logout (session cleanup plus the redirect to /login driven by
  // authState) happens only if the server call succeeds. On failure the user
  // stays authenticated on the dashboard and is told what happened, rather than
  // being left in a half logged out state (TC-IAM-012 / RF-IAM-018).
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

      setState(() => _isMenuOpen = false);
      CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);

      return;
    }

    if (!mounted)
    {
      return;
    }

    context.go('/login');
  }

  DashboardModuleCard _buildModuleCard(_DashboardModule module)
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
      return const Center(child: CircularProgressIndicator());
    }

    return kIsWeb ? _buildWebLayout(context) : _buildNativeLayout(context);
  }

  Widget _buildNativeLayout(BuildContext context)
  {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > _tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Ciao, ${_currentUser?.firstName ?? ''}',
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: AppTheme.primary,
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
            children: _modules.map(_buildModuleCard).toList(),
          ),
        ),
      ),
      bottomNavigationBar: isTablet ? null : _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation()
  {
    return BottomNavigationBar(
      selectedItemColor: AppTheme.primary,
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

  Widget _buildUserMenu()
  {
    return Positioned(
      top: _userMenuTop,
      right: _userMenuRight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation)
        {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _isMenuOpen
            // The inner GestureDetector swallows taps on the menu, so they do
            // not reach the outer one that closes it.
            ? GestureDetector(
                onTap: () {},
                child: UserMenu(
                  key: const ValueKey('menu'),
                  activeRole: RoleLabelMapper.toLabel(_currentUser?.activeRole ?? 'ADMIN'),
                  availableRoles: (_currentUser?.availableRoles ?? const [])
                      .map(RoleLabelMapper.toLabel)
                      .toList(),
                  onRoleSelected: (role) {},
                  onLogout: _logout,
                ),
              )
            : const SizedBox(key: ValueKey('empty')),
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context)
  {
    final viewportWidth = MediaQuery.of(context).size.width;

    final cardsPerRow = ((viewportWidth - 2 * _pageHorizontalMargin + _cardGap) ~/
            (_cardWidth + _cardGap))
        .clamp(1, _modules.length);

    final upperRows = (_modules.length / cardsPerRow).ceil();

    // Every row is centred on its own width, so the last incomplete row does
    // not hang to the left of the ones above it.
    double cardLeft(int index)
    {
      final row = index ~/ cardsPerRow;
      final indexInRow = index % cardsPerRow;

      final cardsInThisRow = row == upperRows - 1
          ? _modules.length - ((upperRows - 1) * cardsPerRow)
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

    final bottomCardsTop = cardTop(_modules.length - 1) + _cardHeight + _bottomCardsTopGap;

    final bottomCardsStartX = stackBottomCards
        ? (viewportWidth - bottomCardWidth) / 2
        : (viewportWidth - ((2 * bottomCardWidth) + _bottomCardsGap)) / 2;

    final contentHeight = stackBottomCards
        ? bottomCardsTop + (2 * bottomCardHeight) + _bottomCardsGap + _bottomCardsBottomMargin
        : bottomCardsTop + bottomCardHeight + _bottomCardsBottomMargin;

    // The canvas grows past the viewport when the content needs it, letting the
    // page scroll instead of clipping the bottom cards.
    final dashboardHeight = math.max(widget.height, contentHeight);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: ()
      {
        if (_isMenuOpen)
        {
          setState(() => _isMenuOpen = false);
        }
      },
      child: Container(
        width: widget.width,
        height: dashboardHeight,
        color: AppTheme.pageBackground,
        child: Stack(
          children: [
            const CornerGlow(corner: GlowCorner.topRight),
            const CornerGlow(corner: GlowCorner.bottomLeft),
            const PageWatermark(),
            DashboardGreeting(firstName: _currentUser?.firstName ?? ''),
            for (var i = 0; i < _modules.length; i++)
              Positioned(
                left: cardLeft(i),
                top: cardTop(i),
                child: _buildModuleCard(_modules[i]),
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
            DashboardHeader(
              isMenuOpen: _isMenuOpen,
              onProfileTap: _toggleMenu,
              fullName: _currentUser?.fullName ?? '',
              profileImageUrl: _currentUser?.profileImageUrl,
            ),
            _buildUserMenu(),
          ],
        ),
      ),
    );
  }
}