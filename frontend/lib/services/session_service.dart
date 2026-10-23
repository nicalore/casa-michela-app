import 'package:shared_preferences/shared_preferences.dart';

import 'session_store_stub.dart' if (dart.library.js_interop) 'session_store_web.dart';

typedef StoredSession = ({String? accessToken, String? refreshToken});

class SessionService
{
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
