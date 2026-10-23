import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';

const String kTourCalendarBands = 'calendar.bands';
const String kTourCalendarDay = 'calendar.day';
const String kTourCalendarCard = 'calendar.card';
const String kTourCalendarLesson = 'calendar.lesson';

const String kTourCalendarPickerDays = 'calendar.picker.days';

const String kTourLessonDetails = 'calendar.dialog.details';
const String kTourLessonStudent = 'calendar.dialog.student';
const String kTourLessonTechnical = 'calendar.dialog.technical';
const String kTourLessonMethodological = 'calendar.dialog.methodological';
const String kTourLessonSensitive = 'calendar.dialog.sensitive';
const String kTourLessonNote = 'calendar.dialog.note';

// True while a lesson's window is up, and while the month picker is: the tours wait for them.
final ValueNotifier<bool> calendarLessonOpen = ValueNotifier(false);
final ValueNotifier<bool> calendarPickerOpen = ValueNotifier(false);

// Set by the lesson's window while it is up: stepping back out of it closes it.
VoidCallback? calendarLessonCloser;

const String _title = 'Calendario';

// Bump a version on every change to that tour.
const (String, int) _pageSeen = ('calendar', 1);
const int _pickerVersion = 2;

// The convocation and the click on a lesson, the first time a call is shown.
const (String, int) _callSeen = ('calendar.call', 1);

// Lesson window parts, each told when first shown. Bump a version on every change to that step.
enum CalendarLessonMark { details, facts, technical, methodological, sensitive, note }

const Map<CalendarLessonMark, int> _markVersions = {
  CalendarLessonMark.details: 1,
  CalendarLessonMark.facts: 1,
  CalendarLessonMark.technical: 1,
  CalendarLessonMark.methodological: 1,
  CalendarLessonMark.sensitive: 1,
  CalendarLessonMark.note: 1,
};

(String, int) _markSeen(CalendarLessonMark mark) => ('calendar.lesson.${mark.name}', _markVersions[mark]!);

const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.right, DesktopTourSide.above];
const List<DesktopTourSide> _belowLeft = [DesktopTourSide.below, DesktopTourSide.left, DesktopTourSide.above];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];
const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];

bool _shown(String id) => isDesktopTourTargetShown(id);

// The same windows serve students and parents: only teachers are toured here.
void startCalendarTour(BuildContext context, DesktopTour tour)
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  if (taxCode == null || ApiService().lastKnownIdentity?.activeRole != 'TEACHER')
  {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_)
  {
    if (context.mounted)
    {
      startDesktopTourOnce(context, taxCode: taxCode, tour: tour);
    }
  });

  // Asked from another frame's callback, it still needs a frame to come.
  WidgetsBinding.instance.scheduleFrame();
}

String? get _teacher
{
  final identity = ApiService().lastKnownIdentity;

  return identity?.activeRole == 'TEACHER' ? identity?.taxCode : null;
}

Future<bool> _seen(String taxCode, (String, int) mark)
{
  final (String slug, int version) = mark;

  return isDesktopTourSeen(
    taxCode: taxCode,
    tour: DesktopTour(slug: slug, title: _title, version: version, steps: const []),
  );
}

// Asked before the page tour: an untold call is shown where it is, as on mobile.
Future<bool> isCalendarCallDue() async
{
  final String? taxCode = _teacher;

  return taxCode != null && !await _seen(taxCode, _callSeen);
}

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
// The bands and the day, the same for teachers, parents and students.
const List<DesktopTourStep> kCalendarMainSteps = [
  DesktopTourStep(
    targets: [kTourCalendarBands],
    text: 'Qui puoi vedere, una volta pubblicati, gli orari delle lezioni per ciascuna fascia oraria (mattina, '
        'pomeriggio, sera).',
    sides: _below,
    pad: 6,
    radius: 25,
  ),
  DesktopTourStep(
    targets: [kTourCalendarDay],
    text: 'Puoi scorrere tra i giorni con le frecce, o cliccare il calendario per selezionare un giorno qualsiasi.',
    sides: _belowLeft,
    pad: 6,
    radius: 25,
  ),
];

