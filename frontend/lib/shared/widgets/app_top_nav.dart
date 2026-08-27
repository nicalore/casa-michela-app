import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../features/dashboard/dashboard_modules.dart';

const double _fontSize = 17;
const double _itemGap = 22;

const double _denseFontSize = 15;
const double _denseItemGap = 14;
const double _underlineHeight = 3;
const double _underlineGap = 7;

const double _entryPadding = 5;

const Duration _hoverFade = Duration(milliseconds: 150);

class AppDestination
{
  final String label;
  final String? route;

  const AppDestination(this.label, this.route);
}

List<AppDestination> get appDestinations
{
  return [
    const AppDestination('Home', '/dashboard'),
    for (final module in dashboardModules) AppDestination(module.title, module.route),
    const AppDestination('Impostazioni', '/settings'),
  ];
}

bool _isCurrent(String? route, String path)
{
  if (route == null)
  {
    return false;
  }

  return path == route || path.startsWith('$route/');
}

class AppTopNav extends StatelessWidget
{
  final bool dense;

  const AppTopNav({super.key, this.dense = false});

  @override
  Widget build(BuildContext context)
  {
    // Asked of the router's delegate, not GoRouter.of, which makes nobody a
    // dependent: nothing would rebuild when the location changes.
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
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.plusJakartaSans(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              color: enabled ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
            ),
          ),
        ),
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
