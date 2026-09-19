import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/birthday.dart';
import '../../features/auth/models/me_response.dart';
import 'page_transition.dart';

const int _count = 140;

// Seconds over which the pieces keep coming out.
const double _pour = 3.0;

// Fall speed, px/s.
const double _slowest = 110;
const double _fastest = 230;

const List<Color> _colors = [
  AppTheme.trialTurquoise,
  AppTheme.trialGold,
  AppTheme.trialViolet,
  AppTheme.trialTealDeep,
  AppTheme.trialDangerLight,
  AppTheme.trialSeaGreen,
];

// Confetti for whoever opens the app on their birthday: the pieces come out
// from under the top bar and fall to the foot of the page.
//
// There is one shower per launch, shared by every bar: a page change carries
// it on where it was, a page without a bar ends it for good.
class BirthdayConfetti extends StatefulWidget
{
  final MeResponse user;

  // Where the pieces come from, in the page's coordinates: the bar, less its
  // rounded ends. Painted under it, they emerge from beneath its lower edge.
  final Rect source;

  const BirthdayConfetti({super.key, required this.user, required this.source});

  // The tax code already celebrated in this run.
  static String? _celebrated;

  static _Shower? _shower;

  // The bars on show. The shower runs as long as one is there to paint it.
  static final Set<_BirthdayConfettiState> _hosts = {};

  static void _startFor(MeResponse user)
  {
    if (!isBirthdayToday(user.birthDate, DateTime.now()) || _celebrated == user.taxCode)
    {
      return;
    }

    _celebrated = user.taxCode;
    _shower = _Shower(List.generate(_count, (_) => _Piece.random(math.Random())));
  }

  @visibleForTesting
  static void debugReset()
  {
    _shower?.end();
    _shower = null;
    _celebrated = null;
  }

  // Seconds since the shower began; null when none is running.
  @visibleForTesting
  static double? get debugElapsed => _shower == null || _shower!.done ? null : _shower!.elapsed;

  @visibleForTesting
  static int get debugHosts => _hosts.length;

  @override
  State<BirthdayConfetti> createState() => _BirthdayConfettiState();
}

class _BirthdayConfettiState extends State<BirthdayConfetti>
{
  bool _hosting = false;

  _Shower? _shower;

  // On show: the destination is the current one, not covered by a route
  // pushed over it, and painting.
  bool get _shown
  {
    return isDestinationShown(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final bool shown = _shown;

    if (shown != _hosting)
    {
      _hosting = shown;

      if (shown)
      {
        BirthdayConfetti._hosts.add(this);
      }
      else
      {
        BirthdayConfetti._hosts.remove(this);
      }
    }

    if (shown)
    {
      BirthdayConfetti._startFor(widget.user);
    }

    _listen(BirthdayConfetti._shower);
  }

  @override
  void didUpdateWidget(BirthdayConfetti oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (_hosting && oldWidget.user.taxCode != widget.user.taxCode)
    {
      BirthdayConfetti._startFor(widget.user);
      _listen(BirthdayConfetti._shower);
    }
  }

  void _listen(_Shower? shower)
  {
    if (identical(shower, _shower))
    {
      return;
    }

    _shower?.removeListener(_onShower);
    _shower = shower;
    _shower?.addListener(_onShower);
  }

  // Ticks repaint through the painter; only the end needs a rebuild, to drop it.
  void _onShower()
  {
    if (_shower!.done)
    {
      setState(() {});
    }
  }

  @override
  void dispose()
  {
    BirthdayConfetti._hosts.remove(this);
    _shower?.removeListener(_onShower);
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final _Shower? shower = _shower;

    if (shower == null || shower.done)
    {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        shower.noteDrop(constraints.maxHeight - widget.source.top);

        return IgnorePointer(
          child: RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _ConfettiPainter(shower: shower, source: widget.source),
              ),
            ),
          ),
        );
      },
    );
  }
}

// The shower itself: the pieces and the clock they fall by. Its own ticker,
// not a bar's, so the clock runs on through a page change; where the pieces
// are at a given moment follows from the clock alone, so a bar picking it
// up mid-way paints the same picture the last one did.
class _Shower extends ChangeNotifier
{
  final List<_Piece> pieces;

  late final Ticker _ticker;

  double elapsed = 0;
  bool done = false;

  // The longest fall any bar has had to paint: the shower is over once the
  // slowest piece has had time to land at the foot of it.
  double _drop = 0;

  _Shower(this.pieces)
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

  // Ticks come before the frame is built, so a bar handing over to another
  // within one frame never leaves an empty moment here.
  void _onTick(Duration since)
  {
    elapsed = since.inMicroseconds / Duration.microsecondsPerSecond;

    final bool landed = _drop > 0 && elapsed > _pour + _drop / _slowest + 1;

    if (landed || BirthdayConfetti._hosts.isEmpty)
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

class _Piece
{
  // Where it starts, as fractions of the source rect.
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

  const _Piece({
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

  factory _Piece.random(math.Random random)
  {
    final bool round = random.nextDouble() < 0.25;
    final double width = round ? 6 + random.nextDouble() * 3 : 6 + random.nextDouble() * 4;

    return _Piece(
      across: random.nextDouble(),
      // The middle of the bar: hidden at first, out within a moment.
      down: 0.35 + random.nextDouble() * 0.3,
      delay: random.nextDouble() * _pour,
      speed: _slowest + random.nextDouble() * (_fastest - _slowest),
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

class _ConfettiPainter extends CustomPainter
{
  final _Shower shower;
  final Rect source;

  _ConfettiPainter({required this.shower, required this.source}) : super(repaint: shower);

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

      // A strip seen edge-on now and then: the tumble that reads as depth.
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
  bool shouldRepaint(_ConfettiPainter old) => old.shower != shower || old.source != source;
}
