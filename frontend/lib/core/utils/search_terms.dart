import 'alphabetical_order.dart';

// Every word typed has to be found among some names; case, accents and spaces do not count.
class SearchTerms
{
  final List<String> _terms;

  const SearchTerms._(this._terms);

  // Null while nothing is typed.
  static SearchTerms? of(String query)
  {
    final terms = [
      for (final word in query.split(RegExp(r'\s+')))
        if (plainForSearch(word) case final plain when plain.isNotEmpty) plain,
    ];

    return terms.isEmpty ? null : SearchTerms._(terms);
  }

  bool findsAmong(Iterable<String> names)
  {
    final plain = [for (final name in names) plainForSearch(name)];

    return _terms.every((term) => plain.any((name) => name.contains(term)));
  }
}
