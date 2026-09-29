import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_theme.dart';

const int kConfettiCount = 140;

// Seconds over which the pieces keep coming out.
const double kConfettiPour = 3.0;

// Fall speed, px/s.
const double kConfettiSlowest = 110;
const double kConfettiFastest = 230;

const List<Color> _colors = [
  AppTheme.trialTurquoise,
  AppTheme.trialGold,
  AppTheme.trialViolet,
  AppTheme.trialTealDeep,
  AppTheme.trialDangerLight,
  AppTheme.trialSeaGreen,
];

// Own ticker so the clock survives a page change; positions derive from elapsed alone.
class ConfettiShower extends ChangeNotifier
{
  final List<ConfettiPiece> pieces;

  // Asked on every tick: true ends the shower early.
  final bool Function()? shouldEnd;

  late final Ticker _ticker;

  double elapsed = 0;
  bool done = false;

  // Longest fall painted so far; the shower ends once the slowest piece has landed it.
  double _drop = 0;

  ConfettiShower({List<ConfettiPiece>? pieces, this.shouldEnd})
      : pieces = pieces ?? List.generate(kConfettiCount, (_) => ConfettiPiece.random(math.Random()))
  {
    _ticker = Ticker(_onTick)..start();
  }

  void noteDrop(double drop)
  {
    if (drop > _drop)
    {
      _drop = drop;
    }
  }

  // Ticks run before build, so a host handing over within one frame is never missed.
  void _onTick(Duration since)
  {
    elapsed = since.inMicroseconds / Duration.microsecondsPerSecond;

    final bool landed = _drop > 0 && elapsed > kConfettiPour + _drop / kConfettiSlowest + 1;

    if (landed || (shouldEnd?.call() ?? false))
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

class ConfettiPiece
{
  // Start position, as fractions of the source rect.
  final double across;
  final double down;

  final double delay;
  final double speed;

  // Sideways: a steady drift plus a sway, px/s and px.
  final double drift;
  final double sway;
  final double swayRate;

  // In-plane spin and the tumble around its own axis, rad/s.
  final double spin;
  final double flip;
  final double phase;

  final Size size;
  final Color color;
  final bool round;

  const ConfettiPiece({
    required this.across,
    required this.down,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.sway,
    required this.swayRate,
    required this.spin,
    required this.flip,
    required this.phase,
    required this.size,
    required this.color,
    required this.round,
  });

  factory ConfettiPiece.random(math.Random random)
  {
    final bool round = random.nextDouble() < 0.25;
    final double width = round ? 6 + random.nextDouble() * 3 : 6 + random.nextDouble() * 4;

    return ConfettiPiece(
      across: random.nextDouble(),
      // Middle band of the source, hidden behind it at first.
      down: 0.35 + random.nextDouble() * 0.3,
      delay: random.nextDouble() * kConfettiPour,
      speed: kConfettiSlowest + random.nextDouble() * (kConfettiFastest - kConfettiSlowest),
      drift: (random.nextDouble() - 0.5) * 40,
      sway: 10 + random.nextDouble() * 25,
      swayRate: 1.5 + random.nextDouble() * 2,
      spin: (random.nextDouble() - 0.5) * 6,
      flip: 3 + random.nextDouble() * 5,
      phase: random.nextDouble() * 2 * math.pi,
      size: Size(width, round ? width : 10 + random.nextDouble() * 6),
      color: _colors[random.nextInt(_colors.length)],
      round: round,
    );
  }
}

class ConfettiPainter extends CustomPainter
{
  final ConfettiShower shower;

  // Where the pieces come from, in the painter's coordinates.
  final Rect source;

  ConfettiPainter({required this.shower, required this.source}) : super(repaint: shower);

  @override
  void paint(Canvas canvas, Size size)
  {
    final double now = shower.elapsed;
    final Paint paint = Paint();

    for (final piece in shower.pieces)
    {
      final double t = now - piece.delay;

      if (t < 0)
      {
        continue;
      }

      final double y = source.top + piece.down * source.height + piece.speed * t;

      if (y - piece.size.longestSide > size.height)
      {
        continue;
      }

      // The sway is zeroed at t = 0 so the piece starts inside the source.
      final double x = source.left +
          piece.across * source.width +
          piece.drift * t +
          piece.sway * (math.sin(piece.swayRate * t + piece.phase) - math.sin(piece.phase));

      // Y-scale by the tumble fakes a 3D flip; clamped so the strip never vanishes.
      final double tumble = math.cos(piece.flip * t + piece.phase);

      paint.color = piece.color;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * t + piece.phase);
      canvas.scale(1, tumble.abs() < 0.05 ? 0.05 : tumble);

      final Rect rect = Rect.fromCenter(
        center: Offset.zero,
        width: piece.size.width,
        height: piece.size.height,
      );

      if (piece.round)
      {
        canvas.drawOval(rect, paint);
      }
      else
      {
        canvas.drawRect(rect, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.shower != shower || old.source != source;
}
