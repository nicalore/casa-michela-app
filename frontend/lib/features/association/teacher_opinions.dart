import '../../services/api_service.dart';
import '../people/models/person_item.dart';
import '../people/models/teacher_subject_item.dart';

const String _parentRole = 'PARENT';

const String kTeachersSearchHint = 'Cerca docente...';
const String kTeachersSortHint = 'Ordina per';
const String kSubjectsFilterLabel = 'Discipline';
const String kSubjectsFilterTitle = 'Filtra per disciplina';
const String kSubjectsFilterHint = 'Es. Algebra';
const String kOnlyDislikedLabel = 'Solo non graditi';

const String kTeachersOpinionNote =
    'Questa informazione verrà tenuta in considerazione nella stesura del '
    'calendario delle lezioni, non sarà visibile ai docenti e rimarrà valida '
    'fino a quando non deciderai di rimuoverla.';

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

String teachersIntro({required String verb, String? whoGotOn})
{
  final String intro = "Di seguito trovi tutti i docenti che collaborano con l'Associazione. "
      '$verb su ciascuno di essi puoi visualizzarne alcune informazioni';

  return whoGotOn == null
      ? '$intro.'
      : '$intro e, se lo desideri, indicare quelli con cui $whoGotOn bene.';
}

String whoGotOn(List<OpinionPupil> pupils, {required bool parent})
{
  if (!parent)
  {
    return 'non ti sei ${_gotOn(pupils.single.gender)}';
  }

  if (pupils.length == 1)
  {
    final OpinionPupil child = pupils.single;

    return '${child.firstName} non si è ${_gotOn(child.gender)}';
  }

  final bool allDaughters = pupils.every((child) => child.gender == 'F');

  return allDaughters
      ? 'le tue figlie non si sono trovate'
      : 'i tuoi figli non si sono trovati';
}

String opinionQuestion(PersonItem teacher)
{
  return 'Chi non si è trovato bene con ${_pronounFor(teacher.gender)}?';
}

String opinionSentence(OpinionPupil pupil, PersonItem teacher, {required bool forSelf})
{
  final String pronoun = _pronounFor(teacher.gender);

  return forSelf
      ? 'Non mi sono ${_gotOn(pupil.gender)} bene con $pronoun'
      : '${pupil.firstName} non si è ${_gotOn(pupil.gender)} bene con $pronoun';
}

String taughtSubjectsLabel(int count)
{
  return switch (count)
  {
    0 => 'Nessuna disciplina insegnata.',
    1 => '1 disciplina insegnata',
    _ => '$count discipline insegnate',
  };
}

String teachersFoundLabel(int count) => count == 1 ? '1 docente trovato' : '$count docenti trovati';

enum TeacherSort
{
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  surnameAsc('Cognome (A-Z)'),
  surnameDesc('Cognome (Z-A)');

  final String label;

  const TeacherSort(this.label);

  int compare(PersonItem a, PersonItem b)
  {
    return switch (this)
    {
      TeacherSort.nameAsc => a.firstName.compareTo(b.firstName),
      TeacherSort.nameDesc => b.firstName.compareTo(a.firstName),
      TeacherSort.surnameAsc => a.lastName.compareTo(b.lastName),
      TeacherSort.surnameDesc => b.lastName.compareTo(a.lastName),
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
