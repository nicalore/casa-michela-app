import 'package:shared_preferences/shared_preferences.dart';

class SessionService
{
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  //SaveAuthenticationTokens
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async
  {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  //RetrieveAccessToken
  static Future<String?> getAccessToken() async
  {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_accessTokenKey);
  }

  //RetrieveRefreshToken
  static Future<String?> getRefreshToken() async
  {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_refreshTokenKey);
  }

  //ClearSessionData
  static Future<void> clear() async
  {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}