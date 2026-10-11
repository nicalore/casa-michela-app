import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/weak_graphics.dart';

// Transitions, blurs and fades; off by choice, by system setting, on weak graphics or slow frames.
abstract final class VisualEffects
{
  // Once set, nothing automatic overrides it.
  static const String _choiceKey = 'visual_effects';

  static const String _slowKey = 'visual_effects_slow';

  // Under 25 fps: browser battery savers cap frames at 30, that alone is not slow.
  static const Duration _slowGap = Duration(milliseconds: 40);

  // Shorter runs are interrupted ones, their first heavy frame would weigh too much.
  static const Duration _shortestRun = Duration(milliseconds: 300);

  static const int _slowRunsToTurnOff = 2;

  // What every transition becomes with effects off.
  static const Duration plainFade = Duration(milliseconds: 200);

  static final Animatable<double> plainFadeCurve = CurveTween(curve: Curves.easeOut);

  static final ValueNotifier<bool> _on = ValueNotifier<bool>(true);

  // Set by load() when no choice is stored: only then can slow frames turn the effects off.
  static bool _auto = false;

  static int _slowRuns = 0;

  static bool get on => _on.value;

  static bool of(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<_VisualEffectsScope>()?.notifier?.value ?? _on.value;
  }

  static Widget scope({required Widget child}) => _VisualEffectsScope(notifier: _on, child: child);

  static Future<void> load() async
  {
    try
    {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool? choice = prefs.getBool(_choiceKey);

      if (choice != null)
      {
        _auto = false;
        _on.value = choice;

        return;
      }

      _auto = true;
      _slowRuns = 0;
      _on.value = !(prefs.getBool(_slowKey) ?? false) &&
          !PlatformDispatcher.instance.accessibilityFeatures.disableAnimations &&
          !hasWeakGraphics();
    }
    catch (_)
    {
      // Storage refused: effects on, as before this setting existed.
    }
  }

  static Future<void> choose(bool on) async
  {
    _auto = false;
    _on.value = on;

    try
    {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_choiceKey, on);
    }
    catch (_)
    {
      // Kept for this visit only.
    }
  }

  static bool get _watching => _auto && _on.value;

  static void _judge(List<Duration> stamps)
  {
    if (!_watching || stamps.length < 3 || stamps.last - stamps.first < _shortestRun)
    {
      return;
    }

    final List<Duration> gaps = [for (var i = 1; i < stamps.length; i++) stamps[i] - stamps[i - 1]]..sort();

    _slowRuns = gaps[gaps.length ~/ 2] > _slowGap ? _slowRuns + 1 : 0;

    if (_slowRuns < _slowRunsToTurnOff)
    {
      return;
    }

    _on.value = false;

    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_slowKey, true)).ignore();
  }
}

class _VisualEffectsScope extends InheritedNotifier<ValueNotifier<bool>>
{
  const _VisualEffectsScope({required super.notifier, required super.child});
}

// Frame times of one long transition, judged when it ends; it never asks for a frame itself.
class TransitionProbe
{
  List<Duration>? _stamps;

  // Tells a callback left over from an earlier run to stop.
  int _run = 0;

  void start()
  {
    if (_stamps != null || !VisualEffects._watching)
    {
      return;
    }

    _stamps = [];
    _record(++_run);
  }

  void _record(int run)
  {
    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      final List<Duration>? stamps = _stamps;

      if (run != _run || stamps == null)
      {
        return;
      }

      stamps.add(SchedulerBinding.instance.currentSystemFrameTimeStamp);
      _record(run);
    });
  }

  void stop()
  {
    final List<Duration>? stamps = _stamps;

    cancel();

    if (stamps != null)
    {
      VisualEffects._judge(stamps);
    }
  }

  void cancel()
  {
    _stamps = null;
    _run++;
  }
}
