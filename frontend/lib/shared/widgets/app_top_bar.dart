import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/api_config.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../features/auth/models/me_response.dart';
import '../../services/api_service.dart';
import 'app_nav_drawer.dart';
import 'app_section_rail.dart';
import 'app_top_nav.dart';
import 'overflow_tooltip_text.dart';
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

class AppTopBar extends StatefulWidget
{
  static const double contentTopInset = _topMargin + _barHeight + _shadowReach;

  static double contentTopInsetFor(AppWindowSize size)
  {
    return _topMarginFor(size) + _barHeightFor(size) + (size.isCompact ? 44 : _shadowReach);
  }

  final String currentRoute;

  final MeResponse? user;

  final String? sectionTitle;
  final List<RailGroup> sectionGroups;
  final int selectedSection;
  final ValueChanged<int>? onSectionSelected;

  const AppTopBar({
    super.key,
    required this.currentRoute,
    this.user,
    this.sectionTitle,
    this.sectionGroups = const [],
    this.selectedSection = 0,
    this.onSectionSelected,
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
  MeResponse? _user;

  @override
  void initState()
  {
    super.initState();

    _user = widget.user ?? _apiService.lastKnownIdentity;

    if (widget.user == null)
    {
      _loadUser();
    }
  }

  @override
  void didUpdateWidget(AppTopBar oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.user != null && widget.user != oldWidget.user)
    {
      setState(() => _user = widget.user);
    }
  }

  Future<void> _loadUser() async
  {
    try
    {
      final user = await _apiService.me();

      if (mounted)
      {
        setState(() => _user = user);
      }
    }
    catch (e)
    {
      // Intentionally ignored: the bar renders without a user.
    }
  }

  String get _activeRoleLabel
  {
    return RoleLabelMapper.toLabel(_user!.activeRole);
  }

  List<String> get _availableRoleLabels
  {
    return _user!.availableRoles.map(RoleLabelMapper.toLabel).toList();
  }

  void _toggleMenu()
  {
    setState(()
    {
      _isMenuOpen = !_isMenuOpen;
      _isDrawerOpen = false;
    });
  }

  void _toggleDrawer()
  {
    setState(()
    {
      _isDrawerOpen = !_isDrawerOpen;
      _isMenuOpen = false;
    });
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
    }
  }

  void _openRoleSwitcher()
  {
    setState(() => _isMenuOpen = false);

    showRoleSwitchDialog(
      context: context,
      activeRole: _activeRoleLabel,
      availableRoles: _availableRoleLabels,
    );
  }

  // Local logout only after the server call succeeds (TC-IAM-012 / RF-IAM-018).
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

  String? get _absoluteImageUrl
  {
    final url = _user?.profileImageUrl;

    if (url == null || url.isEmpty)
    {
      return null;
    }

    final absoluteUrl = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : '${ApiConfig.baseUrl}$url';

    // Cache-buster counts picture changes, not time: a per-build URL would blink
    // the face on every navigation.
    return '$absoluteUrl?v=${_apiService.profileImageVersion}';
  }

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

    return ConstrainedBox(
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
                duration: const Duration(milliseconds: 200),
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
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.trialTurquoise, width: 2),
      ),
      // Keying on the URL forces a rebuild when the picture changes, which a plain
      // backgroundImage swap would not.
      child: CircleAvatar(
        key: ValueKey(imageUrl),
        backgroundColor: Colors.white,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
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
            ? UserMenu(
                key: const ValueKey('menu'),
                canChangeRole: _availableRoleLabels.length > 1,
                onChangeRole: _openRoleSwitcher,
                onLogout: _logout,
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
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const AppTopNav(dense: true),
              ),
            ),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _navGutter),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: const AppTopNav(),
                  ),
                ),
              ),
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
        _buildDrawerButton(),
        const SizedBox(width: 4),
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
    final imageUrl = _absoluteImageUrl;
    final margin = AppBreakpoints.pageMargin(size);

    return Positioned(
      left: margin,
      right: margin,
      top: _topMarginFor(size),
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
    );
  }

  Widget _buildDrawer(AppWindowSize size)
  {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
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
        child: _isDrawerOpen && size.isCompact
            ? AppNavDrawer(
                key: const ValueKey('drawer'),
                currentRoute: widget.currentRoute,
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
              // Always present, merely deaf: a child appearing at the head re-pairs the
              // stack by position and rebuilt the bar on every open.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !(_isMenuOpen || _isDrawerOpen),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeOverlays,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      color: _isDrawerOpen
                          ? AppTheme.trialInk.withValues(alpha: 0.28)
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
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
