import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colours.dart';

// Launches, seconds from the start; the last two burst together as the finale.
const List<double> _launches = [0.15, 0.7, 1.2, 1.7, 2.25, 2.8, 3.3, 3.4];

// Draws for a burst point far enough from the last two.
const int _tries = 30;

// Burst colours for this backdrop; a shell keeps its index, so a backdrop change wraps it round.
List<(Color, Color)> _paletteFor(FireworksSpec spec) =>
    spec.hot ? [...AppTheme.fireworks, AppTheme.fireworksSilver] : AppTheme.fireworks;

class FireworksSpec
{
  final Size page;

  // Bursts land anywhere in here, far enough from its edges to show whole.
  final Rect area;

  // Rockets rise from this height.
  final double floor;

  // Sizes and spreads, 1 on a 1440 x 900 window.
  final double scale;

  // Where the sparks sit between the deep twin (0) and the bright one (1): deeper on light backdrops.
  final double ink;

  // Light that adds up where trails cross, as on a night sky; paint laid over on light pages.
  final bool additive;

  // Sparks born white-hot and glowing, a flash of light, silver among the colours: dark backdrops.
  final bool hot;

  // The phone in light mode, white cards on a dark sea: a deep stroke under a bright core reads sharp on both.
  // Plain paint on purpose: multiply and screen looked the same but made phones copy the screen for every draw.
  final bool twoTone;

  const FireworksSpec({
    required this.page,
    required this.area,
    required this.floor,
    required this.scale,
    required this.ink,
    required this.additive,
    required this.hot,
    this.twoTone = false,
  });

  // The page below the top bar; tuned on a 1440 x 900 window.
  factory FireworksSpec.desktop(Size page, Rect bar)
  {
    final bool dark = ThemeColours.isDark;

    return FireworksSpec(
      page: page,
      area: Rect.fromLTRB(0, bar.bottom + 10, page.width, page.height),
      floor: page.height + 20,
      scale: (page.width / 1440).clamp(0.8, 1.2),
      ink: dark ? 1 : 0.3,
      additive: dark,
      hot: dark,
    );
  }

  // The screen above the menu bar; tuned on a 393 x 852 phone, scaled up on tablets.
  factory FireworksSpec.mobile(Size page)
  {
    final bool dark = ThemeColours.isDark;

    return FireworksSpec(
      page: page,
      area: Rect.fromLTRB(0, page.height * 0.06, page.width, page.height * 0.88),
      floor: page.height + 20,
      scale: 0.72 * (page.shortestSide / 393).clamp(1.0, 1.5),
      ink: dark ? 1 : 0.5,
      additive: dark,
      hot: dark,
      twoTone: !dark,
    );
  }
}

class _Spark
{
  // Launch velocity, px/s.
  final double vx;
  final double vy;

  final double life;
  final double size;

  // Inner sparks take the shell's second colour.
  final bool inner;

  const _Spark(this.vx, this.vy, this.life, this.size, this.inner);
}

class _Shell
{
  final double launchAt;

  // Seconds from launch to burst, climbing from [from] to [at].
  final double rise;

  final Offset from;
  final Offset at;

  // The finale's gold willow droops and lingers; the others are round chrysanthemums.
  final bool willow;

  final int colour;
  final int second;

  final double drag;
  final double gravity;
  final double radius;

  // Trail length, as samples trailStep seconds apart.
  final int trail;
  final double trailStep;

  final List<_Spark> sparks;

  late final double end = launchAt +
      rise +
      sparks.fold<double>(0, (longest, spark) => math.max(longest, spark.life)) +
      trail * trailStep;

  _Shell({
    required this.launchAt,
    required this.rise,
    required this.from,
    required this.at,
    required this.willow,
    required this.colour,
    required this.second,
    required this.drag,
    required this.gravity,
    required this.radius,
    required this.trail,
    required this.trailStep,
    required this.sparks,
  });

