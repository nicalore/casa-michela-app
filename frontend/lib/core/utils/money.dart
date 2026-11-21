import '../language/app_language.dart';

// Amounts in cents: doubles round in binary and the net (a fifth off) must land on the cent.

const int _centsPerUnit = 100;

// Accepts '1200', '1200,50', '1200.50' and thousands grouped as the language in force groups them:
// '1.200,50' in Italian, '1,200.50' in English. Null when not an amount, empty text included.
int? parseAmountCents(String text)
{
  final String cleaned = text.trim().replaceAll(' ', '').replaceAll('€', '');

  if (cleaned.isEmpty)
  {
    return null;
  }

  final bool plain = RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(cleaned);

  // The other language's grouping is refused: in Italian "12,345" is no amount, not 12345.
  final RegExp grouping = isEnglish
      ? RegExp(r'^\d{1,3}(,\d{3})+(\.\d{1,2})?$')
      : RegExp(r'^\d{1,3}(\.\d{3})+(,\d{1,2})?$');
  final bool grouped = grouping.hasMatch(cleaned);

  if (!plain && !grouped)
  {
    return null;
  }

  // A plain figure has one mark at most, whichever it is.
  final int decimal = grouped ? cleaned.lastIndexOf(isEnglish ? '.' : ',') : cleaned.lastIndexOf(RegExp('[.,]'));

  final String units =
      (decimal < 0 ? cleaned : cleaned.substring(0, decimal)).replaceAll(RegExp(r'[.,]'), '');
  final String fraction = decimal < 0 ? '' : cleaned.substring(decimal + 1);

  return int.parse(units) * _centsPerUnit + int.parse(fraction.padRight(2, '0'));
}

int netOfCents(int gross) => (gross * 4 / 5).round();

// The withholding tax: what the gross loses to become the net.
int? withholdingOf(int? gross, int? net) => gross == null || net == null ? null : gross - net;

String formatAmount(int cents)
{
  final String units = (cents ~/ _centsPerUnit).toString();
  final String fraction = (cents % _centsPerUnit).toString().padLeft(2, '0');

  final StringBuffer grouped = StringBuffer();

  for (var i = 0; i < units.length; i++)
  {
    if (i > 0 && (units.length - i) % 3 == 0)
    {
      grouped.write(isEnglish ? ',' : '.');
    }

    grouped.write(units[i]);
  }

  return isEnglish ? '€$grouped.$fraction' : '€ $grouped,$fraction';
}

// "−€ 139,00" below zero, as a balance can be; "−€139.00" in English.
String formatSignedAmount(int cents) => cents < 0 ? '\u2212${formatAmount(-cents)}' : formatAmount(cents);

String? formatAmountText(String? raw)
{
  if (raw == null)
  {
    return null;
  }

  final int? cents = parseAmountCents(raw);

  return cents == null ? null : formatAmount(cents);
}

// Payload format: plain digits with a dot, whatever was typed.
String? amountPayloadOf(String text)
{
  final int? cents = parseAmountCents(text);

  if (cents == null)
  {
    return null;
  }

  return '${cents ~/ _centsPerUnit}.${(cents % _centsPerUnit).toString().padLeft(2, '0')}';
}
