import '../../../core/language/app_language.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import 'booking_window.dart';
import 'opening_window.dart';

typedef WizardGuide = ({String question, String hint});

String get kNewBookingTitle => tr('Nuova prenotazione', 'New booking');
String get kEditBookingTitle => tr('Modifica prenotazione', 'Edit booking');

WizardGuide get kOwnBookingDaysGuide => (
  question: tr('Quando?', 'When?'),
  hint: tr(
    'Indica i giorni da prenotare. Puoi indicare anche più giornate.',
    'Choose the days to book. You can choose more than one.',
  ),
);

String _who(String? name) => name ?? tr('lo studente', 'the student');

// "di Giulia" or "dello studente"; in English "Giulia's" or "the student's".
String whoseLabel(String? name)
{
  return name == null ? tr('dello studente', "the student's") : tr('di $name', "$name's");
}

String _capitalised(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

String _agreed(bool female, String masculine, String feminine) => female ? feminine : masculine;

// English only: "online" or "in-person", before a noun.
String _modeBefore(String mode) => mode == kOnlineMode ? 'online' : 'in-person';

// [name] null reads "lo studente"; [named] puts it at the end of the question.
WizardGuide presenceModesGuide({required bool isSelf, String? name, required bool named})
{
  final String english = named ? _who(name) : 'the student';

  return (
    question: isSelf
        ? tr('Con quale modalità vuoi fare lezione?', 'How would you like to have your lessons?')
        : tr('Con quale modalità vuole fare lezione${named ? ' ${_who(name)}' : ''}?', 'How would $english like to have lessons?'),
    hint: tr('In presenza, online, o entrambe.', 'In person, online, or both.'),
  );
}

WizardGuide presenceHoursGuide(String mode, {required bool isSelf, String? name, required bool named, required bool female})
{
  final String who = named ? ' ${_who(name)}' : '';
  final String english = named ? _who(name) : 'the student';
  final String followed = _agreed(female, 'seguito', 'seguita');

  if (isSelf)
  {
    return mode == kPresenceMode
        ? (
            question: tr('Quando sei in Associazione?', 'When are you at the Association?'),
            hint: tr('Indica gli orari in cui sarai presente in Associazione.', 'Enter the times when you will be at the Association.'),
          )
        : (
            question: tr('Quando puoi essere presente online?', 'When can you be online?'),
            hint: tr(
              'Indica gli orari in cui sei disponibile per essere $followed a distanza.',
              'Enter the times when you are available to be taught remotely.',
            ),
          );
  }

  return mode == kPresenceMode
      ? (
          question: tr('Quando è in Associazione$who?', 'When is $english at the Association?'),
          hint: tr(
            'Indica gli orari in cui ${_who(name)} sarà presente in Associazione.',
            'Enter the times when ${_who(name)} will be at the Association.',
          ),
        )
      : (
          question: tr('Quando può essere presente online$who?', 'When can $english be online?'),
          hint: tr(
            'Indica gli orari in cui ${_who(name)} è disponibile per essere $followed a distanza.',
            'Enter the times when ${_who(name)} is available to be taught remotely.',
          ),
        );
}

WizardGuide presenceSubjectsGuide(String mode, {required bool isSelf, String? name, required bool named})
{
  if (isSelf)
  {
    return (
      question: mode == kPresenceMode
          ? tr('Che lezioni vuoi fare in Associazione?', 'Which lessons would you like at the Association?')
          : tr('Che lezioni vuoi fare online?', 'Which lessons would you like online?'),
      hint: tr(
        'Puoi selezionare una materia del tuo indirizzo di studi, una qualsiasi '
            'disciplina offerta dall\'Associazione, oppure un servizio.',
        'You can choose a subject from your course of study, any discipline offered by the Association, or a service.',
      ),
    );
  }

  final String who = named ? ' ${_who(name)}' : '';
  final String english = named ? _who(name) : 'the student';

  return (
    question: mode == kPresenceMode
        ? tr('Che lezioni vuole fare in Associazione$who?', 'Which lessons would $english like at the Association?')
        : tr('Che lezioni vuole fare online$who?', 'Which lessons would $english like online?'),
    hint: tr(
      'Puoi selezionare una materia del suo indirizzo di studi, una qualsiasi '
          'disciplina offerta dall\'Associazione, oppure un servizio.',
      'You can choose a subject from their course of study, any discipline offered by the Association, or a service.',
    ),
  );
}

String get kPickDayToGoOn => tr('Scegli almeno un giorno per andare avanti.', 'Choose at least one day to continue.');
String get kPickSubjectToGoOn => tr('Scegli almeno una materia per andare avanti.', 'Choose at least one subject to continue.');

String hoursOverlap(String mode, TimeBucket band, [String days = ''])
{
  return tr(
    'Gli orari ${modeLabel(mode).toLowerCase()} ${ofBandLabel(band)}$days si sovrappongono.',
    'The ${_modeBefore(mode)} ${bandLabel(band).toLowerCase()} times$days overlap.',
  );
}

String hoursToGoOn(String mode)
{
  return tr(
    'Indica almeno un orario ${modeLabel(mode).toLowerCase()} per andare avanti.',
    'Enter at least one ${_modeBefore(mode)} time to continue.',
  );
}

String bookingDayRefusal(DateTime day, {required bool shut})
{
  final String when = formatAvailableDayInSentence(day);

  return shut
      ? tr("L'Associazione è chiusa $when.", 'The Association is closed on $when.')
      : tr('Le prenotazioni di $when sono chiuse.', 'Bookings for $when are closed.');
}

String bookingDaysSummary(int count, {required bool split})
{
  return split
      ? tr(
          'Le giornate scelte hanno orari di apertura diversi: orari e materie verranno chiesti separatamente.',
          'The chosen days have different opening hours: times and subjects will be asked for separately.',
        )
      : tr(
          'La prenotazione verrà replicata su tutte le $count giornate selezionate.',
          'The booking will be repeated on all $count selected days.',
        );
}

String get kNotPresent => tr('Non presente', 'Not present');
String get kAssociationShutBand => tr('Associazione chiusa', 'Association closed');
String get kBookingsShutBand => tr('Prenotazioni chiuse', 'Bookings closed');
String get kBandBegun => tr('Già passata', 'Already passed');
String get kSubjectLessonBegun => tr('La lezione di questa materia è già cominciata.', 'The lesson for this subject has already started.');

String takenByOtherMode(String other)
{
  final String how = other == kOnlineMode ? kOnScreen : kInBuilding;

  return tr('Già prenotata $how', 'Already booked $how');
}

// Whose booking a refusal speaks of; [name] null reads "Lo studente" or "La studentessa".
typedef BookingPupil = ({bool isSelf, String? name, String? gender});

const BookingPupil kAnyPupil = (isSelf: false, name: null, gender: null);

String bandBookedOtherWay(String other, [BookingPupil who = kAnyPupil])
{
  final String how = other == kOnlineMode ? kOnScreen : kInBuilding;

  if (who.isSelf)
  {
    return tr('Hai già una prenotazione $how in questa fascia.', 'You already have an ${_modeBefore(other)} booking in this time slot.');
  }

  final String name = who.name ?? tr(who.gender == 'F' ? 'La studentessa' : 'Lo studente', 'The student');

  return tr('$name ha già una prenotazione $how in questa fascia.', '$name already has an ${_modeBefore(other)} booking in this time slot.');
}

String modeShutAllDay(String mode)
{
  return tr(
    "L'Associazione non è aperta ${modeLabel(mode).toLowerCase()} in questa giornata.",
    'The Association is not open ${mode == kOnlineMode ? kOnScreen : kInBuilding} on this day.',
  );
}

List<String> get kSubjectCategoryLabels => [
  tr('Materie', 'Subjects'),
  tr('Discipline', 'Disciplines'),
  tr('Servizi', 'Services'),
];

List<String> get kSubjectSearchHints => [
  tr('Cerca materia...', 'Search subjects...'),
  tr('Cerca disciplina...', 'Search disciplines...'),
  tr('Cerca servizio...', 'Search services...'),
];

List<String> get kSubjectNoMatch => [
  tr('Nessuna materia trovata per questa ricerca.', 'No subjects found for this search.'),
  tr('Nessuna disciplina trovata per questa ricerca.', 'No disciplines found for this search.'),
  tr('Nessun servizio trovato per questa ricerca.', 'No services found for this search.'),
];

// Under a subject with a single discipline, before its name.
String get kSingleDisciplineLabel => tr('Disciplina: ', 'Discipline: ');

String get kNoServices => tr('Nessun servizio disponibile.', 'No services available.');
String get kFrozenLessonsLabel => tr('Lezioni già prenotate', 'Lessons already booked');
String get kFrozenLessonsHint => tr(
  'Le prenotazioni della loro fascia sono chiuse: non si possono più modificare.',
  'Bookings for their time slot are closed: they can no longer be changed.',
);

// [whose] from whoseLabel: "di Giulia" or "dello studente".
String noProgrammeSubjects({required bool isSelf, required String whose})
{
  return isSelf
      ? tr('Il tuo percorso di studi non ha materie collegate.', 'Your study programme has no linked subjects.')
      : tr('Il percorso di studi $whose non ha materie collegate.', '${_capitalised(whose)} study programme has no linked subjects.');
}

String allDisciplinesCovered({required bool isSelf, required String whose})
{
  return isSelf
      ? tr('Tutte le discipline sono già sotto le tue materie.', 'All disciplines are already under your subjects.')
      : tr('Tutte le discipline sono già sotto le materie $whose.', 'All disciplines are already under $whose subjects.');
}

// [days] names a group's days when there are several, else ''.
String get kPickADayToSave => tr('Seleziona almeno una giornata.', 'Select at least one day.');
String get kGiveAnHour => tr('Indica almeno un orario.', 'Enter at least one time.');

String subjectMissing(String mode, String days) => tr('Scegli almeno una materia.', 'Choose at least one subject.');

String subjectsWithoutHours(String label)
{
  return tr('Hai chiesto delle materie $label senza indicare gli orari.', 'You asked for subjects $label without entering the times.');
}

String durationMissing(String name, String label) => tr('Indica la durata di $name ($label).', 'Enter the duration of $name ($label).');

String lessonKindMissing(String name, String label)
{
  return tr('Indica il tipo di lezione di $name ($label).', 'Enter the lesson type for $name ($label).');
}

String bandStayExceeded(TimeBucket band, String days, {required bool isSelf, required String whose})
{
  final String asked = 'Il totale delle ore di lezione richieste ${ofBandLabel(band)}$days';
  final String english = 'The total lesson time requested for the ${bandLabel(band).toLowerCase()}$days';

  return isSelf
      ? tr('$asked supera il tuo tempo di permanenza in quella fascia.', '$english is longer than your stay in that time slot.')
      : tr('$asked supera il tempo di permanenza $whose in quella fascia.', '$english is longer than $whose stay in that time slot.');
}

String minutesLeftLabel(int minutes)
{
  if (minutes <= 0)
  {
    return tr('Rimaste 0h', '0h left');
  }

  return minutes == 60 ? tr('Rimasta 1h', '1h left') : tr('Rimaste ${formatMinutes(minutes)}', '${formatMinutes(minutes)} left');
}

// Lower case, for inside brackets.
String minutesLeftNote(int minutes)
{
  if (minutes <= 0)
  {
    return tr('rimaste 0h', '0h left');
  }

  return minutes == 60 ? tr('rimasta 1h', '1h left') : tr('rimaste ${formatMinutes(minutes)}', '${formatMinutes(minutes)} left');
}

String get kPickBandToGoOn => tr('Scegli la fascia per andare avanti.', 'Choose the time slot to continue.');
String get kPickDurationToGoOn => tr('Scegli la durata per andare avanti.', 'Choose the duration to continue.');

String stayExceeded(String days, {required bool isSelf, required String whose})
{
  return isSelf
      ? tr(
          'Il totale delle ore di lezione richieste$days supera il tuo tempo di '
              'permanenza in Associazione.',
          'The total lesson time requested$days is longer than your stay at the Association.',
        )
      : tr(
          'Il totale delle ore di lezione richieste$days supera il tempo di permanenza '
              '$whose in Associazione.',
          'The total lesson time requested$days is longer than $whose stay at the Association.',
        );
}

// [own]: the reader's bookings rather than an administrator's requests.
String presenceSaved({required bool own, required bool editing, required bool cleared, required int days})
{
  final String what = own ? tr('Prenotazione', 'Booking') : tr('Richiesta', 'Request');

  if (editing)
  {
    return cleared
        ? tr('$what eliminata con successo!', '$what deleted successfully!')
        : tr('$what modificata con successo!', '$what updated successfully!');
  }

  if (days == 1)
  {
    return tr('$what creata con successo!', '$what created successfully!');
  }

  return own
      ? tr('$days prenotazioni create con successo!', '$days bookings created successfully!')
      : tr('$days richieste create con successo!', '$days requests created successfully!');
}

String get kAddSubjectTitle => tr('Aggiungi materia', 'Add subject');
String get kEditSubjectTitle => tr('Modifica materia', 'Edit subject');

enum SubjectRequestStep
{
  band,
  what,
  duration,
  teachers,
  notes;

  String questionFor({required bool isSelf})
  {
    return switch (this)
    {
      SubjectRequestStep.band => tr('In quale fascia?', 'Which time slot?'),
      SubjectRequestStep.what => isSelf
          ? tr('Cosa devi fare durante la lezione?', 'What do you need to do in the lesson?')
          : tr('Cosa deve fare durante la lezione?', 'What does the student need to do in the lesson?'),
      SubjectRequestStep.duration => tr('Quanto deve durare la lezione?', 'How long should the lesson last?'),
      SubjectRequestStep.teachers => tr('Con quale docente?', 'Which teacher?'),
      SubjectRequestStep.notes => tr('Altro?', 'Anything else?'),
    };
  }

  String hintFor({required String? studentName, required bool isSelf})
  {
    final String who = studentName ?? tr('lo studente', 'the student');
    final String whose = whoseLabel(studentName);
    final String byWhom = studentName == null ? 'dallo studente' : 'da $studentName';

    return switch (this)
    {
      SubjectRequestStep.band => tr(
        'La lezione sarà pianificata solo negli orari della fascia che scegli.',
        'The lesson will only be planned within the hours of the time slot you choose.',
      ),
      SubjectRequestStep.what => tr(
        'Almeno una tipologia. Queste informazioni saranno lette dal docente e lo aiuteranno a rendere '
            'la lezione più adatta alle ${isSelf ? 'tue esigenze' : 'esigenze $whose'}.',
        'At least one type. The teacher will read this information, and it will help them suit the lesson to '
            '${isSelf ? 'your needs' : '$whose needs'}.',
      ),
      SubjectRequestStep.duration => kBookingLengthLimits,
      SubjectRequestStep.teachers => tr(
        'Se vuoi, puoi indicare fino a tre docenti '
            '${isSelf ? 'che preferisci' : 'preferiti $byWhom'}. '
            'Le preferenze indicate verranno tenute in considerazione, ma potrebbero non essere '
            'soddisfatte in base alle esigenze dell\'Associazione.',
        'If you like, you can name up to three teachers '
            '${isSelf ? 'you prefer' : 'preferred by $who'}. '
            'These preferences will be taken into account, but may not be met, depending on the Association\'s needs.',
      ),
      SubjectRequestStep.notes => tr(
        'Se lo desideri, puoi inserire qui sotto altre informazioni che ritieni '
            'utili per lo svolgimento della lezione. Le indicazioni saranno lette dal docente che ${isSelf ? 'ti seguirà' : 'seguirà $who'}.',
        'If you wish, you can add any other information you find useful below. '
            'It will be read by the teacher who will ${isSelf ? 'teach you' : 'teach $who'}.',
      ),
    };
  }
}

String get kPickKindToGoOn => tr('Seleziona almeno un tipo di lezione per andare avanti.', 'Select at least one lesson type to continue.');
String get kBookingLengthLimits => tr(
  'Ogni lezione può essere prenotata da un minimo di 15 minuti a un massimo di 5 ore.',
  'Each lesson can be booked for a minimum of 15 minutes and a maximum of 5 hours.',
);

String durationOverStay({required String mode, required bool isSelf, String? name})
{
  final String presence = mode == kOnlineMode ? 'presenza online' : 'presenza';
  final String where = mode == kOnlineMode ? 'online' : 'at the Association';

  return isSelf
      ? tr('Supererebbe le tue ore di $presence.', 'It would go beyond the hours you are $where.')
      : tr(
          'Supererebbe le ore di $presence ${name == null ? 'dello studente' : 'di $name'}.',
          'It would go beyond the hours ${name ?? 'the student'} is $where.',
        );
}

String bandTimeAllTaken(String mode, TimeBucket band)
{
  return tr(
    'Le ore ${modeLabel(mode).toLowerCase()} ${ofBandLabel(band)} sono già tutte occupate dalle altre lezioni.',
    'The ${_modeBefore(mode)} ${bandLabel(band).toLowerCase()} hours are already all taken by other lessons.',
  );
}

String get kLessonKindLabel => tr('Tipo di lezione', 'Lesson type');
String get kTopicLabel => tr('Argomento (opzionale)', 'Topic (optional)');
String get kTopicHint => tr('Es. Disequazioni di secondo grado', 'E.g. Quadratic inequalities');
String get kDurationLabel => tr('Durata', 'Duration');

// Nothing chosen yet reads «0», never «0m».
String durationText(int minutes) => minutes == 0 ? '0' : formatMinutes(minutes);
String get kTeacherNotesLabel => tr('Note per il docente', 'Notes for the teacher');
String get kTeacherNotesExample => tr('Es. Guardare gli esercizi su Classroom', 'E.g. Look at the exercises on Classroom');

String get kBandNotesLabel => tr('Note sulla prenotazione', 'Booking notes');
String get kBandNotesHint => tr(
  "Puoi indicare esigenze organizzative, come l'orario preciso di arrivo o altre richieste particolari. La nota sarà "
      'letta dal Direttivo e da chi preparerà il calendario delle lezioni.',
  'You can mention organisational needs, such as the exact arrival time, or other special requests. The note will be '
      'read by the Board and by whoever prepares the lesson calendar.',
);
String get kBandNotesExample => tr('Es. Arrivo alle 13:15 con pranzo', 'E.g. Arriving at 13:15 with lunch');

String bandNoteAction(String? note) => note == null ? tr('Aggiungi una nota', 'Add a note') : tr('Modifica la nota', 'Edit the note');

String get kDeleteBandNote => tr('Elimina la nota', 'Delete the note');

// [yours] null: the reader books for themselves.
String teacherNotesTourText(String? yours)
{
  return tr(
    'Qui puoi aggiungere eventuali altre informazioni o indicazioni per il docente che '
        '${yours == null ? 'ti seguirà' : 'seguirà $yours'}.',
    'Here you can add any other information or instructions for the teacher who will '
        '${yours == null ? 'teach you' : 'teach $yours'}.',
  );
}

// The last step of a booking: «Crea» for a new one, «Salva» for one changed. [verb]: clicca or tocca.
String bookingFinishTourText(String verb, {required bool editing})
{
  final String english = verb == 'tocca' || verb == 'tap' ? 'tap' : 'click';

  return tr(
    'Quando hai terminato, $verb «${editing ? 'Salva' : 'Crea'}» per concludere e salvare la prenotazione.',
    'When you have finished, $english “${editing ? 'Save' : 'Create'}” to complete and save the booking.',
  );
}

// The tours' step on the note's field, in the window off the band's button.
String get kBandNoteTourText => tr(
  'Qui puoi aggiungere altre informazioni o effettuare richieste organizzative. Ciò che '
      'scriverai sarà letto dal Direttivo e da chi preparerà il calendario delle lezioni.',
  'Here you can add other information or make organisational requests. What you write will be read by the Board '
      'and by whoever prepares the lesson calendar.',
);
String get kTeacherNotesHint => tr('Inserisci...', 'Type here...');

String get kRemoveSubjectLink => tr('Rimuovi materia', 'Remove subject');
String get kRemovalEyebrow => tr('Rimozione', 'Removal');
String get kSubjectRemovalBefore => tr('La materia ', 'The subject ');
String get kSubjectRemovalAfter => tr(' verrà rimossa.', ' will be removed.');
String get kDisciplineRemovalAfter => tr(' verrà rimossa dalla prenotazione.', ' will be removed from the booking.');

String preferredTeachersLabel(String? gender) => tr('Mi sono ${gender == 'F' ? 'trovata' : 'trovato'} meglio con...', 'I got on best with...');

String get kNoTeachers => tr("Nessun docente presente nell'anagrafica.", 'No teachers in the records.');
String get kSearchTeacher => tr('Cerca docente...', 'Search teachers...');
String get kTeachersFull => tr('Tre è il massimo: rimuovine uno per cambiarli', 'Three is the maximum: remove one to change them');
String get kTeachersFullNoMatch => tr('Ne hai già scelti tre.', "You've already chosen three.");
String get kNoTeacherMatch => tr('Nessun docente trovato.', 'No teachers found.');
