import 'package:flutter/services.dart';

const int _groupSize = 3;

// Under this the tail is left whole, avoiding orphaned trailing digits.
const int _shortestSplittableTail = 6;

// The country code, taken as two digits (+39).
const int _countryCodeDigits = 2;

// Separators to strip. The slash is excluded on purpose: it separates two
// numbers written in one field.
final RegExp _separators = RegExp(r'[\s.\-()]');

final RegExp _digits = RegExp(r'^[0-9]+$');

String formatPhoneNumber(String? value)
{
  final raw = (value ?? '').trim();

  if (raw.isEmpty)
  {
    return raw;
  }

  final bare = raw.replaceAll(_separators, '');
  final hasCountryCode = bare.startsWith('+');
  final body = hasCountryCode ? bare.substring(1) : bare;

  if (!_digits.hasMatch(body))
  {
    return raw;
  }

  final groups = <String>[];
  var rest = body;

  if (hasCountryCode && rest.length > _countryCodeDigits)
  {
    groups.add('+${rest.substring(0, _countryCodeDigits)}');
    rest = rest.substring(_countryCodeDigits);
  }
  else if (hasCountryCode)
  {
    return '+$rest';
  }

  while (rest.length >= _shortestSplittableTail)
  {
    groups.add(rest.substring(0, _groupSize));
    rest = rest.substring(_groupSize);
  }

  if (rest.isNotEmpty)
  {
    groups.add(rest);
  }

  return groups.join(' ');
}

String barePhoneNumber(String? value)
{
  return (value ?? '').trim().replaceAll(_separators, '');
}

final RegExp _couldBeANumber = RegExp(r'^\+?[0-9]*$');

// Rewritten whole at each keystroke; the caret is tracked among the digits,
// which do not move, not at a character offset.
class PhoneInputFormatter extends TextInputFormatter
{
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue)
  {
    var text = newValue.text;

    if (!_couldBeANumber.hasMatch(barePhoneNumber(text)))
    {
      return newValue;
    }

    var caret = newValue.selection.isValid ? newValue.selection.baseOffset : text.length;

    // A space rubbed out deletes the digit before it, or backspace would do nothing.
    if (text.length < oldValue.text.length &&
        caret > 0 &&
        barePhoneNumber(text) == barePhoneNumber(oldValue.text))
    {
      text = text.substring(0, caret - 1) + text.substring(caret);
      caret -= 1;
    }

    final formatted = formatPhoneNumber(text);
    final kept = _keptBefore(text, caret);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: _offsetAfter(formatted, kept)),
    );
  }

  // Count of caret-preceding characters that survive the reformatting.
  int _keptBefore(String text, int caret)
  {
    var kept = 0;

    for (var i = 0; i < caret && i < text.length; i++)
    {
      if (!_separators.hasMatch(text[i]))
      {
        kept++;
      }
    }

    return kept;
  }

  int _offsetAfter(String text, int kept)
  {
    if (kept == 0)
    {
      return 0;
    }

    var seen = 0;

    for (var i = 0; i < text.length; i++)
    {
      if (_separators.hasMatch(text[i]))
      {
        continue;
      }

      seen++;

      if (seen == kept)
      {
        return i + 1;
      }
    }

    return text.length;
  }
}
