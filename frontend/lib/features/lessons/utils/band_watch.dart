import 'dart:async';

import 'package:flutter/widgets.dart';

// How often the client says it is still there. Three of these fit inside the
// ninety seconds the server gives a lock, so two lost ones are survivable.
const Duration kBandBeat = Duration(seconds: 30);

// How often the day is read back. Quick while somebody else is building it,
// because their work has to appear; slow otherwise, when it serves only to
// notice that somebody has walked in.
const Duration kWatchingPoll = Duration(seconds: 10);

const Duration kRestingPoll = Duration(seconds: 60);

// The beat and the reload of the calendar, and the one rule they both obey:
// they run only while the calendar is what is on the screen and the app is in
// front of the person.
//
// That rule is the ninety seconds. A tab left behind, an app sent to the
// background, a window closed — none of them beat, so the band they were
// holding comes free on its own, and nothing has to be scheduled to notice.
// What never loses it is somebody actually working: filling in a wizard for
// three minutes is not idleness, and the beat does not care that no hour was
// written while it went on.
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

  // Whether the calendar is the section being shown. Everything else follows
  // from it, so the page says it and this decides what to run.
  void shows(bool shown)
  {
    _shown = shown;
    _sync();
  }

  // Whether the band on the screen is ours, and whether somebody else has it.
  // Both are read off the locks rather than remembered: there is no call that
  // takes a band — writing into the calendar is what does that — so the list
  // of who holds what is the only thing that knows, and a flag kept alongside
  // it would only be a second answer to drift from the first.
  //
  // Somebody else holding it also makes the reload keep up with them rather
  // than merely check on them.
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
