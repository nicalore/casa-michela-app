import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colours.dart';

// In after a short pause, across in this long, and the last sparks out this much later.
const double _start = 0.2;
const double _cross = 5.2;
const double _length = _start + _cross + 2.8;

const int _reindeer = 4;

// Where the sleigh flies and how big it is drawn.
class SleighSpec
{
  final Size page;

  // It flies below this height: the bar, or the phone's status bar.
  final double top;

  // The silhouettes' size; the phone's is about 1.
  final double unit;

  // The sparks' size.
  final double spark;

  final bool dark;

  const SleighSpec({required this.page, required this.top, required this.unit, required this.spark, required this.dark});

  factory SleighSpec.desktop(Size page, Rect bar)
  {
    final double scale = (page.width / 1440).clamp(0.85, 1.15);

    return SleighSpec(page: page, top: bar.bottom, unit: 1.6 * scale, spark: scale, dark: ThemeColours.isDark);
  }

  factory SleighSpec.mobile(Size page, double statusBar)
  {
    final double scale = (page.shortestSide / 393).clamp(1.0, 1.5);

    return SleighSpec(page: page, top: statusBar + 5, unit: 1.05 * scale, spark: 0.92 * scale, dark: ThemeColours.isDark);
  }

  bool get phone => page.width < 600;

  @override
  bool operator ==(Object other)
  {
    return other is SleighSpec && other.page == page && other.top == top && other.unit == unit && other.spark == spark &&
        other.dark == dark;
  }

  @override
  int get hashCode => Object.hash(page, top, unit, spark, dark);
}

// Gold dust shed by the runners: it drifts back and down, twinkles and goes out.
class _Mote
{
  final double born;
  final Offset from;
  final Offset velocity;
  final double life;
  final double size;
  final double rate;
  final double phase;
  final bool pale;

  const _Mote(this.born, this.from, this.velocity, this.life, this.size, this.rate, this.phase, this.pale);
}

// The reindeer's distances ahead of the sleigh along its route.
double _lead(int k, double unit) => (44 + k * 31) * unit;

// The route as points spaced along it, so the sleigh and the reindeer share one curve.
class _Route
{
  final List<Offset> points;
  final List<double> lengths;

  _Route._(this.points, this.lengths);

  // Never turning down. The computer's starts under the bottom edge on the left and leaves through the right edge
  // at two fifths of the height; the phone's comes in from the left and climbs away to the right.
  factory _Route.of(SleighSpec spec)
  {
    final double w = spec.page.width;
    final double h = spec.page.height;
    final double top = spec.top;
    final double unit = spec.unit;
    final List<Offset> controls = spec.phone
        ? [
            Offset(-40 * unit, top + 0.36 * h),
            Offset(0.25 * w, top + 0.24 * h),
            Offset(0.62 * w, top + 0.12 * h),
            Offset(w + 20 * unit, top + 0.05 * h),
          ]
        : [
            Offset(0.185 * w, h + 10),
            Offset(0.3 * w, 0.62 * h),
            Offset(0.58 * w, 0.43 * h),
            Offset(w + 20 * unit, 0.41 * h),
          ];
    final List<Offset> points = [];
    final List<double> lengths = [];

    for (var i = 0; i <= 240; i++)
    {
      final double u = i / 240;
      final double v = 1 - u;
      final Offset point = controls[0] * (v * v * v) + controls[1] * (3 * u * v * v) + controls[2] * (3 * u * u * v) +
          controls[3] * (u * u * u);

      lengths.add(points.isEmpty ? 0 : lengths.last + (point - points.last).distance);
      points.add(point);
    }

    return _Route._(points, lengths);
  }

  double get total => lengths.last;

  // Past either end it carries straight on, so the file can come in and go out of sight.
  Offset at(double s)
  {
    if (s <= 0)
    {
      return points.first + _ending(0) * s;
    }

    if (s >= total)
    {
      return points.last + _ending(points.length - 2) * (s - total);
    }

    var low = 0;
    var high = lengths.length - 1;

    while (high - low > 1)
    {
      final int middle = (low + high) ~/ 2;

      if (lengths[middle] < s)
      {
        low = middle;
      }
      else
      {
        high = middle;
      }
    }

    return Offset.lerp(points[low], points[high], (s - lengths[low]) / (lengths[high] - lengths[low]))!;
  }

