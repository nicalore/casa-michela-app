import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

// A code of this browser or app, kept for good: the server tells a sign-in from a new device by it.
abstract final class ClientDeviceKey
{
  static const String _key = 'client_device_key';

  static String? value;

  static Future<void> load() async
  {
    try
    {
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      final String? kept = preferences.getString(_key);

      if (kept != null)
      {
        value = kept;

        return;
      }

      final Random random = Random.secure();
      final String created = [
        for (var i = 0; i < 16; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join();

      await preferences.setString(_key, created);
      value = created;
    }
    catch (_)
    {
      // No storage: sign-ins name no device, and none is told as new.
    }
  }
}
