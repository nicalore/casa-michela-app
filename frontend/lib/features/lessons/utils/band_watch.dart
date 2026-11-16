import 'dart:async';

import 'package:flutter/widgets.dart';

// Three beats fit inside the server's 90s lock, so two lost beats survive.
const Duration kBandBeat = Duration(seconds: 30);

// Poll fast while somebody else is building, slow otherwise.
const Duration kWatchingPoll = Duration(seconds: 10);

const Duration kRestingPoll = Duration(seconds: 60);

// Runs only while the calendar is shown and the app foregrounded, so an abandoned lock expires.
class CalendarBandWatch
{
  final Future<void> Function() beat;

  final Future<void> Function() poll;

  // Reads the locks only: cheap enough to tell within seconds that somebody began building.
  final Future<void> Function() glance;

  // Another tab released a band; locks are per account, so it may be the one this tab edits.
  // A beat never retakes it: it only tells this tab, and its next change takes it back.
  final Listenable releasedElsewhere;

  CalendarBandWatch({
    required this.beat,
    required this.poll,
    required this.glance,
    required this.releasedElsewhere,
  });

  Timer? _beating;
  Timer? _polling;
  Timer? _glancing;

  AppLifecycleListener? _lifecycle;

  bool _shown = false;
  bool _inFront = true;
  bool _holding = false;
  bool _watching = false;

  bool get holdsTheBand => _holding;

  void start()
  {
    _lifecycle = AppLifecycleListener(
      onShow: () => _say(inFront: true),
      onHide: () => _say(inFront: false),
    );

    releasedElsewhere.addListener(_askWhoHoldsIt);
  }

  void dispose()
  {
    _beating?.cancel();
    _polling?.cancel();
    _glancing?.cancel();
    _lifecycle?.dispose();
    releasedElsewhere.removeListener(_askWhoHoldsIt);
  }

  void _askWhoHoldsIt()
  {
    if (_awake && _holding)
    {
      unawaited(beat());
    }
  }

  void _say({required bool inFront})
  {
    final bool wasAwake = _awake;

    _inFront = inFront;
    _sync();

    // Back in front: the timers restart from zero, so what changed meanwhile is read now.
    if (_awake && !wasAwake)
    {
      unawaited(poll());
    }
  }

  void shows(bool shown)
  {
    _shown = shown;
    _sync();
  }

  // Derived from the lock list, never remembered: only a write takes a band, so locks are the truth.
  void says({required bool holding, required bool watching})
  {
    if (_holding == holding && _watching == watching)
    {
      return;
    }

    _holding = holding;
    _watching = watching;
    _sync();
  }

  bool get _awake => _shown && _inFront;

  void _sync()
  {
    _beating?.cancel();
    _beating = _awake && _holding ? Timer.periodic(kBandBeat, (_) => beat()) : null;

    _polling?.cancel();
    _polling = _awake
        ? Timer.periodic(_watching ? kWatchingPoll : kRestingPoll, (_) => poll())
        : null;

    // A holder hears of its lock from the beat, a watcher from the poll.
    _glancing?.cancel();
    _glancing = _awake && !_holding && !_watching ? Timer.periodic(kWatchingPoll, (_) => glance()) : null;
  }
}
