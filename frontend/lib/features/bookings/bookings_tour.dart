import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';

const String kTourBookingsDays = 'bookings.days';
const String kTourBookingsNext = 'bookings.next';
const String kTourBookingsDeadlines = 'bookings.deadlines';

const String kTourBookingsAdd = 'bookings.add';
const String kTourBookingsLock = 'bookings.lock';
const String kTourBookingsModes = 'bookings.modes';
const String kTourBookingsLesson = 'bookings.lesson';
const String kTourBookingsTopic = 'bookings.topic';
const String kTourBookingsNotes = 'bookings.notes';
const String kTourBookingsLessonActions = 'bookings.lesson.actions';
const String kTourBookingsBandActions = 'bookings.band.actions';
const String kTourBookingsDayBin = 'bookings.day.bin';

enum BookingsTourMark { add, lock, modes, lesson, topic, notes, lessonActions, bandActions, dayBin }

const String kTourBookingsSwitch = 'bookings.hours.switch';
const String kTourBookingsHours = 'bookings.hours.cursors';
const String kTourBookingsHoursAdd = 'bookings.hours.add';
const String kTourBookingsHoursBin = 'bookings.hours.bin';

const String kTourBookingsWizardDays = 'bookings.wizard.days';
const String kTourBookingsWizardForward = 'bookings.wizard.forward';
const String kTourBookingsWizardSave = 'bookings.wizard.save';
const String kTourBookingsWizardBand = 'bookings.wizard.band';
const String kTourBookingsWizardLeft = 'bookings.wizard.left';
const String kTourBookingsWizardMinistry = 'bookings.wizard.ministry';
const String kTourBookingsWizardDisciplines = 'bookings.wizard.disciplines';
const String kTourBookingsWizardServices = 'bookings.wizard.services';
const String kTourBookingsWizardList = 'bookings.wizard.list';
const String kTourBookingsWizardOpen = 'bookings.wizard.open';

const String kTourBookingsSubjectKinds = 'bookings.subject.kinds';
const String kTourBookingsSubjectTopic = 'bookings.subject.topic';
const String kTourBookingsSubjectForward = 'bookings.subject.forward';
const String kTourBookingsSubjectDurations = 'bookings.subject.durations';
const String kTourBookingsSubjectCount = 'bookings.subject.count';
const String kTourBookingsSubjectTeachers = 'bookings.subject.teachers';
const String kTourBookingsSubjectSearch = 'bookings.subject.search';
const String kTourBookingsSubjectNotes = 'bookings.subject.notes';
const String kTourBookingsSubjectSave = 'bookings.subject.save';

const String kTourBookingsMoveDays = 'bookings.move.days';
const String kTourBookingsMoveOptions = 'bookings.move.options';
const String kTourBookingsMoveConfirm = 'bookings.move.confirm';

// True once the next week is on show; its tour step waits for it.
final ValueNotifier<bool> bookingsNextWeekShown = ValueNotifier(false);

// The wizard tells its tours: a date picked, hours given, a subject opened.
final ValueNotifier<int> bookingsWizardDaysPicked = ValueNotifier(0);
final ValueNotifier<bool> bookingsWizardHasHours = ValueNotifier(false);
final ValueNotifier<int> bookingsWizardPicked = ValueNotifier(0);

final ValueNotifier<bool> bookingsSubjectOpen = ValueNotifier(false);

// The move window tells its tour: a day or a place picked.
final ValueNotifier<int> bookingsMovePicked = ValueNotifier(0);

const String _title = 'Prenotazioni';

const String _parentRole = 'PARENT';
const String _studentRole = 'STUDENT';

// Who reads the page: a parent, a student booking, or one only looking.
enum BookingsTourReader { parent, student, reading }

// Whom the windows' sentences name: a son or daughter, or the student booking for themselves.
enum BookingsTourPupil
{
  son,
  daughter,
  self;

  static BookingsTourPupil of({required bool self, required String? gender})
  {
    return self ? BookingsTourPupil.self : (gender == 'F' ? daughter : son);
  }

  String get yours => this == daughter ? 'tua figlia' : 'tuo figlio';
}

