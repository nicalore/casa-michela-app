import '../../core/language/app_language.dart';
import '../../services/api_service.dart';
import '../people/models/person_face.dart';
import '../people/models/person_item.dart';
import '../people/models/teacher_subject_item.dart';

const String _parentRole = 'PARENT';

String get kTeachersSearchHint => tr('Cerca docente...', 'Search teachers...');
String get kTeachersSortHint => tr('Ordina per', 'Sort by');
String get kSubjectsFilterLabel => tr('Discipline', 'Disciplines');
String get kSubjectsFilterTitle => tr('Filtra per disciplina', 'Filter by discipline');
String get kSubjectsFilterHint => tr('Es. Algebra', 'E.g. Algebra');
String get kOnlyDislikedLabel => tr('Solo non graditi', 'Only those not liked');

String get kTeachersOpinionNote => tr(
  'Questa informazione verrà tenuta in considerazione nella stesura del '
      'calendario delle lezioni, non sarà visibile ai docenti e rimarrà valida '
      'fino a quando non deciderai di rimuoverla.',
  'This information will be taken into account when drawing up the '
      'lesson calendar, will not be visible to teachers and will remain valid '
      'until you decide to remove it.',
);

bool canSpeakFor(String role)
{
  final identity = ApiService().lastKnownIdentity;
  final bool answeredFor = identity?.hasParentalResponsibility ?? false;

  return role == _parentRole || !answeredFor || (identity?.autonomousBookings ?? false);
}

class OpinionPupil
{
  final String taxCode;
  final String firstName;
  final String? gender;

  final Set<String> disliked;

  // Sent with each write; the server refuses writes against a stale stamp.
  final DateTime? updatedAt;

  OpinionPupil.of(PersonItem person)
      : taxCode = person.fiscalCode,
        firstName = person.firstName,
        gender = person.gender,
        disliked = person.notPreferredTeacherTaxCodes.toSet(),
        updatedAt = person.studentUpdatedAt;

  bool dislikes(PersonItem teacher) => disliked.contains(teacher.fiscalCode);
}

String _pronounFor(String? gender)
{
  return switch (gender)
  {
    'F' => 'lei',
    'M' => 'lui',
    _ => 'lui/lei',
  };
}

String _gotOn(String? gender) => gender == 'F' ? 'trovata' : 'trovato';

String _englishPronounFor(String? gender)
{
  return switch (gender)
  {
    'F' => 'her',
    'M' => 'him',
    _ => 'them',
  };
}

// Asked of several pupils: feminine only when all are girls.
String opinionQuestion(PersonItem teacher, List<OpinionPupil> pupils)
{
  final String gotOn = pupils.every((pupil) => pupil.gender == 'F') ? 'trovata' : 'trovato';

  return tr(
    'Chi non si è $gotOn bene con ${_pronounFor(teacher.gender)}?',
    "Who didn't get on well with ${_englishPronounFor(teacher.gender)}?",
  );
}

String opinionSentence(OpinionPupil pupil, PersonItem teacher, {required bool forSelf})
{
  final String pronoun = _pronounFor(teacher.gender);
  final String englishPronoun = _englishPronounFor(teacher.gender);

  return forSelf
      ? tr('Non mi sono ${_gotOn(pupil.gender)} bene con $pronoun', "I didn't get on well with $englishPronoun")
      : tr(
          '${pupil.firstName} non si è ${_gotOn(pupil.gender)} bene con $pronoun',
          "${pupil.firstName} didn't get on well with $englishPronoun",
        );
}

String taughtSubjectsLabel(int count)
{
  return switch (count)
  {
    0 => tr('Nessuna disciplina insegnata.', 'No disciplines taught.'),
    1 => tr('1 disciplina insegnata', '1 discipline taught'),
    _ => tr('$count discipline insegnate', '$count disciplines taught'),
  };
}

String teachersFoundLabel(int count) => count == 1
    ? tr('1 docente trovato', '1 teacher found')
    : tr('$count docenti trovati', '$count teachers found');

enum TeacherSort
{
  nameAsc,
  nameDesc,
  surnameAsc,
  surnameDesc;

  String get label => switch (this)
  {
    TeacherSort.nameAsc => tr('Nome (A-Z)', 'First name (A-Z)'),
    TeacherSort.nameDesc => tr('Nome (Z-A)', 'First name (Z-A)'),
    TeacherSort.surnameAsc => tr('Cognome (A-Z)', 'Surname (A-Z)'),
    TeacherSort.surnameDesc => tr('Cognome (Z-A)', 'Surname (Z-A)'),
  };

  int compare(PersonItem a, PersonItem b)
  {
    return switch (this)
    {
      TeacherSort.nameAsc => compareByName(a, b),
      TeacherSort.nameDesc => compareByName(b, a),
      TeacherSort.surnameAsc => compareBySurname(a, b),
      TeacherSort.surnameDesc => compareBySurname(b, a),
    };
  }
}

List<TeacherSubjectItem> subjectsOf(PersonItem teacher)
{
  return teacher.teacherSubjects ?? const <TeacherSubjectItem>[];
}

bool teachesOneOf(PersonItem teacher, Set<int> subjectIds)
{
  return subjectsOf(teacher).any((subject) => subjectIds.contains(subject.subjectId));
}

Map<int, TeacherSubjectItem> taughtSubjectsOf(List<PersonItem> teachers)
{
  return {
    for (final teacher in teachers)
      for (final subject in subjectsOf(teacher)) subject.subjectId: subject,
  };
}

Future<List<OpinionPupil>> readOpinionPupils({required bool parent}) async
{
  final ApiService api = ApiService();
  final me = api.lastKnownIdentity ?? await api.me();
  final PersonItem reader = await api.getPerson(me.taxCode);

  if (!parent)
  {
    return [OpinionPupil.of(reader)];
  }

  final List<PersonItem> children = await Future.wait([
    for (final child in reader.children ?? const []) api.getPerson(child.fiscalCode),
  ]);

  return [for (final child in children) OpinionPupil.of(child)];
}

// Refetched after the write for the stamp the next write must carry.
Future<OpinionPupil> saveTeacherOpinion(OpinionPupil pupil, PersonItem teacher, bool disliked) async
{
  final ApiService api = ApiService();
  final Set<String> codes = {...pupil.disliked};

  if (disliked)
  {
    codes.add(teacher.fiscalCode);
  }
  else
  {
    codes.remove(teacher.fiscalCode);
  }

  await api.updateNotPreferredTeachers(pupil.taxCode, codes.toList(), pupil.updatedAt);

  return OpinionPupil.of(await api.getPerson(pupil.taxCode));
}
