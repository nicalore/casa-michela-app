import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dashboard_greeting.dart';
import 'dashboard_header.dart';
import 'dashboard_module_card.dart';
import 'dashboard_placeholder_card.dart';
import 'user_menu.dart';

import '../../../services/api_service.dart';
import '../../auth/models/me_response.dart';
import '../../../core/utils/role_label_mapper.dart';

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
  bool _isMenuOpen = false;

  MeResponse? _currentUser;
  bool _loadingUser = true;

  @override
  void initState()
  {
    super.initState();
    _loadCurrentUser();
  }

  void _toggleMenu()
  {
    setState(()
    {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  //LoadUserDetails
  Future<void> _loadCurrentUser() async
  {
    try
    {
      final user = await ApiService().me();

      debugPrint('Utente caricato: ${user.fullName}');

      if (!mounted) return;

      setState(()
      {
        _currentUser = user;
        _loadingUser = false;
      });
    }
    catch (e)
    {
      debugPrint('Errore caricamento utente: $e');

      if (!mounted) return;

      setState(()
      {
        _loadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context)
  {
    if (_loadingUser)
    {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    //LayoutDimensions
    final canvasWidth = widget.width;
    final viewportHeight = widget.height;
    final viewportWidth = MediaQuery.of(context).size.width;

    const double cardWidth = 287;
    const double cardHeight = 200;
    const double cardGap = 40;

    final int cardsPerRow = ((viewportWidth - 80 + cardGap) ~/ (cardWidth + cardGap)).clamp(1, 4);
    final int upperRows = (4 / cardsPerRow).ceil();

    //CalculateHorizontalPosition
    double cardLeft(int index)
    {
      final row = index ~/ cardsPerRow;
      final indexInRow = index % cardsPerRow;

      final cardsInThisRow = row == upperRows - 1
          ? 4 - ((upperRows - 1) * cardsPerRow)
          : cardsPerRow;

      final rowWidth = cardsInThisRow * cardWidth + (cardsInThisRow - 1) * cardGap;
      final startX = (viewportWidth - rowWidth) / 2;

      return startX + indexInRow * (cardWidth + cardGap);
    }

    const double dashboardTopPadding = 25;

    //CalculateVerticalPosition
    double cardTop(int index)
    {
      final row = index ~/ cardsPerRow;

      return 264 + dashboardTopPadding + row * (cardHeight + cardGap);
    }

    const double bottomCardsGap = 70;
    const double bottomMargin = 0;
    const double bottomCardAspectRatio = 645.0 / 450.0;

    final double actualBottomCardWidth = math.min(645.0, viewportWidth - 40);
    final double bottomCardHeight = actualBottomCardWidth / bottomCardAspectRatio;

    final double upperSectionBottom = cardTop(3) + cardHeight;
    final bool stackBottomCards = viewportWidth < 1420;

    final double bottomCardsTop = upperSectionBottom + 30;

    final double bottomCardsStartX = stackBottomCards
        ? (viewportWidth - actualBottomCardWidth) / 2
        : (viewportWidth - ((2 * actualBottomCardWidth) + bottomCardsGap)) / 2;

    final double contentHeight = stackBottomCards
        ? bottomCardsTop + (2 * bottomCardHeight) + bottomCardsGap + bottomMargin
        : bottomCardsTop + bottomCardHeight + bottomMargin;

    final double dashboardHeight = math.max(viewportHeight, contentHeight);

    //RenderDashboardUI
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: ()
      {
        if (_isMenuOpen)
        {
          setState(()
          {
            _isMenuOpen = false;
          });
        }
      },
      child: Container(
        width: canvasWidth,
        height: dashboardHeight,
        color: const Color(0xFFF4F7F9),
        child: Stack(
          children: [
            Positioned(
              right: -800,
              top: -800,
              child: IgnorePointer(
                child: Container(
                  width: 1600,
                  height: 1600,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x4D003C82),
                        Color(0x22003C82),
                        Color(0x00003C82),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -800,
              bottom: -800,
              child: IgnorePointer(
                child: Container(
                  width: 1600,
                  height: 1600,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x4D003C82),
                        Color(0x22003C82),
                        Color(0x00003C82),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            if (viewportWidth > 1024)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: 0.04,
                      child: Image.asset(
                        'assets/images/house_watermark.png',
                        width: 800,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            DashboardGreeting(
              firstName: _currentUser?.firstName ?? '',
            ),
            Positioned(
              left: cardLeft(0),
              top: cardTop(0),
              child: DashboardModuleCard(
                title: 'Persone',
                subtitle: 'Gestisci membri e profili',
                icon: Icons.groups_outlined,
                onTap: () {},
              ),
            ),
            Positioned(
              left: cardLeft(1),
              top: cardTop(1),
              child: DashboardModuleCard(
                title: 'Calendario',
                subtitle: 'Organizza prenotazioni e lezioni',
                icon: Icons.calendar_month_rounded,
                onTap: () {},
              ),
            ),
            Positioned(
              left: cardLeft(2),
              top: cardTop(2),
              child: DashboardModuleCard(
                title: 'Contabilità',
                subtitle: 'Monitora pagamenti e ore lavorate',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () {},
              ),
            ),
            Positioned(
              left: cardLeft(3),
              top: cardTop(3),
              child: DashboardModuleCard(
                title: 'Associazione',
                subtitle: 'Configura regole e parametri',
                imageAsset: 'assets/images/house_watermark_white.png',
                onTap: () {},
              ),
            ),
            Positioned(
              left: bottomCardsStartX,
              top: bottomCardsTop,
              child: DashboardPlaceholderCard(
                title: 'Attività',
                width: actualBottomCardWidth,
                height: bottomCardHeight,
              ),
            ),
            Positioned(
              left: stackBottomCards
                  ? bottomCardsStartX
                  : bottomCardsStartX + actualBottomCardWidth + bottomCardsGap,
              top: stackBottomCards
                  ? bottomCardsTop + bottomCardHeight + bottomCardsGap
                  : bottomCardsTop,
              child: DashboardPlaceholderCard(
                title: 'Statistiche',
                width: actualBottomCardWidth,
                height: bottomCardHeight,
              ),
            ),
            DashboardHeader(
              isMenuOpen: _isMenuOpen,
              onProfileTap: _toggleMenu,
              fullName: _currentUser?.fullName ?? '',
              profileImageUrl: _currentUser?.profileImageUrl == null
                  ? null
                  : 'http://localhost:8000${_currentUser!.profileImageUrl}',
            ),
            Positioned(
              top: 115,
              right: 60,
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
                    ? GestureDetector(
                        onTap: () {},
                        child: UserMenu(
                          key: const ValueKey('menu'),
                          activeRole: RoleLabelMapper.toLabel(
                            _currentUser?.activeRole ?? 'ADMIN',
                          ),
                          availableRoles: (_currentUser?.availableRoles ?? const [])
                              .map(RoleLabelMapper.toLabel)
                              .toList(),
                          onRoleSelected: (role)
                          {
                            debugPrint('Ruolo selezionato: $role');
                          },
                          onSettings: _toggleMenu,
                          onLogout: _logout,
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('empty'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //LogoutUser
  Future<void> _logout() async
  {
    final apiService = ApiService();

    await apiService.logout();

    if (!mounted) return;

    context.go('/login');
  }
}