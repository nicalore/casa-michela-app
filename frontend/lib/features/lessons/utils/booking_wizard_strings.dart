import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../models/band_offer.dart';
import 'booking_window.dart';
import 'opening_window.dart';

typedef WizardGuide = ({String question, String hint});

const String kNewBookingTitle = 'Nuova prenotazione';
const String kEditBookingTitle = 'Modifica prenotazione';

const WizardGuide kOwnBookingDaysGuide = (
  question: 'Quando?',
  hint: 'Indica i giorni da prenotare. Puoi indicare anche più giornate.',
);

String _who(String? name) => name ?? 'lo studente';

String _agreed(bool female, String masculine, String feminine) => female ? feminine : masculine;

// [name] null reads "lo studente"; [named] puts it at the end of the question.
WizardGuide presenceModesGuide({required bool isSelf, String? name, required bool named})
{
  return (
    question: isSelf ? 'Con quale modalità vuoi fare lezione?' : 'Con quale modalità vuole fare lezione${named ? ' ${_who(name)}' : ''}?',
    hint: 'In presenza, online, o entrambe.',
  );
}

WizardGuide presenceHoursGuide(String mode, {required bool isSelf, String? name, required bool named, required bool female})
{
  final String who = named ? ' ${_who(name)}' : '';
  final String followed = _agreed(female, 'seguito', 'seguita');

  if (isSelf)
  {
    return mode == kPresenceMode
        ? (
            question: 'Quando sei in Associazione?',
            hint: 'Indica gli orari in cui sarai presente in Associazione.',
          )
        : (
            question: 'Quando puoi essere presente online?',
            hint: 'Indica gli orari in cui sei disponibile per essere $followed a distanza.',
          );
  }

  return mode == kPresenceMode
      ? (
          question: 'Quando è in Associazione$who?',
          hint: 'Indica gli orari in cui ${_who(name)} sarà presente in Associazione.',
        )
      : (
          question: 'Quando può essere presente online$who?',
          hint: 'Indica gli orari in cui ${_who(name)} è disponibile per essere $followed a distanza.',
        );
}

WizardGuide presenceSubjectsGuide(String mode, {required bool isSelf, String? name, required bool named})
{
  if (isSelf)
  {
    return (
      question: mode == kPresenceMode ? 'Che lezioni vuoi fare in Associazione?' : 'Che lezioni vuoi fare online?',
      hint: 'Puoi selezionare una materia del tuo indirizzo di studi, una qualsiasi '
          'disciplina offerta dall\'Associazione, oppure un servizio.',
    );
  }

  final String who = named ? ' ${_who(name)}' : '';

  return (
    question: mode == kPresenceMode ? 'Che lezioni vuole fare in Associazione$who?' : 'Che lezioni vuole fare online$who?',
    hint: 'Puoi selezionare una materia del suo indirizzo di studi, una qualsiasi '
        'disciplina offerta dall\'Associazione, oppure un servizio.',
  );
}

const String kPickDayToGoOn = 'Scegli almeno un giorno per andare avanti.';
const String kPickSubjectToGoOn = 'Scegli almeno una materia per andare avanti.';

String hoursOverlap(String mode, TimeBucket band, [String days = ''])
{
  return 'Gli orari ${modeLabel(mode).toLowerCase()} ${ofBandLabel(band)}$days si sovrappongono.';
}

String hoursToGoOn(String mode) => 'Indica almeno un orario ${modeLabel(mode).toLowerCase()} per andare avanti.';

String bookingDayRefusal(DateTime day, {required bool shut})
{
  final String when = formatAvailableDayLabel(day).toLowerCase();

  return shut ? "L'Associazione è chiusa $when." : 'Le prenotazioni di $when sono chiuse.';
}

String bookingDaysSummary(int count, {required bool split})
{
  return split
      ? 'Le giornate scelte hanno orari di apertura diversi: orari e materie verranno chiesti separatamente.'
      : 'La prenotazione verrà replicata su tutte le $count giornate selezionate.';
}

const String kNotPresent = 'Non presente';
const String kAssociationShutBand = 'Associazione chiusa';
const String kBookingsShutBand = 'Prenotazioni chiuse';

String takenByOtherMode(String other) => 'Già prenotata ${other == kOnlineMode ? kOnScreen : kInBuilding}';

