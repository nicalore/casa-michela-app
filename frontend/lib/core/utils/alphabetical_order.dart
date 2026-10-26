// The server's alphabetical_key follows the same rules.

// Case, accents, spaces and punctuation do not count, as in the database.
int compareAlphabetically(String a, String b) => compareAlphabeticallyInParts([a], [b]);

// Earlier parts lead; case and accents decide only once every part ties.
int compareAlphabeticallyInParts(List<String> a, List<String> b)
{
  for (final int Function(String, String) level in _levels)
  {
    for (int index = 0; index < a.length; index++)
    {
      final int order = level(a[index], b[index]);

      if (order != 0)
      {
        return order;
      }
    }
  }

  return 0;
}

final List<int Function(String, String)> _levels = [
  (a, b) => _plain(a).compareTo(_plain(b)),
  (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
  (a, b) => a.compareTo(b),
];

const Map<String, String> _variantsOf = {
  'a': 'àáâãäåāăą',
  'c': 'çćĉċč',
  'd': 'ďđð',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħ',
  'i': 'ìíîïĩīĭįı',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľŀł',
  'n': 'ñńņň',
  'o': 'òóôõöøōŏő',
  'r': 'ŕŗř',
  's': 'śŝşšș',
  't': 'ţťŧț',
  'u': 'ùúûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
  'ss': 'ß',
  'ae': 'æ',
  'oe': 'œ',
  'th': 'þ',
  '': ' «´·»ʼ ‐‑‒–—‘’“”… ',
};

final Map<int, String> _swaps = {
  for (final MapEntry(key: plain, value: variants) in _variantsOf.entries)
    for (final int unit in variants.codeUnits) unit: plain,
  // Combining accents, left by decomposed text.
  for (int unit = 0x300; unit <= 0x36f; unit++) unit: '',
};

bool _isPlainAscii(int unit) => (unit >= 0x61 && unit <= 0x7a) || (unit >= 0x30 && unit <= 0x39);

String _plain(String text)
{
  final String lower = text.toLowerCase();
  StringBuffer? plain;

  for (int index = 0; index < lower.length; index++)
  {
    final int unit = lower.codeUnitAt(index);
    final String? swap = unit < 0x80 ? (_isPlainAscii(unit) ? null : '') : _swaps[unit];

    if (swap == null && plain == null)
    {
      continue;
    }

    plain ??= StringBuffer(lower.substring(0, index));

    if (swap == null)
    {
      plain.writeCharCode(unit);
    }
    else
    {
      plain.write(swap);
    }
  }

  return plain?.toString() ?? lower;
}
