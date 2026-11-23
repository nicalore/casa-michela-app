import 'package:flutter/widgets.dart';

import '../../core/language/app_language.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../lessons/utils/booking_wizard_strings.dart' show bookingFinishTourText, kBandNoteTourText, teacherNotesTourText;

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
const String kTourBookingsWizardNote = 'bookings.wizard.note';

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

String get _title => tr('Prenotazioni', 'Bookings');

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

  String get yours => this == daughter ? tr('tua figlia', 'your daughter') : tr('tuo figlio', 'your son');
}

// Bump a version on every change to that tour.
const Map<BookingsTourReader, (String, int)> _pageSeen = {
  BookingsTourReader.parent: ('bookings.parent', 4),
  BookingsTourReader.student: ('bookings.student', 4),
  BookingsTourReader.reading: ('bookings.student.reading', 3),
};

const (String, int) _nextSeen = ('bookings.next', 2);

const Map<BookingsTourMark, int> _markVersions = {
  BookingsTourMark.add: 1,
  BookingsTourMark.lock: 1,
  BookingsTourMark.modes: 3,
  BookingsTourMark.lesson: 1,
  BookingsTourMark.topic: 1,
  BookingsTourMark.notes: 2,
  BookingsTourMark.lessonActions: 1,
  BookingsTourMark.bandActions: 3,
  BookingsTourMark.dayBin: 1,
};

(String, int) _markSeen(BookingsTourMark mark) => ('bookings.mark.${mark.name}', _markVersions[mark]!);

