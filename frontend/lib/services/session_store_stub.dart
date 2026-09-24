import 'package:shared_preferences/shared_preferences.dart';

const String _accessTokenKey = 'access_token';
const String _refreshTokenKey = 'refresh_token';

Future<({String? accessToken, String? refreshToken})> readSessionImpl() async
{
  final prefs = await SharedPreferences.getInstance();

  // The web falls back here, where another tab may have written since.
  await prefs.reload();

  return (
    accessToken: prefs.getString(_accessTokenKey),
    refreshToken: prefs.getString(_refreshTokenKey),
  );
}

Future<void> writeSessionImpl(String accessToken, String refreshToken) async
{
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString(_accessTokenKey, accessToken);
  await prefs.setString(_refreshTokenKey, refreshToken);
}

Future<void> clearSessionImpl() async
{
  final prefs = await SharedPreferences.getInstance();

  await prefs.remove(_accessTokenKey);
  await prefs.remove(_refreshTokenKey);
}
