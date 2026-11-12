import '../../association/models/ministry_subject_item.dart';

bool nameFound(String name, String query) => name.toLowerCase().contains(query.trim().toLowerCase());

// Every discipline once the search names the subject, otherwise those it names.
List<AssociationSubjectOption> disciplinesFound(MinistrySubjectItem subject, String query)
{
  if (nameFound(subject.name, query))
  {
    return subject.associationSubjects;
  }

  return subject.associationSubjects.where((discipline) => nameFound(discipline.name, query)).toList();
}

bool subjectFound(MinistrySubjectItem subject, String query)
{
  return nameFound(subject.name, query) || disciplinesFound(subject, query).isNotEmpty;
}

// A discipline answers the search: its group opens on it, whatever the subject's own name says.
bool foundInside(MinistrySubjectItem subject, String query)
{
  return query.trim().isNotEmpty && subject.associationSubjects.any((discipline) => nameFound(discipline.name, query));
}

// Subjects with several disciplines first, then those with one, each keeping its order.
List<MinistrySubjectItem> dividedFirst(Iterable<MinistrySubjectItem> subjects)
{
  final List<MinistrySubjectItem> all = subjects.toList();

  return [
    ...all.where((subject) => subject.associationSubjects.length > 1),
    ...all.where((subject) => subject.associationSubjects.length <= 1),
  ];
}
