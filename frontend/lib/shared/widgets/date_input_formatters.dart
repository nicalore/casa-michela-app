import 'package:flutter/services.dart';

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
