import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import 'page_transition.dart';

// The head of a list page: what shortens the list, and the button that adds to
// it. Below the breakpoint they stack and the button goes full width, rather
// than squeezing the field to its icon so the button can keep its label.
class TabHeaderRow extends StatelessWidget
{
  static const double _gap = 24;
  static const double _stackedGap = 12;

  final Widget search;
  final Widget action;

  const TabHeaderRow({
    super.key,
    required this.search,
    required this.action,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (!AppBreakpoints.fromWidth(constraints.maxWidth).isCompact)
        {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: _gap),
              action,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: _stackedGap),
            action,
          ],
        );
      },
    );
  }
}

// The body of a list page. On a wide window the head is pinned and only the
// cards scroll; on a narrow one everything scrolls together, since stacked the
// head is some three hundred pixels and would leave a phone a third of its
// screen for the cards.
class TabContent extends StatelessWidget
{
  final List<Widget> header;
  final Widget body;

  const TabContent({super.key, required this.header, required this.body});

  // On a change of page the head leaves as one block: the field, the button, the
  // filters and the count read as a single thing, and delaying them among
  // themselves would make the top of the page look like it was coming apart. The
  // cards below carry the stagger on their own.
  List<Widget> get _head
  {
    return [
      for (final entry in header)
        PageTransitionItem(slot: PageTransitionItem.header, child: entry),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (AppBreakpoints.fromWidth(constraints.maxWidth).isCompact)
        {
          return PageTransitionScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [..._head, body],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._head,
            Expanded(child: PageTransitionScrollView(child: body)),
          ],
        );
      },
    );
  }
}

// The cards of a list page, at the size they were drawn: 360 on every window
// that can hold one. Sharing the leftover between columns bought a third card at
// 913px and cost every card its proportions.
//
// The exception is a window narrower than one card, where 360 is not a fixed
// size but seventeen pixels hanging off the side of the phone.
class EntityCardGrid extends StatelessWidget
{
  static const double preferredWidth = 360;
  static const double gap = 20;

  final List<Widget> children;

  const EntityCardGrid({super.key, required this.children});

  static double widthFor(double available)
  {
    return math.min(preferredWidth, available);
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        // Tight, so a card built at its own fixed width is brought down to this
        // one without every card widget having to be told about the window.
        final width = widthFor(constraints.maxWidth);

        // The whole width of the page, on purpose: a Wrap is only as wide as
        // its widest row and the page hands it a loose width, so centring it
        // centred the cards inside themselves — which is to say not at all.
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: [
              // One slot per card, so that on a change of page they leave and
              // come back one after the next rather than as a wall.
              for (var i = 0; i < children.length; i++)
                SizedBox(
                  width: width,
                  child: PageTransitionItem(
                    slot: PageTransitionItem.list + i,
                    child: children[i],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Left of it arranges the list, right of it shortens it. Only along a row:
// once the pills have stacked it divides nothing from nothing, so it steps out
// rather than sitting at the end of a row as a stray mark.
class FilterGroupDivider extends StatelessWidget
{
  const FilterGroupDivider({super.key});

  @override
  Widget build(BuildContext context)
  {
    if (AppBreakpoints.of(context).isCompact)
    {
      return const SizedBox.shrink();
    }

    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppTheme.trialLine,
    );
  }
}
