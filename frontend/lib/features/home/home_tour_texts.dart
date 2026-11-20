// Said alike by the mobile and the desktop home tours.

import '../../core/language/app_language.dart';

String get kTeacherTodayTourText => tr(
    "Qui puoi vedere le disponibilità che hai dato per oggi e l'eventuale convocazione.",
    'Here you can see the availability you gave for today and whether you have been called in.',
);
String get kTeacherMonthTourText => tr(
    'Qui puoi leggere alcune statistiche sul mese corrente: disponibilità date, ore di lezione ed eventuale compenso accumulato.',
    'Here you can read some statistics on the current month: availability given, lesson hours and any pay earned.',
);

String get kStudentTodayTourText => tr('Qui puoi vedere un riepilogo degli orari e delle lezioni prenotate per oggi.', 'Here you can see a summary of the hours and of the lessons booked for today.');

String get kHomeNoticesTourText => tr(
    "Qui puoi trovare le notifiche dell'app e le ultime comunicazioni inviate dal Direttivo di Casa Michela.",
    "Here you can find the app's notifications and the latest announcements sent by the Casa Michela Board.",
);

// [answeredFor]: a parent answers for the student, who then sees no payments.
String studentMonthTourText({required bool answeredFor})
{
  return answeredFor
      ? tr(
          'Qui puoi leggere alcune statistiche sul mese corrente: presenze, giorni prenotati e ore di lezione.',
          'Here you can read some statistics on the current month: attendance, days booked and lesson hours.',
        )
      : tr(
          'Qui puoi leggere alcune statistiche sul mese corrente: presenze, giorni prenotati, ore di lezione e pagamenti.',
          'Here you can read some statistics on the current month: attendance, days booked, lesson hours and payments.',
        );
}

// [genders] has one entry per child, 'F' for a daughter.
String parentTodayTourText(List<String?> genders)
{
  return tr(
    'Qui puoi vedere un riepilogo delle lezioni prenotate per ${_yourChildren(genders)}.',
    'Here you can see a summary of the lessons booked for ${_yourChildren(genders)}.',
  );
}

String parentMonthTourText(List<String?> genders)
{
  return tr(
    'Qui puoi leggere alcune statistiche sul mese corrente per ${_eachChild(genders)}: presenze, giorni '
        'prenotati, ore di lezione e pagamenti.',
    'Here you can read some statistics on the current month for ${_eachChild(genders)}: attendance, days '
        'booked, lesson hours and payments.',
  );
}

bool _daughters(List<String?> genders) => genders.isNotEmpty && genders.every((gender) => gender == 'F');

// Daughters only take the feminine; without children the plural stands.
String _yourChildren(List<String?> genders)
{
  if (genders.length == 1)
  {
    return _daughters(genders) ? tr('tua figlia', 'your child') : tr('tuo figlio', 'your child');
  }

  return _daughters(genders) ? tr('le tue figlie', 'your children') : tr('i tuoi figli', 'your children');
}

String _eachChild(List<String?> genders)
{
  if (genders.length == 1)
  {
    return _daughters(genders) ? tr('tua figlia', 'your child') : tr('tuo figlio', 'your child');
  }

  return _daughters(genders) ? tr('ciascuna figlia', 'each child') : tr('ciascun figlio', 'each child');
}
