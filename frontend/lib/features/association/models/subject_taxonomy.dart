import '../../../core/language/app_language.dart';
// Values must stay aligned with the backend enums.

class SubjectArea
{
  final String value;
  final String label;

  final String compactLabel;

  const SubjectArea(this.value, this.label, this.compactLabel);
}

List<SubjectArea> get subjectAreas => <SubjectArea>[
  SubjectArea('HUMANITIES', tr('Area Umanistica', 'Humanities'), tr('Umanistica', 'Humanities')),
  SubjectArea('LINGUISTICS', tr('Area Linguistica', 'Languages'), tr('Linguistica', 'Languages')),
  SubjectArea('SCIENCES', tr('Area Scientifica', 'Sciences'), tr('Scientifica', 'Sciences')),
];

List<({String title, List<T> items})> groupByArea<T>(Iterable<T> items, String Function(T item) areaOf)
{
  final Map<String, List<T>> byArea = {};

  for (final item in items)
  {
    byArea.putIfAbsent(areaOf(item), () => []).add(item);
  }

  return [
    for (final area in subjectAreas)
      if (byArea.containsKey(area.value)) (title: area.label, items: byArea[area.value]!),
    for (final entry in byArea.entries)
      if (!subjectAreas.any((area) => area.value == entry.key)) (title: entry.key, items: entry.value),
  ];
}

String subjectAreaLabel(String value)
{
  for (final area in subjectAreas)
  {
    if (area.value == value)
    {
      return area.label;
    }
  }

  return value;
}

class SchoolLevel
{
  final String value;
  final String label;

  final String compactLabel;

  final String shortLabel;

  const SchoolLevel(this.value, this.label, this.compactLabel, this.shortLabel);
}

List<SchoolLevel> get schoolLevels => <SchoolLevel>[
  SchoolLevel(
    'PRIMARY_SCHOOL',
    tr('Scuola Primaria', 'Primary school'),
    tr('Primaria', 'Primary school'),
    tr('Primaria', 'Primary'),
  ),
  SchoolLevel(
    'MIDDLE_SCHOOL',
    tr('Scuola Secondaria di I Grado', 'Lower secondary school'),
    tr('Secondaria di I Grado', 'Lower secondary'),
    tr('Secondaria I Grado', 'Lower secondary'),
  ),
  SchoolLevel(
    'HIGH_SCHOOL',
    tr('Scuola Secondaria di II Grado', 'Upper secondary school'),
    tr('Secondaria di II Grado', 'Upper secondary'),
    tr('Secondaria II Grado', 'Upper secondary'),
  ),
];

String schoolLevelLabel(String value)
{
  for (final level in schoolLevels)
  {
    if (level.value == value)
    {
      return level.label;
    }
  }

  return value;
}

String schoolLevelShortLabel(String value)
{
  for (final level in schoolLevels)
  {
    if (level.value == value)
    {
      return level.shortLabel;
    }
  }

  return value;
}

// School order; unknown levels go last.
int schoolLevelRank(String value)
{
  final int rank = schoolLevels.indexWhere((level) => level.value == value);

  return rank < 0 ? schoolLevels.length : rank;
}

// Mirrors HighSchoolTrackEnum on the backend; the server derives a fixed track's years.
class HighSchoolTrack
{
  final String value;
  final String label;

  // Null for OTHER: its years are typed by hand.
  final int? minYear;
  final int? maxYear;

  const HighSchoolTrack(this.value, this.label, [this.minYear, this.maxYear]);

  bool get hasFixedYears => minYear != null;
}

List<HighSchoolTrack> get highSchoolTracks => <HighSchoolTrack>[
  HighSchoolTrack('BIENNIO', tr('Biennio', 'Years 1-2'), 1, 2),
  HighSchoolTrack('TRIENNIO', tr('Triennio', 'Years 3-5'), 3, 5),
  HighSchoolTrack('OTHER', tr('Altro', 'Other')),
];

HighSchoolTrack? highSchoolTrackOf(String? value)
{
  for (final track in highSchoolTracks)
  {
    if (track.value == value)
    {
      return track;
    }
  }

  return null;
}

// The fixed track whose span OTHER would restate; the server refuses that span.
HighSchoolTrack? fixedTrackSpanning(int? minYear, int? maxYear)
{
  for (final track in highSchoolTracks)
  {
    if (track.hasFixedYears && track.minYear == minYear && track.maxYear == maxYear)
    {
      return track;
    }
  }

  return null;
}

// Mirrors high_school_track_short_label on the backend: OTHER names its years.
String? highSchoolTrackShortLabel(String? track, int minYear, int maxYear)
{
  final HighSchoolTrack? cycle = highSchoolTrackOf(track);

  if (cycle == null)
  {
    return null;
  }

  return cycle.hasFixedYears ? cycle.label : tr('Anni $minYear-$maxYear', 'Years $minYear-$maxYear');
}

// The track is in the key, or "biennio" and "triennio" of a course merge into one group.
String programScopeTitle({
  required String level,
  String? sector,
  String? track,
  required int minYear,
  required int maxYear,
  // High school always has a track, so its title stays unique without the level.
  bool namesHighSchool = true,
})
{
  return <String>[
    if (namesHighSchool || level != 'HIGH_SCHOOL') schoolLevelShortLabel(level),
    ?sector,
    ?highSchoolTrackShortLabel(track, minYear, maxYear),
  ].join(' › ');
}

String? descriptionOrNull(String? description)
{
  final String? said = description?.trim();

  return said == null || said.isEmpty ? null : said;
}
