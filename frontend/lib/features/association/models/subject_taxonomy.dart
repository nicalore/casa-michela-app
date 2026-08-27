// Values must stay aligned with the backend enums.

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

// Unknown values are returned unchanged so new backend codes stay visible.
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

  // Without the "Scuola" prefix, for contexts that already say so.
  final String compactLabel;

  final String shortLabel;

  const SchoolLevel(this.value, this.label, this.compactLabel, this.shortLabel);
}

const List<SchoolLevel> schoolLevels = <SchoolLevel>[
  SchoolLevel('PRIMARY_SCHOOL', 'Scuola Primaria', 'Primaria', 'Primaria'),
  SchoolLevel('MIDDLE_SCHOOL', 'Scuola Secondaria di I Grado', 'Secondaria di I Grado', 'Sec. I Grado'),
  SchoolLevel('HIGH_SCHOOL', 'Scuola Secondaria di II Grado', 'Secondaria di II Grado', 'Sec. II Grado'),
];

// Unknown values are returned unchanged so new backend codes stay visible.
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

// Shared so every place listing programmes groups them the same way.
String programScopeTitle({required String level, String? sector})
{
  final String levelLabel = schoolLevelShortLabel(level);

  return sector == null ? levelLabel : '$levelLabel · $sector';
}

// Null, empty, and whitespace-only descriptions are all treated as absent.
String? descriptionOrNull(String? description)
{
  final String? said = description?.trim();

  return said == null || said.isEmpty ? null : said;
}