  factory _Shell.make(
    math.Random random, {
    required double launchAt,
    required double rise,
    required Offset from,
    required Offset at,
    required bool willow,
    required int colour,
    required int second,
    required double radius,
    required double scale,
  })
  {
    final double drag = willow ? 1.5 : 2.3;
    final double life = willow ? 2.5 : 1.55;
    // Speed that settles at radius once drag has eaten it.
    final double speed = radius * drag;
    final List<_Spark> sparks = [];

    void add(double dx, double dy, double share, bool inner)
    {
      final double v = speed * share * (1 + (random.nextDouble() * 2 - 1) * 0.06);

      sparks.add(
        _Spark(
          dx * v,
          dy * v,
          life * (0.91 + random.nextDouble() * 0.18),
          (willow ? 1.0 : 1.25) * scale.clamp(0.75, 1.2) * (0.85 + random.nextDouble() * 0.3),
          inner,
        ),
      );
    }

    // Directions on a sphere seen from afar: denser towards the middle, like a real shell.
    for (var i = 0; i < (willow ? 86 : 130); i++)
    {
      final double z = random.nextDouble() * 2 - 1;
      final double phi = random.nextDouble() * 2 * math.pi;
      final double r = math.sqrt(1 - z * z);

      add(r * math.cos(phi), r * math.sin(phi), 1, false);
    }

    if (!willow)
    {
      // A small core of the second colour.
      for (var i = 0; i < 35; i++)
      {
        final double phi = random.nextDouble() * 2 * math.pi;

        add(math.cos(phi), math.sin(phi), 0.4 + random.nextDouble() * 0.15, true);
      }
    }

    return _Shell(
      launchAt: launchAt,
      rise: rise,
      from: from,
      at: at,
      willow: willow,
      colour: colour,
      second: second,
      drag: drag,
      gravity: (willow ? 150 : 70) * scale,
      radius: radius,
      trail: willow ? 12 : 8,
      trailStep: willow ? 0.055 : 0.04,
      sparks: sparks,
    );
  }

  // Linear drag and gravity, solved: the position at any moment comes from t alone.
  Offset sparkAt(_Spark spark, double t)
  {
    final double fade = (1 - math.exp(-drag * t)) / drag;

    return Offset(
      at.dx + spark.vx * fade,
      at.dy + spark.vy * fade + gravity / drag * (t - fade),
    );
  }

  // The rocket climbs fast and slows into the burst, swaying a little.
  Offset rocketAt(double u)
  {
    final double eased = 1 - math.pow(1 - u.clamp(0.0, 1.0), 2.2).toDouble();
    final double sway = math.sin(u * math.pi * 3 + colour) * 2.5;

    return Offset(
      from.dx + (at.dx - from.dx) * eased + sway,
      from.dy + (at.dy - from.dy) * eased,
    );
  }
}

