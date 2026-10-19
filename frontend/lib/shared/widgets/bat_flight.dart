import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class BatFlightSpec
{
  final Size page;

  // The band the bats come out of, hidden behind it at first.
  final Rect source;

  // Where they wander before leaving.
  final Rect sky;

  // Stretch of the side walls they leave through.
  final double wallTop;
  final double wallBottom;

  final int count;
  final double minSpan;
  final double maxSpan;
  final double minSpeed;
  final double maxSpeed;

  // Seconds before the first bat is out and over which the rest follow.
  final double delay;
  final double pour;

  // The bats leave one by one over this window.
  final double firstExit;
  final double lastExit;
  final double minFlight;

  // Turns tighter than turnRadius slow a bat down; a flight with one under minRadius is redrawn.
  final double turnRadius;
  final double minRadius;

  // Legs of the wander, as shares of the sky's shorter side.
  final double minLeg;
  final double maxLeg;

  // Closer than this, two bats flying the same way read as a group.
  final double companyDistance;

  const BatFlightSpec({
    required this.page,
    required this.source,
    required this.sky,
    required this.wallTop,
    required this.wallBottom,
    required this.count,
    required this.minSpan,
    required this.maxSpan,
    required this.minSpeed,
    required this.maxSpeed,
    required this.delay,
    required this.pour,
    required this.firstExit,
    required this.lastExit,
    required this.minFlight,
    required this.turnRadius,
    required this.minRadius,
    required this.minLeg,
    required this.maxLeg,
    required this.companyDistance,
  });

  // Out from under the top bar; tuned on a 1440 x 900 window.
  factory BatFlightSpec.desktop(Size page, Rect bar)
  {
    return BatFlightSpec(
      page: page,
      source: bar,
      sky: Rect.fromLTRB(
        page.width * 0.0625,
        bar.bottom + 50,
        page.width * 0.9375,
        math.max(bar.bottom + 200, page.height * 0.845),
      ),
      wallTop: bar.bottom + 40,
      wallBottom: math.max(bar.bottom + 240, page.height * 0.945),
      count: (page.width / 100).round().clamp(8, 16),
      minSpan: 28,
      maxSpan: 66,
      minSpeed: 300,
      maxSpeed: 430,
      delay: 0.3,
      pour: 1.3,
      firstExit: 2.6,
      lastExit: 6.0,
      minFlight: 2.0,
      turnRadius: 110,
      minRadius: 45,
      minLeg: 0.35,
      maxLeg: 0.6,
      companyDistance: 130,
    );
  }

  // In from above the screen; tuned on a 393 x 852 phone, scaled up on tablets.
  factory BatFlightSpec.mobile(Size page)
  {
    final double scale = (page.shortestSide / 393).clamp(1.0, 1.5);

    return BatFlightSpec(
      page: page,
      source: Rect.fromLTRB(0, -70, page.width, -10),
      sky: Rect.fromLTRB(page.width * 0.076, page.height * 0.105, page.width * 0.924, page.height * 0.73),
      wallTop: page.height * 0.06,
      wallBottom: page.height * 0.82,
      count: page.shortestSide < 600 ? 9 : 12,
      minSpan: 24 * scale,
      maxSpan: 52 * scale,
      minSpeed: 200 * scale,
      maxSpeed: 280 * scale,
      delay: 0.3,
      pour: 1.1,
      firstExit: 2.4,
      lastExit: 5.4,
      minFlight: 1.9,
      turnRadius: 60 * scale,
      minRadius: 28 * scale,
      minLeg: 0.45,
      maxLeg: 0.8,
      companyDistance: 80 * scale,
    );
  }
}

class FlyingBat
{
  final double start;
  final double duration;

  // Wingspan; nearer bats are bigger, darker and faster.
  final double span;
  final double depth;

  final double flapRate;
  final double flapPhase;

  // The flight as a dense polyline: share of the flight time and heading at each point.
  final List<Offset> track;
  final List<double> progress;
  final List<double> headings;

  const FlyingBat({
    required this.start,
    required this.duration,
    required this.span,
    required this.depth,
    required this.flapRate,
    required this.flapPhase,
    required this.track,
    required this.progress,
    required this.headings,
  });