// Bump a version on every change to that tour.
const Map<BookingsTourReader, (String, int)> _pageSeen = {
  BookingsTourReader.parent: ('bookings.parent', 3),
  BookingsTourReader.student: ('bookings.student', 3),
  BookingsTourReader.reading: ('bookings.student.reading', 3),
};

const (String, int) _nextSeen = ('bookings.next', 1);

const Map<BookingsTourMark, int> _markVersions = {
  BookingsTourMark.add: 1,
  BookingsTourMark.lock: 1,
  BookingsTourMark.modes: 3,
  BookingsTourMark.lesson: 1,
  BookingsTourMark.topic: 1,
  BookingsTourMark.notes: 2,
  BookingsTourMark.lessonActions: 1,
  BookingsTourMark.bandActions: 1,
  BookingsTourMark.dayBin: 1,
};

(String, int) _markSeen(BookingsTourMark mark) => ('bookings.mark.${mark.name}', _markVersions[mark]!);

const (String, int) _daysSeen = ('bookings.wizard.days', 1);
const (String, int) _switchSeen = ('bookings.wizard.switch', 1);
const (String, int) _cursorsSeen = ('bookings.hours.cursors', 1);
const (String, int) _addHoursSeen = ('bookings.hours.add', 1);
const (String, int) _binSeen = ('bookings.hours.bin', 1);
const (String, int) _forwardSeen = ('bookings.wizard.forward', 1);
const (String, int) _saveHoursSeen = ('bookings.wizard.save.hours', 1);
const (String, int) _bandSeen = ('bookings.wizard.band', 1);
const (String, int) _leftSeen = ('bookings.wizard.left', 1);
const (String, int) _ministrySeen = ('bookings.wizard.ministry', 1);
const (String, int) _disciplinesSeen = ('bookings.wizard.disciplines', 1);
const (String, int) _servicesSeen = ('bookings.wizard.services', 1);
const (String, int) _listSeen = ('bookings.wizard.list', 1);
const (String, int) _openSeen = ('bookings.wizard.open', 2);
const (String, int) _createSeen = ('bookings.wizard.create', 1);
const (String, int) _saveSeen = ('bookings.wizard.save', 1);

const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];
const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.right, DesktopTourSide.above];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];
const List<DesktopTourSide> _leftFirst = [DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above];

bool _shown(String id) => isDesktopTourTargetShown(id);

// The page's reader, or null for whoever the tours are not for.
BookingsTourReader? bookingsTourReader()
{
  final identity = ApiService().lastKnownIdentity;

  return switch (identity?.activeRole)
  {
    _parentRole => BookingsTourReader.parent,
    _studentRole when identity!.hasParentalResponsibility && !identity.autonomousBookings => BookingsTourReader.reading,
    _studentRole => BookingsTourReader.student,
    _ => null,
  };
}

// Admins booking for a student share these windows: only parents and students are toured.
// [still]: checked right before showing; false drops the tour (e.g. the card changed).
void startBookingsTour(BuildContext context, DesktopTour tour, {bool Function()? still})
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  if (taxCode == null || bookingsTourReader() == null)
  {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_)
  {
    if (context.mounted)
    {
      startDesktopTourOnce(context, taxCode: taxCode, tour: tour, still: still);
    }
  });

  // Asked from another frame's callback, it still needs a frame to come.
  WidgetsBinding.instance.scheduleFrame();
}

// False when no identity is known.
Future<bool> bookingsTourSeen(DesktopTour tour) async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  return taxCode != null && await isDesktopTourSeen(taxCode: taxCode, tour: tour);
}

// The parts on show not told yet, as one tour; null when none is due.
Future<DesktopTour?> _dueTour(List<DesktopTourStep> steps) async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  return taxCode == null || bookingsTourReader() == null
      ? null
      : dueDesktopTour(taxCode: taxCode, title: _title, steps: steps);
}

// Unseen steps (parts still to come too) under the first present one's mark; null if none shows.
Future<DesktopTour?> _freshTour(List<DesktopTourStep> steps) async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  if (taxCode == null || bookingsTourReader() == null)
  {
    return null;
  }

  final List<DesktopTourStep> fresh = [];

  for (final DesktopTourStep step in steps)
  {
    final (String slug, int version) = step.seen!;

    if (!await isDesktopTourSeen(taxCode: taxCode, tour: DesktopTour(slug: slug, title: _title, version: version, steps: const [])))
    {
      fresh.add(step);
    }
  }

  final DesktopTourStep? first = fresh.where((step) => step.isPresent).firstOrNull;

  if (first == null)
  {
    return null;
  }

  return DesktopTour(slug: first.seen!.$1, title: _title, version: first.seen!.$2, steps: fresh);
}

