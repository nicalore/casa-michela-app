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

// The bar on a narrow window: lower, and closer to the top edge, because on a
// phone the room above the fold is the scarcest thing there is.
const double _compactTopMargin = 12;
const double _compactBarHeight = 64;

// How far the shadow reaches past the bar. It is a wide soft one — 24 of blur
// laid over 19 of spread — so it carries well beyond the white itself, and a
// page that only clears the bar ends up with the shadow falling across whatever
// it puts first. A little more than the 43 those two add up to, for air.
const double _shadowReach = 50;

double _topMarginFor(AppWindowSize size) => size.isCompact ? _compactTopMargin : _topMargin;

double _barHeightFor(AppWindowSize size) => size.isCompact ? _compactBarHeight : _barHeight;

// The shell every page of the app wears: the wordmark, the destinations and the
// identity block, plus the menu that opens under it. It is a Positioned.fill and
// therefore belongs to a Stack, laid over the page content; outside the bar and
// the open menu it is transparent to the pointer, so what sits underneath keeps
// working.
//
// The identity it shows, the menu, the role switch and the logout all live here
// rather than in the pages, so a page joins the shell with one line and cannot
// end up with a bar that behaves differently from the others.
class AppTopBar extends StatefulWidget
{
  // Room a page has to leave itself at the top. The bar floats over the page
  // rather than standing in the column with it, so the space it needs is not
  // taken by anything and has to be left on purpose.
  static const double contentTopInset = _topMargin + _barHeight + _shadowReach;

  // The same room, measured for the width the page actually got. The compact
  // bar is shorter and sits higher, and a page that kept the wide inset would
  // open with a band of empty paper where a phone can least afford one.
  static double contentTopInsetFor(AppWindowSize size)
  {
    return _topMarginFor(size) + _barHeightFor(size) + (size.isCompact ? 44 : _shadowReach);
  }

  // Route of the page showing the bar, for the drawer that stands in for the
  // destinations on a narrow window: its entry is the one marked while you are
  // there. The row in the bar itself asks the router instead — it has to keep
  // agreeing with the bar of the page being handed over, which this cannot say.
  final String currentRoute;

  // The identity already in hand, for a page that fetches it for its own
  // reasons anyway: the dashboard needs the first name for its greeting, and
  // handing it over here spares a second identical request. Left out, the bar
  // asks for it itself, which is what every other page does.
  final MeResponse? user;

  // The sections of the page behind the bar. On a wide window they are the
  // rail's business and the bar never sees them; below the breakpoint the rail
  // is gone and they move into the drawer, which is the only place left that
  // can hold two levels of navigation at once.
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
  // Chosen so the lower line comes out at the size of the role on the other
  // end of the bar. The width is the only handle there is: the lines are scaled
  // to fill it, so it is the width, not the font size below, that decides how
  // big the mark reads. Narrower means smaller and quieter.
  static const double _wordmarkWidth = 124;

  // The two ends of the bar reserve the same width, so the destinations sit on
  // the middle of the bar itself rather than on the middle of whatever the
  // identity block leaves over.
  static const double _sideSlotWidth = 290;

  // What the role is allowed on the middle width. Long enough for
  // "Amministratore", which is 114px at the size it is set there; the two long
  // ones end in an ellipsis with the whole label in the tooltip, which is what
  // OverflowTooltipText is for.
  static const double _mediumRoleWidth = 170;

  // Air the destinations always keep on either side of them, so that a row
  // scaled down to fit still never touches the mark or the role. This is the
  // thing the middle width was missing: three equal slots put the words as
  // close to their neighbours as the arithmetic allowed.
  static const double _navGutter = 20;

  // Where the menu hangs: just below the bar, under the avatar it belongs to.
  static const double _userMenuGap = 15;

  final ApiService _apiService = ApiService();

  bool _isMenuOpen = false;
  bool _isDrawerOpen = false;
  MeResponse? _user;

  @override
  void initState()
  {
    super.initState();

    // What the page handed over, or failing that the identity the app saw last.
    // The bar is drawn on the first frame either way, which is what lets a step
    // between two destinations leave it standing: a bar waiting for its own
    // request would blink out in the middle of the handover and take the
    // illusion with it.
    _user = widget.user ?? _apiService.lastKnownIdentity;

    // Asked for all the same, because what is above is a memory and may be a
    // change of picture or of role out of date.
    if (widget.user == null)
    {
      _loadUser();
    }
  }

