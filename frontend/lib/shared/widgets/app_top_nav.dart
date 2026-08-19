import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../features/dashboard/dashboard_modules.dart';

const double _fontSize = 17;
const double _itemGap = 22;

// The same row, set tighter for the middle width. Type set smaller beats type
// scaled down: a scale shrinks the spaces along with the letters.
const double _denseFontSize = 15;
const double _denseItemGap = 14;
const double _underlineHeight = 3;
const double _underlineGap = 7;

// Breathing room on either side of a word, inside its clickable area. It also
// carries the underline a little past the word, which keeps the mark from
// looking like it is squeezing the text it belongs to.
const double _entryPadding = 5;

// Same duration and curve as the bar that opens beside a user menu entry, so
// the two hover marks of the interface move as one gesture.
const Duration _hoverFade = Duration(milliseconds: 150);

class AppDestination
{
  final String label;
  final String? route;

  const AppDestination(this.label, this.route);
}

// The destinations of the app, in the order they are offered. The bar writes
// them along a row and the drawer writes them down a column, and they read the
// same list so the two can never end up offering different places to go.
List<AppDestination> get appDestinations
{
  return [
    const AppDestination('Home', '/dashboard'),
    for (final module in dashboardModules) AppDestination(module.title, module.route),
    const AppDestination('Impostazioni', '/settings'),
  ];
}

// Whether the app is at a destination, given where it actually is. True as well
// for whatever is opened out of one: a person's page is /people with a name on
// the end, and the row should go on saying you are in Persone.
bool _isCurrent(String? route, String path)
{
  if (route == null)
  {
    return false;
  }

  return path == route || path.startsWith('$route/');
}

// The modules, written along the header bar, with Home opening the row and
// Impostazioni closing it. Those two are not modules and have no card on the
// page, which is why they live here and not in dashboardModules.
class AppTopNav extends StatelessWidget
{
  // Set for a bar that has less room to give: see the two constants above.
  final bool dense;

  const AppTopNav({super.key, this.dense = false});

  @override
  Widget build(BuildContext context)
  {
    // Where the app is, asked of the router and not of the page.
    //
    // Every destination carries a bar of its own, and one told its own route
    // never learns the page was left: it went out in the crossfade with the mark
    // still under its word while the bar arriving came up with the new one
    // drawn — two pictures where there should be one movement.
    //
    // Read from the router, every bar answers the same thing at the same moment.
    //
    // The delegate is listened to and not the router: GoRouter.of makes nobody a
    // dependent, so nothing here would rebuild when the location changes.
    final GoRouterDelegate delegate = GoRouter.of(context).routerDelegate;

    return ListenableBuilder(
      listenable: delegate,
      builder: (context, _) => _buildRow(delegate.currentConfiguration.uri.path),
    );
  }

  Widget _buildRow(String path)
  {
    final destinations = appDestinations;
    final gap = dense ? _denseItemGap : _itemGap;
    final fontSize = dense ? _denseFontSize : _fontSize;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < destinations.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i == destinations.length - 1 ? 0 : gap),
            child: _NavEntry(
              label: destinations[i].label,
              route: destinations[i].route,
              fontSize: fontSize,
              current: _isCurrent(destinations[i].route, path),
            ),
          ),
      ],
    );
  }
}

class _NavEntry extends StatefulWidget
{
  final String label;
  final String? route;
  final bool current;
  final double fontSize;

  const _NavEntry({
    required this.label,
    required this.route,
    required this.current,
    required this.fontSize,
  });

  @override
  State<_NavEntry> createState() => _NavEntryState();
}

class _NavEntryState extends State<_NavEntry>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final route = widget.route;
    final enabled = route != null;
    final underlined = widget.current || (_hover && enabled);

    // The word is laid out first and the line stretched to it. An IntrinsicWidth
    // imposes a width worked out once, so when the real font arrived after the
    // first layout the text no longer fitted and the last letters were cut.
    final Widget entry = Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: _entryPadding,
            right: _entryPadding,
            bottom: _underlineGap + _underlineHeight,
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            // A destination is one word on one line. Left to wrap, a bar that
            // ran short would break "Contabilità" in half rather than let the
            // caller know it has no room.
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.plusJakartaSans(
              fontSize: widget.fontSize,
              // The weight is the same in every state on purpose: a bolder
              // hover would widen the word and shove its neighbours sideways.
              fontWeight: FontWeight.w600,
              color: enabled ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
            ),
          ),
        ),
        // Squeezed by a transform and not by a width, so it takes no part in
        // layout and the row cannot move as the line comes and goes.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _underlineHeight,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: underlined ? 1 : 0),
            duration: _hoverFade,
            curve: Curves.easeOut,
            builder: (context, factor, child) => Transform.scale(
              scaleX: factor,
              alignment: Alignment.center,
              child: child,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.trialGold,
                borderRadius: BorderRadius.circular(_underlineHeight),
              ),
            ),
          ),
        ),
      ],
    );

    if (!enabled)
    {
      return Tooltip(
        waitDuration: const Duration(milliseconds: 400),
        message: 'In arrivo',
        child: entry,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go(route),
        child: entry,
      ),
    );
  }
}