final List<DesktopTourStep> _callSteps = [
  DesktopTourStep(
    targets: const [kTourCalendarCard],
    text: 'Qui puoi consultare un riepilogo della tua convocazione, con gli orari di inizio e fine, il numero di '
        'lezioni assegnate, gli studenti coinvolti e il totale delle ore previste. In basso, se sei in presenza, '
        "trovi la stanza assegnata e l'elenco dei responsabili di stanza.",
    sides: _below,
    pad: 6,
    radius: 21,
    reveal: true,
    present: () => _shown(kTourCalendarCard),
    seen: _callSeen,
  ),
  DesktopTourStep(
    targets: const [kTourCalendarLesson],
    text: 'Clicca una lezione per vederne i dettagli.',
    sides: _beside,
    pad: 4,
    radius: 12,
    reveal: true,
    listen: calendarLessonOpen,
    reached: () => calendarLessonOpen.value,
    present: () => _shown(kTourCalendarLesson),
    seen: _callSeen,
  ),
];

// [undo]: first window step inside the page's tour. [coming]: counted before the window is up.
DesktopTourStep _lessonStep(CalendarLessonMark mark, {VoidCallback? undo, bool Function()? coming})
{
  bool there(String id) => calendarLessonOpen.value && _shown(id);

  final (String target, String text) = switch (mark)
  {
    CalendarLessonMark.details => (
        kTourLessonDetails,
        'Qui trovi tutte le informazioni sulla lezione. Le note sono indicazioni aggiuntive inserite dal genitore '
            'per te.',
      ),
    CalendarLessonMark.facts => (
        kTourLessonStudent,
        'Queste sono alcune informazioni sullo studente che possono aiutarti a organizzare la lezione.',
      ),
    CalendarLessonMark.technical => (
        kTourLessonTechnical,
        "Le osservazioni tecniche sono indicazioni sullo studente inserite dal Direttivo dell'Associazione.",
      ),
    CalendarLessonMark.methodological => (
        kTourLessonMethodological,
        "Le osservazioni metodologiche sono indicazioni operative redatte dagli psicologi dell'Associazione che "
            'seguono o hanno seguito lo studente. Se presenti, ti preghiamo di leggerle con attenzione e di tenerne '
            'conto per adattare la lezione alle esigenze specifiche dello studente.',
      ),
    CalendarLessonMark.sensitive => (
        kTourLessonSensitive,
        "Alcune di queste informazioni sono particolarmente delicate. Puoi "
            'consultarle al fine di offrire allo studente un servizio più attento e adeguato alle sue necessità. Ti '
            'chiediamo, tuttavia, di accedervi in un luogo riservato, assicurandoti che nessun altro possa vederle, e '
            'di non divulgarle in alcun caso, nel rispetto dello studente.',
      ),
    CalendarLessonMark.note => (
        kTourLessonNote,
        'Puoi aggiungere alcune note relative al comportamento e al rendimento dello studente durante la lezione. '
            'Queste note verranno lette dal Direttivo e in seguito potrebbero essere comunicate alle famiglie oppure, '
            'se ritenute utili per tutti i docenti, aggiunte alle osservazioni tecniche.',
      ),
  };

  // The window closed under the tour takes it away.
  return switch (mark)
  {
    CalendarLessonMark.details || CalendarLessonMark.facts => DesktopTourStep(
        targets: [target],
        text: text,
        sides: _beside,
        pad: 6,
        radius: 31,
        reveal: true,
        listen: calendarLessonOpen,
        gone: () => !calendarLessonOpen.value,
        undo: undo,
        present: () => there(target),
        coming: coming,
        seen: _markSeen(mark),
      ),
    CalendarLessonMark.technical || CalendarLessonMark.methodological => DesktopTourStep(
        targets: [target],
        text: text,
        sides: _over,
        pad: 10,
        radius: 14,
        reveal: true,
        listen: calendarLessonOpen,
        gone: () => !calendarLessonOpen.value,
        undo: undo,
        present: () => there(target),
        coming: coming,
        seen: _markSeen(mark),
      ),
    // Every masked value lit; the student's card brought back in sight for its first ones.
    CalendarLessonMark.sensitive => DesktopTourStep(
        targets: [target],
        apart: true,
        text: text,
        sides: const [DesktopTourSide.left, DesktopTourSide.right, DesktopTourSide.above, DesktopTourSide.below],
        pad: 8,
        radius: 12,
        reveal: true,
        revealing: kTourLessonStudent,
        listen: calendarLessonOpen,
        gone: () => !calendarLessonOpen.value,
        undo: undo,
        present: () => there(target),
        coming: coming,
        seen: _markSeen(mark),
      ),
    CalendarLessonMark.note => DesktopTourStep(
        targets: [target],
        text: text,
        sides: _over,
        pad: 6,
        radius: 17,
        listen: calendarLessonOpen,
        gone: () => !calendarLessonOpen.value,
        undo: undo,
        present: () => there(target),
        coming: coming,
        seen: _markSeen(mark),
      ),
  };
}