  Offset _ending(int i)
  {
    final Offset d = points[i + 1] - points[i];

    return d / d.distance;
  }

  // Heading there, kept to a climb a sleigh can take.
  double heading(double s)
  {
    final Offset d = at(s + 3) - at(s - 3);

    return math.atan2(d.dy, d.dx).clamp(-0.85, 0.3);
  }

  // Where the sleigh is along the route a given time into the flight: from out of sight, file and all, to out of sight.
  double sleighAt(double t, double unit)
  {
    final double from = -_lead(_reindeer - 1, unit) - 40 * unit;
    final double to = total + 40 * unit;

    return from + (to - from) * ((t - _start) / _cross).clamp(0.0, 1.0);
  }
}

class SleighFlight extends ChangeNotifier
{
  // Asked on every tick: true ends the flight early.
  final bool Function()? shouldEnd;

  final int seed;

  late final Ticker _ticker;

  double elapsed = 0;
  bool done = false;

  SleighSpec? _planned;
  late _Route _route;
  List<_Mote> _motes = const [];

  SleighFlight({this.shouldEnd, int? seed}) : seed = seed ?? math.Random().nextInt(1 << 30)
  {
    _ticker = Ticker(_onTick)..start();
  }

  // The route and the dust for this page, drawn again only when the page changes.
  (_Route, List<_Mote>) _planFor(SleighSpec spec)
  {
    if (spec != _planned)
    {
      _planned = spec;
      _route = _Route.of(spec);
      _motes = _plan(spec, _route, math.Random(seed));
    }

    return (_route, _motes);
  }

  static List<_Mote> _plan(SleighSpec spec, _Route route, math.Random random)
  {
    final double unit = spec.unit;
    final List<_Mote> motes = [];

    for (double t = _start + 0.1; t < _start + _cross; t += 0.03)
    {
      final double along = route.sleighAt(t, unit);
      final double heading = route.heading(along);
      final Offset runners = route.at(along) + Offset(math.cos(heading), math.sin(heading)) * (-18 * unit) +
          Offset(0, 9 * unit);

      motes.add(_Mote(
        t,
        runners + Offset((random.nextDouble() - 0.5) * 8, (random.nextDouble() - 0.5) * 5) * unit,
        Offset(-20 - random.nextDouble() * 30, (random.nextDouble() - 0.2) * 20) * unit,
        1.2 + random.nextDouble() * 1.4,
        (0.8 + random.nextDouble() * 1.1) * spec.spark,
        8 + random.nextDouble() * 10,
        random.nextDouble() * math.pi * 2,
        random.nextDouble() < 0.4,
      ));
    }

    return motes;
  }

  void _onTick(Duration since)
  {
    elapsed = since.inMicroseconds / Duration.microsecondsPerSecond;

    if (elapsed > _length || (shouldEnd?.call() ?? false))
    {
      end();

      return;
    }

    notifyListeners();
  }

  void end()
  {
    if (done)
    {
      return;
    }

    done = true;
    _ticker.dispose();
    notifyListeners();
  }
}

class SleighPainter extends CustomPainter
{
  final SleighFlight flight;
  final SleighSpec spec;

  SleighPainter({required this.flight, required this.spec}) : super(repaint: flight);

