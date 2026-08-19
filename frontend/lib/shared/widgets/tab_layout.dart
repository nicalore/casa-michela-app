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

  // A grid knows how to give itself out a row at a time, which is what keeps a
  // catalogue of three hundred from being described whole for the two dozen rows
  // anyone can see. Everything else a tab puts here — the sentence a day with
  // nothing in it shows — is one box and goes in as one.
  Widget get _body
  {
    final Widget body = this.body;

    return body is EntityCardGrid ? body.sliver : SliverToBoxAdapter(child: body);
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (AppBreakpoints.fromWidth(constraints.maxWidth).isCompact)
        {
          return PageTransitionScrollView.slivers(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _head,
                ),
              ),
              _body,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._head,
            Expanded(child: PageTransitionScrollView.slivers(slivers: [_body])),
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

  // How many fit on a row, which is what tells a card which row it is on and so
  // when its turn to move comes. Worked out the way a Wrap works it out, because
  // that is the layout this is standing in for.
  static int columnsFor(double available)
  {
    final int columns = ((available + gap) / (widthFor(available) + gap)).floor();

    return columns < 1 ? 1 : columns;
  }

  // The grid handed to a scroll view a row at a time.
  Widget get sliver
  {
    return SliverLayoutBuilder(
      builder: (context, constraints)
      {
        final double available = constraints.crossAxisExtent;

        return CardRows(
          cards: children,
          cardWidth: widthFor(available),
          perRow: columnsFor(available),
        );
      },
    );
  }

  // The same grid as a plain box, for the few places that hold one inside a
  // column of other things rather than handing it a scroll view of its own.
  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double available = constraints.maxWidth;
        final double width = widthFor(available);
        final int columns = columnsFor(available);
        final int rows = CardRows.rowsFor(children.length, columns);

        // The whole width of the page, on purpose: the rows are centred within
        // it, and a box only as wide as its widest row would centre the cards
        // inside themselves — which is to say not at all.
        return SizedBox(
          width: available,
          child: Column(
            children: [
              for (var row = 0; row < rows; row++)
                CardRows.row(
                  children,
                  row,
                  perRow: columns,
                  cardWidth: width,
                  last: row == rows - 1,
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

// The cards of a list page handed to a scroll view a row at a time.
//
// Described in one piece — as a Wrap, which is what this replaced — a catalogue
// builds, lays out and, for as long as a step is running, composites every card
// it holds, for the handful of rows anybody can see. A hundred and nine of them
// was ninety-odd layers on every frame of a step, for two dozen on screen. Here
// the rows are described as they come into view, and a list of three hundred
// costs what a list of thirty does.
//
// Rows and not cells: a row has no height anyone knows in advance, and a
// SliverList is the one lazy list that does not ask for one.
class CardRows extends StatelessWidget
{
  final List<Widget> cards;

  // What a card is brought down to, and how many of them share a row. Worked out
  // by whoever is placing the grid, since a catalogue and the register of people
  // do not size their cards the same way.
  final double cardWidth;
  final int perRow;

  final double gap;

  const CardRows({
    super.key,
    required this.cards,
    required this.cardWidth,
    required this.perRow,
    this.gap = EntityCardGrid.gap,
  });

  static int rowsFor(int count, int perRow) => perRow < 1 ? 0 : (count + perRow - 1) ~/ perRow;

  // One row of the grid, centred in the page the way a Wrap centres each of its
  // runs: a last row holding a single card puts it in the middle and not against
  // the left edge, which is where it has always sat.
  static Widget row(
    List<Widget> cards,
    int row, {
    required int perRow,
    required double cardWidth,
    required bool last,
    double gap = EntityCardGrid.gap,
  })
  {
    final int start = row * perRow;
    final int end = math.min(start + perRow, cards.length);

    return Padding(
      // Between the rows and not after the last, which is the runSpacing a Wrap
      // would have put there.
      padding: EdgeInsets.only(bottom: last ? 0 : gap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        // The top of the row, as in a Wrap: where two cards of a row are not the
        // same height they hang from the same line rather than sitting on it.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = start; i < end; i++) ...[
            if (i > start) SizedBox(width: gap),
            // Tight, so a card built at its own fixed width is brought down to
            // this one without every card widget having to be told about the
            // window.
            SizedBox(
              width: cardWidth,
              child: PageTransitionItem(
                // One slot per card, so that on a change of page they leave and
                // come back one after the next rather than as a wall. Counted
                // across the grid rather than along the list, so the rows below
                // the first carry the run-up too.
                slot: PageTransitionItem.gridSlot(i, perRow),
                child: cards[i],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final int rows = rowsFor(cards.length, perRow);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => row(
          cards,
          index,
          perRow: perRow,
          cardWidth: cardWidth,
          last: index == rows - 1,
          gap: gap,
        ),
        childCount: rows,
      ),
    );
  }
}
