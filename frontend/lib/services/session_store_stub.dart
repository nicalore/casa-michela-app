import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_store_prefs.dart' as legacy;

const String _accessTokenKey = 'access_token';
const String _refreshTokenKey = 'refresh_token';

// The preferences go with the app and the Keychain does not: no mark means a fresh install.
const String _installedKey = 'session_store_installed';

// A Keychain item on iOS, a Keystore key on Android: this device only, never in a backup.
const FlutterSecureStorage _secure = FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

// A reinstall drops the last install's Keychain items; an older build's session moves over.
Future<void> _settle() async
{
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  if (!(prefs.getBool(_installedKey) ?? false))
  {
    await _secure.delete(key: _accessTokenKey);
    await _secure.delete(key: _refreshTokenKey);
    await prefs.setBool(_installedKey, true);
  }

  final stored = await legacy.readSessionImpl();
  final String? accessToken = stored.accessToken;
  final String? refreshToken = stored.refreshToken;

  if (accessToken == null && refreshToken == null)
  {
    return;
  }

  if (accessToken != null && refreshToken != null)
  {
    await _secure.write(key: _accessTokenKey, value: accessToken);
    await _secure.write(key: _refreshTokenKey, value: refreshToken);
  }

  await legacy.clearSessionImpl();
}

Future<({String? accessToken, String? refreshToken})> readSessionImpl() async
{
  await _settle();

  return (
    accessToken: await _secure.read(key: _accessTokenKey),
    refreshToken: await _secure.read(key: _refreshTokenKey),
  );
}

Future<void> writeSessionImpl(String accessToken, String refreshToken) async
{
  await _settle();
  await _secure.write(key: _accessTokenKey, value: accessToken);
  await _secure.write(key: _refreshTokenKey, value: refreshToken);
}

Future<void> clearSessionImpl() async
{
  await _settle();
  await _secure.delete(key: _accessTokenKey);
  await _secure.delete(key: _refreshTokenKey);
}