String bandBookedOtherWay(String other) => 'Lo studente ha già una prenotazione ${other == kOnlineMode ? kOnScreen : kInBuilding} in questa fascia.';

String modeShutAllDay(String mode) => "L'Associazione non è aperta ${modeLabel(mode).toLowerCase()} in questa giornata.";

const List<String> kSubjectCategoryLabels = ['Materie', 'Discipline', 'Servizi'];
const List<String> kSubjectSearchHints = ['Cerca materia...', 'Cerca disciplina...', 'Cerca servizio...'];
const List<String> kSubjectNoMatch = [
  'Nessuna materia trovata per questa ricerca.',
  'Nessuna disciplina trovata per questa ricerca.',
  'Nessun servizio trovato per questa ricerca.',
];

const String kNoServices = 'Nessun servizio disponibile.';
const String kFrozenLessonsLabel = 'Lezioni già prenotate';
const String kFrozenLessonsHint = 'Le prenotazioni della loro fascia sono chiuse: non si possono più modificare.';

// [whose] reads "di Giulia" or "dello studente".
String noProgrammeSubjects({required bool isSelf, required String whose})
{
  return isSelf ? 'Il tuo percorso di studi non ha materie collegate.' : 'Il percorso di studi $whose non ha materie collegate.';
}

String allDisciplinesCovered({required bool isSelf, required String whose})
{
  return isSelf ? 'Tutte le discipline sono già sotto le tue materie.' : 'Tutte le discipline sono già sotto le materie $whose.';
}

// [days] names a group's days when there are several, else ''.
const String kPickADayToSave = 'Seleziona almeno una giornata.';
const String kGiveAnHour = 'Indica almeno un orario.';

String onlineSubjectMissing(String days) => 'Scegli almeno una materia online$days.';

String subjectsWithoutHours(String label) => 'Hai chiesto delle materie $label senza indicare gli orari.';

String durationMissing(String name, String label) => 'Indica la durata di $name ($label).';

String lessonKindMissing(String name, String label) => 'Indica il tipo di lezione di $name ($label).';

// [label] names the mode and the band, as "in presenza del pomeriggio".
String disciplineOverBand(String discipline, int minutes, int ceiling, String label)
{
  return '$discipline ($label): ${formatMinutes(minutes)}. Non si possono richiedere più di '
      '${formatMinutes(ceiling)} per fascia su una disciplina.';
}

String bandStayExceeded(TimeBucket band, String days, {required bool isSelf, required String whose})
{
  final String asked = 'Il totale delle ore di lezione richieste ${ofBandLabel(band)}$days';

  return isSelf
      ? '$asked supera il tuo tempo di permanenza in quella fascia.'
      : '$asked supera il tempo di permanenza $whose in quella fascia.';
}

String minutesLeftLabel(int minutes)
{
  if (minutes <= 0)
  {
    return 'Rimaste 0h';
  }

  return minutes == 60 ? 'Rimasta 1h' : 'Rimaste ${formatMinutes(minutes)}';
}

String bandsLeftLabel(List<BandOffer> offers)
{
  return [for (final offer in offers) '${bandLabel(offer.band)}: ${minutesLeftLabel(offer.left)}'].join(' · ');
}

const String kPickBandToGoOn = 'Scegli la fascia per andare avanti.';

String stayExceeded(String days, {required bool isSelf, required String whose})
{
  return isSelf
      ? 'Il totale delle ore di lezione richieste$days supera il tuo tempo di '
          'permanenza in Associazione.'
      : 'Il totale delle ore di lezione richieste$days supera il tempo di permanenza '
          '$whose in Associazione.';
}

// [own]: the reader's bookings rather than an administrator's requests.
String presenceSaved({required bool own, required bool editing, required bool cleared, required int days})
{
  final String what = own ? 'Prenotazione' : 'Richiesta';

  if (editing)
  {
    return cleared ? '$what eliminata con successo!' : '$what modificata con successo!';
  }

  return days == 1 ? '$what creata con successo!' : '$days ${own ? 'prenotazioni' : 'richieste'} create con successo!';
}

const String kAddSubjectTitle = 'Aggiungi materia';
const String kEditSubjectTitle = 'Modifica materia';

enum SubjectRequestStep
{
  band,
  disciplines,
  what,
  duration,
  teachers,
  notes;