// The children the page shows, as its first sentence names them; [genders] holds one per child.
String _whose(BookingsTourReader reader, List<String?> genders)
{
  if (reader != BookingsTourReader.parent || genders.isEmpty)
  {
    return '';
  }

  if (genders.length == 1)
  {
    return genders.single == 'F' ? ' per tua figlia' : ' per tuo figlio';
  }

  return genders.every((gender) => gender == 'F') ? ' per le tue figlie' : ' per i tuoi figli';
}

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
final Map<BookingsTourMark, DesktopTourStep> _marks = {
  BookingsTourMark.add: DesktopTourStep(
    targets: const [kTourBookingsAdd],
    text: 'Con «Aggiungi in presenza» e «Aggiungi online» puoi prenotare una lezione in presenza oppure online.',
    sides: _leftFirst,
    pad: 6,
    radius: 23,
    reveal: true,
    present: () => _shown(kTourBookingsAdd),
    seen: _markSeen(BookingsTourMark.add),
  ),
  BookingsTourMark.lock: DesktopTourStep(
    targets: const [kTourBookingsLock],
    text: 'Il lucchetto indica che non è più possibile modificare la prenotazione.',
    sides: _beside,
    pad: 6,
    radius: 10,
    reveal: true,
    present: () => _shown(kTourBookingsLock),
    seen: _markSeen(BookingsTourMark.lock),
  ),
  BookingsTourMark.modes: DesktopTourStep(
    targets: const [kTourBookingsModes],
    apart: true,
    text: "Le lezioni in presenza sono contrassegnate dal colore verde e dall'icona di una casa, mentre quelle "
        "online sono indicate in arancione e con l'icona di una videocamera.",
    sides: _beside,
    pad: 6,
    radius: 16,
    reveal: true,
    present: () => _shown(kTourBookingsModes),
    seen: _markSeen(BookingsTourMark.modes),
  ),
  BookingsTourMark.lesson: DesktopTourStep(
    targets: const [kTourBookingsLesson],
    text: 'Qui puoi vedere i dettagli della prenotazione.',
    sides: _over,
    pad: 6,
    radius: 19,
    reveal: true,
    present: () => _shown(kTourBookingsLesson),
    seen: _markSeen(BookingsTourMark.lesson),
  ),
  // Topic and notes are lit apart: a lesson may have one without the other.
  BookingsTourMark.topic: DesktopTourStep(
    targets: const [kTourBookingsTopic],
    text: "Passando il mouse su questa icona puoi leggere l'argomento della lezione.",
    sides: _over,
    pad: 4,
    radius: 12,
    reveal: true,
    present: () => _shown(kTourBookingsTopic),
    seen: _markSeen(BookingsTourMark.topic),
  ),
  BookingsTourMark.notes: DesktopTourStep(
    targets: const [kTourBookingsNotes],
    text: 'Passando il mouse su questa icona puoi leggere le note per il docente.',
    sides: _over,
    pad: 4,
    radius: 12,
    reveal: true,
    present: () => _shown(kTourBookingsNotes),
    seen: _markSeen(BookingsTourMark.notes),
  ),
  // The row keeps its buttons in sight while lit, as the mouse would.
  BookingsTourMark.lessonActions: DesktopTourStep(
    targets: const [kTourBookingsLessonActions],
    text: 'Passando con il mouse su una materia compaiono i pulsanti con cui puoi modificarne la prenotazione, '
        'eliminarla, oppure cambiare giorno, fascia oraria e/o modalità (online o in presenza).',
    sides: _over,
    pad: 4,
    radius: 10,
    reveal: true,
    present: () => _shown(kTourBookingsLessonActions),
    seen: _markSeen(BookingsTourMark.lessonActions),
  ),
  BookingsTourMark.bandActions: DesktopTourStep(
    targets: const [kTourBookingsBandActions],
    text: 'Passando con il mouse su una fascia oraria compaiono i pulsanti con cui puoi modificare gli orari delle '
        "prenotazioni, richiedere un'altra lezione nella stessa fascia, spostare tutte le lezioni della fascia "
        'oraria selezionata (mattina, pomeriggio o sera) oppure eliminare tutte le materie prenotate in quella fascia.',
    sides: _beside,
    pad: 4,
    radius: 10,
    reveal: true,
    present: () => _shown(kTourBookingsBandActions),
    seen: _markSeen(BookingsTourMark.bandActions),
  ),
  BookingsTourMark.dayBin: DesktopTourStep(
    targets: const [kTourBookingsDayBin],
    text: "Con questo cestino puoi cancellare le prenotazioni dell'intera giornata.",
    sides: _beside,
    pad: 4,
    radius: 10,
    reveal: true,
    present: () => _shown(kTourBookingsDayBin),
    seen: _markSeen(BookingsTourMark.dayBin),
  ),
};

