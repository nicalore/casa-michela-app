import 'package:shared_preferences/shared_preferences.dart';

import 'session_store_stub.dart' if (dart.library.js_interop) 'session_store_web.dart';

typedef StoredSession = ({String? accessToken, String? refreshToken});

class SessionService
{
  static const String _demoKey = 'session_on_demo_server';

  // Whether the stored pair belongs to the demo server, read before it is renewed.
  static Future<bool> readDemo() async
  {
    return (await SharedPreferences.getInstance()).getBool(_demoKey) ?? false;
  }

  static Future<void> saveDemo(bool demo) async
  {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (demo)
    {
      await prefs.setBool(_demoKey, true);
    }
    else
    {
      await prefs.remove(_demoKey);
    }
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  })
  {
    return writeSessionImpl(accessToken, refreshToken);
  }

  static Future<StoredSession> read()
  {
    return readSessionImpl();
  }

  static const String _roleKey = 'session_worn_role';

  // Per device: the server's stored role follows the last switch on any of them.
  static Future<String?> readRole() async
  {
    return (await SharedPreferences.getInstance()).getString(_roleKey);
  }

  static Future<void> saveRole(String role) async
  {
    await (await SharedPreferences.getInstance()).setString(_roleKey, role);
  }

  // The role goes with the pair: the next account to sign in here starts from its own.
  static Future<void> clear() async
  {
    await clearSessionImpl();
    await (await SharedPreferences.getInstance()).remove(_roleKey);
  }

  // Only that pair: another tab may have stored one of its own since.
  static Future<void> clearIfHolding(String refreshToken) async
  {
    if ((await read()).refreshToken == refreshToken)
    {
      await clear();
    }
  }
}
