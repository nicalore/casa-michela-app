import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/colour_theme_scope.dart';
import '../core/theme/theme_choice.dart';
import '../core/theme/theme_colours.dart';
import '../features/auth/models/me_response.dart';
import 'api_service.dart';
import 'auth_state.dart';

// The signed-in account's colours and mode; sign-in pages and a signed-out app keep Casa Michela's light ones.
abstract final class AccountColourTheme
{
  // The device's copy paints a restored session from its first frame, before /auth/me answers.
  static const String _storedKey = 'colour_theme';
  static const String _storedModeKey = 'theme_mode';

  // Light, dark or the device's own: what the settings tick. ThemeColours.dark is what this resolves to now.
  static final ValueNotifier<ThemeChoice> choice = ValueNotifier(ThemeChoice.light);

  static bool _following = false;

  // Before restoreSession(), so a stored session opens in its own colours.
  static Future<void> follow() async
  {
    if (_following)
    {
      return;
    }

    _following = true;

    try
    {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      ThemeColours.current.value = ColourTheme.fromKey(prefs.getString(_storedKey));
      choice.value = ThemeChoice.fromKey(prefs.getString(_storedModeKey));
      ThemeColours.dark.value = _darkFor(choice.value);
    }
    catch (_)
    {
      // Storage refused: Casa Michela until the identity arrives.
    }

    final ApiService api = ApiService();

    api.identity.addListener(_adopt);
    api.authState.addListener(_adopt);
    WidgetsBinding.instance.addObserver(_DeviceBrightness());
  }

  static bool get _signedOut => ApiService().authState.value == AuthState.unauthenticated;

  static bool _darkFor(ThemeChoice choice)
  {
    return switch (choice)
    {
      ThemeChoice.light => false,
      ThemeChoice.dark => true,
      ThemeChoice.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
    };
  }

  // The device switched light and dark while the app was open: an account following it fades along.
  static void _deviceChanged()
  {
    if (choice.value != ThemeChoice.system || _signedOut)
    {
      return;
    }

    final bool dark = _darkFor(ThemeChoice.system);

    if (dark != ThemeColours.dark.value)
    {
      ColourThemeScope.fadeInto(() => ThemeColours.dark.value = _darkFor(choice.value));
    }
  }

  static void _adopt()
  {
    final ApiService api = ApiService();
    final MeResponse? identity = api.identity.value;

    if (_signedOut)
    {
      _apply(ColourTheme.casaMichela, ThemeChoice.light);

      return;
    }

    if (identity != null)
    {
      _apply(identity.colourTheme, identity.themeChoice);
    }
  }

  static void _apply(ColourTheme theme, ThemeChoice mode)
  {
    ThemeColours.current.value = theme;
    choice.value = mode;
    ThemeColours.dark.value = _darkFor(mode);
    unawaited(_store(theme, mode));
  }

  static Future<void> _store(ColourTheme theme, ThemeChoice mode) async
  {
    try
    {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      if (theme == ColourTheme.casaMichela)
      {
        await prefs.remove(_storedKey);
      }
      else
      {
        await prefs.setString(_storedKey, theme.key);
      }

      if (mode == ThemeChoice.light)
      {
        await prefs.remove(_storedModeKey);
      }
      else
      {
        await prefs.setString(_storedModeKey, mode.key);
      }
    }
    catch (_)
    {
      // Only the next start's first frame is affected.
    }
  }

  // Signing out by hand: the page in view fades to the sign-in look first, then the way to the login runs.
  // Other ways out (an expired session, another tab) change it as they go.
  static Future<void> fadeToSignedOut()
  {
    if (ThemeColours.current.value == ColourTheme.casaMichela && !ThemeColours.dark.value)
    {
      return Future.value();
    }

    return ColourThemeScope.fadeInto(()
    {
      ThemeColours.current.value = ColourTheme.casaMichela;
      ThemeColours.dark.value = false;
    });
  }

  // Faded in at once; a refusal fades the previous colours back and is rethrown.
  static Future<void> choose(ColourTheme theme) async
  {
    final ColourTheme previous = ThemeColours.current.value;

    ColourThemeScope.fadeInto(() => ThemeColours.current.value = theme);

    try
    {
      await ApiService().setColourTheme(theme);
    }
    catch (_)
    {
      ColourThemeScope.fadeInto(()
      {
        if (ThemeColours.current.value == theme)
        {
          ThemeColours.current.value = previous;
        }
      });

      rethrow;
    }
  }

  // Light, dark or the device's own, faded in at once; a refusal fades the previous one back and is rethrown.
  static Future<void> chooseMode(ThemeChoice mode) async
  {
    final ThemeChoice previous = choice.value;

    void show(ThemeChoice shown)
    {
      choice.value = shown;
      ThemeColours.dark.value = _darkFor(shown);
    }

    ColourThemeScope.fadeInto(() => show(mode));

    try
    {
      await ApiService().setThemeMode(mode);
    }
    catch (_)
    {
      ColourThemeScope.fadeInto(()
      {
        if (choice.value == mode)
        {
          show(previous);
        }
      });

      rethrow;
    }
  }
}

class _DeviceBrightness with WidgetsBindingObserver
{
  @override
  void didChangePlatformBrightness() => AccountColourTheme._deviceChanged();
}
