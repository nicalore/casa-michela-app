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

  static Future<void> clear()
  {
    return clearSessionImpl();
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
