import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../features/auth/models/me_response.dart';
import '../../features/reports/reports_board.dart';
import '../../features/updates/unread_updates.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../services/profile_photo_image.dart';
import 'app_nav_drawer.dart';
import 'app_section_rail.dart';
import 'app_top_nav.dart';
import 'birthday_confetti.dart';
import 'desktop_tour.dart';
import 'halloween_bats.dart';
import 'overflow_tooltip_text.dart';
import 'page_transition.dart';
import 'role_switch_dialog.dart';
import 'shared_components.dart';
import 'snackbar.dart';
import 'user_menu.dart';

const Color _headerShadow = Color(0x14000000);

const double _topMargin = 20;
const double _barHeight = 80;

const double _compactTopMargin = 12;
const double _compactBarHeight = 64;

const double _shadowReach = 50;

double _topMarginFor(AppWindowSize size) => size.isCompact ? _compactTopMargin : _topMargin;

double _barHeightFor(AppWindowSize size) => size.isCompact ? _compactBarHeight : _barHeight;

const String kTourTopBar = 'topbar';
const String kTourTopBarRole = 'topbar.role';
const String kTourTopBarMenu = 'topbar.menu';
const String kTourTopBarSections = 'topbar.sections';

class AppTopBar extends StatefulWidget
{
  static const double contentTopInset = _topMargin + _barHeight + _shadowReach;

  // The user menu of the bar on show; the desktop tour opens and shuts it too.
  static final ValueNotifier<bool> userMenuOpen = ValueNotifier<bool>(false);

  static double contentTopInsetFor(AppWindowSize size)
  {
    return _topMarginFor(size) + _barHeightFor(size) + (size.isCompact ? 44 : _shadowReach);
  }

  static double bottomFor(AppWindowSize size) => _topMarginFor(size) + _barHeightFor(size);

  final String currentRoute;

  final MeResponse? user;

  final String? sectionTitle;
  final List<RailGroup> sectionGroups;
  final int selectedSection;
  final ValueChanged<int>? onSectionSelected;

  // False for single-page roles: the bar keeps the wordmark and user area, dropping nav and drawer.
  final bool showNavigation;

