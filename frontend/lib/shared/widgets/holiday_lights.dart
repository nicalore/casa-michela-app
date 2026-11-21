import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colours.dart';
import '../../core/utils/festivities.dart';
import '../../core/utils/rome_clock.dart';
import '../../features/auth/models/me_response.dart';

// Bulb colours in the order a string repeats them: the fireworks' fixed pairs, the same in every theme.
final List<(Color, Color)> _bulbColours = [for (final i in const [0, 2, 3, 5, 7, 1, 6]) AppTheme.fireworks[i]];

// Lit from the start, they twinkle, two waves of light run along the string and a few bulbs blink, until it calms down.
const double _calmFrom = 4.0;
const List<double> _waves = [1.2, 2.9];
const double _twinkleLength = 4.8;

enum HolidayLightsShape
{
  // Round the desktop bar's ends and in swags under it.
  bar,
  // The same in the short bar of a dense window: shallow swags, bulbs leaning, so the page keeps its gap.
  compactBar,
  // Along the phone menu's top edge, the bulbs hanging over its glass.
  menu,
}

// A string of lights on show 20 December - 2 January, always lit; once per launch it twinkles, then stays still.
class HolidayLights extends StatefulWidget
{
  final MeResponse user;
  final HolidayLightsShape shape;

  // The bar, or the menu with its rounded top corners, in this widget's coordinates.
  final Rect frame;

  const HolidayLights({super.key, required this.user, required this.shape, required this.frame});

  // Tax code whose lights twinkled this launch: later hosts show them still.
  static String? _twinkledFor;

  // Hosts still twinkling.
  static int _twinkling = 0;

  @visibleForTesting
  static void debugReset() => _twinkledFor = null;

  @visibleForTesting
  static bool get debugTwinkling => _twinkling > 0;

  @override
  State<HolidayLights> createState() => _HolidayLightsState();
}

class _HolidayLightsState extends State<HolidayLights> with TickerProviderStateMixin
{
  Ticker? _ticker;

  // Seconds into the twinkle; null once still.
  final ValueNotifier<double?> _time = ValueNotifier<double?>(null);

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _twinkle();
  }

  @override
  void didUpdateWidget(HolidayLights oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.taxCode != widget.user.taxCode)
    {
      _twinkle();
    }
  }

  void _twinkle()
  {
    final DateTime today = romeNow();

    if (_ticker != null || HolidayLights._twinkledFor == widget.user.taxCode || !isDecoratedDay(today))
    {
      return;
    }

    HolidayLights._twinkledFor = widget.user.taxCode;

    // Still with the effects off; a birthday's or a feast's own show plays over them.
    if (!VisualEffects.of(context) || MediaQuery.disableAnimationsOf(context))
    {
      return;
    }

    _time.value = 0;
    _ticker = createTicker(_tick)..start();
    HolidayLights._twinkling++;
  }

  void _tick(Duration elapsed)
  {
    final double t = elapsed.inMicroseconds / 1e6;

    if (t < _twinkleLength)
    {
      _time.value = t;

      return;
    }

    // Still from here on: no ticker left to ask for frames.
    _stop();
    _time.value = null;
  }

  void _stop()
  {
    _ticker!.dispose();
    _ticker = null;
    HolidayLights._twinkling--;
  }

  @override
  void dispose()
  {
    if (_ticker != null)
    {
      _stop();
    }

    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    if (!isDecoratedDay(romeNow()))
    {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _LightsPainter(shape: widget.shape, frame: widget.frame, dark: ThemeColours.isDark, time: _time),
        ),
      ),
    );
  }
}

class _Bulb
{
  final Offset at;
  final double angle;

  // How far along the string, 0 at its start, 1 at its end.
  final double along;
  final (Color, Color) colour;

  // Its own twinkle, and the moment it blinks if it is a blinker.
  final double phase;
  final double rate;
  final double? blinkAt;

  const _Bulb(this.at, this.angle, this.along, this.colour, this.phase, this.rate, this.blinkAt);
}

class _LightsPainter extends CustomPainter
{
  final HolidayLightsShape shape;
  final Rect frame;
  final bool dark;
  final ValueNotifier<double?> time;

  late final double _scale;
  late final Path _wire;
  late final List<_Bulb> _bulbs;

  _LightsPainter({required this.shape, required this.frame, required this.dark, required this.time}) : super(repaint: time)
  {
    _scale = shape == HolidayLightsShape.menu ? 0.92 : (frame.width / 1360).clamp(0.85, 1.1);

    final List<Offset> points = shape == HolidayLightsShape.menu ? _menuWire() : _barWire();

    _wire = Path()..addPolygon(points, false);
    _bulbs = _placeBulbs(points);
  }

  bool get _compact => shape == HolidayLightsShape.compactBar;

