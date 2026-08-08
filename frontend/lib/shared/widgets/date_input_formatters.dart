import 'package:flutter/services.dart';

// The slashes of a date insert themselves while typing: filling in a form
// should not mean typing the punctuation too.

class DateInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  )
  {
    if (oldValue.text.length >= newValue.text.length)
    {
      return newValue;
    }

    String text = newValue.text;
    // Follows the caret instead of forcing it to the end, so editing a digit
    // in the middle of an already typed date leaves the cursor where it was.
    int caret = newValue.selection.baseOffset;

    if (text.length == 2 && !text.contains('/'))
    {
      text += '/';

      if (caret == 2)
      {
        caret = 3;
      }
    }
    else if (text.length == 5 && text.indexOf('/', 3) == -1)
    {
      text += '/';

      if (caret == 5)
      {
        caret = 6;
      }
    }

    if (text.length > 10)
    {
      return oldValue;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret.clamp(0, text.length)),
    );
  }
}

class DayMonthInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  )
  {
    if (oldValue.text.length >= newValue.text.length)
    {
      return newValue;
    }

    String text = newValue.text;

    if (text.length == 2 && !text.contains('/'))
    {
      text += '/';
    }

    if (text.length > 5)
    {
      return oldValue;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
