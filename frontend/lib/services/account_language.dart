import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/language/app_language.dart';
import '../core/language/document_language.dart';
import '../core/theme/colour_theme_scope.dart';
import '../features/auth/models/me_response.dart';
import 'api_service.dart';

// The signed-in account's language; before sign-in, the last one chosen on this device, else the device's own.
abstract final class AccountLanguage
{
  // The device's copy writes a restored session and the sign-in pages from their first frame.
  static const String _storedKey = 'language';

  static bool _following = false;

  // Before restoreSession(), so a stored session opens in its own language.
  static Future<void> follow() async
  {
    if (_following)
    {
      return;
    }

    _following = true;

    AppLanguage language = _deviceLanguage();

    try
    {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      language = AppLanguage.fromKey(prefs.getString(_storedKey)) ?? language;
    }
    catch (_)
    {
      // Storage refused: the device's language until the identity arrives.
    }

    AppLanguages.current.addListener(_named);
    AppLanguages.current.value = language;
    _named();
    ApiService().identity.addListener(_adopt);
  }

  // English if the phone or browser speaks it, otherwise Italian.
  static AppLanguage _deviceLanguage()
  {
    final String code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    return code == AppLanguage.english.key ? AppLanguage.english : AppLanguage.italian;
  }

  static void _named() => setDocumentLanguage(AppLanguages.current.value.key);

  // An account that never chose keeps what this device shows; signing out keeps it too.
  static void _adopt()
  {
    final MeResponse? identity = ApiService().identity.value;
    final AppLanguage? language = identity?.language;

    if (language == null)
    {
      return;
    }

    AppLanguages.current.value = language;
    unawaited(_store(language));
  }

  static Future<void> _store(AppLanguage language) async
  {
    try
    {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(_storedKey, language.key);
    }
    catch (_)
    {
      // Only the next start's first frame is affected.
    }
  }

  // Faded in at once; a refusal fades the previous language back and is rethrown.
  static Future<void> choose(AppLanguage language) async
  {
    final AppLanguage previous = AppLanguages.current.value;

    ColourThemeScope.fadeInto(() => AppLanguages.current.value = language);
    unawaited(_store(language));

    try
    {
      await ApiService().setLanguage(language);
    }
    catch (_)
    {
      ColourThemeScope.fadeInto(()
      {
        if (AppLanguages.current.value == language)
        {
          AppLanguages.current.value = previous;
        }
      });
      unawaited(_store(previous));

      rethrow;
    }
  }
}
