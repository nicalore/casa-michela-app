import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/platform/visual_effects.dart';
import 'app_slide_switcher.dart';
import 'app_tooltip.dart';
import 'carousel_arrow_button.dart';
import 'desktop_tour.dart';
import 'dialog_density.dart';
import 'page_density.dart';

const Duration _transition = Duration(milliseconds: 300);

// Not zero: a zero-length AnimatedSize finishes inside its own layout and asserts.
const Duration _instant = Duration(microseconds: 1);

// Inside a dense dialog; under the card, the arrows shrink a little more.
const double _denseArrowSize = 48;
const double _denseArrowsBelowSize = 44;
const double _denseGap = 14;
const double _denseHeaderGap = 16;

class AppCarouselFrame extends StatefulWidget
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

  // Under the header; a page heading wants less room than a wizard's question.
  final double headerSpacing;

  final double maxContentWidth;

  final bool canGoBack;
  final bool canGoForward;

  final bool showArrows;

  final String? forwardBlockedReason;
  final VoidCallback onBack;
  final VoidCallback onForward;

  // The forward arrow, for a tour to light.
  final String? forwardTour;

  const AppCarouselFrame({
    super.key,
    required this.index,
    required this.movingForward,
    required this.child,
    this.header,
    this.headerSpacing = headerGap,
    required this.maxContentWidth,
    required this.canGoBack,
    required this.canGoForward,
    this.showArrows = true,
    this.forwardBlockedReason,
    required this.onBack,
    required this.onForward,
    this.forwardTour,
  });

  @override
  State<AppCarouselFrame> createState() => _AppCarouselFrameState();
}

class _AppCarouselFrameState extends State<AppCarouselFrame>
{
  Size? _window;

  // The dialog's footer holds the arrows while they are handed over.
  AppDialogArrows? _slot;
  bool _handed = false;

  @override
  void dispose()
  {
    final AppDialogArrows? slot = _slot;

    if (_handed && slot != null)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => slot.show(null));
    }

    super.dispose();
  }

  // After the frame: the footer is outside this subtree, built before this layout ran.
  void _hand((Widget, Widget)? arrows)
  {
    final AppDialogArrows? slot = _slot;

    if (slot == null || (arrows == null && !_handed))
    {
      return;
    }

    _handed = arrows != null;

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        slot.show(arrows);
      }
    });
  }

  Widget _slide(Widget child)
  {
    return AppSlideSwitcher(index: widget.index, movingForward: widget.movingForward, child: child);
  }

  Widget _forward(double size, double iconSize)
  {
    final String? reason = widget.forwardBlockedReason;

    Widget forward = CarouselArrowButton(
      icon: Icons.chevron_right_rounded,
      isDisabled: !widget.canGoForward || reason != null,
      size: size,
      iconSize: iconSize,
      onTap: widget.onForward,
    );

    if (reason != null)
    {
      forward = AppTooltip(
        message: reason,
        waitDuration: const Duration(milliseconds: 300),
        child: forward,
      );
    }

    return DesktopTourTarget(id: widget.forwardTour, child: forward);
  }

  Widget _back(double size, double iconSize)
  {
    return CarouselArrowButton(
      icon: Icons.chevron_left_rounded,
      isDisabled: !widget.canGoBack,
      size: size,
      iconSize: iconSize,
      onTap: widget.onBack,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // A dense dialog, or a dense page (the first access below the wide window).
    final bool dense = AppDialogDensity.of(context) || AppPageDensity.of(context);
    final double arrowSize = dense ? _denseArrowSize : AppCarouselFrame.arrowSize;
    final double gap = dense ? _denseGap : AppCarouselFrame.gap;
    final double headerSpacing = dense ? min(widget.headerSpacing, _denseHeaderGap) : widget.headerSpacing;
    final double compactMax = AppCarouselFrame.minContentWidth + 2 * (arrowSize + gap);

    // A new window size snaps the frame to it: animated, the card would lag behind the window.
    final Size window = MediaQuery.sizeOf(context);
    final bool resized = _window != null && _window != window;
    _window = window;

    final Widget card = _slide(widget.child);
    final Widget? header = widget.header;
    final Widget? question = header == null ? null : _slide(header);
    final double maxContentWidth = widget.maxContentWidth;
    final bool showArrows = widget.showArrows;

    _slot = AppDialogArrowsScope.maybeOf(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool compact = constraints.maxWidth < compactMax;
        final double belowSize = dense ? _denseArrowsBelowSize : arrowSize;

        // Under the card they could be scrolled out of sight: inside a dialog they go to its footer.
        final bool handed = compact && showArrows && _slot != null;

        _hand(handed ? (_back(belowSize, dense ? 24 : 32), _forward(belowSize, dense ? 24 : 32)) : null);

        final Widget turned = !showArrows
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: card,
                ),
              )
            : handed
                ? SizedBox(width: constraints.maxWidth, child: card)
                : compact
                    ? Column(
                        children: [
                          SizedBox(width: constraints.maxWidth, child: card),
                          SizedBox(height: gap),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _back(belowSize, dense ? 24 : 32),
                              SizedBox(width: gap),
                              _forward(belowSize, dense ? 24 : 32),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _back(arrowSize, dense ? 26 : 32),
                          SizedBox(width: gap),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxContentWidth),
                              child: card,
                            ),
                          ),
                          SizedBox(width: gap),
                          _forward(arrowSize, dense ? 26 : 32),
                        ],
                      );

        final double cardWidth = !showArrows
            ? min(maxContentWidth, constraints.maxWidth)
            : compact
                ? constraints.maxWidth
                : min(maxContentWidth, constraints.maxWidth - 2 * (arrowSize + gap));

        final Widget frame = question == null
            ? turned
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: cardWidth, child: question),
                  SizedBox(height: headerSpacing),
                  turned,
                ],
              );

        return AnimatedSize(
          duration: VisualEffects.of(context) && !resized ? _transition : _instant,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: frame,
        );
      },
    );
  }
}
