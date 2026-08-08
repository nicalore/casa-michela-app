// Single source of truth for the two closed vocabularies shared by the
// association tabs. The values must stay aligned with the backend enums.

class SubjectArea
{
  final String value;
  final String label;

  const SubjectArea(this.value, this.label);
}

const List<SubjectArea> subjectAreas = <SubjectArea>[
  SubjectArea('HUMANITIES', 'Area Umanistica'),
  SubjectArea('LINGUISTICS', 'Area Linguistica'),
  SubjectArea('SCIENCES', 'Area Scientifica'),
];

// Unknown values are returned unchanged, so a new backend area shows up as its
// raw code instead of disappearing from the interface.
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

  /// Drops the redundant "Scuola" prefix, for places where the surrounding
  /// context already says these are school levels (the selection chips and the
  /// level filter). Keeps the three options on a single row.
  final String compactLabel;

  final String shortLabel;

  const SchoolLevel(this.value, this.label, this.compactLabel, this.shortLabel);
}

const List<SchoolLevel> schoolLevels = <SchoolLevel>[
  SchoolLevel('PRIMARY_SCHOOL', 'Scuola Primaria', 'Primaria', 'Primaria'),
  SchoolLevel('MIDDLE_SCHOOL', 'Scuola Secondaria di I Grado', 'Secondaria di I Grado', 'Sec. I Grado'),
  SchoolLevel('HIGH_SCHOOL', 'Scuola Secondaria di II Grado', 'Secondaria di II Grado', 'Sec. II Grado'),
];

// Unknown values are returned unchanged, so a new backend level shows up as
// its raw code instead of disappearing from the interface.
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

// The heading a programme sits under when programmes are grouped: the level,
// which they all have, and the sector where there is one. Here because the two
// places listing programmes — the one that picks them and the one that only
// shows them — have to group them the same way.
String programScopeTitle({required String level, String? sector})
{
  final String levelLabel = schoolLevelShortLabel(level);

  return sector == null ? levelLabel : '$levelLabel · $sector';
}

// A discipline's description, or null where it says nothing.
//
// A description never written arrives null, a cleared one arrives as an empty
// string, and a half-written one can be two spaces: three ways of having said
// nothing, and whoever shows it has to treat them as one.
String? descriptionOrNull(String? description)
{
  final String? said = description?.trim();

  return said == null || said.isEmpty ? null : said;
}