// One only looking has nothing to change, nor deadlines to keep.
const Set<BookingsTourMark> _readerMarks = {
  BookingsTourMark.modes,
  BookingsTourMark.lesson,
  BookingsTourMark.topic,
  BookingsTourMark.notes,
};

List<DesktopTourStep> _marksOf(BookingsTourReader reader) => [
      for (final MapEntry(key: mark, value: step) in _marks.entries)
        if (reader != BookingsTourReader.reading || _readerMarks.contains(mark)) step,
    ];

// A part told once per tour, on this week or, once it is open, on the next.
DesktopTourStep _once(DesktopTourStep step, Map<(String, int), Object> told, {bool nextWeek = false})
{
  return desktopTourStepOnce(step, told, when: nextWeek ? () => bookingsNextWeekShown.value : null);
}

// The next week: its arrow, then its days; back from these turns the page to this week again.
List<DesktopTourStep> _nextWeekSteps(VoidCallback showThisWeek)
{
  return [
    DesktopTourStep(
      targets: const [kTourBookingsNext],
      text: 'Clicca la freccia per passare alla settimana prossima.',
      sides: _leftFirst,
      pad: 6,
      radius: 25,
      listen: bookingsNextWeekShown,
      reached: () => bookingsNextWeekShown.value,
      present: () => _shown(kTourBookingsNext) && !bookingsNextWeekShown.value,
      seen: _nextSeen,
    ),
    DesktopTourStep(
      targets: const [kTourBookingsDays],
      text: 'Qui puoi prenotare le lezioni per la settimana prossima, che si sblocca il venerdì alle 20:00.',
      sides: _over,
      pad: 6,
      radius: 27,
      undo: showThisWeek,
      present: () => bookingsNextWeekShown.value,
      coming: () => _shown(kTourBookingsNext),
      seen: _nextSeen,
    ),
  ];
}

// This week and its parts, then for bookers the next week and the deadlines.
// [genders]: the children the page shows, one each, for the first sentence.
DesktopTour bookingsPageTour({
  required BookingsTourReader reader,
  required List<String?> genders,
  required VoidCallback showThisWeek,
})
{
  final Map<(String, int), Object> told = {};
  final bool books = reader != BookingsTourReader.reading;
  final List<DesktopTourStep> marks = _marksOf(reader);
  final (String slug, int version) = _pageSeen[reader]!;

  return DesktopTour(
    slug: slug,
    title: _title,
    version: version,
    steps: [
      // The next week shown by a click while the tour got ready: back on this week.
      DesktopTourStep(
        targets: const [kTourBookingsDays],
        text: 'Qui puoi vedere tutte le prenotazioni effettuate questa settimana${_whose(reader, genders)}.',
        sides: _over,
        pad: 6,
        radius: 27,
        enter: () => bookingsNextWeekShown.value ? showThisWeek() : null,
      ),
      for (final step in marks) _once(step, told),
      if (books) ...[
        ..._nextWeekSteps(showThisWeek),
        for (final step in marks) _once(step, told, nextWeek: true),
        const DesktopTourStep(
          targets: [kTourBookingsDeadlines],
          text: 'Qui trovi le scadenze entro cui effettuare o modificare le prenotazioni.',
          sides: _below,
          pad: 8,
          radius: 14,
        ),
      ],
    ],
  );
}

