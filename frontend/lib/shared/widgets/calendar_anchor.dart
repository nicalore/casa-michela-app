import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colours.dart';
import '../utils/day_marks.dart';
import 'app_tooltip.dart';
import 'carousel_arrow_button.dart';
import 'close_on_resize.dart';
import 'desktop_tour.dart';

const double _popoverWidth = 336;
const double _popoverGap = 8;
const double _windowMargin = 8;

const double kCalendarArrowSize = 32;
const double kCalendarArrowIconSize = 18;

Color get kCalendarDisabled =>  ThemeColours.fixed(0xFFB4C0C7);

BoxDecoration get kCalendarPopoverDecoration => BoxDecoration(
  color: AppTheme.surface,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    ...AppTheme.overlayShadow,
    BoxShadow(color: Color(0x29081E2C), offset: Offset(0, 18), blurRadius: 40),
  ],
);

const Duration _revealIn = Duration(milliseconds: 200);
const Duration _revealOut = Duration(milliseconds: 120);

// No scaling: text scaled per frame shimmers and the shadows redraw every frame.
const double _revealRise = 6;

// Lowest drawn alpha: at 0 the first paint (blurs, glyphs) would stall the motion's first frame.
const double _primeOpacity = 1 / 255;

// The round calendar button and the popover that comes down from it.
class CalendarAnchor extends StatefulWidget
{
  final double size;
  final String tooltip;

  final Widget Function(BuildContext context, VoidCallback close) popover;

  // Hovered or about to open: time to read what the popover will show.
  final VoidCallback? onPrefetch;

  // Told when the popover comes up and when it goes.
  final void Function(BuildContext context, bool open)? onOpen;

  // Once it is gone for good, not while it may reopen.
  final VoidCallback? onClosed;

  // For a button at the left of the page, where a centred popover would leave the window.
  final bool startAligned;

  const CalendarAnchor({
    super.key,
    required this.size,
    required this.tooltip,
    required this.popover,
    this.startAligned = false,
    this.onPrefetch,
    this.onOpen,
    this.onClosed,
  });

  @override
  State<CalendarAnchor> createState() => _CalendarAnchorState();
}

class _CalendarAnchorState extends State<CalendarAnchor> with SingleTickerProviderStateMixin, CloseOnResize
{
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  // Built in initState: a late controller first touched in dispose() would be created there.
  late final AnimationController _reveal;
  late final Animation<double> _curve;
  late final Animation<double> _opacity;

  bool _isHovered = false;

  // Sideways move that keeps the popover inside the window, set as it opens.
  double _shift = 0;

  bool get _isOpen => _portal.isShowing && _reveal.status != AnimationStatus.reverse;

  @override
  bool get menuShown => _isOpen;

  @override
  void closeMenuForResize() => _close();

  @override
  void initState()
  {
    super.initState();

    _reveal = AnimationController(vsync: this, duration: _revealIn, reverseDuration: _revealOut);
    _curve = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    _opacity = Tween<double>(begin: _primeOpacity, end: 1).animate(_curve);
  }

  @override
  void dispose()
  {
    _reveal.dispose();
    super.dispose();
  }

