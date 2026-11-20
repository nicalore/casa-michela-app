import '../language/app_language.dart';

String get kInvalidIban => tr('Formato IBAN italiano non valido', 'Invalid Italian IBAN format');

final RegExp _italianIban = RegExp(r'^IT\d{2}[A-Z]\d{10}[A-Z0-9]{12}$');

String normalizedIban(String text) => text.replaceAll(RegExp(r'\s'), '').toUpperCase();

bool isItalianIban(String iban) => _italianIban.hasMatch(iban);
