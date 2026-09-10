// Amounts in cents: doubles round in binary and the net (a fifth off) must land on the cent.

const int _centsPerUnit = 100;

// Accepts '1200', '1200,50', '1200.50', '1.200,50'; null when not an amount, empty text included.
int? parseAmountCents(String text)
{
  final String cleaned = text.trim().replaceAll(' ', '').replaceAll('€', '');

  if (cleaned.isEmpty)
  {
    return null;
  }

  final bool plain = RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(cleaned);
  final bool grouped = RegExp(r'^\d{1,3}(\.\d{3})+(,\d{1,2})?$').hasMatch(cleaned);

  if (!plain && !grouped)
  {
    return null;
  }

  // The last separator is the decimal one; anything before it groups thousands.
  final int comma = cleaned.lastIndexOf(',');
  final int dot = cleaned.lastIndexOf('.');
  final int decimal = comma > dot ? comma : dot;

  final String units =
      (decimal < 0 ? cleaned : cleaned.substring(0, decimal)).replaceAll(RegExp(r'[.,]'), '');
  final String fraction = decimal < 0 ? '' : cleaned.substring(decimal + 1);

  return int.parse(units) * _centsPerUnit + int.parse(fraction.padRight(2, '0'));
}

int netOfCents(int gross) => (gross * 4 / 5).round();

String formatAmount(int cents)
{
  final String units = (cents ~/ _centsPerUnit).toString();
  final String fraction = (cents % _centsPerUnit).toString().padLeft(2, '0');

  final StringBuffer grouped = StringBuffer();

  for (var i = 0; i < units.length; i++)
  {
    if (i > 0 && (units.length - i) % 3 == 0)
    {
      grouped.write('.');
    }

    grouped.write(units[i]);
  }

  return '€ $grouped,$fraction';
}

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
