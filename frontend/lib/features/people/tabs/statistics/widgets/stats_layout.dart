import 'package:flutter/material.dart';

// No IntrinsicHeight: the two cards may have different heights.
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

// Cards are builders handed (width, matched): intrinsic height matching means
// nothing in a card's subtree may measure itself — a LayoutBuilder cannot
// answer an intrinsic query.
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