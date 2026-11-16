const String kInvalidIban = 'Formato IBAN italiano non valido';

final RegExp _italianIban = RegExp(r'^IT\d{2}[A-Z]\d{10}[A-Z0-9]{12}$');

String normalizedIban(String text) => text.replaceAll(RegExp(r'\s'), '').toUpperCase();

bool isItalianIban(String iban) => _italianIban.hasMatch(iban);
