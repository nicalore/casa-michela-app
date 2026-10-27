import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

// Shared by the desktop and mobile tours: what can be touched glows, a touch that missed nudges the forward button.

const Duration _breathPeriod = Duration(milliseconds: 1600);
const int _breaths = 3;
const Duration _breathRise = Duration(milliseconds: 400);

// The glow at rest, and how far a breath takes it either way.
const double _restGlow = 0.6;
const double _glowSwing = 0.4;

// Kept apart from real pointers and devices.
int _tapPointer = 1 << 20;
const int _tapDevice = 1 << 20;

const Duration kTourNudgeDuration = Duration(milliseconds: 520);

final Animatable<double> kTourNudge = TweenSequence<double>([
  TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
  TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.96).chain(CurveTween(curve: Curves.easeInOut)), weight: 25),
  TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.03).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
  TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
]);

// A few breaths, then the glow rests: a step waiting for a touch draws no frames.
class TourBreath
{
  final AnimationController _phase;
  final AnimationController _amplitude;

  bool _fading = false;

  TourBreath(TickerProvider vsync)
      : _phase = AnimationController(vsync: vsync, duration: _breathPeriod * _breaths),
        _amplitude = AnimationController(vsync: vsync, duration: _breathRise)
  {
    _phase.addListener(_onPhase);
  }

  Listenable get listenable => Listenable.merge([_phase, _amplitude]);

  double get glow => _restGlow + _glowSwing * math.sin(2 * math.pi * _phase.value * _breaths) * _amplitude.value;

  // Again while breathing: from the same point of a breath, so the glow never jumps.
  void start()
  {
    final double from = _phase.isAnimating ? (_phase.value * _breaths) % 1 / _breaths : 0;

    _fading = false;
    _phase.forward(from: from);
    _amplitude.animateTo(1, duration: _breathRise);
  }

  void _onPhase()
  {
    if (!_fading && _phase.value * _breaths >= _breaths - 1)
    {
      _fading = true;
      _amplitude.animateTo(0, duration: _breathPeriod);
    }
  }

  void dispose()
  {
    _phase.dispose();
    _amplitude.dispose();
  }
}

// [glow] 0 to 1, outside [rim] only.
void paintTourHalo(Canvas canvas, RRect rim, double glow)
{
  if (glow <= 0)
  {
    return;
  }

  final Paint halo = Paint()
    ..color = AppTheme.trialGold.withValues(alpha: math.min(1, glow))
    ..maskFilter = MaskFilter.blur(BlurStyle.outer, 3 + 9 * glow);

  // Twice: a blur outside fades too soon to read on the dark at rest.
  canvas
    ..drawRRect(rim, halo)
    ..drawRRect(rim, halo);
}

// What the user's touch would do: a tap on the middle of [part], once the event under way is handled.
bool tapTourPart(BuildContext part)
{
  final RenderObject? box = part.findRenderObject();

  if (box is! RenderBox || !box.attached || !box.hasSize)
  {
    return false;
  }

  final Offset at = box.localToGlobal(box.size.center(Offset.zero));
  final int viewId = View.of(part).viewId;
  final int pointer = _tapPointer++;

  scheduleMicrotask(()
  {
    GestureBinding.instance
      ..handlePointerEvent(PointerDownEvent(pointer: pointer, device: _tapDevice, position: at, viewId: viewId))
      ..handlePointerEvent(PointerUpEvent(pointer: pointer, device: _tapDevice, position: at, viewId: viewId));
  });

  return true;
}
