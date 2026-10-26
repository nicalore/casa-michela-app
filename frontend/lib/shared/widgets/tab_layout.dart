import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alphabetical_order.dart';
import 'app_filter_pill.dart';
import 'app_gradient_button.dart';
import 'app_search_field.dart';
import 'desktop_tour.dart';
import 'filter_menu.dart';
import 'page_transition.dart';

const double _actionHeight = 50;
const double _actionFontSize = 14;

const double _denseActionHeight = 40;
const double _denseActionFontSize = 13;

const double _filterSpacing = 12;
const double _countFontSize = 17;

const double _denseFilterSpacing = 8;
const double _denseCountFontSize = 13.5;

// Below the wide window: the gap under the search row and under the filters.
const double _denseHeaderGap = 10;
const double _denseBodyGap = 12;

// Least widths of a dense grid's cards, which then grow to fill the row.
const double kDenseCatalogueWidth = 270;
const double kDenseWideCardWidth = 300;
const double kDenseSmallCardWidth = 240;

const double kDenseCardGap = 12;

const double _footerGap = 28;

void sortByCriterion<T>(
  List<T> items,
  SortCriterion sort, {
  required String Function(T) name,
  required DateTime Function(T) createdAt,
})
{
  items.sort((a, b) => switch (sort)
  {
    SortCriterion.nameAsc => compareAlphabetically(name(a), name(b)),
    SortCriterion.nameDesc => compareAlphabetically(name(b), name(a)),
    SortCriterion.dateAsc => createdAt(a).compareTo(createdAt(b)),
    SortCriterion.dateDesc => createdAt(b).compareTo(createdAt(a)),
  });
}

Widget tabActionButton({
  required String label,
  required VoidCallback onPressed,
  IconData icon = Icons.add_rounded,
  LinearGradient gradient = AppTheme.brandGradient,
  Color accent = AppTheme.trialTealDeep,
})
{
  return Builder(
    builder: (context)
    {
      final bool dense = AppBreakpoints.of(context).isDense;

      return AppGradientButton(
        label: label,
        icon: icon,
        gradient: gradient,
        accent: accent,
        height: dense ? _denseActionHeight : _actionHeight,
        radius: (dense ? _denseActionHeight : _actionHeight) / 2,
        fontSize: dense ? _denseActionFontSize : _actionFontSize,
        onPressed: onPressed,
      );
    },
  );
}

List<Widget> entityTabHeader({
  required TextEditingController searchController,
  required ValueChanged<String> onSearchChanged,
  required String searchHint,
  // Both null for a reader.
  String? actionLabel,
  VoidCallback? onAction,
  IconData actionIcon = Icons.add_rounded,
  LinearGradient actionGradient = AppTheme.brandGradient,
  Color actionAccent = AppTheme.trialTealDeep,
  required SortCriterion sort,
  required ValueChanged<SortCriterion> onSortChanged,
  List<SortCriterion> sortCriteria = SortCriterion.values,
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
      action: actionLabel != null && onAction != null
          ? tabActionButton(
              label: actionLabel,
              icon: actionIcon,
              gradient: actionGradient,
              accent: actionAccent,
              onPressed: onAction,
            )
          : null,
    ),
    const TabHeaderGap(wide: 28, dense: _denseHeaderGap),
    TabFiltersRow(
      filters: [
        AppSortPill(value: sort, onChanged: onSortChanged, criteria: sortCriteria),
        ...filters,
      ],
      countLabel: countLabel,
    ),
    const TabHeaderGap(wide: 16, dense: _denseBodyGap),
  ];
}

// A gap of the list header that narrows below the wide window.
class TabHeaderGap extends StatelessWidget
{
  final double wide;
  final double dense;

  const TabHeaderGap({super.key, required this.wide, required this.dense});

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(height: AppBreakpoints.of(context).isDense ? dense : wide);
  }
}

// The pills, then the count: under them when wide, at their right end when dense.
class TabFiltersRow extends StatelessWidget
{
  final List<Widget> filters;

  final String? countLabel;

  // The pills alone, for a tour to light.
  final String? tour;

  // Wide only: from the pills down to the count.
  final double countGap;

  const TabFiltersRow({super.key, required this.filters, this.countLabel, this.tour, this.countGap = 20});

