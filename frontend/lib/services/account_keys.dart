import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Device keys name an account by this, never by the tax code, which would outlive the session.
String accountKeyOf(String taxCode)
{
  return sha256.convert(utf8.encode('casa-michela/$taxCode')).toString().substring(0, 16);
}

// Keys written before the change carry the tax code as a path segment: renamed, then gone.
// Synchronous: the cache changes at once and is saved behind, so no read waits for it.
void moveAccountKeys(SharedPreferences prefs, String taxCode)
{
  final String account = accountKeyOf(taxCode);

  for (final String key in prefs.getKeys().toList())
  {
    final List<String> parts = key.split('/');

    if (!parts.contains(taxCode))
    {
      continue;
    }

    final String renamed = [for (final part in parts) part == taxCode ? account : part].join('/');
    final Object? value = prefs.get(key);

    if (!prefs.containsKey(renamed))
    {
      switch (value)
      {
        case final bool flag:
          unawaited(prefs.setBool(renamed, flag));
        case final int number:
          unawaited(prefs.setInt(renamed, number));
        case final double number:
          unawaited(prefs.setDouble(renamed, number));
        case final String text:
          unawaited(prefs.setString(renamed, text));
        case final List<Object?> list:
          unawaited(prefs.setStringList(renamed, list.whereType<String>().toList()));
      }
    }

    unawaited(prefs.remove(key));
  }
}
