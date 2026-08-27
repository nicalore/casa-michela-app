import 'dart:math';

import 'package:flutter/material.dart';

import 'carousel_arrow_button.dart';

const Duration _transition = Duration(milliseconds: 300);

class AppCarouselFrame extends StatelessWidget
{
  static const double arrowSize = 64;
  static const double gap = 24;

  static const double headerGap = 26;

  static const double minContentWidth = 520;

  static const double compactMax = minContentWidth + 2 * (arrowSize + gap);

  final int index;
  final bool movingForward;

  final Widget child;

  final Widget? header;

  final double maxContentWidth;

  final bool canGoBack;
  final bool canGoForward;

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

  Widget _slide(Widget child)
  {
    return AnimatedSwitcher(
      duration: _transition,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [
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

        return AnimatedSize(
          duration: _transition,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: frame,
        );
      },
    );
  }
}