  const AppTopBar({
    super.key,
    required this.currentRoute,
    this.user,
    this.sectionTitle,
    this.sectionGroups = const [],
    this.selectedSection = 0,
    this.onSectionSelected,
    this.showNavigation = true,
  });

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar>
{
  static const double _avatarSize = 54;
  static const double _compactAvatarSize = 42;
  static const double _maxRoleWidth = 190;
  static const double _wordmarkWidth = 124;

  static const double _sideSlotWidth = 290;

  static const double _mediumRoleWidth = 170;

  static const double _navGutter = 20;

  static const double _userMenuGap = 15;

  final ApiService _apiService = ApiService();

  bool _isMenuOpen = false;
  bool _isDrawerOpen = false;

  // Effects off: the user menu, its arrow and the drawer snap open and shut.
  bool _animates = true;

  @override
  void initState()
  {
    super.initState();

    if (widget.user == null && _apiService.lastKnownIdentity == null)
    {
      _loadUser();
    }

    // The menu's count, ready before it opens.
    if (!ReportsBoard.instance.loaded)
    {
      unawaited(ReportsBoard.instance.refresh(_user));
    }

    AppTopBar.userMenuOpen.addListener(_followMenu);

    // Whatever page opens first after signing in shows the updates not yet read.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        unawaited(showUnreadUpdatesOnce(context));
      }
    });
  }

  @override
  void dispose()
  {
    AppTopBar.userMenuOpen.removeListener(_followMenu);
    super.dispose();
  }

  // Bars of the destinations kept behind stay as they are.
  void _followMenu()
  {
    final bool open = AppTopBar.userMenuOpen.value;

    if (!mounted || open == _isMenuOpen || !isDestinationShownNow(context))
    {
      return;
    }

    setState(()
    {
      _isMenuOpen = open;
      _isDrawerOpen = false;
    });
  }

  void _syncMenu() => AppTopBar.userMenuOpen.value = _isMenuOpen;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _animates = VisualEffects.of(context);
  }

  // The page's copy wins when set; otherwise the shared identity, watched so a role switch redraws.
  MeResponse? get _user => widget.user ?? _apiService.lastKnownIdentity;

  // The page's role, not the identity's: a page leaving after a switch keeps its bar.
  String get _role => roleOfPath(widget.currentRoute) ?? _user!.activeRole;

  List<AppDestination> get _destinations => destinationsFor(_user!, role: _role);

  Future<void> _loadUser() async
  {
    try
    {
      await _apiService.me();
    }
    catch (e)
    {
      // Intentionally ignored: the bar renders without a user.
    }
  }

  String get _activeRoleLabel
  {
    return RoleLabelMapper.toLabel(_role, feminine: _user?.gender == 'F');
  }

  void _toggleMenu()
  {
    setState(()
    {
      _isMenuOpen = !_isMenuOpen;
      _isDrawerOpen = false;
    });
    _syncMenu();

    if (_isMenuOpen)
    {
      unawaited(ReportsBoard.instance.refresh(_user));
    }
  }

  void _toggleDrawer()
  {
    setState(()
    {
      _isDrawerOpen = !_isDrawerOpen;
      _isMenuOpen = false;
    });
    _syncMenu();
  }

  void _closeOverlays()
  {
    if (_isMenuOpen || _isDrawerOpen)
    {
      setState(()
      {
        _isMenuOpen = false;
        _isDrawerOpen = false;
      });
      _syncMenu();
    }
  }

  void _goTo(String route)
  {
    setState(() => _isMenuOpen = false);
    _syncMenu();

    if (route != widget.currentRoute)
    {
      context.go(route);
    }
  }

  void _openRoleSwitcher()
  {
    setState(() => _isMenuOpen = false);
    _syncMenu();

    showRoleSwitchDialog(
      context: context,
      activeRole: _user!.activeRole,
      availableRoles: _user!.availableRoles,
      feminine: _user!.gender == 'F',
      onSelected: _switchRole,
    );
  }

  Future<void> _switchRole(String role) async
  {
    try
    {
      await _apiService.setActiveRole(role);
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

    context.go(homeForRole(role));
  }

  // Local logout only after the server call succeeds.
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
      _syncMenu();
      CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);

      return;
    }

    if (!mounted)
    {
      return;
    }

    context.go('/login');
  }

  String? get _imageUrl => _user?.profileImageUrl;

  String _initials(String fullName)
  {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty)
    {
      return '';
    }

    if (parts.length == 1)
    {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildProfileButton(AppWindowSize size)
  {
    final medium = size == AppWindowSize.medium;

    final Widget button = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: medium ? _mediumRoleWidth : _maxRoleWidth),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleMenu,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (size == AppWindowSize.expanded)
                      Text(
                        'SEI AUTENTICATO COME',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                          height: 1.2,
                          color: AppTheme.trialMutedText,
                        ),
                      ),
                    OverflowTooltipText(
                      text: _activeRoleLabel,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: medium ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: AppTheme.trialTealDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _isMenuOpen ? 0.5 : 0,
                duration: _animates ? const Duration(milliseconds: 200) : Duration.zero,
                curve: Curves.easeInOut,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppTheme.trialTealDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return DesktopTourTarget(id: kTourTopBarRole, child: button);
  }

  Widget _buildWordmark()
  {
    return SizedBox(
      width: _wordmarkWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(
              'ASSOCIAZIONE',
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4,
                height: 1.2,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(
              'Casa Michela',
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppTheme.trialTealDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerButton()
  {
    return FadeHoverIconButton(
      icon: _isDrawerOpen ? Icons.close_rounded : Icons.menu_rounded,
      color: AppTheme.trialTealDeep,
      hoverColor: AppTheme.trialGoldSurface,
      onTap: _toggleDrawer,
    );
  }

  Widget _buildAvatar(String? imageUrl, double diameter)
  {
    final ProfilePhotoImage? photo = ProfilePhotoImage.of(imageUrl);

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.trialTurquoise, width: 2),
      ),
      // Keyed on the URL: a backgroundImage swap alone would not rebuild on a new picture.
      child: CircleAvatar(
        key: ValueKey(photo),
        backgroundColor: Colors.white,
        backgroundImage: photo,
        child: photo == null
            ? Text(
                _initials(_user!.fullName),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: diameter * 0.37,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialTealDeep,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildMenu(AppWindowSize size)
  {
    return Positioned(
      top: _topMarginFor(size) + _barHeightFor(size) + _userMenuGap,
      right: AppBreakpoints.pageMargin(size) + 20,
      child: AnimatedSwitcher(
        duration: _animates ? const Duration(milliseconds: 180) : Duration.zero,
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
            ? DesktopTourTarget(
                key: const ValueKey('menu'),
                id: kTourTopBarMenu,
                child: UserMenu(
                  destinations: menuDestinationsFor(
                    _user!,
                    role: _role,
                    from: widget.currentRoute,
                  ),
                  canChangeRole: _user!.availableRoles.length > 1,
                  onGo: _goTo,
                  onChangeRole: _openRoleSwitcher,
                  onLogout: _logout,
                  unreadReports: ReportsBoard.instance.unread,
                ),
              )
            : const SizedBox(key: ValueKey('empty')),
      ),
    );
  }

  Widget _buildWideBar(AppWindowSize size, String? imageUrl)
  {
    if (size == AppWindowSize.medium)
    {
      return Row(
        children: [
          _buildWordmark(),
          const SizedBox(width: _navGutter),
          Expanded(
            child: widget.showNavigation
                ? Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: DesktopTourTarget(
                        id: kTourTopBarSections,
                        child: AppTopNav(destinations: _destinations, dense: true),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: _navGutter),
          _buildProfileButton(size),
          const SizedBox(width: 12),
          _buildAvatar(imageUrl, _avatarSize),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final sideWidth = math.min(_sideSlotWidth, constraints.maxWidth / 3);
        final navWidth = math.max(0.0, constraints.maxWidth - 2 * sideWidth);

        return Row(
          children: [
            SizedBox(
              width: sideWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildWordmark(),
              ),
            ),
            SizedBox(
              width: navWidth,
              child: widget.showNavigation
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _navGutter),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: DesktopTourTarget(
                            id: kTourTopBarSections,
                            child: AppTopNav(destinations: _destinations),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(
              width: sideWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(child: _buildProfileButton(size)),
                  const SizedBox(width: 12),
                  _buildAvatar(imageUrl, _avatarSize),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactBar(String? imageUrl)
  {
    return Row(
      children: [
        if (widget.showNavigation) ...[
          _buildDrawerButton(),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildWordmark(),
          ),
        ),
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleMenu,
            child: _buildAvatar(imageUrl, _compactAvatarSize),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(AppWindowSize size)
  {
    final imageUrl = _imageUrl;
    final margin = AppBreakpoints.pageMargin(size);

    return Positioned(
      left: margin,
      right: margin,
      top: _topMarginFor(size),
      child: DesktopTourTarget(
        id: kTourTopBar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: _barHeightFor(size),
          padding: EdgeInsets.symmetric(horizontal: size.isCompact ? 12 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
            boxShadow: const [
              BoxShadow(color: _headerShadow, blurRadius: 24, spreadRadius: 19),
            ],
          ),
          child: size.isCompact
              ? _buildCompactBar(imageUrl)
              : _buildWideBar(size, imageUrl),
        ),
      ),
    );
  }

  // The bar in page coordinates, stopping short of the pill's rounded ends.
  Rect _celebrationSource(AppWindowSize size, double width)
  {
    final double margin = AppBreakpoints.pageMargin(size);
    final double top = _topMarginFor(size);
    final double height = _barHeightFor(size);

    return Rect.fromLTRB(margin + height / 2, top, width - margin - height / 2, top + height);
  }

  // Always in the stack, empty on an ordinary day: a layer coming and going would re-pair the bar.
  Widget _buildConfetti(AppWindowSize size, double width)
  {
    return Positioned.fill(
      child: BirthdayConfetti(user: _user!, source: _celebrationSource(size, width)),
    );
  }

  // Only the homes fly them.
  Widget _buildBats(AppWindowSize size, double width)
  {
    return Positioned.fill(
      child: homeByRole.containsValue(widget.currentRoute)
          ? HalloweenBats(user: _user!, source: _celebrationSource(size, width))
          : const SizedBox.shrink(),
    );
  }

  Widget _buildDrawer(AppWindowSize size)
  {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: AnimatedSwitcher(
        duration: _animates ? const Duration(milliseconds: 220) : Duration.zero,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation)
        {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: widget.showNavigation && _isDrawerOpen && size.isCompact
            ? AppNavDrawer(
                key: const ValueKey('drawer'),
                currentRoute: widget.currentRoute,
                destinations: _destinations,
                sectionTitle: widget.sectionTitle,
                sectionGroups: widget.sectionGroups,
                selectedSection: widget.selectedSection,
                onSectionSelected: widget.onSectionSelected,
                onDismiss: _closeOverlays,
              )
            : const SizedBox(key: ValueKey('empty')),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return ValueListenableBuilder<MeResponse?>(
      valueListenable: _apiService.identity,
      builder: (context, _, _) => _buildBars(),
    );
  }

  Widget _buildBars()
  {
    if (_user == null)
    {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final size = AppBreakpoints.fromWidth(constraints.maxWidth);

          return Stack(
            children: [
              // Always present, only deaf: a new first child would rebuild the whole bar.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !(_isMenuOpen || _isDrawerOpen),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeOverlays,
                    child: AnimatedContainer(
                      duration: _animates ? const Duration(milliseconds: 220) : Duration.zero,
                      curve: Curves.easeOut,
                      color: _isDrawerOpen
                          ? AppTheme.trialInk.withValues(alpha: 0.28)
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
              _buildConfetti(size, constraints.maxWidth),
              _buildBats(size, constraints.maxWidth),
              _buildBar(size),
              _buildMenu(size),
              _buildDrawer(size),
            ],
          );
        },
      ),
    );
  }
}