const (String, int) _daysSeen = ('bookings.wizard.days', 2);
const (String, int) _switchSeen = ('bookings.wizard.switch', 2);
const (String, int) _cursorsSeen = ('bookings.hours.cursors', 2);
const (String, int) _addHoursSeen = ('bookings.hours.add', 3);
const (String, int) _binSeen = ('bookings.hours.bin', 3);
const (String, int) _forwardSeen = ('bookings.wizard.forward', 4);
const (String, int) _saveHoursSeen = ('bookings.wizard.save.hours', 3);
const (String, int) _bandSeen = ('bookings.wizard.band', 1);
const (String, int) _leftSeen = ('bookings.wizard.left', 1);
const (String, int) _ministrySeen = ('bookings.wizard.ministry', 1);
const (String, int) _disciplinesSeen = ('bookings.wizard.disciplines', 1);
const (String, int) _servicesSeen = ('bookings.wizard.services', 1);
const (String, int) _listSeen = ('bookings.wizard.list', 2);
const (String, int) _openSeen = ('bookings.wizard.open', 3);
const (String, int) _createSeen = ('bookings.wizard.create', 5);
const (String, int) _saveSeen = ('bookings.wizard.save', 5);
const (String, int) _noteSeen = ('bookings.wizard.note', 3);
const (String, int) _noteForwardSeen = ('bookings.wizard.note.forward', 1);

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
    return genders.single == 'F' ? tr(' per tua figlia', ' for your daughter') : tr(' per tuo figlio', ' for your son');
  }

  return genders.every((gender) => gender == 'F')
      ? tr(' per le tue figlie', ' for your daughters')
      : tr(' per i tuoi figli', ' for your children');
}

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
Map<BookingsTourMark, DesktopTourStep> get _marks => {
  BookingsTourMark.add: DesktopTourStep(
    targets: const [kTourBookingsAdd],
    text: tr(
      'Con «Aggiungi in presenza» e «Aggiungi online» puoi prenotare una lezione in presenza oppure online.',
      'With “Add in person” and “Add online” you can book a lesson in person or online.',
    ),
    sides: _leftFirst,
    pad: 6,
    radius: 23,
    reveal: true,
    present: () => _shown(kTourBookingsAdd),
    seen: _markSeen(BookingsTourMark.add),
  ),
  BookingsTourMark.lock: DesktopTourStep(
    targets: const [kTourBookingsLock],
    text: tr('Il lucchetto indica che non è più possibile modificare la prenotazione.', 'The padlock means the booking can no longer be changed.'),
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
    text: tr(
      "Le lezioni in presenza sono contrassegnate dal colore verde e dall'icona di una casa, mentre quelle "
          "online sono indicate in arancione e con l'icona di una videocamera.",
      'In-person lessons are marked in green with a house icon, while online ones are shown in orange '
          'with a video camera icon.',
    ),
    sides: _beside,
    pad: 6,
    radius: 16,
    reveal: true,
    present: () => _shown(kTourBookingsModes),
    seen: _markSeen(BookingsTourMark.modes),
  ),
  BookingsTourMark.lesson: DesktopTourStep(
    targets: const [kTourBookingsLesson],
    text: tr('Qui puoi vedere i dettagli della prenotazione.', 'Here you can see the details of the booking.'),
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
    text: tr("Passando il mouse su questa icona puoi leggere l'argomento della lezione.", 'Hover over this icon to read the topic of the lesson.'),
    sides: _over,
    pad: 4,
    radius: 12,
    reveal: true,
    present: () => _shown(kTourBookingsTopic),
    seen: _markSeen(BookingsTourMark.topic),
  ),
  BookingsTourMark.notes: DesktopTourStep(
    targets: const [kTourBookingsNotes],
    text: tr('Passando il mouse su questa icona puoi leggere le note per il docente.', 'Hover over this icon to read the notes for the teacher.'),
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
    text: tr(
      'Passando con il mouse su una materia compaiono i pulsanti con cui puoi modificarne la prenotazione, '
          'eliminarla, oppure cambiare giorno, fascia oraria e/o modalità (online o in presenza).',
      'Hovering over a subject shows the buttons to change its booking, delete it, or change its day, '
          'time slot and/or mode (online or in person).',
    ),
    sides: _over,
    pad: 4,
    radius: 10,
    reveal: true,
    present: () => _shown(kTourBookingsLessonActions),
    seen: _markSeen(BookingsTourMark.lessonActions),
  ),
  BookingsTourMark.bandActions: DesktopTourStep(
    targets: const [kTourBookingsBandActions],
    text: tr(
      'Passando con il mouse su una fascia oraria compaiono i pulsanti con cui puoi modificare gli orari delle '
          "prenotazioni, richiedere un'altra lezione nella stessa fascia, aggiungere una nota sulla prenotazione, "
          'spostare tutte le lezioni della fascia oraria selezionata (mattina, pomeriggio o sera) oppure eliminare '
          'tutte le materie prenotate in quella fascia.',
      'Hovering over a time slot shows the buttons to change the hours of the bookings, request another lesson '
          'in the same time slot, add a note to the booking, move all the lessons of that time slot (morning, '
          'afternoon or evening) or delete all the subjects booked in it.',
    ),
    sides: _beside,
    pad: 4,
    radius: 10,
    reveal: true,
    present: () => _shown(kTourBookingsBandActions),
    seen: _markSeen(BookingsTourMark.bandActions),
  ),
  BookingsTourMark.dayBin: DesktopTourStep(
    targets: const [kTourBookingsDayBin],
    text: tr("Con questo cestino puoi cancellare le prenotazioni dell'intera giornata.", 'With this bin you can delete the bookings of the whole day.'),
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
      text: tr('Clicca la freccia per passare alla settimana prossima.', 'Click the arrow to go to next week.'),
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
      text: tr(
        'Qui puoi prenotare le lezioni per la settimana prossima, che si sblocca il venerdì alle 20:00.',
        'Here you can book lessons for next week, which unlocks on Friday at 20:00.',
      ),
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
        text: tr(
          'Qui puoi vedere tutte le prenotazioni effettuate questa settimana${_whose(reader, genders)}.',
          'Here you can see all the bookings made this week${_whose(reader, genders)}.',
        ),
        sides: _over,
        pad: 6,
        radius: 27,
        enter: () => bookingsNextWeekShown.value ? showThisWeek() : null,
      ),
      for (final step in marks) _once(step, told),
      if (books) ...[
        ..._nextWeekSteps(showThisWeek),
        for (final step in marks) _once(step, told, nextWeek: true),
        DesktopTourStep(
          targets: const [kTourBookingsDeadlines],
          text: tr(
            'Qui trovi le scadenze entro cui effettuare o modificare le prenotazioni.',
            'Here you find the deadlines for making or changing bookings.',
          ),
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

String _presence(bool online) => online ? tr('presenza online', 'online attendance') : tr('presenza', 'attendance');

// The dates of a new booking; picking one ends it.
DesktopTourStep get _daysStep => DesktopTourStep(
  targets: const [kTourBookingsWizardDays],
  text: tr(
    'Puoi selezionare una data cliccandola. Passando il mouse su una data barrata scopri perché non è '
        'disponibile.',
    "You can pick a date by clicking it. Hover over a struck-out date to find out why it isn't available.",
  ),
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
DesktopTourStep get _cursorsStep => DesktopTourStep(
  targets: const [kTourBookingsHours],
  text: tr('Trascinando i cursori cambi gli orari in cui vuoi prenotare.', 'Drag the handles to change the hours you want to book.'),
  sides: _beside,
  pad: 6,
  radius: 14,
  interactive: true,
  present: () => _shown(kTourBookingsHours),
  seen: _cursorsSeen,
);

DesktopTourStep get _addHoursStep => DesktopTourStep(
  targets: const [kTourBookingsHoursAdd],
  text: tr(
    'Puoi indicare più orari nella stessa fascia. Ad esempio, dalle 14:00 alle 15:00 e dalle 17:00 alle 18:00.',
    'You can give more than one time in the same time slot. For example, from 14:00 to 15:00 and from 17:00 to 18:00.',
  ),
  sides: _beside,
  pad: 6,
  radius: 19,
  present: () => _shown(kTourBookingsHoursAdd),
  seen: _addHoursSeen,
);

DesktopTourStep get _binStep => DesktopTourStep(
  targets: const [kTourBookingsHoursBin],
  text: tr('Puoi eliminare un orario cliccando sul cestino.', 'You can delete a time by clicking the bin.'),
  sides: _beside,
  pad: 4,
  radius: 12,
  present: () => _shown(kTourBookingsHoursBin),
  seen: _binSeen,
);

// The hours card: a "Sì" brings the cursors in; then the band's note, or the hours saved alone.
Future<DesktopTour?> bookingsWizardHoursTour({
  required BookingsTourPupil pupil,
  required bool online,
  required bool hoursOnly,
})
{
  final String whose = pupil == BookingsTourPupil.self
      ? tr('la tua ${_presence(online)}', 'your ${_presence(online)}')
      : tr('la ${_presence(online)} di ${pupil.yours}', "${pupil.yours}'s ${_presence(online)}");

  return _freshTour([
    DesktopTourStep(
      targets: const [kTourBookingsSwitch],
      text: tr(
        'Con il selettore aggiungi o rimuovi $whose nella fascia oraria corrispondente (mattina, pomeriggio o sera).',
        'With the switch you add or remove $whose in that time slot (morning, afternoon or evening).',
      ),
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
      interactive: true,
      present: _cursorsStep.present,
      coming: () => !_shown(kTourBookingsHours),
      seen: _cursorsSeen,
    ),
    _addHoursStep,
    _binStep,
    if (hoursOnly)
      DesktopTourStep(
        targets: const [kTourBookingsWizardSave],
        text: tr('Quando hai finito, clicca «Salva» per salvare i nuovi orari.', "When you're done, click “Save” to save the new hours."),
        sides: _beside,
        pad: 6,
        radius: 17,
        present: () => _shown(kTourBookingsWizardSave),
        seen: _saveHoursSeen,
      )
    else
      DesktopTourStep(
        targets: const [kTourBookingsWizardForward],
        text: tr('Quando hai finito, clicca la freccia per andare avanti.', "When you're done, click the arrow to continue."),
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
DesktopTourStep get _openStep => DesktopTourStep(
  targets: const [kTourBookingsWizardOpen],
  text: tr(
    "Questa materia è articolata in più aree disciplinari. Seleziona l'area per cui desideri prenotare una "
        'lezione. Se hai bisogno di prenotare lezioni per più aree, puoi farlo separatamente, una alla volta.',
    'This subject is divided into several disciplines. Choose the one you want to book a lesson for. '
        'If you need lessons for more than one, you can book them separately, one at a time.',
  ),
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
    text: bookingFinishTourText('clicca', editing: editing),
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
          ? tr(
              "Qui trovi gli orari in cui hai indicato di essere presente${online ? ' online' : ''}: le lezioni prenotate "
                  "verranno organizzate all'interno di questo intervallo.",
              "Here you find the hours when you said you'd be present${online ? ' online' : ''}: the booked lessons "
                  'will be arranged within this time.',
            )
          : tr(
              "Qui trovi gli orari in cui hai indicato che $yours è presente${online ? ' online' : ''}: le lezioni "
                  "prenotate verranno organizzate all'interno di questo intervallo.",
              'Here you find the hours when you said $yours will be present${online ? ' online' : ''}: the booked '
                  'lessons will be arranged within this time.',
            ),
      sides: _below,
      pad: 6,
      radius: 10,
      present: () => _shown(kTourBookingsWizardBand),
      seen: _bandSeen,
    ),
    DesktopTourStep(
      targets: const [kTourBookingsWizardLeft],
      text: tr(
        'A destra trovi il totale delle ore di lezione che puoi ancora richiedere, calcolato sottraendo le ore già '
            'prenotate dal totale delle ore di ${_presence(online)} indicate.',
        'On the right you find the lesson hours you can still request, worked out by taking the hours already '
            'booked away from the hours of ${_presence(online)} you gave.',
      ),
      sides: _below,
      pad: 6,
      radius: 10,
      present: () => _shown(kTourBookingsWizardLeft),
      seen: _leftSeen,
    ),
    tab(
      kTourBookingsWizardMinistry,
      self
          ? tr('In «Materie» trovi solo le materie previste nel tuo indirizzo di studi.', 'In “Subjects” you find only the subjects of your course of study.')
          : tr(
              "In «Materie» trovi solo le materie previste nell'indirizzo di studi di $yours.",
              "In “Subjects” you find only the subjects of $yours's course of study.",
            ),
      _ministrySeen,
    ),
    tab(
      kTourBookingsWizardDisciplines,
      tr(
        'In «Discipline» trovi tutte le discipline che è possibile prenotare in Associazione.',
        'In “Disciplines” you find all the disciplines that can be booked at the Association.',
      ),
      _disciplinesSeen,
    ),
    tab(
      kTourBookingsWizardServices,
      self
          ? tr(
              "In «Servizi» trovi altri servizi che è possibile prenotare, come il supporto per la stesura della tesina "
                  "d'esame.",
              'In “Services” you find other services you can book, such as help writing your exam paper.',
            )
          : tr(
              'In «Servizi» trovi altri servizi che è possibile prenotare per $yours, come il supporto per la stesura '
                  "della tesina d'esame.",
              'In “Services” you find other services you can book for $yours, such as help writing the exam paper.',
            ),
      _servicesSeen,
    ),
    // Its window or its disciplines opened by a click move the tour on.
    DesktopTourStep(
      targets: const [kTourBookingsWizardList],
      text: tr('Da qui puoi selezionare le materie da prenotare.', 'From here you can choose the subjects to book.'),
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

// The band's note card, before its subjects: the field, then the arrow to them.
Future<DesktopTour?> bookingsWizardNoteTour()
{
  return _freshTour([
    DesktopTourStep(
      targets: const [kTourBookingsWizardNote],
      text: kBandNoteTourText,
      sides: _beside,
      pad: 6,
      radius: 17,
      interactive: true,
      present: () => _shown(kTourBookingsWizardNote),
      seen: _noteSeen,
    ),
    DesktopTourStep(
      targets: const [kTourBookingsWizardForward],
      text: tr('Quando hai finito, clicca la freccia per scegliere le materie.', "When you're done, click the arrow to choose the subjects."),
      sides: _leftFirst,
      pad: 6,
      radius: 35,
      present: () => _shown(kTourBookingsWizardForward),
      seen: _noteForwardSeen,
    ),
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
  _SubjectMark.kinds: 2,
  _SubjectMark.topic: 3,
  _SubjectMark.forward: 3,
  _SubjectMark.durations: 5,
  _SubjectMark.count: 2,
  _SubjectMark.teachers: 2,
  _SubjectMark.search: 2,
  _SubjectMark.notes: 4,
  _SubjectMark.add: 3,
  _SubjectMark.save: 3,
};

(String, int) _subjectSeen(_SubjectMark mark) => ('bookings.subject.${mark.name}', _subjectVersions[mark]!);

// [first]: the window's first card, with the intro; [editing]: saves a booked lesson.
Future<DesktopTour?> bookingsSubjectTour({
  required BookingsSubjectCard card,
  required bool first,
  required bool editing,
  required BookingsTourPupil pupil,
})
{
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
        tr(
          'Quando selezioni una materia, ti vengono chieste alcune informazioni aggiuntive, necessarie per '
              'organizzare al meglio le lezioni.',
          "When you choose a subject, you're asked for some extra information, needed to arrange the lessons as "
              'well as possible.',
        ),
      ),
    ...switch (card)
    {
      BookingsSubjectCard.what => [
          step(
            _SubjectMark.kinds,
            tr('Puoi selezionare uno o più tipi di lezione tra quelli indicati.', 'You can choose one or more of the lesson types shown.'),
            target: kTourBookingsSubjectKinds,
            interactive: true,
          ),
          step(
            _SubjectMark.topic,
            tr(
              "Puoi indicare l'argomento da affrontare durante la lezione. Il campo è facoltativo, ma ti invitiamo a "
                  'compilarlo quando possibile: conoscere in anticipo gli argomenti da trattare aiuta il docente a '
                  'preparare la lezione in modo più mirato ed efficace.',
              'You can give the topic to cover during the lesson. The field is optional, but please fill it in '
                  'when you can: knowing the topics in advance helps the teacher prepare a more focused and '
                  'effective lesson.',
            ),
            target: kTourBookingsSubjectTopic,
            radius: 17,
            interactive: true,
          ),
          step(
            _SubjectMark.forward,
            tr('Quando hai fatto, clicca la freccia.', "When you're done, click the arrow."),
            target: kTourBookingsSubjectForward,
            sides: _leftFirst,
            radius: 35,
          ),
        ],
      BookingsSubjectCard.duration => [
          step(
            _SubjectMark.durations,
            tr('Qui puoi selezionare la durata della lezione.', 'Here you can choose the length of the lesson.'),
            target: kTourBookingsSubjectDurations,
            pad: 4,
            radius: 14,
            interactive: true,
          ),
          step(
            _SubjectMark.count,
            tr(
              'Qui puoi vedere quante ore di lezione sono state prenotate rispetto al totale delle ore che puoi '
                  'richiedere.',
              'Here you can see how many lesson hours have been booked out of the hours you can request.',
            ),
            target: kTourBookingsSubjectCount,
            pad: 6,
            radius: 10,
          ),
        ],
      BookingsSubjectCard.teachers => [
          step(
            _SubjectMark.teachers,
            tr('Puoi selezionare fino a tre docenti preferiti per la lezione.', 'You can choose up to three preferred teachers for the lesson.'),
            target: kTourBookingsSubjectTeachers,
            radius: 31,
            interactive: true,
          ),
          step(
            _SubjectMark.search,
            tr('Puoi cercare direttamente un docente tramite il suo nome e cognome.', 'You can search for a teacher directly by first and last name.'),
            target: kTourBookingsSubjectSearch,
            radius: 28,
            interactive: true,
          ),
        ],
      BookingsSubjectCard.notes => [
          step(
            _SubjectMark.notes,
            teacherNotesTourText(pupil == BookingsTourPupil.self ? null : pupil.yours),
            target: kTourBookingsSubjectNotes,
            radius: 17,
            interactive: true,
          ),
          if (editing)
            step(
              _SubjectMark.save,
              tr('Quando hai finito, clicca «Salva» per salvare le modifiche.', "When you're done, click “Save” to save the changes."),
              target: kTourBookingsSubjectSave,
              radius: 17,
            )
          else
            step(
              _SubjectMark.add,
              tr(
                'Quando hai finito, clicca «Aggiungi» per concludere e tornare alla selezione delle materie.',
                "When you're done, click “Add” to finish and go back to choosing the subjects.",
              ),
              target: kTourBookingsSubjectSave,
              radius: 17,
            ),
        ],
    },
  ]);
}

enum _MoveMark { days, options, confirm }

const Map<_MoveMark, int> _moveVersions = {
  _MoveMark.days: 2,
  _MoveMark.options: 2,
  _MoveMark.confirm: 3,
};

(String, int) _moveSeen(_MoveMark mark) => ('bookings.move.${mark.name}', _moveVersions[mark]!);

// The move window: a day, where to, the hours if asked, the button.
// [hoursMayCome]: some option of the picked day would ask for hours.
Future<DesktopTour?> bookingsMoveTour({required bool Function() hoursMayCome})
{
  return _freshTour([
    DesktopTourStep(
      targets: const [kTourBookingsMoveDays],
      text: tr(
        'Puoi selezionare il giorno in cui vuoi spostare la prenotazione. Passando il mouse su una data barrata '
            'scopri perché non è disponibile.',
        "You can choose the day to move the booking to. Hover over a struck-out date to find out why it isn't "
            'available.',
      ),
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
      text: tr(
        "Puoi scegliere con quale modalità e in quale fascia oraria vuoi spostare la lezione. Passando il mouse "
            "su un'opzione barrata scopri perché non è disponibile.",
        "You can choose the mode and time slot to move the lesson to. Hover over a struck-out option to find out "
            "why it isn't available.",
      ),
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
      interactive: true,
      present: _cursorsStep.present,
      coming: hoursMayCome,
      seen: _cursorsSeen,
    ),
    _addHoursStep,
    _binStep,
    DesktopTourStep(
      targets: const [kTourBookingsMoveConfirm],
      text: tr('Quando hai finito, clicca «Sposta».', "When you're done, click “Move”."),
      sides: _beside,
      pad: 6,
      radius: 17,
      present: () => _shown(kTourBookingsMoveConfirm),
      seen: _moveSeen(_MoveMark.confirm),
    ),
  ]);
}

Future<DesktopTour?> bookingsLateMoveTour() => _dueTour([_cursorsStep, _addHoursStep, _binStep]);
