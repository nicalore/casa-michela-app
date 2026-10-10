// Letters of a last word kept from standing alone; a longer one reads fine there.
const int _longestBound = 8;

final RegExp _letter = RegExp(r'\p{L}', unicode: true);

// Joins a paragraph's last two words with a no-break space, unless the last word is long.
String withoutOrphans(String text)
{
  return text.split('\n').map((paragraph)
  {
    final String trimmed = paragraph.trimRight();
    final int last = trimmed.lastIndexOf(' ');

    // Under three words the whole paragraph would become one unbreakable run.
    if (last <= 0 || trimmed.indexOf(' ') == last)
    {
      return paragraph;
    }

    if (_letter.allMatches(trimmed.substring(last + 1)).length > _longestBound)
    {
      return paragraph;
    }

    return '${trimmed.substring(0, last)} ${trimmed.substring(last + 1)}';
  }).join('\n');
}
