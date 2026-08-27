import 'package:flutter/material.dart';

enum GlowCorner
{
  topRight,
  bottomLeft,
}

class CornerGlow extends StatefulWidget
{
  static const double _diameter = 1600;

  static const double _widthFactor = 1.15;
  static const double _minDiameter = 520;

  static double _diameterFor(BuildContext context)
  {
    final width = MediaQuery.sizeOf(context).width * _widthFactor;

    return width.clamp(_minDiameter, _diameter);
  }

  static const Color _defaultTint = Color(0xFF003C82);

  static const double _innerOpacity = 0.30;
  static const double _midOpacity = 0.13;

  final GlowCorner corner;

  final Color tint;

  final Color? edgeTint;

  final double intensity;

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
  static const Duration _topRightPeriod = Duration(seconds: 11);
  static const Duration _bottomLeftPeriod = Duration(seconds: 15);

  static const double _restScale = 1.0;
  static const double _breathScale = 1.22;

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

    // Clamped: intensity is a free-form knob and alpha outside 0..1 throws.
    final innerAlpha = (CornerGlow._innerOpacity * widget.intensity).clamp(0.0, 1.0);
    final midAlpha = (CornerGlow._midOpacity * widget.intensity).clamp(0.0, 1.0);

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

    final offset = -diameter / 2;

    return Positioned(
      top: isTopRight ? offset : null,
      right: isTopRight ? offset : null,
      bottom: isTopRight ? null : offset,
      left: isTopRight ? null : offset,
      child: IgnorePointer(
        child: widget.animated
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
