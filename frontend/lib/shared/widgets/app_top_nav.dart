import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/models/me_response.dart';
import '../../features/dashboard/dashboard_modules.dart';
import '../../features/reports/report_strings.dart';
import '../../features/updates/update_strings.dart';
import '../../routing/app_router.dart';
import '../../routing/role_sections.dart';
import 'app_menu.dart';
import 'app_tooltip.dart';

const double _fontSize = 17;
const double _itemGap = 22;

const double _denseFontSize = 14.5;
const double _denseItemGap = 20;
const double _underlineHeight = 3;
const double _underlineGap = 7;

const double _entryPadding = 5;

const Duration _hoverFade = Duration(milliseconds: 150);

const double _chevronSize = 19;
const double _menuWidth = 230;

const String kMoreEntry = 'Altro';

class AppDestination
{
  final String label;
  final String? route;

  // Shown in the bar's menus, never on the bar itself.
  final IconData? icon;

  const AppDestination(this.label, this.route, {this.icon});
}

const Map<String, IconData> _moduleIcons = {
  'Persone': Icons.groups_rounded,
  'Lezioni': Icons.menu_book_rounded,
  'Contabilità': Icons.account_balance_wallet_rounded,
  'Associazione': Icons.domain_rounded,
};

// reports only for those who receive them, updates only for IT managers.
typedef MenuDestinations = ({
  AppDestination ownPage,
  AppDestination settings,
  AppDestination? reports,
  AppDestination? updates,
});

AppDestination _destinationOf(RoleSection section, String? home)
{
  return AppDestination(
    section.label,
    section.available && home != null ? '$home/${section.slug}' : null,
    icon: kSectionIcons[section.slug],
  );
}

// role is the page's, not the identity's: a page leaving after a switch keeps its bar.
List<AppDestination> destinationsFor(MeResponse user, {String? role})
{
  role ??= user.activeRole;

  if (role == 'ADMIN')
  {
    return [
      const AppDestination('Home', adminHome, icon: Icons.home_rounded),
      for (final module in dashboardModules)
        AppDestination(module.title, module.route, icon: _moduleIcons[module.title] ?? module.icon),
    ];
  }

  final String? home = homeByRole[role];

  if (home == null)
  {
    return const [];
  }

  return [
    AppDestination('Home', home, icon: Icons.home_rounded),
    for (final section in sectionsFor(
      role,
      hasParentalResponsibility: user.hasParentalResponsibility,
    ))
      _destinationOf(section, home),
  ];
}

String _screenRoute(String route, String? from)
{
  return from == null ? route : '$route?from=$from';
}

MenuDestinations menuDestinationsFor(MeResponse user, {String? role, String? from})
{
  role ??= user.activeRole;

  return (
    ownPage: AppDestination(user.firstName, _screenRoute(ownPageForRole(role), from)),
    settings: AppDestination('Impostazioni', _screenRoute(settingsPageForRole(role), from)),
    reports: user.readsReports ? AppDestination(kReportsEntry, _screenRoute(reportsPageForRole(role), from)) : null,
    updates: user.managesUpdates ? AppDestination(kUpdatesEntry, _screenRoute(updatesPageForRole(role), from)) : null,
  );
}

// Longest matching route wins: a home matches every section beneath it.
int? _currentIndex(List<AppDestination> destinations, String path)
{
  int? current;
  int matched = -1;

  for (var i = 0; i < destinations.length; i++)
  {
    final String? route = destinations[i].route;

    if (route == null || !(path == route || path.startsWith('$route/')))
    {
      continue;
    }

    if (route.length > matched)
    {
      current = i;
      matched = route.length;
    }
  }

  return current;
}

class AppTopNav extends StatefulWidget
{
  final List<AppDestination> destinations;

  final bool dense;

  // Entries past the room there is go under the more entry, the last ones first.
  final bool folds;

  const AppTopNav({super.key, required this.destinations, this.dense = false, this.folds = false});

  @override
  State<AppTopNav> createState() => _AppTopNavState();
}

