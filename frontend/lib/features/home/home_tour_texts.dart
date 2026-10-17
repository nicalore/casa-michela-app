// Said alike by the mobile and the desktop home tours.

const String kTeacherTodayTourText =
    "Qui puoi vedere le disponibilità che hai dato per oggi e l'eventuale convocazione.";
const String kTeacherMonthTourText =
    'Qui puoi leggere alcune statistiche sul mese corrente: disponibilità date, ore di lezione ed eventuale compenso accumulato.';

const String kStudentTodayTourText = 'Qui puoi vedere un riepilogo degli orari e delle lezioni prenotate per oggi.';

const String kHomeNoticesTourText =
    "Qui puoi trovare le notifiche dell'app e le ultime comunicazioni inviate dal Direttivo di Casa Michela.";

// [answeredFor]: a parent answers for the student, who then sees no payments.
String studentMonthTourText({required bool answeredFor})
{
  return answeredFor
      ? 'Qui puoi leggere alcune statistiche sul mese corrente: presenze, giorni prenotati e ore di lezione.'
      : 'Qui puoi leggere alcune statistiche sul mese corrente: presenze, giorni prenotati, ore di lezione e pagamenti.';
}

// [genders] has one entry per child, 'F' for a daughter.
String parentTodayTourText(List<String?> genders)
{
  return 'Qui puoi vedere un riepilogo delle lezioni prenotate per ${_yourChildren(genders)}.';
}

String parentMonthTourText(List<String?> genders)
{
  return 'Qui puoi leggere alcune statistiche sul mese corrente per ${_eachChild(genders)}: presenze, giorni '
      'prenotati, ore di lezione e pagamenti.';
}

bool _daughters(List<String?> genders) => genders.isNotEmpty && genders.every((gender) => gender == 'F');

// Daughters only take the feminine; without children the plural stands.
String _yourChildren(List<String?> genders)
{
  if (genders.length == 1)
  {
    return _daughters(genders) ? 'tua figlia' : 'tuo figlio';
  }

  return _daughters(genders) ? 'le tue figlie' : 'i tuoi figli';
}

String _eachChild(List<String?> genders)
{
  if (genders.length == 1)
  {
    return _daughters(genders) ? 'tua figlia' : 'tuo figlio';
  }

  return _daughters(genders) ? 'ciascuna figlia' : 'ciascun figlio';
}
