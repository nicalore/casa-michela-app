import '../../../../../core/language/app_language.dart';

// First year and month with data; every year picker and padded series starts
// there.
const int dataStartYear = 2023;
const int dataStartMonth = 1;

List<String> get monthAbbreviations => [
  tr('Gen', 'Jan'), tr('Feb', 'Feb'), tr('Mar', 'Mar'), tr('Apr', 'Apr'), tr('Mag', 'May'), tr('Giu', 'Jun'),
  tr('Lug', 'Jul'), tr('Ago', 'Aug'), tr('Set', 'Sep'), tr('Ott', 'Oct'), tr('Nov', 'Nov'), tr('Dic', 'Dec'),
];