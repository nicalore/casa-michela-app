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

// The header these cards used to build for themselves — title on the left,
// filters on the right, stacked below a breakpoint — now lives in AppCard, which
// is where every card of the app gets its heading.

// Two cards that have to read as one row rather than as two: the same height,
// whichever of them is taller, and the shorter one spreading its content into
// what it was given instead of leaving a hole under itself.
//
// The cards are built by the callers rather than passed in, because each of them
// has to be told two things it cannot work out for itself. How wide it will be:
// matching the heights means asking a card how tall it would be at a given
// width, and nothing in the subtree of a card being asked that question may
// measure itself — a LayoutBuilder in there cannot answer at all. And whether
// its height is the pair's or its own, which decides whether there is any room
// to spread into.
class MatchedCardPair extends StatelessWidget
{
  static const double _breakpoint = 900.0;
  static const double _gap = 24.0;

  final Widget Function(double width, bool matched) first;
  final Widget Function(double width, bool matched) second;

  const MatchedCardPair({
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
        // One under the other, each as tall as it needs: there is no row for
        // them to share, so there is nothing to match.
        if (constraints.maxWidth < _breakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first(constraints.maxWidth, false),
              const SizedBox(height: _gap),
              second(constraints.maxWidth, false),
            ],
          );
        }

        final double width = (constraints.maxWidth - _gap) / 2;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first(width, true)),
              const SizedBox(width: _gap),
              Expanded(child: second(width, true)),
            ],
          ),
        );
      },
    );
  }
}