// The first time the arrow is there, for whoever saw the page before it unlocked.
DesktopTour bookingsNextWeekTour({required VoidCallback showThisWeek})
{
  return DesktopTour(slug: _nextSeen.$1, title: _title, version: _nextSeen.$2, steps: _nextWeekSteps(showThisWeek));
}

Future<DesktopTour?> bookingsLatePageTour(BookingsTourReader reader) => _dueTour(_marksOf(reader));

String _presence(bool online) => online ? 'presenza online' : 'presenza';

// The dates of a new booking; picking one ends it.
final DesktopTourStep _daysStep = DesktopTourStep(
  targets: const [kTourBookingsWizardDays],
  text: 'Puoi selezionare una data cliccandola. Passando il mouse su una data barrata scopri perché non è '
      'disponibile.',
  sides: _below,
  pad: 6,
  radius: 31,
  interactive: true,
  listen: bookingsWizardDaysPicked,
  reached: () => true,
  present: () => _shown(kTourBookingsWizardDays),
  seen: _daysSeen,
);

Future<DesktopTour?> bookingsWizardDaysTour() => _dueTour([_daysStep]);

// Shared with the move window: seen in one, seen in both.
final DesktopTourStep _cursorsStep = DesktopTourStep(
  targets: const [kTourBookingsHours],
  text: 'Trascinando i cursori cambi gli orari in cui vuoi prenotare.',
  sides: _beside,
  pad: 6,
  radius: 14,
  present: () => _shown(kTourBookingsHours),
  seen: _cursorsSeen,
);

final DesktopTourStep _addHoursStep = DesktopTourStep(
  targets: const [kTourBookingsHoursAdd],
  text: 'Puoi indicare più orari nella stessa fascia. Ad esempio, dalle 14:00 alle 15:00 e dalle 17:00 alle 18:00.',
  sides: _beside,
  pad: 6,
  radius: 19,
  present: () => _shown(kTourBookingsHoursAdd),
  seen: _addHoursSeen,
);

final DesktopTourStep _binStep = DesktopTourStep(
  targets: const [kTourBookingsHoursBin],
  text: 'Puoi eliminare un orario cliccando sul cestino.',
  sides: _beside,
  pad: 4,
  radius: 12,
  present: () => _shown(kTourBookingsHoursBin),
  seen: _binSeen,
);

// The hours card: a "Sì" brings the cursors in; then the subjects, or the hours saved alone.
Future<DesktopTour?> bookingsWizardHoursTour({
  required BookingsTourPupil pupil,
  required bool online,
  required bool hoursOnly,
})
{
  final String whose = pupil == BookingsTourPupil.self ? 'la tua ${_presence(online)}' : 'la ${_presence(online)} di ${pupil.yours}';

  return _freshTour([
    DesktopTourStep(
      targets: const [kTourBookingsSwitch],
      text: 'Con il selettore aggiungi o rimuovi $whose nella fascia oraria corrispondente (mattina, pomeriggio o sera).',
      sides: _beside,
      pad: 6,
      radius: 23,
      interactive: true,
      listen: bookingsWizardHasHours,
      reached: () => bookingsWizardHasHours.value,
      present: () => _shown(kTourBookingsSwitch),
      seen: _switchSeen,
    ),
    DesktopTourStep(
      targets: _cursorsStep.targets,
      text: _cursorsStep.text,
      sides: _cursorsStep.sides,
      pad: _cursorsStep.pad,
      radius: _cursorsStep.radius,
      present: _cursorsStep.present,
      coming: () => !_shown(kTourBookingsHours),
      seen: _cursorsSeen,
    ),
    _addHoursStep,
    _binStep,
    if (hoursOnly)
      DesktopTourStep(
        targets: const [kTourBookingsWizardSave],
        text: 'Quando hai finito, clicca «Salva» per salvare i nuovi orari.',
        sides: _beside,
        pad: 6,
        radius: 17,
        present: () => _shown(kTourBookingsWizardSave),
        seen: _saveHoursSeen,
      )
    else
      DesktopTourStep(
        targets: const [kTourBookingsWizardForward],
        text: 'Quando hai finito, clicca la freccia per scegliere le materie.',
        sides: _leftFirst,
        pad: 6,
        radius: 35,
        present: () => _shown(kTourBookingsWizardForward),
        seen: _forwardSeen,
      ),
  ]);
}