class _AppTopNavState extends State<AppTopNav>
{
  @override
  void initState()
  {
    super.initState();

    // The fold is measured with the bar's font: measured again once it has loaded.
    PaintingBinding.instance.systemFonts.addListener(_refold);
  }

  @override
  void dispose()
  {
    PaintingBinding.instance.systemFonts.removeListener(_refold);
    super.dispose();
  }

  void _refold()
  {
    if (mounted && widget.folds)
    {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context)
  {
    // GoRouter.of registers no dependency; listening to the delegate rebuilds on location change.
    final GoRouterDelegate delegate = GoRouter.of(context).routerDelegate;

    final Widget row = ListenableBuilder(
      listenable: delegate,
      builder: (context, _) => _buildRow(context, delegate.currentConfiguration.uri.path),
    );

    // Room above as below the words, so they sit on the low bar's middle like its other parts.
    if (!widget.dense)
    {
      return row;
    }

    return Padding(padding: const EdgeInsets.only(top: _underlineGap + _underlineHeight), child: row);
  }

  double get _gap => widget.dense ? _denseItemGap : _itemGap;

  double get _labelSize => widget.dense ? _denseFontSize : _fontSize;

  double _entryWidth(BuildContext context, String label, {bool chevron = false})
  {
    final TextPainter painter = TextPainter(
      // Text inherits DefaultTextStyle (letter spacing): measured without it, labels overflow.
      text: TextSpan(text: label, style: DefaultTextStyle.of(context).style.merge(_navStyle(_labelSize, enabled: true))),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double width = painter.width;
    painter.dispose();

    return width + 2 * _entryPadding + (chevron ? _chevronSize + 1 : 0);
  }

  // How many entries stay on the bar, with the more entry after them when not all of them do.
  int _fitting(BuildContext context, double room)
  {
    final List<double> widths = [
      for (final destination in widget.destinations) _entryWidth(context, destination.label),
    ];

    double used = 0;

    for (var i = 0; i < widths.length; i++)
    {
      used += widths[i] + (i > 0 ? _gap : 0);
    }

    if (used <= room)
    {
      return widths.length;
    }

    final double more = _entryWidth(context, kMoreEntry, chevron: true);

    for (var kept = widths.length - 1; kept > 0; kept--)
    {
      double width = more + kept * _gap;

      for (var i = 0; i < kept; i++)
      {
        width += widths[i];
      }

      if (width <= room)
      {
        return kept;
      }
    }

    return 0;
  }

  Widget _buildRow(BuildContext context, String path)
  {
    final List<AppDestination> destinations = widget.destinations;
    final int? current = currentDestinationIndex(destinations, path);

    Widget entry(int i) => _NavEntry(
          label: destinations[i].label,
          route: destinations[i].route,
          fontSize: _labelSize,
          current: i == current,
        );

    if (!widget.folds)
    {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == destinations.length - 1 ? 0 : _gap),
              child: entry(i),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final int kept = _fitting(context, constraints.maxWidth);
        final List<int> folded = [for (var i = kept; i < destinations.length; i++) i];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < kept; i++)
              Padding(
                padding: EdgeInsets.only(right: i == kept - 1 && folded.isEmpty ? 0 : _gap),
                child: entry(i),
              ),
            if (folded.isNotEmpty)
              _MoreEntry(
                destinations: [for (final i in folded) destinations[i]],
                current: current != null && current >= kept ? destinations[current] : null,
                fontSize: _labelSize,
              ),
          ],
        );
      },
    );
  }
}

TextStyle _navStyle(double fontSize, {required bool enabled})
{
  return GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    color: enabled ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
  );
}

int? currentDestinationIndex(List<AppDestination> destinations, String path) => _currentIndex(destinations, path);