  // The page that hands the identity over may only have it a frame later, so
  // the bar keeps watching the property instead of reading it once.
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
      // The bar stays out rather than showing itself with nobody in it: not
      // being able to name the person is no reason to take the page away from
      // them.
    }
  }

  String get _activeRoleLabel
  {
    return RoleLabelMapper.toLabel(_user!.activeRole);
  }

  // Every role the person holds, in the same Italian labels the switch dialog
  // shows. With a single one the menu drops the "cambia ruolo" entry.
  List<String> get _availableRoleLabels
  {
    return _user!.availableRoles.map(RoleLabelMapper.toLabel).toList();
  }

  void _toggleMenu()
  {
    setState(()
    {
      _isMenuOpen = !_isMenuOpen;
      // Never both at once: they are two answers to the same question, and on a
      // window this narrow they would be standing on top of each other.
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

  // The menu closes first: leaving it hanging open behind the blurred backdrop
  // would show it again, still open, once the dialog is dismissed.
  void _openRoleSwitcher()
  {
    setState(() => _isMenuOpen = false);

    showRoleSwitchDialog(
      context: context,
      activeRole: _activeRoleLabel,
      availableRoles: _availableRoleLabels,
    );
  }

  // The local logout (session cleanup plus the redirect to /login driven by
  // authState) happens only if the server call succeeds. On failure the user
  // stays authenticated on the page and is told what happened, rather than
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

    // The query parameter defeats the browser cache, so a freshly uploaded
    // picture replaces the old one instead of showing the stale copy. It counts
    // the changes of picture rather than the time, so the URL is the same on
    // every page of the app: stamped with the moment the bar was built, each
    // page would ask for the same image again under a name the cache had never
    // seen, and the face would blink on every navigation.
    return '$absoluteUrl?v=${_apiService.profileImageVersion}';
  }

  // Works on the already concatenated full name, splitting on whitespace,
  // because first and last name are not available separately here.
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

  // The name used to sit here, and it already sits fifty pixels below in the
  // greeting. The role does not appear anywhere else on the page and used to be
  // buried inside the menu, so the bar now answers a question you could not
  // otherwise ask it: which of your roles you are currently wearing.
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
                    // Set like the upper line of the mark on the other end:
                    // upper case, tracked, muted, small. The two ends of the
                    // bar then read as one pair of blocks facing each other,
                    // each a quiet label over a name.
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

  // Two lines locked to one width. Each is scaled to fill the box rather than
  // set at a chosen size, which is the only way to make two different words end
  // flush: type set at a fixed size ends where the letters happen to end.
  //
  // Because the scale is what makes them equal, the size written below only
  // decides the ratio between the two lines, not how big they come out. The
  // upper line is uppercase and tracked so it needs more width per letter and
  // therefore lands smaller once fitted, which is what keeps it subordinate to
  // the name under it.
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
              // The same weight and the same colour as the role at the other
              // end, so the two ends of the bar carry equal weight. They cannot
              // mirror each other in shape: that end finishes on a 54px circle
              // that you can click, this one is a mark that does nothing. What
              // can be made equal is how loudly they speak.
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

  // Three lines and nothing else: on this width the word "menu" would cost more
  // room than it explains, and this is the one drawing everybody already reads
  // as "the rest of the app is behind here".
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
      // Keying on the URL forces a rebuild when the picture changes, which a
      // plain backgroundImage swap would not do.
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

  // The bar as it is on a window wide enough for it: the mark on one end, the
  // destinations along the middle, who you are on the other.
  Widget _buildWideBar(AppWindowSize size, String? imageUrl)
  {
    // On the middle width the bar stops reserving equal ends. Two hundred and
    // ninety pixels a side is what centres the destinations on a wide bar, and
    // it is also what leaves them 348 of the 928 there are at 1024 — half of
    // what the six words need. Here the mark and the role take the width they
    // actually are, the destinations take everything else, and the two gutters
    // keep them from ever touching either.
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
        // The side slots give way before the middle does, so a bar too
        // narrow for everything squeezes the mark and the role rather than
        // leaving the destinations no room at all.
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
              // Below its natural width the row of destinations shrinks as
              // a whole instead of overflowing: the words keep their
              // spacing and their proportions, and the bar keeps working
              // down to sizes where nothing else would fit.
              child: Padding(
                // The same air the middle width keeps. Here the slots are
                // usually generous enough on their own, but between 1280 and
                // about 1350 the row fills its slot exactly, and without this
                // it would end flush against the block beside it.
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

  // The bar on a narrow window. The destinations are not squeezed into it, they
  // are moved out of it: what stays is the one thing that opens them, the mark
  // that says which app this is, and the face that opens the identity menu.
  Widget _buildCompactBar(String? imageUrl)
  {
    return Row(
      children: [
        _buildDrawerButton(),
        const SizedBox(width: 4),
        // Takes what the two ends leave and gives the rest back: the mark is
        // the one thing here that can be cut short without costing a way of
        // getting somewhere.
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
    // Nothing at all until the identity arrives: a bar drawn now would have an
    // empty role and a blank avatar in it, and would then jump as they fill in.
    if (_user == null)
    {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      // The page under it decides the shape, not the window: on a wide layout
      // the page can be wider than the window and scroll, and a bar measured
      // against the window would change form halfway along its own page.
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final size = AppBreakpoints.fromWidth(constraints.maxWidth);

          return Stack(
            children: [
              // A sheet over the whole page that catches the next tap and closes
              // whatever is open with it. It is always here and merely stops
              // listening when nothing is: a child appearing at the head of the
              // list shifts the ones below it by one, and Flutter, which pairs
              // children with their elements by position, would tear the bar and
              // the menu down and build them again on every open. That is what
              // cost the menu its opening animation and reset the underline
              // under whichever destination you were on.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !(_isMenuOpen || _isDrawerOpen),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeOverlays,
                    // Dimmed only under the drawer, which covers the page and
                    // has to say so. The menu hangs off the bar over a page you
                    // are still reading, and darkening it would be a lie about
                    // how much of the app it has taken.
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