Future<DesktopTour?> bookingsLateHoursTour() => _dueTour([_cursorsStep, _addHoursStep, _binStep]);

// A subject divided in disciplines, once open under its row.
final DesktopTourStep _openStep = DesktopTourStep(
  targets: const [kTourBookingsWizardOpen],
  text: "Questa materia è articolata in più aree disciplinari. Seleziona l'area per cui desideri prenotare una "
      'lezione. Se hai bisogno di prenotare lezioni per più aree, puoi farlo separatamente, una alla volta.',
  sides: _beside,
  pad: 6,
  radius: 19,
  interactive: true,
  listen: bookingsSubjectOpen,
  reached: () => bookingsSubjectOpen.value,
  present: () => _shown(kTourBookingsWizardOpen) && !bookingsSubjectOpen.value,
  seen: _openSeen,
);

// Once a subject is chosen: [editing] saves the booking, else creates it.
DesktopTourStep _finishStep({required bool editing})
{
  return DesktopTourStep(
    targets: const [kTourBookingsWizardSave],
    text: 'Quando hai selezionato tutte le materie che ti interessano, clicca «${editing ? 'Salva' : 'Crea'}» per '
        'concludere e salvare la prenotazione.',
    sides: _beside,
    pad: 6,
    radius: 17,
    present: () => _shown(kTourBookingsWizardSave) && !bookingsSubjectOpen.value,
    seen: editing ? _saveSeen : _createSeen,
  );
}

// The subjects card: band and hours left, the lists; a click on a subject opens it.
// [chosen]: some subject is already in the card, so the button saving it all is told too.
Future<DesktopTour?> bookingsWizardSubjectsTour({
  required BookingsTourPupil pupil,
  required bool online,
  required bool editing,
  required bool Function() chosen,
})
{
  final bool self = pupil == BookingsTourPupil.self;
  final String yours = pupil.yours;
  final DesktopTourStep finish = _finishStep(editing: editing);

  DesktopTourStep tab(String target, String text, (String, int) seen)
  {
    return DesktopTourStep(
      targets: [target],
      text: text,
      sides: _below,
      pad: 4,
      radius: 20,
      present: () => _shown(target),
      seen: seen,
    );
  }

  return _freshTour([
    DesktopTourStep(
      targets: const [kTourBookingsWizardBand],
      text: self
          ? "Qui trovi gli orari in cui hai indicato di essere presente${online ? ' online' : ''}: le lezioni prenotate "
              "verranno organizzate all'interno di questo intervallo."
          : "Qui trovi gli orari in cui hai indicato che $yours è presente${online ? ' online' : ''}: le lezioni "
              "prenotate verranno organizzate all'interno di questo intervallo.",
      sides: _below,
      pad: 6,
      radius: 10,
      present: () => _shown(kTourBookingsWizardBand),
      seen: _bandSeen,
    ),
    DesktopTourStep(
      targets: const [kTourBookingsWizardLeft],
      text: 'A destra trovi il totale delle ore di lezione che puoi ancora richiedere, calcolato sottraendo le ore già '
          'prenotate dal totale delle ore di ${_presence(online)} indicate.',
      sides: _below,
      pad: 6,
      radius: 10,
      present: () => _shown(kTourBookingsWizardLeft),
      seen: _leftSeen,
    ),
    tab(
      kTourBookingsWizardMinistry,
      self
          ? 'In «Materie» trovi solo le materie previste nel tuo indirizzo di studi.'
          : "In «Materie» trovi solo le materie previste nell'indirizzo di studi di $yours.",
      _ministrySeen,
    ),
    tab(
      kTourBookingsWizardDisciplines,
      'In «Discipline» trovi tutte le discipline che è possibile prenotare in Associazione.',
      _disciplinesSeen,
    ),
    tab(
      kTourBookingsWizardServices,
      self
          ? "In «Servizi» trovi altri servizi che è possibile prenotare, come il supporto per la stesura della tesina "
              "d'esame."
          : 'In «Servizi» trovi altri servizi che è possibile prenotare per $yours, come il supporto per la stesura '
              "della tesina d'esame.",
      _servicesSeen,
    ),
    // Its window or its disciplines opened by a click move the tour on.
    DesktopTourStep(
      targets: const [kTourBookingsWizardList],
      text: 'Da qui puoi selezionare le materie da prenotare.',
      sides: _beside,
      pad: 6,
      radius: 19,
      interactive: true,
      listen: Listenable.merge([bookingsWizardPicked, bookingsSubjectOpen]),
      reached: () => bookingsSubjectOpen.value || _shown(kTourBookingsWizardOpen),
      present: () => _shown(kTourBookingsWizardList),
      seen: _listSeen,
    ),
    _openStep,
    if (chosen()) finish,
  ]);
}

