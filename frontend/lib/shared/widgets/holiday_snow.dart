import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/theme_colours.dart';
import '../../core/utils/festivities.dart';
import '../../core/utils/rome_clock.dart';

// How far the snow rises above a card: a scroll area whose first cards touch its top keeps this much inside it.
const double kSnowRoom = 8;

// Marks the phone home: its outermost glass cards carry the snow, the panels inside them do not.
class HolidaySnow extends InheritedWidget
{
  final bool on;

  const HolidaySnow({super.key, this.on = true, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<HolidaySnow>()?.on ?? false;

  @override
  bool updateShouldNotify(HolidaySnow oldWidget) => oldWidget.on != on;
}

// Snow lying still on a card's top edge, 20 December - 2 January, only where the edge runs straight.
class SnowCap extends StatefulWidget
{
  final Widget child;

  // The card's corner radius: the snow ends before the edge starts to curve.
  final double radius;

  // Sizes, 1 on desktop.
  final double scale;

  const SnowCap({super.key, required this.child, required this.radius, this.scale = 1});

  @override
  State<SnowCap> createState() => _SnowCapState();
}

class _SnowCapState extends State<SnowCap>
{
  // Each card its own drifts, kept while it lives.
  static int _cards = 0;
  final int _seed = _cards++;

  @override
  Widget build(BuildContext context)
  {
    if (!isDecoratedDay(romeNow()))
    {
      return widget.child;
    }

    return CustomPaint(
      foregroundPainter: _SnowCapPainter(seed: _seed, radius: widget.radius, scale: widget.scale, dark: ThemeColours.isDark),
      child: widget.child,
    );
  }
}

// A bump of snow: centre, half width, height.
typedef _Bump = (double, double, double);

class _SnowCapPainter extends CustomPainter
{
  final int seed;
  final double radius;
  final double scale;
  final bool dark;

  const _SnowCapPainter({required this.seed, required this.radius, required this.scale, required this.dark});

  // Bumps along the span at gaps drawn between the two bounds, each of its own size.
  static List<_Bump> _bumps(math.Random random, double span, double gapFrom, double gapTo,
      (double, double) width, (double, double) height)
  {
    final List<_Bump> bumps = [];

    for (double x = random.nextDouble() * gapFrom; x < span; x += gapFrom + random.nextDouble() * (gapTo - gapFrom))
    {
      bumps.add((
        x,
        width.$1 + random.nextDouble() * (width.$2 - width.$1),
        height.$1 + random.nextDouble() * (height.$2 - height.$1),
      ));
    }

    return bumps;
  }

  static double _sum(List<_Bump> bumps, double x)
  {
    double total = 0;

    for (final (centre, width, height) in bumps)
    {
      final double d = (x - centre) / width;

      if (d.abs() < 3)
      {
        total += height * math.exp(-d * d);
      }
    }

    return total;
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    final double s = scale;
    final double left = radius + 2 * s;
    final double span = size.width - radius - 2 * s - left;

    if (span < 24 * s)
    {
      return;
    }

    final math.Random random = math.Random(seed * 7919 + 17);
    final double layer = (1.6 + random.nextDouble() * 0.8) * s;
    final List<_Bump> mounds = _bumps(random, span, 36 * s, 100 * s, (16 * s, 40 * s), (1.2 * s, 4.6 * s));
    // A lip of snow slipping just over the front edge, so it lies on the card rather than on top of it.
    final List<_Bump> lip = _bumps(random, span, 12 * s, 28 * s, (6 * s, 14 * s), (0.3 * s, 1.4 * s));
    final double lipDepth = 1.2 * s;
    final double highest = kSnowRoom - 0.6;
    final double endLength = 20 * s;

    // Thinner towards both ends, like the end of a heap.
    double end(double x)
    {
      final double d = math.min(x, span - x);

      if (d >= endLength)
      {
        return 1;
      }

      final double u = (endLength - d) / endLength;

      // Thinning out along the way, rounded at the very tip.
      final double v = 1 - u;

      return math.sqrt(v * v * (3 - 2 * v));
    }

    final List<Offset> top = [];
    final List<Offset> bottom = [];
    double deepest = 0;

    for (double x = 0; x <= span; x += 1.5)
    {
      final double e = end(x);
      final double above = math.min(layer + _sum(mounds, x), highest) * e;
      final double below = (lipDepth + _sum(lip, x)) * e;

      top.add(Offset(left + x, -above));
      bottom.add(Offset(left + x, below));
      deepest = math.max(deepest, below);
    }

    final Path cap = Path()..addPolygon([...top, ...bottom.reversed], true);

    // Its shadow on the card under the lip, and a soft rim against the page above.
    canvas.drawPath(
      cap.shift(Offset(0, 1.4 * s)),
      Paint()
        ..color = dark ? Colors.black.withValues(alpha: 0.35) : const Color(0xFF2E4B66).withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
    );

    // White on top, cooler down the front where it faces away from the light.
    final Color shade = dark ? const Color(0xFFB4C6D6) : const Color(0xFFB9CCDE);
    canvas.drawPath(
      cap,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, -highest), Offset(0, math.max(deepest, 1)), [
          Colors.white,
          const Color(0xFFF6F9FC),
          shade,
        ], [0, highest / (highest + math.max(deepest, 1)), 1]),
    );
  }

  @override
  bool shouldRepaint(_SnowCapPainter oldDelegate)
  {
    return oldDelegate.seed != seed || oldDelegate.radius != radius || oldDelegate.scale != scale || oldDelegate.dark != dark;
  }
}
