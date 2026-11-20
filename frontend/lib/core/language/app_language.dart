import 'package:flutter/widgets.dart';

// The app's two languages; the key is how the API and the device's copy name them.
enum AppLanguage
{
  italian('it'),
  english('en');

  final String key;

  const AppLanguage(this.key);

  Locale get locale => Locale(key);

  // Null for an unknown or missing key: the caller keeps its default.
  static AppLanguage? fromKey(String? key)
  {
    for (final AppLanguage language in values)
    {
      if (language.key == key)
      {
        return language;
      }
    }

    return null;
  }
}

abstract final class AppLanguages
{
  // The language in force; ColourThemeScope redoes the whole app when it changes.
  static final ValueNotifier<AppLanguage> current = ValueNotifier(AppLanguage.italian);

  static const List<Locale> supportedLocales = [Locale('it'), Locale('en')];
}

bool get isEnglish => AppLanguages.current.value == AppLanguage.english;

// Every text the user reads, Italian first.
String tr(String italian, String english) => isEnglish ? english : italian;