// Late parts of the card: a subject opened in place, the button once one is chosen.
Future<DesktopTour?> bookingsLateSubjectsTour({required bool editing, required bool chosen})
{
  return _dueTour([_openStep, if (chosen) _finishStep(editing: editing)]);
}

enum BookingsSubjectCard { what, duration, teachers, notes }

enum _SubjectMark { intro, kinds, topic, forward, durations, count, teachers, search, notes, add, save }

const Map<_SubjectMark, int> _subjectVersions = {
  _SubjectMark.intro: 1,
  _SubjectMark.kinds: 1,
  _SubjectMark.topic: 1,
  _SubjectMark.forward: 1,
  _SubjectMark.durations: 1,
  _SubjectMark.count: 1,
  _SubjectMark.teachers: 1,
  _SubjectMark.search: 1,
  _SubjectMark.notes: 1,
  _SubjectMark.add: 1,
  _SubjectMark.save: 1,
};

(String, int) _subjectSeen(_SubjectMark mark) => ('bookings.subject.${mark.name}', _subjectVersions[mark]!);

// [first]: the window's first card, with the intro; [editing]: saves a booked lesson.
Future<DesktopTour?> bookingsSubjectTour({
  required BookingsSubjectCard card,
  required bool first,
  required bool editing,
  required bool online,
  required BookingsTourPupil pupil,
})
{
  final String total = pupil == BookingsTourPupil.self
      ? 'il totale delle tue ore di ${_presence(online)}'
      : 'il totale di ore di ${_presence(online)} di ${pupil.yours}';

  // Closing the window ends the tour.
  DesktopTourStep step(
    _SubjectMark mark,
    String text, {
    String? target,
    List<DesktopTourSide> sides = _beside,
    double pad = 6,
    double radius = 25,
    bool reveal = false,
    bool interactive = false,
  })
  {
    return DesktopTourStep(
      targets: [?target],
      text: text,
      sides: sides,
      pad: pad,
      radius: radius,
      reveal: reveal,
      interactive: interactive,
      listen: bookingsSubjectOpen,
      gone: () => !bookingsSubjectOpen.value,
      present: () => bookingsSubjectOpen.value && (target == null || _shown(target)),
      seen: _subjectSeen(mark),
    );
  }

  return _freshTour([
    if (first)
      step(
        _SubjectMark.intro,
        'Quando selezioni una materia, ti vengono chieste alcune informazioni aggiuntive, necessarie per '
            'organizzare al meglio le lezioni.',
      ),
    ...switch (card)
    {
      BookingsSubjectCard.what => [
          step(
            _SubjectMark.kinds,
            'Puoi selezionare uno o più tipi di lezione tra quelli indicati.',
            target: kTourBookingsSubjectKinds,
            interactive: true,
          ),
          step(
            _SubjectMark.topic,
            "Puoi indicare l'argomento da affrontare durante la lezione. Il campo è facoltativo, ma ti invitiamo a "
                'compilarlo quando possibile: conoscere in anticipo gli argomenti da trattare aiuta il docente a '
                'preparare la lezione in modo più mirato ed efficace.',
            target: kTourBookingsSubjectTopic,
            radius: 17,
            interactive: true,
          ),
          step(
            _SubjectMark.forward,
            'Quando hai fatto, clicca la freccia.',
            target: kTourBookingsSubjectForward,
            sides: _leftFirst,
            radius: 35,
          ),
        ],
      BookingsSubjectCard.duration => [
          step(
            _SubjectMark.durations,
            'Qui puoi selezionare la durata della lezione.',
            target: kTourBookingsSubjectDurations,
            interactive: true,
          ),
          step(
            _SubjectMark.count,
            'Qui puoi vedere quante ore di lezione sono state prenotate rispetto al totale delle ore che puoi '
                'richiedere. Se diventa rosso, significa che hai superato $total.',
            target: kTourBookingsSubjectCount,
            pad: 6,
            radius: 10,
          ),
        ],
      BookingsSubjectCard.teachers => [
          step(
            _SubjectMark.teachers,
            'Puoi selezionare fino a tre docenti preferiti per la lezione.',
            target: kTourBookingsSubjectTeachers,
            radius: 31,
            interactive: true,
          ),
          step(
            _SubjectMark.search,
            'Puoi cercare direttamente un docente tramite il suo nome e cognome.',
            target: kTourBookingsSubjectSearch,
            radius: 28,
            interactive: true,
          ),
        ],
      BookingsSubjectCard.notes => [
          step(
            _SubjectMark.notes,
            'Qui puoi aggiungere eventuali altre osservazioni o informazioni che ritieni utili.',
            target: kTourBookingsSubjectNotes,
            radius: 17,
            interactive: true,
          ),
          if (editing)
            step(
              _SubjectMark.save,
              'Quando hai finito, clicca «Salva» per salvare le modifiche.',
              target: kTourBookingsSubjectSave,
              radius: 17,
            )
          else
            step(
              _SubjectMark.add,
              'Quando hai finito, clicca «Aggiungi» per concludere e tornare alla selezione delle materie.',
              target: kTourBookingsSubjectSave,
              radius: 17,
            ),
        ],
    },
  ]);
}