  // Round the left end from the top, in swags under the bar, round the right end to the top.
  List<Offset> _barWire()
  {
    final double r = frame.height / 2;
    final double out = (_compact ? 2 : 3) * _scale;
    final Offset left = Offset(frame.left + r, frame.top + r);
    final Offset right = Offset(frame.right - r, frame.top + r);
    // A dense window's bar sits close to its top: there the string starts lower on the ends.
    final double skip = _compact ? math.pi / 4 : 0;
    final double turn = math.pi - 2 * skip;
    final List<Offset> points = [];

    for (var i = 0; i <= 40; i++)
    {
      final double a = -math.pi / 2 - skip - turn * i / 40;

      points.add(left + Offset(math.cos(a), math.sin(a)) * (r + out));
    }

    final double span = frame.width - 2 * r;
    final int swags = math.max(3, (span / ((_compact ? 120 : 150) * _scale)).round());
    final double sag = (_compact ? 3.5 : 10) * _scale;

    for (var s = 0; s < swags; s++)
    {
      for (var i = 1; i <= 30; i++)
      {
        final double u = i / 30;

        points.add(Offset(frame.left + r + span * (s + u) / swags, frame.bottom + out + sag * 4 * u * (1 - u)));
      }
    }

    for (var i = 1; i <= 40; i++)
    {
      final double a = math.pi / 2 - turn * i / 40;

      points.add(right + Offset(math.cos(a), math.sin(a)) * (r + out));
    }

    return points;
  }

  // On the rim: up round the left corner, in shallow swags along the top edge, down round the right corner.
  List<Offset> _menuWire()
  {
    const double r = 28;
    const double rim = 0.8;
    final List<Offset> points = [Offset(frame.left - 2, frame.top + r + 4)];

    for (var i = 0; i <= 20; i++)
    {
      final double a = math.pi + math.pi / 2 * i / 20;

      points.add(Offset(frame.left + r, frame.top + r) + Offset(math.cos(a), math.sin(a)) * (r - rim));
    }

    final double span = frame.width - 2 * r;
    final int swags = math.max(2, (span / 66).round());
    const double sag = 3.5;

    for (var s = 0; s < swags; s++)
    {
      for (var i = 1; i <= 24; i++)
      {
        final double u = i / 24;

        points.add(Offset(frame.left + r + span * (s + u) / swags, frame.top + rim + sag * 4 * u * (1 - u)));
      }
    }

    for (var i = 1; i <= 20; i++)
    {
      final double a = -math.pi / 2 + math.pi / 2 * i / 20;

      points.add(Offset(frame.right - r, frame.top + r) + Offset(math.cos(a), math.sin(a)) * (r - rim));
    }

    points.add(Offset(frame.right + 2, frame.top + r + 4));

    return points;
  }

  List<_Bulb> _placeBulbs(List<Offset> points)
  {
    final List<double> lengths = [0];

    for (var i = 1; i < points.length; i++)
    {
      lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
    }

    final double total = lengths.last;
    final math.Random random = math.Random(21);
    final double gap = (shape == HolidayLightsShape.menu ? 30 : (_compact ? 27 : 31)) * _scale;
    final List<_Bulb> bulbs = [];
    var segment = 1;
    var k = 0;

    for (double along = gap * 0.6; along < total - gap * 0.4; along += gap)
    {
      while (segment < lengths.length - 1 && lengths[segment] < along)
      {
        segment++;
      }

      final Offset a = points[segment - 1];
      final Offset b = points[segment];
      final double span = lengths[segment] - lengths[segment - 1];
      final Offset at = Offset.lerp(a, b, span == 0 ? 0 : ((along - lengths[segment - 1]) / span).clamp(0.0, 1.0))!;
      final Offset dir = (b - a) / math.max((b - a).distance, 1e-6);
      // On the string's right: away from the bar, into the menu's glass.
      final Offset normal = Offset(-dir.dy, dir.dx);
      double angle = math.atan2(normal.dy, normal.dx);
      final double lean = (k.isEven ? 1 : -1) * (0.35 + random.nextDouble() * 0.3);
      final double jitter = (random.nextDouble() - 0.5) * 0.45;
      final double phase = random.nextDouble() * math.pi * 2;
      final double rate = 0.7 + random.nextDouble() * 0.9;
      final double? blinkAt = random.nextDouble() < 0.18 ? 0.4 + random.nextDouble() * 3.1 : null;

      angle += switch (shape)
      {
        // Hanging, the corners' ones half way down.
        HolidayLightsShape.menu => (math.pi / 2 - angle) * 0.5 + jitter * 0.7,
        HolidayLightsShape.compactBar => at.dy > frame.bottom ? lean : jitter,
        // Hanging under the bar, the swags pull them towards the floor.
        HolidayLightsShape.bar => (at.dy > frame.bottom ? (math.pi / 2 - angle) * 0.55 : 0) + jitter,
      };

      bulbs.add(_Bulb(at, angle, along / total, _bulbColours[k % _bulbColours.length], phase, rate, blinkAt));
      k++;
    }

    return bulbs;
  }

