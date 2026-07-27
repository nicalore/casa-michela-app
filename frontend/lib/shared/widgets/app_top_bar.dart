import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../features/auth/models/me_response.dart';
import '../../services/api_service.dart';
import 'app_top_nav.dart';
import 'overflow_tooltip_text.dart';
import 'role_switch_dialog.dart';
import 'snackbar.dart';
import 'user_menu.dart';

const Color _headerShadow = Color(0x14000000);

const double _topMargin = 20;
const double _barHeight = 80;

// How far the shadow reaches past the bar. It is a wide soft one — 24 of blur
// laid over 19 of spread — so it carries well beyond the white itself, and a
// page that only clears the bar ends up with the shadow falling across whatever
// it puts first. A little more than the 43 those two add up to, for air.
const double _shadowReach = 50;

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

  // Route of the page showing the bar: its entry in the destinations keeps the
  // underline for as long as you are there.
  final String currentRoute;

  // The identity already in hand, for a page that fetches it for its own
  // reasons anyway: the dashboard needs the first name for its greeting, and
  // handing it over here spares a second identical request. Left out, the bar
  // asks for it itself, which is what every other page does.
  final MeResponse? user;

  const AppTopBar({
    super.key,
    required this.currentRoute,
    this.user,
  });

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar>
{
  static const double _horizontalMargin = 40;
  static const double _avatarSize = 54;
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

  // Where the menu hangs: just below the bar, under the avatar it belongs to.
  static const double _userMenuTop = 115;
  static const double _userMenuRight = 60;

  final ApiService _apiService = ApiService();

  bool _isMenuOpen = false;
  MeResponse? _user;

  late final String _sessionCacheBuster;

  @override
  void initState()
  {
    super.initState();

    // Computed once per mount: the value must stay stable across rebuilds, or
    // every rebuild would produce a new URL and refetch the image.
    _sessionCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

    _user = widget.user;

    if (_user == null)
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
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  void _closeMenu()
  {
    if (_isMenuOpen)
    {
      setState(() => _isMenuOpen = false);
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
    // picture replaces the old one instead of showing the stale copy.
    return '$absoluteUrl?v=$_sessionCacheBuster';
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
  Widget _buildProfileButton()
  {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxRoleWidth),
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
                    Text(
                      'SEI AUTENTICATO COME',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
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
                        fontSize: 17,
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

  Widget _buildAvatar(String? imageUrl)
  {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
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
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialTealDeep,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildMenu()
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

  Widget _buildBar()
  {
    final imageUrl = _absoluteImageUrl;

    return Positioned(
      left: _horizontalMargin,
      right: _horizontalMargin,
      top: _topMargin,
      child: Container(
        height: _barHeight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(color: _headerShadow, blurRadius: 24, spreadRadius: 19),
          ],
        ),
        child: LayoutBuilder(
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
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AppTopNav(currentRoute: widget.currentRoute),
                    ),
                  ),
                ),
                SizedBox(
                  width: sideWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: _buildProfileButton()),
                      const SizedBox(width: 12),
                      _buildAvatar(imageUrl),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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
      child: Stack(
        children: [
          // A sheet over the whole page that catches the next tap and closes the
          // menu with it. It is always here and merely stops listening when the
          // menu is shut, rather than being added and removed: a child appearing
          // at the head of the list shifts the two below it by one, and Flutter,
          // which pairs children with their elements by position, would tear the
          // bar and the menu down and build them again on every open. That is
          // what cost the menu its opening animation and reset the underline
          // under whichever destination you were on.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isMenuOpen,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeMenu,
              ),
            ),
          ),
          _buildBar(),
          _buildMenu(),
        ],
      ),
    );
  }
}