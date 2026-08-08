import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import 'page_transition.dart';

// The head of a list page: the field that shortens the list, and the one button
// that adds to it.
//
// Side by side while there is room for both. Below the breakpoint they stack,
// and the button takes the full width rather than keeping its natural one: a
// row where the field has been squeezed to its icon so that a button can keep
// its label is a row that has decided the wrong thing matters.
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

// The body of a list page: what shortens the list, and then the list.
//
// On a wide window the head of the page is pinned and only the cards scroll
// under it. On a narrow one everything scrolls together: stacked, the search
// field, the button, the filters and the count come to some three hundred
// pixels, and pinning all of that to the top of a phone leaves the cards a
// third of the screen to live in.
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

// The cards of a list page, at the size they were drawn.
//
// Three hundred and sixty wide is the card, and it stays that on every window
// that can hold one: filling the row instead — as many columns as fit, the
// leftover shared between them — bought a third card at 913px of content and
// cost every card its proportions, which is a bad trade now that the whole page
// scrolls and a row with air on its right is not a row with something missing.
//
// The one exception is a window narrower than a single card. There it takes the
// width there is, because 360 of card on a 343 screen is not a fixed size, it is
// seventeen pixels of card hanging off the side of the phone.
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

        // The whole width of the page, taken on purpose.
        //
        // A Wrap left to itself is only as wide as its widest row, and the page
        // hands it a loose width — the head of a list page is a column aligned
        // to the start, so nothing below it is stretched. Centred inside its own
        // width, the block of cards was being centred inside itself, which is to
        // say not at all: two columns of cards sat against the left edge with a
        // third column of empty paper beside them, and the wider the window the
        // more of it there was.
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

// The rule of the filter row: what is left of it arranges the list, what is
// right of it shortens it.
//
// It only says that along a row. Once the pills have stacked, one below the
// next, a line between two of them divides nothing from nothing — so on a
// narrow window it steps out rather than sitting at the end of a row as a
// stray mark.
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