  // 1 lit as when still; the twinkle dims it, a wave brightens it past 1.
  double _brightness(_Bulb bulb, double? t)
  {
    if (t == null)
    {
      return 1;
    }

    // How much they twinkle: swelling in from still, gone once it calms down.
    final double live = _smooth(t / 0.6) * (1 - _smooth((t - _calmFrom) / 0.7));
    double b = 1 - live * (0.22 + 0.22 * math.sin(math.pi * 2 * bulb.rate * t + bulb.phase));

    for (final double wave in _waves)
    {
      final double x = (t - wave - 0.75 * bulb.along) / 0.13;

      b += 0.55 * math.exp(-x * x);
    }

    final double? blinkAt = bulb.blinkAt;

    if (blinkAt != null && t > blinkAt && t < blinkAt + 0.32)
    {
      b *= 0.08;
    }

    return b;
  }

  static double _smooth(double t)
  {
    final double x = t.clamp(0.0, 1.0);

    return x * x * (3 - 2 * x);
  }

  double get _bulbScale => _scale * switch (shape)
  {
    HolidayLightsShape.bar => 1.15,
    HolidayLightsShape.compactBar => 0.9,
    HolidayLightsShape.menu => 1,
  };

  @override
  void paint(Canvas canvas, Size size)
  {
    if (frame.width <= frame.height)
    {
      return;
    }

    final double? t = time.value;
    final double s = _bulbScale;

    // Glows first, so a neighbour's glass sits over them.
    for (final bulb in _bulbs)
    {
      final double b = _brightness(bulb, t);

      if (b <= 0.01)
      {
        continue;
      }

      final Offset centre = bulb.at + Offset(math.cos(bulb.angle), math.sin(bulb.angle)) * 10 * s;
      final double radius = (dark ? 16.5 : 13) * s;
      final Color bright = bulb.colour.$2;

      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver
          ..shader = ui.Gradient.radial(centre, radius, [
            bright.withValues(alpha: (dark ? 0.5 : 0.34) * math.min(b, 1.2)),
            bright.withValues(alpha: 0),
          ]),
      );
    }

    canvas.drawPath(
      _wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * _scale
        ..strokeJoin = StrokeJoin.round
        ..color = (dark ? const Color(0xFF5E786A) : const Color(0xFF22402F)).withValues(alpha: 0.9),
    );

    for (final bulb in _bulbs)
    {
      _paintBulb(canvas, bulb, _brightness(bulb, t).clamp(0.0, 1.0), s);
    }
  }

  // Socket and glass along the bulb's own axis, the glass shaded like a lit cylinder.
  void _paintBulb(Canvas canvas, _Bulb bulb, double lit, double s)
  {
    final (Color deep, Color bright) = bulb.colour;
    final Color off = Color.lerp(deep, const Color(0xFF59606B), dark ? 0.55 : 0.25)!;
    final Color body = Color.lerp(off, bright, lit)!;
    final Color edge = Color.lerp(Color.lerp(off, deep, 0.4)!, Color.lerp(bright, deep, 0.45)!, lit)!;
    final Color core = Color.lerp(Color.lerp(off, Colors.white, 0.25)!, Color.lerp(bright, Colors.white, 0.6)!, lit)!;

    canvas.save();
    canvas.translate(bulb.at.dx, bulb.at.dy);
    canvas.rotate(bulb.angle);
    canvas.scale(s);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-0.5, -1.9, 5, 3.8), const Radius.circular(1)),
      Paint()..color = dark ? const Color(0xFF3F5A4B) : const Color(0xFF1C3A2A),
    );

    canvas.drawPath(
      Path()
        ..moveTo(4, -2.1)
        ..cubicTo(6.6, -3.7, 11.4, -3.8, 14.2, 0)
        ..cubicTo(11.4, 3.8, 6.6, 3.7, 4, 2.1)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, -3.7), const Offset(0, 3.7), [edge, core, body, edge], const [0, 0.38, 0.62, 1]),
    );

    if (dark && lit > 0)
    {
      canvas.drawCircle(
        const Offset(9.4, 0),
        2.2,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: 0.55 * lit),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(8.2, -1.6), width: 3.6, height: 1.1),
      Paint()..color = Colors.white.withValues(alpha: 0.45 + 0.35 * lit),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LightsPainter oldDelegate)
  {
    return oldDelegate.shape != shape || oldDelegate.frame != frame || oldDelegate.dark != dark || oldDelegate.time != time;
  }
}
