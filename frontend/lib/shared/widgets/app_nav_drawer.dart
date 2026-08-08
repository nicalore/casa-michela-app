import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_section_rail.dart';
import 'app_top_nav.dart';
import 'shared_components.dart';

const double _maxWidth = 320;

// Never the whole window: the strip of page left uncovered is what says the
// drawer is standing over something you can go back to, and it is also where
// the finger lands to dismiss it.
const double _minUncoveredWidth = 56;

// Where the app goes on a window too narrow for the bar to carry it.
//
// It holds both levels of navigation at once — the destinations, and the
// sections of the page you are on — because that is exactly what the two
// surfaces it replaces do together, and a narrow window is no reason to make
// somebody open two things to get somewhere.
class AppNavDrawer extends StatelessWidget
{
  static double widthFor(double windowWidth)
  {
    return math.min(_maxWidth, math.max(0, windowWidth - _minUncoveredWidth));
  }

  final String currentRoute;

  // The module's own sections, when the page has any. Left out, the drawer is
  // the destinations alone.
  final String? sectionTitle;
  final List<RailGroup> sectionGroups;
  final int selectedSection;
  final ValueChanged<int>? onSectionSelected;

  final VoidCallback onDismiss;

  const AppNavDrawer({
    super.key,
    required this.currentRoute,
    required this.onDismiss,
    this.sectionTitle,
    this.sectionGroups = const [],
    this.selectedSection = 0,
    this.onSectionSelected,
  });

  Widget _buildHeader()
  {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 8, top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ASSOCIAZIONE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.4,
                    height: 1.2,
                    color: AppTheme.trialMutedText,
                  ),
                ),
                Text(
                  'Casa Michela',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
              ],
            ),
          ),
          FadeHoverIconButton(
            icon: Icons.close,
            color: AppTheme.trialTealDeep,
            hoverColor: AppTheme.trialGoldSurface,
            onTap: onDismiss,
          ),
        ],
      ),
    );
  }

  // The drawer closes before the route changes: left open it would still be
  // there, on the page you have already left, for as long as the transition
  // takes.
  void _goTo(BuildContext context, String route)
  {
    onDismiss();

    if (route != currentRoute)
    {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final children = <Widget>[];

    for (final destination in appDestinations)
    {
      final route = destination.route;

      children.add(AppRailEntry(
        label: destination.label,
        nested: false,
        selected: route != null && route == currentRoute,
        onTap: route == null ? onDismiss : () => _goTo(context, route),
      ));
    }

    final onSelected = onSectionSelected;

    if (sectionGroups.isNotEmpty && onSelected != null)
    {
      children.add(const Divider(height: 33, thickness: 1, color: AppTheme.trialLine));

      var entryIndex = 0;

      for (final group in sectionGroups)
      {
        final groupTitle = group.title;

        if (groupTitle != null)
        {
          children.add(AppRailHeading(groupTitle));
        }
        else
        {
          children.add(const SizedBox(height: 8));
        }

        for (final entry in group.entries)
        {
          final index = entryIndex++;

          children.add(AppRailEntry(
            label: entry,
            nested: groupTitle != null,
            selected: index == selectedSection,
            onTap: ()
            {
              onDismiss();
              onSelected(index);
            },
          ));
        }
      }
    }

    return Container(
      width: widthFor(MediaQuery.sizeOf(context).width),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: AppTheme.dialogShadow,
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            _buildHeader(),
            const Divider(height: 25, thickness: 1, color: AppTheme.trialLine),
            // The list scrolls on its own: a phone lying on its side has room
            // for about half of it, and a drawer you cannot reach the bottom of
            // is worse than no drawer.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
