import '../../../core/utils/role_label_mapper.dart';
import '../models/people_filter_state.dart';
import '../models/person_item.dart';

// Must match RoleLabelMapper's spelling.
const String _studentRoleLabel = 'Studente';

// Open-ended bucket; label and threshold must stay in step with the filter dialog.
const String _openEndedChildrenCount = '4+';
const int _openEndedChildrenThreshold = 4;

// Only a minor is asked for leave: an adult matches neither yes nor no.
bool matchesEarlyExit(PersonItem person, bool? expected)
{
  if (expected == null)
  {
    return true;
  }

  return !person.isAdult && person.earlyExit == expected;
}

bool _matchesRoles(PersonItem person, PeopleFilterState filter)
{
  final selectedRoles = filter.selectedRoles;

  if (selectedRoles.isEmpty)
  {
    return true;
  }

  final specificRoles = selectedRoles.where((role) => role != RoleLabelMapper.memberLabel);

  if (person.shownRoles.any(specificRoles.contains))
  {
    return true;
  }

  // "Associato" matches plain members only, not teachers or students.
  return selectedRoles.contains(RoleLabelMapper.memberLabel) &&
      RoleLabelMapper.hasOnlyMemberRole(person.shownRoles);
}

bool _matchesAgeRange(PersonItem person, PeopleFilterState filter)
{
  final range = filter.ageRange;

  if (range == null)
  {
    return true;
  }

  final age = person.age;

  if (age == null)
  {
    return false;
  }

  if (age >= range.start && age <= range.end)
  {
    return true;
  }

  // The top of the slider means "this age and above".
  return range.end == PeopleFilterState.defaultAgeRange.end &&
      age >= PeopleFilterState.defaultAgeRange.end;
}

bool _matchesChildrenCount(PersonItem person, PeopleFilterState filter)
{
  final expected = filter.childrenCount;

  if (expected == null)
  {
    return true;
  }

  final count = person.childrenCount;

  if (count == null)
  {
    return false;
  }

  // The last option is open ended rather than an exact figure.
  if (expected == _openEndedChildrenCount)
  {
    return count >= _openEndedChildrenThreshold;
  }

  return count.toString() == expected;
}

bool _matchesSubjects(PersonItem person, PeopleFilterState filter)
{
  // Selecting several subjects means "teaches all of them", not "any of them".
  if (!filter.taughtSubjects.every(person.taughtSubjects.contains))
  {
    return false;
  }

  final range = filter.taughtSubjectsCount;

  if (range == null)
  {
    return true;
  }

  final count = person.taughtSubjects.length;

  if (count >= range.start && count <= range.end)
  {
    return true;
  }

  return range.end == PeopleFilterState.defaultTaughtSubjectsCount.end &&
      count >= PeopleFilterState.defaultTaughtSubjectsCount.end;
}

bool _matchesMethodologicalNotes(PersonItem person, PeopleFilterState filter)
{
  final expected = filter.hasMethodologicalNotes;

  return expected == null || (person.methodologicalNotes ?? const []).isNotEmpty == expected;
}

bool _matchesText(String? value, String? expected)
{
  if (expected == null || expected.isEmpty)
  {
    return true;
  }

  return value?.toLowerCase() == expected.toLowerCase();
}

bool _matchesExactly(Object? value, Object? expected)
{
  return expected == null || value == expected;
}

// Every filter but the search text.
bool matchesPeopleFilter(PersonItem person, PeopleFilterState filter)
{
  return _matchesRoles(person, filter) &&
      _matchesAgeRange(person, filter) &&
      _matchesChildrenCount(person, filter) &&
      _matchesSubjects(person, filter) &&
      filter.matchesCertification(
        certificationTypes: person.certificationTypes,
        isStudent: person.roles.contains(_studentRoleLabel),
      ) &&
      _matchesMethodologicalNotes(person, filter) &&
      filter.matchesBirthNation(person.birthNation) &&
      PeopleFilterState.matchesAny(person.birthCity, filter.birthCities) &&
      PeopleFilterState.matchesAny(person.city, filter.cities) &&
      PeopleFilterState.matchesAny(person.schoolName, filter.schoolNames) &&
      PeopleFilterState.matchesAny(person.studyProgram, filter.studyPrograms) &&
      _matchesText(person.courseType, filter.courseType) &&
      _matchesExactly(person.isActiveCollaborator, filter.isActiveCollaborator) &&
      _matchesExactly(person.enrollmentYear, filter.enrollmentYear) &&
      _matchesExactly(person.educationLevel, filter.educationLevel) &&
      _matchesExactly(person.schoolClass, filter.schoolClass) &&
      matchesEarlyExit(person, filter.earlyExit) &&
      _matchesExactly(person.collaborationType, filter.collaborationType) &&
      _matchesExactly(person.isMedicalCertificateValid, filter.isMedicalCertificateValid);
}
