import '../../people/models/person_item.dart';
import '../models/calendar_day.dart';

// How long somebody counts as newly joined.
const Duration kNewMemberWindow = Duration(days: 14);

String uncalledNewTeacherWarning(String teacher) =>
    'Attenzione: il docente $teacher è iscritto da meno di due settimane e non è stato convocato.';

// Start of the earliest membership: later ones are renewals.
DateTime? joinedTheAssociationOn(PersonItem person)
{
  final memberships = person.memberships;

  if (memberships == null || memberships.isEmpty)
  {
    return null;
  }

  return memberships
      .map((membership) => membership.startDate)
      .reduce((earliest, other) => other.isBefore(earliest) ? other : earliest);
}

bool joinedRecently(PersonItem person, {required DateTime by})
{
  final joined = joinedTheAssociationOn(person);

  return joined != null && by.difference(joined) < kNewMemberWindow;
}

// [day] is the calendar's day, not today: recency is measured against the day
// being published.
List<String> uncalledNewTeacherWarnings({
  required List<TeacherLane> lanes,
  required List<PersonItem> people,
  required DateTime day,
})
{
  final byTaxCode = {for (final person in people) person.fiscalCode: person};

  return [
    for (final lane in lanes)
      if (lane.lessons.isEmpty)
        if (byTaxCode[lane.teacherTaxCode] case final person?)
          if (joinedRecently(person, by: day)) uncalledNewTeacherWarning(lane.teacher.fullName),
  ];
}
