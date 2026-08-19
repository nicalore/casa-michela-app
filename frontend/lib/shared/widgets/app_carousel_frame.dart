import 'dart:math';

import 'package:flutter/material.dart';

import 'carousel_arrow_button.dart';

const Duration _transition = Duration(milliseconds: 300);

// One card at a time between two arrows. The arrows sit beside the card while
// there is room and drop underneath when there is not, since a phone giving a
// hundred and seventy pixels to two buttons has nothing left for the card.
//
// The frame owns the change of card as well as the arrows, because they are one
// movement: the card slides in from the side it came from and the frame takes
// its height along the way.
class AppCarouselFrame extends StatelessWidget
{
  static const double arrowSize = 64;
  static const double gap = 24;

  static const double headerGap = 26;

  // Below this a card has no room left for two fields side by side, which is
  // where the arrows give up their place beside it.
  static const double minContentWidth = 520;

  static const double compactMax = minContentWidth + 2 * (arrowSize + gap);

  // Which card is showing, and which way it was reached. The direction is not
  // worked out from the index because the frame is rebuilt for many other
  // reasons than a move, and an old index is not something to keep around.
  final int index;
  final bool movingForward;

  final Widget child;

  // Above the card and moving with it, but not counted by the arrows: they turn
  // the card, and centring them on header plus card put them too high.
  final Widget? header;

  // How wide the card is allowed to get. The frame is this plus an arrow and a
  // gap on either side.
  final double maxContentWidth;

  final bool canGoBack;
  final bool canGoForward;

  // Why one cannot move on, where one cannot. Shown on hovering the disabled
  // arrow: an arrow that neither responds nor says anything leaves whoever
  // presses it wondering whether it is broken.
  final String? forwardBlockedReason;
  final VoidCallback onBack;
  final VoidCallback onForward;

  const AppCarouselFrame({
    super.key,
    required this.index,
    required this.movingForward,
    required this.child,
    this.header,
    required this.maxContentWidth,
    required this.canGoBack,
    required this.canGoForward,
    this.forwardBlockedReason,
    required this.onBack,
    required this.onForward,
  });

  // The same transition for the card and for the header above it: two subtrees,
  // but they change together and on the same timings, so they move as one.
  Widget _slide(Widget child)
  {
    return AnimatedSwitcher(
      duration: _transition,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [
          // Laid over rather than laid out: a Stack sizes to its unpositioned
          // children, so the frame is as tall as the card arriving. Sized by
          // both, a step back held the old height and dropped it all at once.
          for (final previous in previousChildren)
            Positioned(top: 0, left: 0, right: 0, child: previous),
          ?currentChild,
        ],
      ),
      transitionBuilder: (child, animation)
      {
        final isEntering = (child.key as ValueKey<int>).value == index;
        final beginOffset = movingForward
            ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0))
            : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      // The key rides on a KeyedSubtree rather than on the card itself, because
      // the transition above reads it back to tell the card arriving from the
      // card leaving.
      child: KeyedSubtree(key: ValueKey(index), child: child),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget back = CarouselArrowButton(
      icon: Icons.chevron_left_rounded,
      isDisabled: !canGoBack,
      size: arrowSize,
      iconSize: 32,
      onTap: onBack,
    );

    Widget forward = CarouselArrowButton(
      icon: Icons.chevron_right_rounded,
      isDisabled: !canGoForward || forwardBlockedReason != null,
      size: arrowSize,
      iconSize: 32,
      onTap: onForward,
    );

    if (forwardBlockedReason != null)
    {
      forward = Tooltip(
        message: forwardBlockedReason!,
        waitDuration: const Duration(milliseconds: 300),
        child: forward,
      );
    }

    final Widget card = _slide(child);
    final Widget? question = header == null ? null : _slide(header!);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool compact = constraints.maxWidth < compactMax;

        final Widget turned = compact
            ? Column(
                children: [
                  SizedBox(width: constraints.maxWidth, child: card),
                  const SizedBox(height: gap),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      back,
                      const SizedBox(width: gap),
                      forward,
                    ],
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  back,
                  const SizedBox(width: gap),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: card,
                    ),
                  ),
                  const SizedBox(width: gap),
                  forward,
                ],
              );

        // As wide as the card and not the frame: the header belongs to the
        // card's column. The card gets whatever the arrows leave it.
        final double cardWidth = compact
            ? constraints.maxWidth
            : min(maxContentWidth, constraints.maxWidth - 2 * (arrowSize + gap));

        final Widget frame = question == null
            ? turned
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: cardWidth, child: question),
                  const SizedBox(height: headerGap),
                  turned,
                ],
              );

        // Two cards of different heights — the dates of a variation and its
        // three bands — would otherwise move everything under them the moment
        // the taller one appeared or the shorter one was left alone.
        return AnimatedSize(
          duration: _transition,
          // Eased at both ends, unlike the card sliding inside it: the height is
          // a thing everything below has to follow, and a movement that starts
          // at full speed reads as a jump however long it then takes.
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: frame,
        );
      },
    );
  }
}