enum _MoveMark { days, options, confirm }

const Map<_MoveMark, int> _moveVersions = {
  _MoveMark.days: 1,
  _MoveMark.options: 1,
  _MoveMark.confirm: 1,
};

(String, int) _moveSeen(_MoveMark mark) => ('bookings.move.${mark.name}', _moveVersions[mark]!);

// The move window: a day, where to, the hours if asked, the button.
// [hoursMayCome]: some option of the picked day would ask for hours.
Future<DesktopTour?> bookingsMoveTour({required bool Function() hoursMayCome})
{
  return _freshTour([
    DesktopTourStep(
      targets: const [kTourBookingsMoveDays],
      text: 'Puoi selezionare il giorno in cui vuoi spostare la prenotazione. Passando il mouse su una data barrata '
          'scopri perché non è disponibile.',
      sides: _beside,
      pad: 6,
      radius: 25,
      interactive: true,
      listen: bookingsMovePicked,
      reached: () => true,
      present: () => _shown(kTourBookingsMoveDays),
      seen: _moveSeen(_MoveMark.days),
    ),
    DesktopTourStep(
      targets: const [kTourBookingsMoveOptions],
      text: "Puoi scegliere con quale modalità e in quale fascia oraria vuoi spostare la lezione. Passando il mouse "
          "su un'opzione barrata scopri perché non è disponibile.",
      sides: _beside,
      pad: 6,
      radius: 25,
      interactive: true,
      listen: bookingsMovePicked,
      reached: () => true,
      present: () => _shown(kTourBookingsMoveOptions),
      seen: _moveSeen(_MoveMark.options),
    ),
    DesktopTourStep(
      targets: _cursorsStep.targets,
      text: _cursorsStep.text,
      sides: _cursorsStep.sides,
      pad: _cursorsStep.pad,
      radius: _cursorsStep.radius,
      present: _cursorsStep.present,
      coming: hoursMayCome,
      seen: _cursorsSeen,
    ),
    _addHoursStep,
    _binStep,
    DesktopTourStep(
      targets: const [kTourBookingsMoveConfirm],
      text: 'Quando hai finito, clicca «Sposta».',
      sides: _beside,
      pad: 6,
      radius: 17,
      present: () => _shown(kTourBookingsMoveConfirm),
      seen: _moveSeen(_MoveMark.confirm),
    ),
  ]);
}

Future<DesktopTour?> bookingsLateMoveTour() => _dueTour([_cursorsStep, _addHoursStep, _binStep]);
