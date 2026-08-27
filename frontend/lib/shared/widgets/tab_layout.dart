import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import 'app_filter_pill.dart';
import 'app_gradient_button.dart';
import 'app_search_field.dart';
import 'filter_menu.dart';
import 'page_transition.dart';

const double _actionHeight = 50;
const double _actionRadius = 25;
const double _actionFontSize = 14;

const double _filterSpacing = 12;
const double _countFontSize = 17;

void sortByCriterion<T>(
  List<T> items,
  SortCriterion sort, {
  required String Function(T) name,
  required DateTime Function(T) createdAt,
})
{
  items.sort((a, b) => switch (sort)
  {
    SortCriterion.nameAsc => name(a).compareTo(name(b)),
    SortCriterion.nameDesc => name(b).compareTo(name(a)),
    SortCriterion.dateAsc => createdAt(a).compareTo(createdAt(b)),
    SortCriterion.dateDesc => createdAt(b).compareTo(createdAt(a)),
  });
}

List<Widget> entityTabHeader({
  required TextEditingController searchController,
  required ValueChanged<String> onSearchChanged,
  required String searchHint,
  required String actionLabel,
  required VoidCallback onAction,
  required SortCriterion sort,
  required ValueChanged<SortCriterion> onSortChanged,
  required String countLabel,
  List<Widget> filters = const [],
})
{
  return [
    TabHeaderRow(
      search: AppSearchField(
        controller: searchController,
        onChanged: onSearchChanged,
        hintText: searchHint,
      ),
      action: AppGradientButton(
        label: actionLabel,
        icon: Icons.add_rounded,
        height: _actionHeight,
        radius: _actionRadius,
        fontSize: _actionFontSize,
        onPressed: onAction,
      ),
    ),
    const SizedBox(height: 28),
    Wrap(
      spacing: _filterSpacing,
      runSpacing: _filterSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppSortPill(value: sort, onChanged: onSortChanged),
        ...filters,
      ],
    ),
    const SizedBox(height: 20),
    Text(
      countLabel,
      style: GoogleFonts.plusJakartaSans(
        fontSize: _countFontSize,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialMutedText,
      ),
    ),
    const SizedBox(height: 16),
  ];
}

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

class TabContent extends StatelessWidget
{
  final List<Widget> header;
  final Widget body;

  const TabContent({super.key, required this.header, required this.body});

  List<Widget> get _head
  {
    return [
      for (final entry in header)
        PageTransitionItem(slot: PageTransitionItem.header, child: entry),
    ];
  }

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

  static int columnsFor(double available)
  {
    final int columns = ((available + gap) / (widthFor(available) + gap)).floor();

    return columns < 1 ? 1 : columns;
  }

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

class CardRows extends StatelessWidget
{
  final List<Widget> cards;

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
      padding: EdgeInsets.only(bottom: last ? 0 : gap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = start; i < end; i++) ...[
            if (i > start) SizedBox(width: gap),
            SizedBox(
              width: cardWidth,
              child: PageTransitionItem.wave(child: cards[i]),
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
