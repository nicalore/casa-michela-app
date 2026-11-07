const String _vowels = 'aeiouyàáèéìíòóùú';

// A letter stays with the syllable it starts, so a group of consonants splits before the longest of these.
const Set<String> _openers = {
  'bl', 'br', 'cl', 'cr', 'dr', 'fl', 'fr', 'gl', 'gr', 'pl', 'pr', 'tl', 'tr', 'vr',
  'ch', 'gh', 'gn', 'ph', 'pn', 'ps', 'th',
  'sb', 'sc', 'sd', 'sf', 'sg', 'sk', 'sl', 'sm', 'sn', 'sp', 'sq', 'sr', 'st', 'sv',
  'sbl', 'sbr', 'sch', 'scl', 'scr', 'sdr', 'sfl', 'sfr', 'sgh', 'sgl', 'sgr', 'spl', 'spr', 'str', 'svr',
};

const int _shortestPiece = 2;

final RegExp _letters = RegExp(r'\p{L}+', unicode: true);

bool _isVowel(String letter) => _vowels.contains(letter);

int _splitOf(String group)
{
  for (int index = 0; index < group.length - 1; index++)
  {
    if (_openers.contains(group.substring(index)))
    {
      return index;
    }
  }

  return group.length - 1;
}

// Vowels stay together: the letters alone cannot tell a diphthong from a hiatus.
List<int> _breaksIn(String word)
{
  final List<int> breaks = [];
  int index = 0;

  while (index < word.length && !_isVowel(word[index]))
  {
    index++;
  }

  while (index < word.length)
  {
    while (index < word.length && _isVowel(word[index]))
    {
      index++;
    }

    final int start = index;

    while (index < word.length && !_isVowel(word[index]))
    {
      index++;
    }

    if (index == word.length)
    {
      break;
    }

    final int cut = start + _splitOf(word.substring(start, index));

    if (cut >= _shortestPiece && word.length - cut >= _shortestPiece)
    {
      breaks.add(cut);
    }
  }

  return breaks;
}

// Offsets in [text] where a line may end with a hyphen, for each run of letters in it.
List<int> italianSyllableBreaks(String text)
{
  return [
    for (final RegExpMatch run in _letters.allMatches(text))
      for (final int cut in _breaksIn(run[0]!.toLowerCase()))
        run.start + cut,
  ];
}
