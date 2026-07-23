import 'package:flutter/material.dart';

// Side by side above the breakpoint, stacked below it. No IntrinsicHeight here:
// the two cards are allowed to have different heights rather than being
// stretched to match.
class ResponsiveCardPair extends StatelessWidget
{
  static const double _breakpoint = 900.0;

  final Widget first;
  final Widget second;

  const ResponsiveCardPair({
    required this.first,
    required this.second,
    super.key,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _breakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: 24),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 24),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

// Title on the left, filters on the right, stacked below the breakpoint. The
// filters stay wrapped in Flexible even side by side, so an internal Wrap can
// absorb the squeeze instead of overflowing.
class ResponsiveCardHeader extends StatelessWidget
{
  final Widget title;
  final Widget filters;
  final double breakpoint;

  const ResponsiveCardHeader({
    required this.title,
    required this.filters,
    this.breakpoint = 620,
    super.key,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < breakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              filters,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            Flexible(
              child: Align(alignment: Alignment.centerRight, child: filters),
            ),
          ],
        );
      },
    );
  }
}