import 'package:flutter/material.dart';

const double _cardGap = 12;
const double _columnGap = 12;

class MobileCardGrid extends StatelessWidget
{
  final bool tablet;
  final List<Widget> cards;

  const MobileCardGrid({super.key, required this.tablet, required this.cards});

  @override
  Widget build(BuildContext context)
  {
    final List<Widget> rows = [
      if (!tablet)
        ...cards
      else
        for (var i = 0; i < cards.length; i += 2)
          i + 1 < cards.length
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: _columnGap),
                      Expanded(child: cards[i + 1]),
                    ],
                  ),
                )
              : cards[i],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: _cardGap),
          rows[i],
        ],
      ],
    );
  }
}
