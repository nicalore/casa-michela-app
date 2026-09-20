// The same rules run on the server, which has the last word.

final RegExp _letter = RegExp(r'\p{L}', unicode: true);

// A word starts at a letter that no other letter precedes.
String titleCase(String value)
{
  final StringBuffer shaped = StringBuffer();
  bool afterLetter = false;

  for (final int rune in value.runes)
  {
    final String character = String.fromCharCode(rune);

    shaped.write(afterLetter ? character.toLowerCase() : character.toUpperCase());
    afterLetter = _letter.hasMatch(character);
  }

  return shaped.toString();
}

// Administrative lines.
String sentenceCase(String value)
{
  return _split(value, (rest) => rest.toLowerCase());
}

// Clinical notes: acronyms and drug names further in survive.
String openingCapital(String value)
{
  return _split(value, (rest) => rest);
}

String _split(String value, String Function(String rest) shapeRest)
{
  if (value.isEmpty)
  {
    return value;
  }

  final String first = String.fromCharCode(value.runes.first);

  return first.toUpperCase() + shapeRest(value.substring(first.length));
}