// Eight shells at random points of the area, each clear of the last two, in random colours.
List<_Shell> _plan(FireworksSpec spec, math.Random random)
{
  final Rect area = spec.area;
  final double s = spec.scale;
  final int colours = _paletteFor(spec).length;
  final List<_Shell> shells = [];

  double jitter(double amount) => (random.nextDouble() * 2 - 1) * amount;

  int pick(Set<int> avoid)
  {
    while (true)
    {
      final int colour = random.nextInt(colours);

      if (!avoid.contains(colour))
      {
        return colour;
      }
    }
  }

  // Whole bursts: the sparks droop, so more room below than above; a window too small gets its middle.
  Offset place(double radius)
  {
    final Rect room = Rect.fromLTRB(
      area.left + radius * 0.75,
      area.top + radius * 0.75,
      area.right - radius * 0.75,
      area.bottom - radius,
    );
    Offset best = area.center;
    double bestGap = -1;

    for (var k = 0; k < _tries; k++)
    {
      final Offset point = Offset(
        room.width > 0 ? room.left + random.nextDouble() * room.width : area.center.dx,
        room.height > 0 ? room.top + random.nextDouble() * room.height : area.center.dy,
      );
      // Distance to the nearest of the last two bursts, in their combined radii.
      double gap = double.infinity;

      for (final shell in shells.reversed.take(2))
      {
        gap = math.min(gap, (point - shell.at).distance / (shell.radius + radius));
      }

      if (gap > bestGap)
      {
        best = point;
        bestGap = gap;
      }

      if (gap >= 0.9)
      {
        break;
      }
    }

    return best;
  }

  var colour = -1;

  for (var i = 0; i < _launches.length; i++)
  {
    final bool finale = i >= _launches.length - 2;
    final double radius = (finale ? 175 : 125 + random.nextDouble() * 40) * s;
    final Offset at = place(radius);
    // Lower bursts climb for less time.
    final double climb = ((spec.floor - at.dy) / spec.page.height).clamp(0.0, 1.2);

    // The burst beside the gold willow takes another colour.
    colour = pick({colour, if (i == _launches.length - 2) AppTheme.fireworks.indexOf(AppTheme.fireworksGold)});

    shells.add(
      // Its own draws: the sparks' count never moves where the next shell bursts.
      _Shell.make(
        math.Random(random.nextInt(1 << 30)),
        launchAt: _launches[i] + jitter(0.06),
        rise: 0.55 + 0.55 * climb + random.nextDouble() * 0.1,
        from: Offset(at.dx + jitter(60 * s), spec.floor),
        at: at,
        willow: i == _launches.length - 1,
        colour: colour,
        second: pick({colour}),
        radius: radius,
        scale: s,
      ),
    );
  }

  return shells;
}

// Each burst's spread and colour index, for tests.
@visibleForTesting
List<(Rect, int)> fireworkBursts(FireworksSpec spec, math.Random random) =>
    [for (final shell in _plan(spec, random)) (Rect.fromCircle(center: shell.at, radius: shell.radius), shell.colour)];

// Own ticker so the clock survives a page change; everything derives from elapsed alone.
class FireworksShow extends ChangeNotifier
{
  // Asked on every tick: true ends the show early.
  final bool Function()? shouldEnd;

  // The same seed draws the same show again when the window changes size.
  final int seed;

  late final Ticker _ticker;

  double elapsed = 0;
  bool done = false;

  Size? _plannedPage;
  Rect? _plannedArea;
  List<_Shell> _shells = const [];
  double _length = double.infinity;

  FireworksShow({this.shouldEnd, int? seed}) : seed = seed ?? math.Random().nextInt(1 << 30)
  {
    _ticker = Ticker(_onTick)..start();
  }

  List<_Shell> _planFor(FireworksSpec spec)
  {
    if (spec.page != _plannedPage || spec.area != _plannedArea)
    {
      _plannedPage = spec.page;
      _plannedArea = spec.area;
      _shells = _plan(spec, math.Random(seed));
      _length = _shells.fold<double>(0, (last, shell) => math.max(last, shell.end));
    }

    return _shells;
  }

  // Ticks run before build, so a host handing over within one frame is never missed.
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

class FireworksPainter extends CustomPainter
{
  final FireworksShow show;
  final FireworksSpec spec;

  FireworksPainter({required this.show, required this.spec}) : super(repaint: show);

  @override
  void paint(Canvas canvas, Size size)
  {
    final double now = show.elapsed;
    final List<(Color, Color)> palette = _paletteFor(spec);
    final double s = spec.scale.clamp(0.75, 1.2);

    for (final shell in show._planFor(spec))
    {
      final double t = now - shell.launchAt;

      if (t < 0 || now > shell.end)
      {
        continue;
      }

      if (t < shell.rise)
      {
        _paintRocket(canvas, shell, t, AppTheme.fireworksGold, s);

        continue;
      }

      final double tb = t - shell.rise;
      final (Color deep, Color bright) = shell.willow ? AppTheme.fireworksGold : palette[shell.colour % palette.length];
      final (Color secondDeep, Color secondBright) = palette[shell.second % palette.length];

      _paintFlash(canvas, shell, tb, bright);
      _paintSparks(canvas, shell, tb, (deep, bright), (secondDeep, secondBright));
    }
  }

