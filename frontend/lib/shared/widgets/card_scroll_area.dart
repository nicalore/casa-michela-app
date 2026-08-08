import 'package:flutter/material.dart';

// Whatever inside a card is longer than a card should be scrolls in here,
// instead of stretching the card and setting the whole dialog in motion. Left to
// grow, the card pushes the dialog's footer off screen, and getting back to the
// save button means scrolling past everything just written.
//
// Only the list goes inside: labels, filters and the add-row button stay out,
// above and below, or they would scroll away exactly when they are needed.
class CardScrollArea extends StatelessWidget
{
  // How far it can grow before it starts scrolling. The same number for every
  // card of the app, because two cards stopping at different heights read as two
  // different dialogs.
  static const double maxHeight = 420;

  final Widget child;

  // Room inside the scrolling area. Needed where the content casts a shadow:
  // without it, the first and last rows leave it on the clipping edge.
  final EdgeInsets padding;

  const CardScrollArea({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context)
  {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: padding,
        child: child,
      ),
    );
  }
}