Future<List<CalendarLessonMark>> _unseenMarks(String taxCode) async
{
  return [
    for (final CalendarLessonMark mark in CalendarLessonMark.values)
      if (!await _seen(taxCode, _markSeen(mark))) mark,
  ];
}

// Page, call and lesson window as one tour (a click opens the window); null if none is due.
// [student], [note]: what the lit lesson's window shows.
Future<DesktopTour?> calendarPageTour({required bool student, required bool note}) async
{
  final String? taxCode = _teacher;

  if (taxCode == null)
  {
    return null;
  }

  final bool main = !await _seen(taxCode, _pageSeen);
  final bool call = !await _seen(taxCode, _callSeen);
  final bool lesson = _shown(kTourCalendarLesson);

  if (!main && !(call && lesson))
  {
    return null;
  }

  final List<CalendarLessonMark> marks = call ? await _unseenMarks(taxCode) : const [];

  final (String slug, int version) = main ? _pageSeen : _callSeen;

  return DesktopTour(
    slug: slug,
    title: _title,
    version: version,
    steps: [
      if (main) ...kCalendarMainSteps,
      if (call) ..._callSteps,
      for (final (int index, CalendarLessonMark mark) in marks.indexed)
        _lessonStep(
          mark,
          undo: index == 0 ? () => calendarLessonCloser?.call() : null,
          coming: () => lesson && switch (mark)
          {
            CalendarLessonMark.details => true,
            CalendarLessonMark.note => note,
            _ => student,
          },
        ),
    ],
  );
}

// A lesson's window opened outside the page's tour: its parts never seen, the first time they show.
Future<DesktopTour?> calendarLessonTour() async
{
  final String? taxCode = _teacher;

  if (taxCode == null)
  {
    return null;
  }

  final List<CalendarLessonMark> marks = await _unseenMarks(taxCode);

  return dueDesktopTour(
    taxCode: taxCode,
    title: _title,
    steps: [for (final CalendarLessonMark mark in marks) _lessonStep(mark)],
  );
}

// Over the picker; a click on a day picks it and ends the tour.
final DesktopTour calendarPickerTour = DesktopTour(
  slug: 'calendar.picker',
  title: _title,
  version: _pickerVersion,
  steps: [
    DesktopTourStep(
      targets: const [kTourCalendarPickerDays],
      text: 'Il pallino sotto una data indica la presenza di un calendario pubblicato in quel giorno.',
      sides: _beside,
      pad: 6,
      radius: 12,
      interactive: true,
      listen: calendarPickerOpen,
      reached: () => !calendarPickerOpen.value,
    ),
  ],
);
