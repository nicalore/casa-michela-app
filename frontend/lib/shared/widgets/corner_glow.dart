import 'package:flutter/material.dart';

enum GlowCorner
{
  topRight,
  bottomLeft,
}

// Decorative radial glow bleeding in from a corner of the page. It is far
// larger than the viewport and deliberately positioned off screen, so only the
// faded tail of the gradient is visible.
class CornerGlow extends StatefulWidget
{
  // The size it was drawn at, on a page as wide as the layout was drawn for.
  static const double _diameter = 1600;

  // On a narrower window it comes down with the page. Fixed at 1600 it stopped
  // being a glow in a corner of a phone and became the background: half of it
  // is 800px, which is more than twice the width of the screen it was tinting.
  static const double _widthFactor = 1.15;
  static const double _minDiameter = 520;

  static double _diameterFor(BuildContext context)
  {
    final width = MediaQuery.sizeOf(context).width * _widthFactor;

    return width.clamp(_minDiameter, _diameter);
  }

  // The blue every page has always used. It stays the default so tinting the
  // glow is opt in, page by page.
  static const Color _defaultTint = Color(0xFF003C82);

  static const double _innerOpacity = 0.30;
  static const double _midOpacity = 0.13;

  final GlowCorner corner;

  // Hue at the heart of the glow, the one sitting in the corner itself.
  final Color tint;

  // Hue the glow shifts to as it fades inward. Left null it stays on tint, so a
  // page that only wants a single colour still passes one value; giving both
  // lets a glow travel along a ramp the way the mockup's background does.
  final Color? edgeTint;

  // Multiplies both opacity stops, for the pages where one corner has to carry
  // more weight than the other. Above roughly 1.6 the gradient stops reading as
  // a glow and starts looking like a coloured corner.
  final double intensity;

  // Slow breathing of the glow, off by default. It is a background effect on a
  // very large surface: see the note on _syncAnimation before turning it on.
  final bool animated;

  const CornerGlow({
    super.key,
    required this.corner,
    this.tint = _defaultTint,
    this.edgeTint,
    this.intensity = 1.0,
    this.animated = false,
  });

  @override
  State<CornerGlow> createState() => _CornerGlowState();
}

class _CornerGlowState extends State<CornerGlow> with SingleTickerProviderStateMixin
{
  // Two different periods for the two corners, so they never breathe in step: a
  // shared one reads as a mechanical pulse, while these drift in and out of
  // phase on their own and never quite repeat the same frame.
  static const Duration _topRightPeriod = Duration(seconds: 11);
  static const Duration _bottomLeftPeriod = Duration(seconds: 15);

  static const double _restScale = 1.0;
  static const double _breathScale = 1.22;

  // Travel of the glow along the diagonal that runs from its corner to the
  // centre of the page, in logical pixels. It moves in step with the swelling
  // rather than against it: on its own the scaling is nearly invisible, because
  // a circle growing about a centre that sits off screen barely changes where
  // its edge falls, while sliding the whole shape inward is movement the eye
  // actually catches.
  static const double _driftDistance = 34;

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _drift;

  @override
  void initState()
  {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.corner == GlowCorner.topRight ? _topRightPeriod : _bottomLeftPeriod,
    );

    final eased = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _scale = Tween<double>(begin: _restScale, end: _breathScale).animate(eased);
    _drift = Tween<double>(begin: 0, end: _driftDistance).animate(eased);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(CornerGlow oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  // The breathing runs only when the page asks for it and the system is not set
  // to reduce motion: a shape this large drifting behind the content is exactly
  // what that setting exists to stop. A stopped controller asks for no ticks,
  // so a page that leaves the effect off pays nothing for it.
  void _syncAnimation()
  {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldRun = widget.animated && !reduceMotion;

    if (shouldRun && !_controller.isAnimating)
    {
      _controller.repeat(reverse: true);

      return;
    }

    if (!shouldRun && _controller.isAnimating)
    {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final isTopRight = widget.corner == GlowCorner.topRight;
    final outerTint = widget.edgeTint ?? widget.tint;

    // Opacities are clamped because intensity is a free-form knob and alpha
    // outside 0..1 throws.
    final innerAlpha = (CornerGlow._innerOpacity * widget.intensity).clamp(0.0, 1.0);
    final midAlpha = (CornerGlow._midOpacity * widget.intensity).clamp(0.0, 1.0);

    // Under the RepaintBoundary the gradient is rasterised once and the
    // animation only re-transforms that layer, instead of re-shading a circle
    // this size on every frame.
    final diameter = CornerGlow._diameterFor(context);

    final Widget glow = RepaintBoundary(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.tint.withValues(alpha: innerAlpha),
                outerTint.withValues(alpha: midAlpha),
                outerTint.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
    );

    // Half of it hangs off the corner, whatever size it came out.
    final offset = -diameter / 2;

    return Positioned(
      top: isTopRight ? offset : null,
      right: isTopRight ? offset : null,
      bottom: isTopRight ? null : offset,
      left: isTopRight ? null : offset,
      child: IgnorePointer(
        child: widget.animated
            // Both transforms run on the cached layer, so the frame costs a
            // matrix and no repainting. The drift always heads for the middle
            // of the page, which is away from the corner the glow sits in.
            ? AnimatedBuilder(
                animation: _controller,
                child: glow,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    isTopRight ? -_drift.value : _drift.value,
                    isTopRight ? _drift.value : -_drift.value,
                  ),
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                ),
              )
            : glow,
      ),
    );
  }
}