  @override
  void paint(Canvas canvas, Size size)
  {
    final double t = flight.elapsed;
    final (_Route route, List<_Mote> motes) = flight._planFor(spec);

    _paintMotes(canvas, motes, t);

    if (t < _start || t > _start + _cross)
    {
      return;
    }

    final double unit = spec.unit;
    final double along = route.sleighAt(t, unit);
    final double heading = route.heading(along);
    // The bob moves it, never tilts it.
    final Offset at = route.at(along) + Offset(0, math.sin(t * 5.2) * 2.2 * unit);
    final Offset forward = Offset(math.cos(heading), math.sin(heading));
    // Night blue on light pages, moonlit cream on dark ones.
    final Color ink = spec.dark ? const Color(0xEBF1E4C0) : const Color(0xE61B2A40);
    final Paint fill = Paint()..color = ink;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;

    // Reindeer in single file ahead of the sleigh along the route, each on its own beat and heading.
    final Path reins = Path();
    final Offset hands = at + forward * (9 * unit) + Offset(0, -6 * unit);

    reins.moveTo(hands.dx, hands.dy);

    for (var k = 0; k < _reindeer; k++)
    {
      final double beat = t * 2 * math.pi * 2.1 + k * 0.9;
      final double ahead = along + _lead(k, unit);
      final double facing = route.heading(ahead);
      final Offset place = route.at(ahead) + Offset(0, math.sin(beat) * 1.6 * unit - 6 * unit);
      final Offset chest = place + Offset(math.cos(facing), math.sin(facing)) * (7 * unit) + Offset(0, unit);

      reins.lineTo(chest.dx, chest.dy);
      _paintReindeer(canvas, place, facing, unit, beat, fill, line);
    }

    canvas.drawPath(reins, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * unit
      ..color = ink.withValues(alpha: ink.a * 0.7));

    _paintSleigh(canvas, at, heading, unit, fill, line);
  }

  void _paintMotes(Canvas canvas, List<_Mote> motes, double t)
  {
    final double s = spec.spark;
    final bool dark = spec.dark;
    final Path deep = Path();
    final Path bright = Path();
    final Path pale = Path();
    final Path glow = Path();

    for (final mote in motes)
    {
      final double age = t - mote.born;

      if (age < 0 || age > mote.life)
      {
        continue;
      }

      final double fade = (age / 0.08).clamp(0.0, 1.0) * (1 - math.pow(age / mote.life, 1.6).toDouble());
      final double a = fade * (0.55 + 0.45 * math.sin(mote.rate * age + mote.phase));

      if (a < 0.15)
      {
        continue;
      }

      final Offset at = mote.from + mote.velocity * age + Offset(0, 22 * s * age * age);
      final double r = mote.size * (0.6 + 0.4 * a);

      (mote.pale ? pale : bright).addOval(Rect.fromCircle(center: at, radius: r));
      deep.addOval(Rect.fromCircle(center: at, radius: r * 1.5));
      glow.addOval(Rect.fromCircle(center: at, radius: r * 3.2));
    }

    final (Color goldDeep, Color goldBright) = AppTheme.fireworksGold;
    final BlendMode blend = dark ? BlendMode.plus : BlendMode.srcOver;

    if (dark)
    {
      canvas.drawPath(glow, Paint()
        ..blendMode = BlendMode.plus
        ..color = goldBright.withValues(alpha: 0.12));
    }
    else
    {
      canvas.drawPath(deep, Paint()..color = goldDeep.withValues(alpha: 0.75));
    }

    canvas.drawPath(bright, Paint()
      ..blendMode = blend
      ..color = goldBright);
    canvas.drawPath(pale, Paint()
      ..blendMode = blend
      ..color = dark ? const Color(0xFFFFF1B8) : const Color(0xFFFFE07A));
  }

