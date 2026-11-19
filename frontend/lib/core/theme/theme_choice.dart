// The account's choice between light and dark; system follows the device's own setting.
enum ThemeChoice
{
  light('LIGHT'),
  dark('DARK'),
  system('SYSTEM');

  // As the API names it.
  final String key;

  const ThemeChoice(this.key);

  static ThemeChoice fromKey(String? key) => values.firstWhere((choice) => choice.key == key, orElse: () => light);
}
