import '../../people/models/person_item.dart';
import '../models/calendar_day.dart';

// How long somebody counts as newly joined. Two weeks is what the association
// gives a new docente to be called at least once before the calendar goes out.
const Duration kNewMemberWindow = Duration(days: 14);

String uncalledNewTeacherWarning(String teacher) =>
    'Attenzione: il docente $teacher è iscritto da meno di due settimane e non è stato convocato.';

// The day somebody joined: the start of their first membership. The years
// after it are renewals, so the earliest one is the only one that says when
// they arrived.
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

// The docenti who gave their hours for the fascia, were left without a single
// lesson in it, and joined the association less than two weeks ago.
//
// [day] is the day of the calendar being sent, not today: the question is
// whether they were new when these hours were being handed out, and reading it
// off the clock would answer for a day the calendar is not about.
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
