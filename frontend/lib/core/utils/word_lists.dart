import '../language/app_language.dart';

// No-break space, en dash, space: the dash never starts a line.
const String kFigureSeparator = ' – ';

// Between the parts of a document title (en dash).
const String kTitleSeparator = ' – ';

// No-break space, hyphen, space.
const String kShortSeparator = ' - ';

String joinFigures(Iterable<String> parts) => parts.join(kFigureSeparator);

// "a", "a e b", "a, b e c".
String joinWithAnd(List<String> parts)
{
  if (parts.length < 2)
  {
    return parts.join();
  }

  return '${parts.take(parts.length - 1).join(', ')}${tr(' e ', ' and ')}${parts.last}';
}

// A day label after a comma: "lunedì 2 novembre", but "Monday 2 November".
String dayInSentence(String label)
{
  return isEnglish || label.isEmpty ? label : '${label[0].toLowerCase()}${label.substring(1)}';
}

// "2 nov, di Giulia Rossi".
String withAuthor(String when, String author) => tr('$when, di $author', '$when, by $author');

// After a colon: "In regola: rimangono 3h".
String lowerFirst(String text) => text.isEmpty ? text : '${text[0].toLowerCase()}${text.substring(1)}';