  void _toggle()
  {
    if (_isOpen)
    {
      _close();

      return;
    }

    widget.onPrefetch?.call();
    _shift = _shiftInside();
    setState(_portal.show);

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted && _isOpen)
      {
        widget.onOpen?.call(context, true);
      }
    });

    if (!VisualEffects.on)
    {
      _reveal.value = 1;

      return;
    }

    // After the month's costly first frame, so the motion does not start with a stall.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted && _portal.isShowing)
      {
        _reveal.forward();
      }
    });
  }

  Future<void> _close() async
  {
    if (!_isOpen)
    {
      return;
    }

    widget.onOpen?.call(context, false);
    setState(() {});

    if (VisualEffects.on)
    {
      await _reveal.reverse();
    }
    else
    {
      _reveal.value = 0;
    }

    // Reopened while leaving: it stays.
    if (mounted && _reveal.isDismissed)
    {
      setState(_portal.hide);
      widget.onClosed?.call();
    }
  }

  // Where the window cuts it: lined up with the button's nearer edge, else against the margin.
  double _shiftInside()
  {
    final RenderObject? anchor = context.findRenderObject();
    final RenderObject? overlay = Overlay.maybeOf(context)?.context.findRenderObject();

    if (anchor is! RenderBox || overlay is! RenderBox || !anchor.hasSize || !overlay.hasSize)
    {
      return 0;
    }

    final Rect button = anchor.localToGlobal(Offset.zero, ancestor: overlay) & anchor.size;
    final double right = overlay.size.width - _windowMargin;
    final double left = widget.startAligned ? button.left : button.center.dx - _popoverWidth / 2;

    if (left >= _windowMargin && left + _popoverWidth <= right)
    {
      return 0;
    }

    final double lined = left < _windowMargin ? button.left : button.right - _popoverWidth;
    final double inside = lined.clamp(_windowMargin, math.max(_windowMargin, right - _popoverWidth));

    return inside - left;
  }

  Widget _buildPopover(BuildContext context)
  {
    return Positioned(
      width: _popoverWidth,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: widget.startAligned ? Alignment.bottomLeft : Alignment.bottomCenter,
        followerAnchor: widget.startAligned ? Alignment.topLeft : Alignment.topCenter,
        offset: Offset(_shift, _popoverGap),
        child: TapRegion(
          groupId: _link,
          // A tour over the popover takes the clicks around it.
          onTapOutside: (_)
          {
            if (!isDesktopTourShown)
            {
              _close();
            }
          },
          child: CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
            child: Focus(
              autofocus: true,
              child: FadeTransition(
                opacity: _opacity,
                child: AnimatedBuilder(
                  animation: _curve,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -_revealRise * (1 - _curve.value)),
                    child: child,
                  ),
                  // Painted once; the frames of the motion only move it.
                  child: RepaintBoundary(child: widget.popover(context, _close)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool lit = _isHovered || _isOpen;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildPopover,
        child: TapRegion(
          groupId: _link,
          child: AppTooltip(
            message: widget.tooltip,
            waitDuration: const Duration(milliseconds: 400),
            decoration: AppTheme.tooltipDecoration,
            textStyle: AppTheme.tooltipTextStyle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_)
              {
                setState(() => _isHovered = true);
                widget.onPrefetch?.call();
              },
              onExit: (_) => setState(() => _isHovered = false),
              child: GestureDetector(
                onTap: _toggle,
                // Sized outside the animation: only the colours fade, a new size never animates.
                child: SizedBox.square(
                  dimension: widget.size,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: lit ? AppTheme.trialTealDeep : AppTheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      size: widget.size * 21 / CarouselArrowButton.defaultSize,
                      color: lit ? Colors.white : AppTheme.trialTealDeepText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarTodayButton extends StatefulWidget
{
  final bool enabled;
  final VoidCallback onTap;

  const CalendarTodayButton({super.key, required this.enabled, required this.onTap});

  @override
  State<CalendarTodayButton> createState() => _CalendarTodayButtonState();
}

class _CalendarTodayButtonState extends State<CalendarTodayButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    final bool lit = _isHovered && widget.enabled;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: kCalendarArrowSize,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: !widget.enabled
                ? AppTheme.arrowDisabledSurface
                : (lit ? AppTheme.trialTealDeep : AppTheme.surface),
            borderRadius: BorderRadius.circular(kCalendarArrowSize / 2),
            boxShadow: widget.enabled ? AppTheme.cardShadow : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: !widget.enabled
                  ? AppTheme.trialMutedText.withValues(alpha: 0.5)
                  : (lit ? Colors.white : AppTheme.trialTealDeepText),
            ),
            child: Text(kTodayLabel, maxLines: 1),
          ),
        ),
      ),
    );
  }
}