  double get end => start + duration;

  // Position and lean [t] seconds after the flock set off; null before take-off and once gone.
  (Offset, double)? at(double t)
  {
    final double share = (t - start) / duration;

    if (share <= 0 || share >= 1)
    {
      return null;
    }

    var low = 0;
    var high = progress.length - 1;

    while (high - low > 1)
    {
      final int mid = (low + high) >> 1;

      if (progress[mid] <= share)
      {
        low = mid;
      }
      else
      {
        high = mid;
      }
    }

    final double piece = progress[high] - progress[low];
    final double f = piece == 0 ? 0 : (share - progress[low]) / piece;
    final double heading = headings[low] + _wrap(headings[high] - headings[low]) * f;

    return (Offset.lerp(track[low], track[high], f)!, 0.2 * math.cos(heading));
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _wrap(double angle)
{
  var a = angle;

  while (a > math.pi)
  {
    a -= 2 * math.pi;
  }

  while (a < -math.pi)
  {
    a += 2 * math.pi;
  }

  return a;
}

// Uniform cubic B-spline: curvature never jumps, and the curve stays inside its control points.
Offset _bspline(Offset a, Offset b, Offset c, Offset d, double u)
{
  final double u2 = u * u;
  final double u3 = u2 * u;

  return a * ((1 - u) * (1 - u) * (1 - u) / 6) +
      b * ((3 * u3 - 6 * u2 + 4) / 6) +
      c * ((-3 * u3 + 3 * u2 + 3 * u + 1) / 6) +
      d * (u3 / 6);
}

const double _trailStep = 0.05;

const int _samplesPerSpan = 40;

// Positions every _trailStep seconds from the flock's start, for comparing bats cheaply.
List<Offset?> _trail(FlyingBat bat)
{
  return [
    for (var k = 0; k * _trailStep < bat.end + _trailStep; k++) bat.at(k * _trailStep)?.$1,
  ];
}

// Each bat dives out, wanders, then leaves alone: its own wall, height and moment.
List<FlyingBat> planBats(BatFlightSpec spec, math.Random r)
{
  Offset towards(double angle, double length) => Offset(math.cos(angle), math.sin(angle)) * length;

  List<double> spread(int n, double from, double to) =>
      [for (var k = 0; k < n; k++) _lerp(from, to, (k + r.nextDouble()) / n)]..shuffle(r);

  // A dive, a meandering walk about [length] long, then out through the wall at [y].
  List<Offset> controlsFrom(Offset p0, bool left, double y, double length)
  {
    final double side = left ? -1 : 1;
    final double edge = left ? 0 : spec.page.width;
    final double scale = spec.sky.shortestSide;
    final Offset approach = Offset(edge - side * 0.07 * spec.page.width, y);
    final Offset exit = Offset(edge + side * spec.maxSpan * 2, y + _lerp(-0.06, 0.06, r.nextDouble()) * spec.page.height);
    final Offset onward = (exit - approach) / (exit - approach).distance;
    var heading = math.pi / 2 + _lerp(-0.6, 0.6, r.nextDouble());
    final List<Offset> path = [
      p0,
      p0 + towards(heading, (spec.sky.top - p0.dy) + _lerp(0.05, 0.25, r.nextDouble()) * scale),
    ];
    var walked = (path[1] - p0).distance;

    while (path.length < 8 && walked + (approach - path.last).distance < length - spec.minLeg * scale * 0.5)
    {
      Offset next = path.last;

      for (var attempt = 0; attempt < 30; attempt++)
      {
        // A random swerve, widened when the walk keeps hitting the edges.
        final double angle = heading + _lerp(-1.3, 1.3, r.nextDouble()) * (1 + attempt / 10);
        final Offset candidate = path.last + towards(angle, _lerp(spec.minLeg, spec.maxLeg, r.nextDouble()) * scale);

        if (spec.sky.contains(candidate))
        {
          next = candidate;
          heading = angle;
          break;
        }
      }

      if (next == path.last)
      {
        next = Offset.lerp(path.last, spec.sky.center, 0.6)!;
        heading = math.atan2(next.dy - path.last.dy, next.dx - path.last.dx);
      }

      walked += (next - path.last).distance;
      path.add(next);
    }

    // The way out behind the bat: one more stop swinging round towards it keeps the turn wide.
    final double behind = _wrap(math.atan2(approach.dy - path.last.dy, approach.dx - path.last.dx) - heading);

    if (behind.abs() > 1.6)
    {
      final Offset round = path.last + towards(heading + behind.sign * 1.4, 0.45 * scale);

      path.add(Offset(round.dx.clamp(spec.sky.left, spec.sky.right), round.dy.clamp(spec.sky.top, spec.sky.bottom)));
    }

    // The start three times over, so the curve begins on it.
    return [
      p0,
      p0,
      ...path,
      approach,
      exit,
      exit + onward * (spec.page.width * 0.3),
      exit + onward * (spec.page.width * 0.6),
    ];
  }

  final int count = spec.count;
  final int half = count ~/ 2;
  final List<int> slots = List<int>.generate(count, (i) => i)..shuffle(r);

  // Each half of the source sends as many bats out on the left as on the right.
  final List<bool> fromLeft = [for (var k = 0; k < half; k++) k.isEven]..shuffle(r);
  final List<bool> fromRight = [for (var k = 0; k < count - half; k++) k.isOdd]..shuffle(r);
  final List<bool> exitLeft = [
    for (final slot in slots) slot < half ? fromLeft[slot] : fromRight[slot - half],
  ];

  final List<double> leftHeights = spread(exitLeft.where((left) => left).length, spec.wallTop, spec.wallBottom);
  final List<double> rightHeights = spread(exitLeft.where((left) => !left).length, spec.wallTop, spec.wallBottom);
  var leftUsed = 0;
  var rightUsed = 0;
  final List<double> heights = [
    for (final left in exitLeft) left ? leftHeights[leftUsed++] : rightHeights[rightUsed++],
  ];
  final List<double> takeOffs = spread(count, spec.delay, spec.delay + spec.pour);
  final List<double> leavings = spread(count, spec.firstExit, spec.lastExit);
  final List<double> depths = [for (var i = 0; i < count; i++) (i + r.nextDouble()) / count];
  final List<double> spans = [for (final depth in depths) _lerp(spec.minSpan, spec.maxSpan, depth)];
  final List<double> speeds = [for (final depth in depths) _lerp(spec.minSpeed, spec.maxSpeed, depth)];
  final List<double> xs = [
    for (var i = 0; i < count; i++)
      _lerp(spec.source.left + spans[i], spec.source.right - spans[i], (slots[i] + r.nextDouble()) / count),
  ];

  // Shortest flight each bat can make: down out of the source, then across to its wall.
  final List<double> needs = [
    for (var i = 0; i < count; i++)
      math.max(
        spec.minFlight,
        ((spec.sky.top - spec.source.center.dy) +
                (Offset(exitLeft[i] ? 0 : spec.page.width, heights[i]) - Offset(xs[i], spec.sky.top)).distance) /
            speeds[i],
      ),
  ];

  bool fits(int bat, double leaving) => leaving - takeOffs[bat] >= needs[bat];

  // Short flights go to the bats that can make them.
  for (var tries = 0; tries < 2000; tries++)
  {
    final int bad = List<int>.generate(count, (i) => i).firstWhere((i) => !fits(i, leavings[i]), orElse: () => -1);

    if (bad < 0)
    {
      break;
    }

    final int other = r.nextInt(count);

    if (fits(bad, leavings[other]) && fits(other, leavings[bad]) || tries > 1500)
    {
      final double swapped = leavings[bad];

      leavings[bad] = leavings[other];
      leavings[other] = swapped;
    }
  }

  final List<FlyingBat> bats = [];
  final List<List<Offset?>> trails = [];

  for (var i = 0; i < count; i++)
  {
    final Offset p0 = Offset(xs[i], spec.source.center.dy);
    final double duration = math.max(leavings[i] - takeOffs[i], needs[i]);
    FlyingBat? chosen;
    List<Offset?>? chosenTrail;
    var chosenFlaw = double.infinity;

    // A draw that folds back somewhere in sight, or keeps company with another bat, is drawn again.
    for (var tries = 0; tries < 30 && chosenFlaw > 0; tries++)
    {
      final List<Offset> controls = controlsFrom(p0, exitLeft[i], heights[i], duration * speeds[i]);
      final List<Offset> track = [];

      for (var k = 0; k + 3 < controls.length; k++)
      {
        for (var s = 0; s < _samplesPerSpan; s++)
        {
          track.add(_bspline(controls[k], controls[k + 1], controls[k + 2], controls[k + 3], s / _samplesPerSpan));
        }
      }

      final int gone = track.indexWhere((p) => p.dx < -spans[i] || p.dx > spec.page.width + spans[i]);
      final List<Offset> flight = track.sublist(0, gone < 0 ? track.length : gone + 1);
      final List<double> headings = [
        for (var k = 0; k < flight.length; k++)
          _heading(flight[math.min(k + 1, flight.length - 1)] - flight[math.max(k - 1, 0)]),
      ];

      // Slower in tight turns, as bats are: time per step grows as the radius shrinks.
      final List<double> slowness = [1];
      var tightest = double.infinity;

      for (var k = 1; k < flight.length; k++)
      {
        final double bend = _wrap(headings[k] - headings[k - 1]).abs();
        final double radius = bend == 0 ? double.infinity : (flight[k] - flight[k - 1]).distance / bend;

        if (flight[k].dy > spec.source.bottom)
        {
          tightest = math.min(tightest, radius);
        }

        slowness.add(radius.isInfinite ? 1 : 1 / (1 - 0.45 * spec.turnRadius / (radius + spec.turnRadius)));
      }

      final List<double> times = [0];

      for (var k = 1; k < flight.length; k++)
      {
        var sum = 0.0;
        var n = 0;

        for (var w = math.max(1, k - 3); w <= math.min(flight.length - 1, k + 3); w++)
        {
          sum += slowness[w];
          n++;
        }

        times.add(times.last + (flight[k] - flight[k - 1]).distance * sum / n);
      }

      // The pace stays near the bat's own, even if that moves its moment a little.
      final double natural = times.last / speeds[i];
      final FlyingBat candidate = FlyingBat(
        start: takeOffs[i],
        duration: duration.clamp(natural / 1.15, natural / 0.8),
        span: spans[i],
        depth: depths[i],
        flapRate: _lerp(5.2, 3.8, depths[i]),
        flapPhase: r.nextDouble(),
        track: flight,
        progress: [for (final t in times) t / times.last],
        headings: headings,
      );
      final List<Offset?> trail = _trail(candidate);
      final double flaw = (tightest < spec.minRadius ? 100 : 0) + math.max(0, _company(trail, trails, spec) - 0.3);

      if (flaw < chosenFlaw)
      {
        chosenFlaw = flaw;
        chosen = candidate;
        chosenTrail = trail;
      }
    }

    bats.add(chosen!);
    trails.add(chosenTrail!);
  }

  // Far bats first, so the near ones fly over them.
  return bats..sort((a, b) => a.depth.compareTo(b.depth));
}

double _heading(Offset d) => d == Offset.zero ? math.pi / 2 : math.atan2(d.dy, d.dx);

// Seconds [trail] spends close beside one of [others], flying the same way.
double _company(List<Offset?> trail, List<List<Offset?>> others, BatFlightSpec spec)
{
  var seconds = 0.0;

  for (final other in others)
  {
    final int steps = math.min(trail.length, other.length) - 1;

    for (var k = 0; k < steps; k++)
    {
      final Offset? a = trail[k];
      final Offset? b = other[k];
      final Offset? a2 = trail[k + 1];
      final Offset? b2 = other[k + 1];

      if (a == null || b == null || a2 == null || b2 == null || (a - b).distance > spec.companyDistance)
      {
        continue;
      }

      if (_wrap(_heading(a2 - a) - _heading(b2 - b)).abs() < 0.8)
      {
        seconds += _trailStep;
      }
    }
  }

  return seconds;
}

// Own ticker so the clock survives a page change; the flock is planned at its first layout.
class BatFlight extends ChangeNotifier
{
  final bool Function()? shouldEnd;

  final math.Random _random;

  late final Ticker _ticker;

  List<FlyingBat>? _bats;

  double elapsed = 0;
  bool done = false;

  BatFlight({this.shouldEnd, math.Random? random}) : _random = random ?? math.Random()
  {
    _ticker = Ticker(_onTick)..start();
  }

  List<FlyingBat> planFor(BatFlightSpec spec) => _bats ??= planBats(spec, _random);

  void _onTick(Duration since)
  {
    elapsed = since.inMicroseconds / Duration.microsecondsPerSecond;

    final List<FlyingBat>? bats = _bats;

    // Never laid out, it has nowhere to fly.
    final bool over = bats == null ? elapsed > 1 : bats.every((bat) => elapsed >= bat.end);

    if (over || (shouldEnd?.call() ?? false))
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

// Right wing in a 100-unit wingspan: start point, then (control, end) pairs.
const Offset _wingStart = Offset(3, -5);
const List<(Offset, Offset)> _wingQuads = [
  (Offset(12, -16), Offset(22, -15)),
  (Offset(36, -17), Offset(50, -6)),
  (Offset(43, -3), Offset(40, 5)),
  (Offset(34, -1), Offset(28, 8)),
  (Offset(21, 2), Offset(15, 11)),
  (Offset(9, 5), Offset(4, 9)),
];

final List<Offset> _wingOutline = ()
{
  final List<Offset> points = [_wingStart];
  var from = _wingStart;

  for (final (control, to) in _wingQuads)
  {
    for (var k = 1; k <= 6; k++)
    {
      final double u = k / 6;
      final double v = 1 - u;

      points.add(from * (v * v) + control * (2 * v * u) + to * (u * u));
    }

    from = to;
  }

  return points;
}();

// Every part wound the same way, so the overlaps fill once under the nonzero rule.
void _addClockwise(Path path, List<Offset> points)
{
  var area = 0.0;

  for (var i = 0; i < points.length; i++)
  {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];

    area += a.dx * b.dy - b.dx * a.dy;
  }

  path.addPolygon(area >= 0 ? points : points.reversed.toList(), true);
}

// A bat seen from the front, 100 units across; [flap] runs from -1 (wings up) to 1 (down).
Path _batPath(double flap)
{
  final double bob = flap < 0 ? 0 : -2.5 * flap;
  final Path path = Path()
    ..addOval(Rect.fromCenter(center: Offset(0, 3 + bob), width: 13, height: 20))
    ..addOval(Rect.fromCircle(center: Offset(0, -9 + bob), radius: 7));

  for (final side in const [-1.0, 1.0])
  {
    _addClockwise(path, [
      Offset(side * 6.8, -10.5 + bob),
      Offset(side * 6.2, -21 + bob),
      Offset(side * 1.2, -14.5 + bob),
    ]);
    _addClockwise(path, [
      for (final p in _wingOutline)
        Offset(
          side * (4 + (p.dx - 4) * (1 - 0.12 * flap.abs())),
          p.dy + bob + (p.dx - 4) * (flap < 0 ? 0.7 : 0.38) * flap,
        ),
    ]);
  }

  return path;
}

class BatsPainter extends CustomPainter
{
  final BatFlight flight;
  final List<FlyingBat> bats;

  final Color far;
  final Color near;

  BatsPainter({required this.flight, required this.bats, required this.far, required this.near})
      : super(repaint: flight);

  @override
  void paint(Canvas canvas, Size size)
  {
    final double now = flight.elapsed;
    final Paint paint = Paint();

    for (final bat in bats)
    {
      final (Offset, double)? pose = bat.at(now);

      if (pose == null)
      {
        continue;
      }

      final double flap = math.sin(2 * math.pi * (bat.flapRate * (now - bat.start) + bat.flapPhase));
      final Offset at = pose.$1 + Offset(0, -0.05 * bat.span * flap);

      paint.color = Color.lerp(far, near, bat.depth)!;

      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(pose.$2);
      canvas.scale(bat.span / 100);
      canvas.drawPath(_batPath(flap), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BatsPainter old) => old.flight != flight || old.bats != bats || old.far != far || old.near != near;
}
