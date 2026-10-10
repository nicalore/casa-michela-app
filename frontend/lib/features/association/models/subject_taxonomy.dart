// Values must stay aligned with the backend enums.

class SubjectArea
{
  final String value;
  final String label;

  final String compactLabel;

  const SubjectArea(this.value, this.label, this.compactLabel);
}

const List<SubjectArea> subjectAreas = <SubjectArea>[
  SubjectArea('HUMANITIES', 'Area Umanistica', 'Umanistica'),
  SubjectArea('LINGUISTICS', 'Area Linguistica', 'Linguistica'),
  SubjectArea('SCIENCES', 'Area Scientifica', 'Scientifica'),
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

const List<SchoolLevel> schoolLevels = <SchoolLevel>[
  SchoolLevel('PRIMARY_SCHOOL', 'Scuola Primaria', 'Primaria', 'Primaria'),
  SchoolLevel('MIDDLE_SCHOOL', 'Scuola Secondaria di I Grado', 'Secondaria di I Grado', 'Secondaria I Grado'),
  SchoolLevel('HIGH_SCHOOL', 'Scuola Secondaria di II Grado', 'Secondaria di II Grado', 'Secondaria II Grado'),
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

// Values must stay aligned with HighSchoolTrackEnum on the backend; the server derives the years of a fixed track.
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

const List<HighSchoolTrack> highSchoolTracks = <HighSchoolTrack>[
  HighSchoolTrack('BIENNIO', 'Biennio', 1, 2),
  HighSchoolTrack('TRIENNIO', 'Triennio', 3, 5),
  HighSchoolTrack('OTHER', 'Altro'),
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

  return cycle.hasFixedYears ? cycle.label : 'Anni $minYear-$maxYear';
}

// The track is part of the key: without it biennio and triennio of a course collapse into one group.
String programScopeTitle({
  required String level,
  String? sector,
  String? track,
  required int minYear,
  required int maxYear,
})
{
  return <String>[
    schoolLevelShortLabel(level),
    ?sector,
    ?highSchoolTrackShortLabel(track, minYear, maxYear),
  ].join(' · ');
}

String? descriptionOrNull(String? description)
{
  final String? said = description?.trim();

  return said == null || said.isEmpty ? null : said;
}