  // Hairline trails in a soft halo, newborn sparks glowing white on dark backdrops; two-tone trails bare.
  void _paintSparks(Canvas canvas, _Shell shell, double tb, (Color, Color) first, (Color, Color) second)
  {
    final BlendMode blend = spec.additive ? BlendMode.plus : BlendMode.srcOver;
    final _Strips halos = _Strips();
    final _Strips lines = _Strips();
    final _Strips shades = _Strips();
    final _Strips cores = _Strips();
    final _Dots glows = _Dots();
    final _Dots heads = _Dots();
    final double tailLength = shell.trail * shell.trailStep;

    for (final spark in shell.sparks)
    {
      if (tb - tailLength > spark.life)
      {
        continue;
      }

      // A spent spark stops; its trail runs out behind it.
      final double head = math.min(tb, spark.life);
      final double gone = tb > spark.life ? (tb - spark.life) / tailLength : 0;
      final double alpha = _alpha(spark, head) * (1 - gone);

      if (alpha <= 0.01)
      {
        continue;
      }

      final (Color, Color) pair = spark.inner ? second : first;
      final Color colour = Color.lerp(pair.$1, pair.$2, spec.ink)!;
      final double radius = spark.size * (1 - 0.3 * head / spark.life);
      final List<Offset> points = [
        for (var j = 0; j <= shell.trail; j++) shell.sparkAt(spark, math.max(0, head - j * shell.trailStep)),
      ];

      if (spec.twoTone)
      {
        // No bead at the head: the trail's widest end is the spark.
        shades.add(points, radius * 1.5, Color.lerp(pair.$1, pair.$2, 0.15)!, alpha);
        cores.add(points, radius, pair.$2, alpha);

        continue;
      }

      halos.add(points, radius * 5.5, colour, (spec.hot ? 0.13 : 0.1) * alpha);
      lines.add(points, radius * 1.3, colour, 0.95 * alpha);

      if (gone > 0)
      {
        continue;
      }

      // In quarters, so heads cooling together share a path.
      final double heat = spec.hot ? ((1 - head / 0.4).clamp(0.0, 1.0) * 4).round() / 4 : 0;

      if (heat > 0)
      {
        glows.add(points.first, radius * 4, colour.withValues(alpha: 0.25 * alpha * heat));
      }

      heads.add(points.first, radius * 0.9, Color.lerp(colour, Colors.white, heat * 0.85)!.withValues(alpha: alpha));
    }

    glows.paint(canvas, BlendMode.plus);
    heads.paint(canvas, blend);
    halos.paint(canvas, blend);
    lines.paint(canvas, blend);
    shades.paint(canvas, BlendMode.srcOver);
    cores.paint(canvas, BlendMode.srcOver);
  }

  double _alpha(_Spark spark, double t)
  {
    final double settle = spark.life * 0.55;
    final double fade = t < settle ? 1 : math.pow(1 - (t - settle) / (spark.life - settle), 1.3).toDouble();

    // Out of the flash: bunched together at the burst the sparks would read as a blot.
    return (fade * Curves.easeIn.transform((t / 0.07).clamp(0.0, 1.0))).clamp(0.0, 1.0);
  }

  // A short tapering comet, the last tenth of a second of its climb.
  void _paintRocket(Canvas canvas, _Shell shell, double t, (Color, Color) gold, double s)
  {
    final (Color deep, Color bright) = gold;
    final Color colour = Color.lerp(deep, bright, spec.ink)!;
    final _Strips trail = _Strips();
    final List<Offset> points = [
      for (var j = 0; j <= 8; j++) shell.rocketAt(math.max(0, t - j * 0.018) / shell.rise),
    ];

    trail.add(points, 1.5 * s, colour, 0.9);
    trail.paint(canvas, spec.additive ? BlendMode.plus : BlendMode.srcOver);
    canvas.drawCircle(points.first, 1.1 * s, Paint()..color = spec.additive ? Colors.white : colour);
  }

