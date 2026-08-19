import 'package:flutter/services.dart';

// A telephone number as it is read aloud rather than as it is stored.
//
// It is kept as a run of digits — that is what a number is, and what the server
// is given — and read in threes: 333 111 2222 is one glance, 3331112222 is a
// string somebody has to count through twice to check against a phone.
//
// The grouping is threes from the left, with the last group taking whatever is
// left over rather than trailing a digit or two of its own: ten digits come out
// 3-3-4, nine come out 3-3-3. An Italian mobile is ten and a landline is nine to
// eleven, so this covers what the register actually holds without a table of
// area codes — which is the only way to do better, and a table nobody maintains
// is worse than a rule everybody can see.
const int _groupSize = 3;

// Under this the tail is left whole: splitting five into three and two is what
// puts a pair of orphaned digits at the end of a number.
const int _shortestSplittableTail = 6;

// The country code, taken as two digits. It is +39 here and two everywhere
// around it; the rest of the world is left readable rather than right.
const int _countryCodeDigits = 2;

// Everything a number may be written with and is not part of it. The slash is
// not in it on purpose: in this register it separates two numbers written in one
// field, and taken out it would splice them into a single impossible one.
final RegExp _separators = RegExp(r'[\s.\-()]');

final RegExp _digits = RegExp(r'^[0-9]+$');

// The number spaced, or exactly what it was where it is not a number at all: an
// extension written beside it, a note in the field, two numbers in one. Those
// are somebody's data and not this function's to rearrange.
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

// The digits alone, which is what is stored and what is checked. The inverse of
// the spacing above, so a number typed with spaces, dots or dashes is the same
// number as one typed without.
String barePhoneNumber(String? value)
{
  return (value ?? '').trim().replaceAll(_separators, '');
}

// Whether what is in the field could still become a number: digits, and a plus
// at the head of them. Anything else — a note, an extension, two numbers in one
// field — is somebody typing something this does not understand, and the rule
// there is to keep out of the way.
final RegExp _couldBeANumber = RegExp(r'^\+?[0-9]*$');

// The spaces of a number put themselves in while typing, the way the slashes of
// a date do: filling in a form should not mean typing the punctuation too.
//
// The grouping moves as the number grows — six digits are two threes, seven are
// a three and a four — so the whole field is written out again at each keystroke
// rather than a space being appended at a fixed place. That is what the caret
// arithmetic below is for: it is kept among the digits, which do not move, and
// not at a character offset, which does.
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

    // A space rubbed out is the digit before it rubbed out. The spaces are put
    // there by this formatter, so putting one straight back is a backspace that
    // does nothing, pressed against a cursor that will not move.
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

  // How many of the characters before the caret survive the spacing: the digits
  // and the plus, which is the only count that means the same thing on both
  // sides of a reformatting.
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

  // And where that many of them have gone by, which is where the caret belongs.
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
