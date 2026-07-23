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
  final String shortLabel;

  const SchoolLevel(this.value, this.label, this.shortLabel);
}

const List<SchoolLevel> schoolLevels = <SchoolLevel>[
  SchoolLevel('PRIMARY_SCHOOL', 'Scuola Primaria', 'Primaria'),
  SchoolLevel('MIDDLE_SCHOOL', 'Scuola Secondaria di I Grado', 'Sec. I Grado'),
  SchoolLevel('HIGH_SCHOOL', 'Scuola Secondaria di II Grado', 'Sec. II Grado'),
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