  void _paintFlash(Canvas canvas, _Shell shell, double tb, Color bright)
  {
    final double span = spec.hot ? 0.9 : 0.5;

    if (tb > span)
    {
      return;
    }

    final double grow = Curves.easeOut.transform((tb / 0.3).clamp(0.0, 1.0));
    final double fade = tb < 0.06 ? tb / 0.06 : math.pow(1 - ((tb - 0.06) / (span - 0.06)).clamp(0.0, 1.0), 1.6).toDouble();
    final double radius = shell.radius * (spec.hot ? 0.3 + 0.55 * grow : 0.25 + 0.3 * grow);
    final Color colour = Color.lerp(bright, Colors.white, spec.hot ? 0.5 : 0.0)!;

    canvas.drawCircle(
      shell.at,
      radius,
      Paint()
        ..blendMode = spec.hot ? BlendMode.plus : BlendMode.srcOver
        ..shader = RadialGradient(
          colors: [colour.withValues(alpha: (spec.hot ? 0.19 : 0.18) * fade), colour.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: shell.at, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(FireworksPainter old) => old.show != show || old.spec != spec;
}

// Tapering trails as antialiased shapes (vertices are drawn without antialiasing): each trail is cut in three
// stretches of falling alpha, and stretches of one colour and alpha share a path, so overlaps never darken twice
// and a shell costs a handful of draws.
class _Strips
{
  // Where the stretches end, as shares of the trail, and how much of the spark's alpha each keeps.
  static const List<double> _cuts = [0.0, 0.3, 0.6, 1.0];
  static const List<double> _fades = [1.0, 0.55, 0.22];

  final Map<int, Path> _paths = {};

  void add(List<Offset> points, double width, Color colour, double alpha)
  {
    final int n = points.length - 1;
    final List<Offset> left = [];
    final List<Offset> right = [];

    for (var j = 0; j <= n; j++)
    {
      final Offset along = points[math.max(0, j - 1)] - points[math.min(n, j + 1)];
      final double length = along.distance;
      final Offset normal = length < 0.001 ? Offset.zero : Offset(-along.dy, along.dx) / length;
      final double half = width * (1 - j / n) / 2;

      left.add(points[j] + normal * half);
      right.add(points[j] - normal * half);
    }

    for (var k = 0; k < _fades.length; k++)
    {
      final int from = (_cuts[k] * n).round();
      final int to = (_cuts[k + 1] * n).round();
      // Alpha in twelfths, so sparks fading together share a path.
      final int level = (alpha * _fades[k] * 12).round();

      if (to <= from || level == 0)
      {
        continue;
      }

      _paths.putIfAbsent(colour.withValues(alpha: level / 12).toARGB32(), Path.new).addPolygon([
        for (var j = from; j <= to; j++) left[j],
        for (var j = to; j >= from; j--) right[j],
      ], true);
    }
  }

  void paint(Canvas canvas, BlendMode blend)
  {
    for (final MapEntry(key: argb, value: path) in _paths.entries)
    {
      canvas.drawPath(path, Paint()..color = Color(argb)..blendMode = blend);
    }
  }
}

// Heads and glows gathered the same way: one path per colour and alpha, not a draw per spark.
class _Dots
{
  final Map<int, Path> _paths = {};

  void add(Offset centre, double radius, Color colour)
  {
    // Alpha in twelfths, so dots fading together share a path.
    final int level = (colour.a * 12).round();

    if (level == 0)
    {
      return;
    }

    _paths
        .putIfAbsent(colour.withValues(alpha: level / 12).toARGB32(), Path.new)
        .addOval(Rect.fromCircle(center: centre, radius: radius));
  }

  void paint(Canvas canvas, BlendMode blend)
  {
    for (final MapEntry(key: argb, value: path) in _paths.entries)
    {
      canvas.drawPath(path, Paint()..color = Color(argb)..blendMode = blend);
    }
  }
}