  @override
  Widget build(BuildContext context)
  {
    final String? countLabel = this.countLabel;

    if (!AppBreakpoints.of(context).isDense)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DesktopTourTarget(
            id: tour,
            child: Wrap(
              spacing: _filterSpacing,
              runSpacing: _filterSpacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: filters,
            ),
          ),
          if (countLabel != null) ...[
            SizedBox(height: countGap),
            Text(
              countLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: _countFontSize,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: DesktopTourTarget(
              id: tour,
              child: Wrap(
                spacing: _denseFilterSpacing,
                runSpacing: _denseFilterSpacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: filters,
              ),
            ),
          ),
        ),
        if (countLabel != null) ...[
          const SizedBox(width: 12),
          // Level with the first row of pills.
          SizedBox(
            height: 36,
            child: Center(
              child: Text(
                countLabel,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: _denseCountFontSize,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class TabHeaderRow extends StatefulWidget
{
  static const double _gap = 24;
  static const double _denseGap = 12;
  static const double _stackedGap = 12;

  // Below it the search would be too short beside the button; the button then goes under it, its own width.
  static const double _stackBelow = 480;

  final Widget search;
  final Widget? action;

  // A longer button stacks sooner, so the search keeps a usable width.
  final double stackBelow;

  const TabHeaderRow({
    super.key,
    required this.search,
    this.action,
    this.stackBelow = _stackBelow,
  });

  @override
  State<TabHeaderRow> createState() => _TabHeaderRowState();
}

class _TabHeaderRowState extends State<TabHeaderRow>
{
  // Moved, not rebuilt, when the button goes under it: the field keeps its focus.
  final GlobalKey _searchKey = GlobalKey();

  @override
  Widget build(BuildContext context)
  {
    final Widget? action = widget.action;
    final Widget search = KeyedSubtree(key: _searchKey, child: widget.search);

    if (action == null)
    {
      return search;
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth >= widget.stackBelow)
        {
          return Row(
            children: [
              Expanded(child: search),
              SizedBox(width: AppBreakpoints.of(context).isDense ? TabHeaderRow._denseGap : TabHeaderRow._gap),
              action,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: TabHeaderRow._stackedGap),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        );
      },
    );
  }
}

class TabContent extends StatefulWidget
{
  final List<Widget> header;
  final Widget body;

  // Centred after the body, scrolling with it.
  final Widget? footer;

  // The scrolling list, for a tour to light.
  final String? bodyTour;

  // Stands in for the body, centred in the room left below the header.
  final Widget? empty;

  const TabContent({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.bodyTour,
    this.empty,
  });

  @override
  State<TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<TabContent>
{
  // Moved, not rebuilt, when the header goes into the scroll view: the field keeps its focus, the list its offset.
  final GlobalKey _headKey = GlobalKey();
  final GlobalKey _scrollKey = GlobalKey();

  Widget get _head
  {
    return Column(
      key: _headKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in widget.header)
          PageTransitionItem(slot: PageTransitionItem.header, child: entry),
      ],
    );
  }

  List<Widget> get _body
  {
    final Widget body = widget.body;
    final Widget? footer = widget.footer;
    final Widget? empty = widget.empty;

    if (empty != null)
    {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PageTransitionItem(slot: PageTransitionItem.list, child: empty),
                if (footer != null) ...[
                  const SizedBox(height: _footerGap),
                  PageTransitionItem.wave(child: footer),
                ],
              ],
            ),
          ),
        ),
      ];
    }

    return [
      body is EntityCardGrid ? body.sliver : SliverToBoxAdapter(child: body),
      if (footer != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: _footerGap),
            child: Center(child: PageTransitionItem.wave(child: footer)),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (AppBreakpoints.isNarrowWidth(constraints.maxWidth))
        {
          return PageTransitionScrollView.slivers(
            key: _scrollKey,
            slivers: [
              SliverToBoxAdapter(child: _head),
              ..._body,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _head,
            Expanded(
              child: DesktopTourTarget(
                id: widget.bodyTour,
                child: PageTransitionScrollView.slivers(key: _scrollKey, slivers: _body),
              ),
            ),
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

  final double cardWidth;

  // Below the wide window: the least width; the cards grow to fill the row.
  final double denseWidth;

  const EntityCardGrid({
    super.key,
    required this.children,
    this.cardWidth = preferredWidth,
    this.denseWidth = kDenseCatalogueWidth,
  });

  // As many as fit, filling the row; a short last row in the middle, as on the wide window.
  static ({int perRow, double width}) denseLayout(double available, double least)
  {
    final int perRow = math.max(1, ((available + kDenseCardGap) / (least + kDenseCardGap)).floor());

    return (perRow: perRow, width: (available - kDenseCardGap * (perRow - 1)) / perRow);
  }

  static double widthFor(double available, [double preferred = preferredWidth])
  {
    return math.min(preferred, available);
  }

  static int columnsFor(double available, [double preferred = preferredWidth])
  {
    final int columns = ((available + gap) / (widthFor(available, preferred) + gap)).floor();

    return columns < 1 ? 1 : columns;
  }

  Widget get sliver
  {
    return SliverLayoutBuilder(
      builder: (context, constraints)
      {
        final double available = constraints.crossAxisExtent;

        if (AppBreakpoints.of(context).isDense)
        {
          final dense = denseLayout(available, denseWidth);

          return CardRows(
            cards: children,
            cardWidth: dense.width,
            perRow: dense.perRow,
            gap: kDenseCardGap,
          );
        }

        return CardRows(
          cards: children,
          cardWidth: widthFor(available, cardWidth),
          perRow: columnsFor(available, cardWidth),
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
        final bool dense = AppBreakpoints.of(context).isDense;
        final layout = denseLayout(available, denseWidth);
        final double width = dense ? layout.width : widthFor(available, cardWidth);
        final int columns = dense ? layout.perRow : columnsFor(available, cardWidth);
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
                  gap: dense ? kDenseCardGap : EntityCardGrid.gap,
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
    if (AppBreakpoints.of(context).isDense)
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
