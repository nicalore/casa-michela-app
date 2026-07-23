// Values shared by every statistics tab, so a change to the data window or to
// the month labels does not have to be repeated seven times.

// First year and month with data: the association started collecting in
// November 2022, so every year picker and every padded series starts there.
const int dataStartYear = 2023;
const int dataStartMonth = 1;

const List<String> monthAbbreviations = [
  'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
  'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
];