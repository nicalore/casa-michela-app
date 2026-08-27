import 'dart:async';

import 'package:flutter/widgets.dart';

// Three beats fit inside the server's 90s lock, so two lost beats survive.
const Duration kBandBeat = Duration(seconds: 30);

// Poll fast while somebody else is building, slow otherwise.
const Duration kWatchingPoll = Duration(seconds: 10);

const Duration kRestingPoll = Duration(seconds: 60);

// Beat and poll run only while the calendar section is shown and the app is
// foregrounded, so an abandoned tab or backgrounded app stops beating and its
// lock expires on its own.
class CalendarBandWatch
{
  final Future<void> Function() beat;

  final Future<void> Function() poll;

  CalendarBandWatch({required this.beat, required this.poll});

  Timer? _beating;
  Timer? _polling;

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
  }

  void dispose()
  {
    _beating?.cancel();
    _polling?.cancel();
    _lifecycle?.dispose();
  }

  void _say({bool? inFront})
  {
    if (inFront != null)
    {
      _inFront = inFront;
    }

    _sync();
  }

  void shows(bool shown)
  {
    _shown = shown;
    _sync();
  }

  // Both flags are derived from the lock list, never remembered here: there
  // is no call that takes a band (writing does), so the locks are the only
  // source of truth.
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
  }
}