  // Facing right in its own units: body, neck and head, antlers, and the legs at their point of the gallop.
  void _paintReindeer(Canvas canvas, Offset at, double heading, double unit, double beat, Paint fill, Paint line)
  {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(heading);
    canvas.scale(unit);

    canvas.drawPath(
      Path()
        ..addOval(Rect.fromCenter(center: Offset.zero, width: 20, height: 8.5))
        ..addOval(Rect.fromCenter(center: const Offset(6.5, -0.5), width: 9, height: 8))
        ..addPolygon(const [Offset(5.5, -2.5), Offset(11, -9.5), Offset(14, -8.5), Offset(10, 1.5)], true)
        ..addPolygon(const [Offset(-9.5, -2.5), Offset(-13.5, -4.5), Offset(-10.5, -0.2)], true)
        ..addPolygon(const [Offset(12.5, -11.5), Offset(11.2, -14.2), Offset(13.8, -12)], true),
      fill,
    );

    canvas.save();
    canvas.translate(14.6, -10);
    canvas.rotate(0.25);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 7.5, height: 4.2), fill);
    canvas.drawOval(Rect.fromCenter(center: const Offset(3.2, 0.6), width: 3.6, height: 2.8), fill);
    canvas.restore();

    line.strokeWidth = 1.0;
    canvas.drawPath(
      Path()
        ..moveTo(13.2, -12.5)
        ..lineTo(11, -16)
        ..lineTo(8.6, -19.5)
        ..moveTo(11.8, -14.9)
        ..lineTo(13.8, -18.4)
        ..moveTo(10, -17.4)
        ..lineTo(10.8, -20.6)
        ..moveTo(14.4, -12.7)
        ..lineTo(13.6, -16.6)
        ..lineTo(12.4, -20.2)
        ..moveTo(13.8, -15.4)
        ..lineTo(16, -17.6),
      line,
    );

    // The forelegs reach and gather, the hind pair half a beat behind.
    line.strokeWidth = 1.7;

    for (final (hip, step, reach) in [
      (const Offset(6, 3), beat, 0.45),
      (const Offset(7.5, 3), beat + 0.5, 0.45),
      (const Offset(-6.5, 2.5), beat + math.pi * 0.9, -0.35),
      (const Offset(-5, 2.8), beat + math.pi * 0.9 + 0.5, -0.35),
    ])
    {
      final double thigh = reach + 0.65 * math.sin(step);
      final double bend = reach > 0 ? -0.5 - 0.5 * math.cos(step) : 0.7 + 0.3 * math.cos(step);
      final Offset knee = hip + Offset(math.sin(thigh), math.cos(thigh)) * 5;
      final Offset hoof = knee + Offset(math.sin(thigh + bend), math.cos(thigh + bend)) * 5.2;

      canvas.drawPath(
        Path()
          ..moveTo(hip.dx, hip.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(hoof.dx, hoof.dy),
        line,
      );
    }

    canvas.restore();
  }

  // Runner curling up at the front, the sack, the body with its high curled back, Santa with the reins.
  void _paintSleigh(Canvas canvas, Offset at, double heading, double unit, Paint fill, Paint line)
  {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(heading);
    canvas.scale(unit);

    line.strokeWidth = 1.7;
    canvas.drawPath(
      Path()
        ..moveTo(-24, 9)
        ..lineTo(12, 9)
        ..quadraticBezierTo(19.5, 9, 19.5, 4)
        ..quadraticBezierTo(19.5, 0.5, 16, 1.4)
        ..moveTo(-15, 9)
        ..lineTo(-15, 5)
        ..moveTo(5, 9)
        ..lineTo(5, 5),
      line,
    );

    canvas.drawOval(Rect.fromCenter(center: const Offset(-12.5, -11.5), width: 10, height: 10), fill);
    canvas.drawPath(
      Path()
        ..moveTo(-20, 5.5)
        ..lineTo(10, 5.5)
        ..quadraticBezierTo(15.5, 5.5, 15.5, 0)
        ..lineTo(13.5, -3)
        ..lineTo(-12, -3)
        ..lineTo(-14.5, -10)
        ..quadraticBezierTo(-15.5, -14.5, -19.5, -13.5)
        ..quadraticBezierTo(-23, -12.5, -21, -8)
        ..close(),
      fill,
    );

    canvas.drawOval(Rect.fromCenter(center: const Offset(-2.5, -7.5), width: 10.5, height: 10.5), fill);
    canvas.drawCircle(const Offset(-0.8, -14.6), 3.5, fill);
    canvas.drawPath(
      Path()
        ..moveTo(-4.4, -15.8)
        ..lineTo(2.6, -16.6)
        ..quadraticBezierTo(-1.5, -21.5, -8.4, -20.4)
        ..close(),
      fill,
    );
    canvas.drawCircle(const Offset(-8.8, -20), 1.6, fill);
    line.strokeWidth = 2.2;
    canvas.drawLine(const Offset(0.5, -9.5), const Offset(9, -6), line);

    canvas.restore();
  }

  @override
  bool shouldRepaint(SleighPainter oldDelegate) => oldDelegate.flight != flight || oldDelegate.spec != spec;
}
