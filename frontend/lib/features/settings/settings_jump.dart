import 'package:flutter/foundation.dart';

// A notification asking the settings for their Dispositivi: a page not built yet takes it when it
// starts, one already shown hears of it.
abstract final class SettingsJumps
{
  static bool _devices = false;

  // Bumped on every request.
  static final ValueNotifier<int> asked = ValueNotifier<int>(0);

  static void requestDevices()
  {
    _devices = true;
    asked.value++;
  }

  static bool takeDevices()
  {
    final bool pending = _devices;
    _devices = false;

    return pending;
  }
}