  String questionFor({required bool isSelf})
  {
    return switch (this)
    {
      SubjectRequestStep.band => 'In quale fascia?',
      SubjectRequestStep.disciplines => isSelf
          ? 'Cosa devi studiare di questa materia?'
          : 'Cosa deve studiare di questa materia?',
      SubjectRequestStep.what => isSelf ? 'Cosa devi fare durante la lezione?' : 'Cosa deve fare durante la lezione?',
      SubjectRequestStep.duration => 'Quanto deve durare la lezione?',
      SubjectRequestStep.teachers => 'Con quale docente?',
      SubjectRequestStep.notes => 'Altro?',
    };
  }

  String hintFor({required String? studentName, required bool isSelf})
  {
    final String who = studentName ?? 'lo studente';
    final String whose = studentName == null ? 'dello studente' : 'di $studentName';
    final String byWhom = studentName == null ? 'dallo studente' : 'da $studentName';

    return switch (this)
    {
      SubjectRequestStep.band => 'La lezione sarà pianificata solo negli orari della fascia che scegli.',
      SubjectRequestStep.disciplines => 'Almeno uno.',
      SubjectRequestStep.what => 'Almeno una tipologia. Queste informazioni aiuteranno il docente a rendere '
          'la lezione più adatta alle ${isSelf ? 'tue esigenze' : 'esigenze $whose'}.',
      SubjectRequestStep.duration => 'Non è possibile organizzare più di due ore di lezione al giorno per la '
          'stessa materia. Se hai bisogno di altre ore, puoi richiedere una lezione online.',
      SubjectRequestStep.teachers => 'Se vuoi, puoi indicare fino a tre docenti '
          '${isSelf ? 'che preferisci' : 'preferiti $byWhom'}. '
          'Le preferenze indicate verranno tenute in considerazione, ma potrebbero non essere '
          'soddisfatte in base alle esigenze dell\'Associazione.',
      SubjectRequestStep.notes => 'Se lo desideri, puoi inserire qui sotto altre informazioni che ritieni '
          'utili. Le indicazioni saranno lette dal docente che ${isSelf ? 'ti seguirà' : 'seguirà $who'}.',
    };
  }
}

const String kPickDisciplineToGoOn = 'Seleziona almeno una disciplina per andare avanti.';
const String kPickKindToGoOn = 'Seleziona almeno un tipo di lezione per andare avanti.';
const String kPickDurationToGoOn = 'Seleziona la durata per andare avanti.';

String durationOverStay(int taken, int available, {required bool isSelf, String? name, TimeBucket? band})
{
  return 'La durata totale delle lezioni${band == null ? '' : ' ${ofBandLabel(band)}'} è ${formatMinutes(taken)}, ma '
      '${isSelf ? 'sei presente' : '${name ?? 'lo studente'} è presente'} '
      'per ${formatMinutes(available)}.';
}

String bandTimeAllTaken(String mode, TimeBucket band)
{
  return 'Le ore ${modeLabel(mode).toLowerCase()} ${ofBandLabel(band)} sono già tutte occupate dalle altre lezioni.';
}

String disciplineOverCeiling(String discipline, int minutes, int ceiling)
{
  return '$discipline: ${formatMinutes(minutes)} in questa fascia. Su una stessa disciplina '
      'non si può andare oltre ${formatMinutes(ceiling)} per fascia.';
}

const String kLessonKindLabel = 'Tipo di lezione';
const String kTopicLabel = 'Argomento (opzionale)';
const String kTopicHint = 'Es. Disequazioni di secondo grado';
const String kDurationLabel = 'Durata';
const String kTeacherNotesLabel = 'Note per il docente';
const String kTeacherNotesHint = 'Inserisci...';

const String kRemoveSubjectLink = 'Rimuovi materia';
const String kRemovalEyebrow = 'Rimozione';
const String kSubjectRemovalBefore = 'La materia ';
const String kSubjectRemovalAfter = ' verrà rimossa.';

String preferredTeachersLabel(String? gender) => 'Mi sono ${gender == 'F' ? 'trovata' : 'trovato'} meglio con...';

const String kNoTeachers = "Nessun docente presente nell'anagrafica.";
const String kSearchTeacher = 'Cerca docente...';
const String kTeachersFull = 'Tre è il massimo: rimuovine uno per cambiarli';
const String kTeachersFullNoMatch = 'Ne hai già scelti tre.';
const String kNoTeacherMatch = 'Nessun docente trovato.';
