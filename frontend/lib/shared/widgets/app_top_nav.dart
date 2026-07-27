import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../features/dashboard/dashboard_modules.dart';

const double _fontSize = 17;
const double _itemGap = 22;
const double _underlineHeight = 3;
const double _underlineGap = 7;

// Breathing room on either side of a word, inside its clickable area. It also
// carries the underline a little past the word, which keeps the mark from
// looking like it is squeezing the text it belongs to.
const double _entryPadding = 5;

// Same duration and curve as the bar that opens beside a user menu entry, so
// the two hover marks of the interface move as one gesture.
const Duration _hoverFade = Duration(milliseconds: 150);

class _NavDestination
{
  final String label;
  final String? route;

  const _NavDestination(this.label, this.route);
}

// The modules, written along the header bar, with Home opening the row and
// Impostazioni closing it. Those two are not modules and have no card on the
// page, which is why they live here and not in dashboardModules.
class AppTopNav extends StatelessWidget
{
  // Route of the page on screen: its entry keeps the underline while you are
  // there, without waiting for the pointer.
  final String? currentRoute;

  const AppTopNav({super.key, this.currentRoute});

  List<_NavDestination> get _destinations
  {
    return [
      const _NavDestination('Home', '/dashboard'),
      for (final module in dashboardModules) _NavDestination(module.title, module.route),
      const _NavDestination('Impostazioni', '/settings'),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final destinations = _destinations;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < destinations.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i == destinations.length - 1 ? 0 : _itemGap),
            child: _NavEntry(
              label: destinations[i].label,
              route: destinations[i].route,
              current: destinations[i].route != null &&
                  destinations[i].route == currentRoute,
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

  const _NavEntry({
    required this.label,
    required this.route,
    required this.current,
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

    // The word is laid out first and the line is stretched to whatever width it
    // turned out to be. Measuring the word instead, with an IntrinsicWidth, is
    // what used to clip these labels: the intrinsic width is worked out once
    // and then imposed as a tight constraint, so when the real font arrived
    // from the network after the first layout the text no longer fitted the
    // width its stand-in had asked for, and the last letters were cut off.
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
              fontSize: _fontSize,
              // The weight is the same in every state on purpose: a bolder
              // hover would widen the word and shove its neighbours sideways.
              fontWeight: FontWeight.w600,
              color: enabled ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
            ),
          ),
        ),
        // The line opens from the middle and closes back into it, the same way
        // the vertical bar grows out of the centre of a menu entry. It is
        // squeezed by a transform and not by a width, so it takes no part in
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
