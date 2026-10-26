import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'stat_widgets.dart';

// No IntrinsicHeight: the two cards may have different heights.
class ResponsiveCardPair extends StatelessWidget
{
  final Widget first;
  final Widget second;

  // Side by side only while each card keeps this width: narrower, its own content would stack, and
  // unstack again once the pair goes into a column.
  final double minCardWidth;

  const ResponsiveCardPair({
    required this.first,
    required this.second,
    this.minCardWidth = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);
    final double pairFrom = math.max(metrics.pairFrom, 2 * minCardWidth + metrics.cardGap);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < pairFrom)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              SizedBox(height: metrics.cardGap),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: metrics.cardGap),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

// Intrinsic height matching: nothing in a card may measure itself, e.g. no LayoutBuilder.
class MatchedCardPair extends StatelessWidget
{
  final Widget Function(double width, bool matched) first;
  final Widget Function(double width, bool matched) second;

  // As in ResponsiveCardPair.
  final double minCardWidth;

  const MatchedCardPair({
    required this.first,
    required this.second,
    this.minCardWidth = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);
    final double gap = metrics.cardGap;
    final double pairFrom = math.max(metrics.pairFrom, 2 * minCardWidth + gap);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < pairFrom)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first(constraints.maxWidth, false),
              SizedBox(height: gap),
              second(constraints.maxWidth, false),
            ],
          );
        }

        final double width = (constraints.maxWidth - gap) / 2;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first(width, true)),
              SizedBox(width: gap),
              Expanded(child: second(width, true)),
            ],
          ),
        );
      },
    );
  }
}
// Two rankings inside one card, ruled apart; stacked when the card is narrow.
class RankingPair extends StatelessWidget
{
  final Widget first;
  final Widget second;

  const RankingPair({
    required this.first,
    required this.second,
    super.key,
  });

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < metrics.listsFrom)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              first,
              const StatPartDivider(lists: true),
              second,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first),
              const StatColumnDivider(),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}
