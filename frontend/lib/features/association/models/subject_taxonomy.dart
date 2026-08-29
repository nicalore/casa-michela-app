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
  SchoolLevel('MIDDLE_SCHOOL', 'Scuola Secondaria di I Grado', 'Secondaria di I Grado', 'Sec. I Grado'),
  SchoolLevel('HIGH_SCHOOL', 'Scuola Secondaria di II Grado', 'Secondaria di II Grado', 'Sec. II Grado'),
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

// Values must stay aligned with HighSchoolTrackEnum on the backend; the server
// derives the years.
class HighSchoolTrack
{
  final String value;
  final String label;

  final String shortLabel;

  final int minYear;
  final int maxYear;

  const HighSchoolTrack(this.value, this.label, this.shortLabel, this.minYear, this.maxYear);
}

const List<HighSchoolTrack> highSchoolTracks = <HighSchoolTrack>[
  HighSchoolTrack('BIENNIO', 'Biennio', 'Biennio', 1, 2),
  HighSchoolTrack('TRIENNIO', 'Triennio', 'Triennio', 3, 5),
  HighSchoolTrack('QUADRIENNALE', 'Percorso quadriennale', 'Quadriennale', 1, 4),
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

// The track is part of the key: without it a biennio and a triennio of the same
// course collapse into one group.
String programScopeTitle({required String level, String? sector, String? track})
{
  final HighSchoolTrack? cycle = highSchoolTrackOf(track);

  return <String>[
    schoolLevelShortLabel(level),
    ?sector,
    if (cycle != null) cycle.shortLabel,
  ].join(' · ');
}

String? descriptionOrNull(String? description)
{
  final String? said = description?.trim();

  return said == null || said.isEmpty ? null : said;
}