// The destinations as a menu, opened by the more entry and by the minimal window's single button.
Widget appDestinationMenu(
  BuildContext context, {
  required List<AppDestination> destinations,
  required AppDestination? current,
  required VoidCallback close,
  Widget? footer,
})
{
  return AppMenuCard(
    width: _menuWidth,
    children: [
      const SizedBox(height: 6),
      for (final destination in destinations)
        AppMenuItem(
          icon: destination.icon,
          text: destination.label,
          current: identical(destination, current),
          dense: true,
          onTap: destination.route == null
              ? null
              : ()
                {
                  close();

                  if (!identical(destination, current))
                  {
                    context.go(destination.route!);
                  }
                },
        ),
      const SizedBox(height: 6),
      if (footer != null) ...[
        const Divider(height: 1),
        footer,
      ],
    ],
  );
}

class _MoreEntry extends StatefulWidget
{
  final List<AppDestination> destinations;
  final AppDestination? current;
  final double fontSize;

  const _MoreEntry({required this.destinations, required this.current, required this.fontSize});

  @override
  State<_MoreEntry> createState() => _MoreEntryState();
}

class _MoreEntryState extends State<_MoreEntry>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return AppAnchoredMenu(
      alignEnd: true,
      gap: 14,
      menu: (context, close) => appDestinationMenu(
        context,
        destinations: widget.destinations,
        current: widget.current,
        close: close,
      ),
      builder: (context, open, toggle) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle,
          child: _Underlined(
            underlined: widget.current != null || _hover || open,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kMoreEntry, maxLines: 1, softWrap: false, style: _navStyle(widget.fontSize, enabled: true)),
                const SizedBox(width: 1),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: VisualEffects.of(context) ? const Duration(milliseconds: 200) : Duration.zero,
                  curve: Curves.easeInOut,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: _chevronSize,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// The minimal window's whole navigation: the open page's name, opening every destination.
class AppNavSwitch extends StatelessWidget
{
  final List<AppDestination> destinations;

  // The pages of the user menu, named when one of them is open.
  final List<AppDestination> others;

  // Hung from the button's right end, for a button at the bar's end.
  final bool alignEnd;

  // Under the destinations: what the face would open where the bar shows none.
  final Widget Function(BuildContext context, VoidCallback close)? footer;

  const AppNavSwitch({
    super.key,
    required this.destinations,
    this.others = const [],
    this.alignEnd = false,
    this.footer,
  });

  @override
  Widget build(BuildContext context)
  {
    final GoRouterDelegate delegate = GoRouter.of(context).routerDelegate;

    return ListenableBuilder(
      listenable: delegate,
      builder: (context, _) => _build(context, delegate.currentConfiguration.uri.path),
    );
  }

  Widget _build(BuildContext context, String path)
  {
    final int? index = _currentIndex(destinations, path);
    final AppDestination? current = index == null ? null : destinations[index];

    final AppDestination? other = others
        .where((destination) => destination.route != null && path == destination.route!.split('?').first)
        .firstOrNull;

    final String label = current?.label ?? other?.label ?? destinations.firstOrNull?.label ?? '';

    return AppAnchoredMenu(
      gap: 12,
      alignEnd: alignEnd,
      menu: (context, close) => appDestinationMenu(
        context,
        destinations: destinations,
        current: current,
        close: close,
        footer: footer?.call(context, close),
      ),
      builder: (context, open, toggle) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 38,
            padding: const EdgeInsets.only(left: 12, right: 10),
            decoration: BoxDecoration(
              color: open ? AppTheme.closedSurface : AppTheme.todaySurface,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_rounded, size: _chevronSize, color: AppTheme.trialTealDeep),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: _denseFontSize,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.trialTealDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: VisualEffects.of(context) ? const Duration(milliseconds: 200) : Duration.zero,
                  curve: Curves.easeInOut,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: _chevronSize,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

    final Widget entry = _Underlined(
      underlined: underlined,
      child: Text(
        widget.label,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: _navStyle(widget.fontSize, enabled: enabled),
      ),
    );

    if (!enabled)
    {
      return AppTooltip(
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

class _Underlined extends StatelessWidget
{
  final bool underlined;
  final Widget child;

  const _Underlined({required this.underlined, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: _entryPadding,
            right: _entryPadding,
            bottom: _underlineGap + _underlineHeight,
          ),
          child: child,
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
  }
}
