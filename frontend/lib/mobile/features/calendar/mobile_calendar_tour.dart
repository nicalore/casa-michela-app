import 'package:flutter/foundation.dart';

import '../../../core/language/app_language.dart';
import '../../../core/utils/time_bucket.dart';
import '../../shared/widgets/mobile_choice_sheet.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';

String get _title => tr('Calendario', 'Calendar');

// Bump a version on every change to that tour.
const String _slug = 'calendar';
const int _version = 6;

// The convocation and the tap on a lesson, the first time a call is shown.
const String _callSlug = 'calendar.call';
const int _callVersion = 2;

const String kCalendarTourBands = 'calendar.bands';
const String kCalendarTourDay = 'calendar.day';

// The day picker, the first time it opens.
const String _pickerSlug = 'calendar.picker';
const int _pickerVersion = 2;

const String kCalendarTourPickerDays = 'calendar.picker.days';

String get _picker => tr(
  'Il pallino sotto una data indica la presenza di un calendario pubblicato in quel giorno.',
  'The dot under a date means that a calendar has been published for that day.',
);

String calendarTourCard(TimeBucket band) => 'calendar.card.${band.name}';
String calendarTourLesson(TimeBucket band) => 'calendar.lesson.${band.name}';

String get _bands => tr(
  'Qui puoi vedere, una volta pubblicati, gli orari delle lezioni per ciascuna fascia oraria (mattina, '
      'pomeriggio, sera).',
  'Here you can see, once published, the lesson times for each time slot (morning, afternoon, evening).',
);
String get _day => tr(
  'Puoi scorrere tra i giorni con le frecce, o toccare la data al centro per selezionare un giorno qualsiasi.',
  'You can move between days with the arrows, or tap the date in the middle to choose any day.',
);
String get _card => tr(
  'Qui puoi consultare un riepilogo della tua convocazione, con gli orari di inizio e fine, il numero di lezioni '
      'assegnate, gli studenti coinvolti e il totale delle ore previste. In basso, se sei in presenza, trovi la stanza '
      "assegnata e l'elenco dei responsabili di stanza.",
  'Here you can see a summary of your call-in, with the start and end times, the number of lessons assigned, the '
      'students involved and the total hours planned. At the bottom, if you are in person, you will find the room '
      'assigned and the list of room supervisors.',
);
String get _lesson => tr('Tocca una lezione per vederne i dettagli.', 'Tap a lesson to see its details.');

// The lesson sheet's parts, each explained once, the first time it shows.
enum LessonSheetMark { details, studentTab, facts, technical, methodological, sensitive, note }

// Bump a version on every change to that step.
const String _sheetSlug = 'calendar.lesson';

const Map<LessonSheetMark, int> _sheetVersions = {
  LessonSheetMark.details: 3,
  LessonSheetMark.studentTab: 2,
  LessonSheetMark.facts: 3,
  LessonSheetMark.technical: 2,
  LessonSheetMark.methodological: 2,
  LessonSheetMark.sensitive: 6,
  LessonSheetMark.note: 2,
};

Map<LessonSheetMark, String> get _sheetTexts => {
  LessonSheetMark.details: tr(
    'Qui trovi tutte le informazioni sulla lezione. Le note sono indicazioni aggiuntive inserite da chi ha '
        'prenotato la lezione.',
    'Here you will find all the information about the lesson. The notes are extra directions added by whoever '
        'booked the lesson.',
  ),
  LessonSheetMark.studentTab: tr('Tocca «Studente».', 'Tap “Student”.'),
  LessonSheetMark.facts: tr(
    'Queste sono alcune informazioni sullo studente che possono aiutarti a organizzare la lezione.',
    'This is some information about the student that can help you plan the lesson.',
  ),
  LessonSheetMark.technical: tr(
    "Le osservazioni tecniche sono indicazioni sullo studente inserite dal Direttivo dell'Associazione.",
    "Technical observations are notes about the student added by the Association's Board.",
  ),
  LessonSheetMark.methodological: tr(
    "Le osservazioni metodologiche sono indicazioni operative redatte dagli psicologi dell'Associazione che "
        'seguono o hanno seguito lo studente. Se presenti, ti preghiamo di leggerle con attenzione e di tenerne conto '
        'per adattare la lezione alle esigenze specifiche dello studente.',
    "Methodological observations are practical directions written by the Association's psychologists who follow "
        'or have followed the student. If there are any, please read them carefully and take them into account to '
        "adapt the lesson to the student's specific needs.",
  ),
  LessonSheetMark.sensitive: tr(
    'Alcune di queste informazioni sono particolarmente delicate. Puoi consultarle al fine di offrire allo '
        'studente un servizio più attento e adeguato alle sue necessità. Ti chiediamo, tuttavia, di accedervi in un '
        'luogo riservato, assicurandoti che nessun altro possa vederle, e di non divulgarle in alcun caso, nel '
        'rispetto dello studente.',
    'Some of this information is particularly sensitive. You can read it in order to offer the student a more '
        'attentive service, suited to their needs. We ask you, however, to open it in a private place, making sure '
        'that nobody else can see it, and never to disclose it, out of respect for the student.',
  ),
  LessonSheetMark.note: tr(
    'Puoi aggiungere alcune note relative al comportamento e al rendimento dello studente durante la lezione. '
        'Queste note verranno lette dal Direttivo e in seguito potrebbero essere comunicate alle famiglie oppure, '
        'se ritenute utili per tutti i docenti, aggiunte alle osservazioni tecniche.',
    "You can add some notes about the student's behaviour and performance during the lesson. These notes will be "
        'read by the Board and may later be passed on to the families or, if useful for all the teachers, added to '
        'the technical observations.',
  ),
};

String lessonSheetTourTarget(LessonSheetMark mark) => 'calendar.sheet.${mark.name}';

// One per page of the sheet's strip.
const List<String> kLessonSheetTourTabs = ['calendar.sheet.tab.0', 'calendar.sheet.tab.1'];

(String, int) _sheetSeen(LessonSheetMark mark) => ('$_sheetSlug.${mark.name}', _sheetVersions[mark]!);

// What a tour reads of the lesson sheet, and how it puts the sheet back.
class LessonSheetTourLink extends ChangeNotifier
{
  // Up and still, so its parts can be measured.
  bool open = false;

  int page = 0;

  // The student's page shows the student's facts.
  bool student = false;

  bool note = false;

  VoidCallback? _toFirstPage;
  VoidCallback? _close;

  void rise({
    required bool student,
    required bool note,
    required VoidCallback toFirstPage,
    required VoidCallback close,
  })
  {
    this.student = student;
    this.note = note;
    _toFirstPage = toFirstPage;
    _close = close;
    open = true;
    page = 0;
    notifyListeners();
  }

  void turned(int page)
  {
    if (page != this.page)
    {
      this.page = page;
      notifyListeners();
    }
  }

  void fall()
  {
    open = false;
    page = 0;
    _toFirstPage = null;
    _close = null;
    notifyListeners();
  }

  void toFirstPage() => _toFirstPage?.call();

  void close() => _close?.call();
}

Future<bool> _seen(String taxCode, (String, int) mark)
{
  final (String slug, int version) = mark;

  return isMobileTourSeen(
    taxCode: taxCode,
    tour: MobileTour(slug: slug, title: _title, version: version, steps: const []),
  );
}

Future<bool> isCalendarMainTourSeen(String taxCode) => _seen(taxCode, (_slug, _version));

Future<bool> isCalendarCallTourSeen(String taxCode) => _seen(taxCode, (_callSlug, _callVersion));

Future<Set<LessonSheetMark>> unseenLessonSheetMarks(String taxCode) async
{
  return {
    for (final LessonSheetMark mark in LessonSheetMark.values)
      if (!await _seen(taxCode, _sheetSeen(mark))) mark,
  };
}

// [band]: the band whose call and first lesson are shown; null for none.
// [sheetMarks]: sheet parts never seen, shown once the sheet is up, or at once when [opened].
MobileTour calendarTour({
  required bool main,
  required TimeBucket? band,
  required Set<LessonSheetMark> sheetMarks,
  required LessonSheetTourLink sheet,
  bool student = false,
  bool opened = false,
})
{
  // Set once the sheet rose for the tour: closing it then leaves the tour.
  bool sheetUp = opened;

  final bool lessonAhead = band != null;
  final bool studentAhead = lessonAhead && student;

  bool onStudentPage() => sheet.open && sheet.student && sheet.page == 1;

  MobileTourStep sheetStep(LessonSheetMark mark)
  {
    final String text = _sheetTexts[mark]!;
    final String target = lessonSheetTourTarget(mark);
    final (String, int) seen = _sheetSeen(mark);

    return switch (mark)
    {
      LessonSheetMark.details => MobileTourStep(
          text: text,
          shown: [target],
          present: () => sheet.open,
          coming: () => lessonAhead,
          seen: seen,
        ),
      LessonSheetMark.studentTab => MobileTourStep(
          text: text,
          touched: [kLessonSheetTourTabs[1]],
          watch: sheet,
          reached: () => sheet.page == 1,
          undo: sheet.toFirstPage,
          present: () => sheet.open && sheet.student,
          coming: () => studentAhead,
          seen: seen,
        ),
      LessonSheetMark.facts ||
      LessonSheetMark.technical ||
      LessonSheetMark.methodological => MobileTourStep(
          text: text,
          shown: [target],
          reveal: target,
          present: onStudentPage,
          coming: () => studentAhead || sheet.student,
          seen: seen,
        ),
      // About the whole page: all of it lit, the banner on top.
      LessonSheetMark.sensitive => MobileTourStep(
          text: text,
          high: true,
          lightsAll: true,
          present: onStudentPage,
          coming: () => studentAhead || sheet.student,
          seen: seen,
        ),
      // It turns the sheet to the note's form: nothing left to light.
      LessonSheetMark.note => MobileTourStep(
          text: text,
          touched: [target],
          tapEnds: true,
          present: () => sheet.open && sheet.note,
          coming: () => lessonAhead || sheet.note,
          seen: seen,
        ),
    };
  }

  const (String, int) mainSeen = (_slug, _version);
  const (String, int) callSeen = (_callSlug, _callVersion);

  final List<MobileTourStep> steps = [
    if (main) ...[
      // The page may open scrolled to the lesson under way, the header gone.
      MobileTourStep(
        text: _bands,
        shown: const [kCalendarTourBands],
        reveal: kCalendarTourBands,
        scrolls: false,
        seen: mainSeen,
      ),
      MobileTourStep(text: _day, shown: const [kCalendarTourDay], reveal: kCalendarTourDay, seen: mainSeen),
    ],
    if (band != null) ...[
      MobileTourStep(text: _card, shown: [calendarTourCard(band)], reveal: calendarTourCard(band), seen: callSeen),
      MobileTourStep(
        text: _lesson,
        touched: [calendarTourLesson(band)],
        reveal: calendarTourLesson(band),
        watch: sheet,
        reached: ()
        {
          sheetUp = sheetUp || sheet.open;

          return sheet.open;
        },
        undo: ()
        {
          sheetUp = false;
          sheet.close();
        },
        seen: callSeen,
      ),
    ],
    for (final LessonSheetMark mark in LessonSheetMark.values)
      if (sheetMarks.contains(mark) && (band != null || opened)) sheetStep(mark),
  ];

  final (String slug, int version) = main
      ? mainSeen
      : band != null
          ? callSeen
          : _sheetSeen(LessonSheetMark.values.firstWhere(sheetMarks.contains));

  return MobileTour(
    slug: slug,
    title: _title,
    version: version,
    steps: steps,
    coversIfClosed: [
      mainSeen,
      callSeen,
      for (final LessonSheetMark mark in LessonSheetMark.values) _sheetSeen(mark),
    ],
    leave: sheet,
    left: () => sheetUp && !sheet.open,
  );
}

// Over the picker's sheet; closed under it, it comes again the next time.
MobileTour calendarPickerTour()
{
  return MobileTour(
    slug: _pickerSlug,
    title: _title,
    version: _pickerVersion,
    steps: [MobileTourStep(text: _picker, shown: const [kCalendarTourPickerDays])],
    leave: MobileNavSheet.hidden,
    left: () => !MobileNavSheet.hidden.value,
  );
}

// Parents' page: bands, child picker, day; once a band is published, summary, layouts, a lesson.
// Bump a version on every change to that tour.
const String _parentSlug = 'calendar.parent';
const int _parentVersion = 1;

const String _parentBandSlug = 'calendar.parent.published';
const int _parentBandVersion = 3;

// A student's own page; the lesson sheet's parts keep the parents' slugs.
const String _studentSlug = 'calendar.student';
const int _studentVersion = 1;

const String _studentBandSlug = 'calendar.student.published';
const int _studentBandVersion = 2;

(String, int) _mainSeen({required bool self}) => self ? (_studentSlug, _studentVersion) : (_parentSlug, _parentVersion);

(String, int) _bandSeen({required bool self}) =>
    self ? (_studentBandSlug, _studentBandVersion) : (_parentBandSlug, _parentBandVersion);

const String kPupilCalendarTourBands = 'calendar.pupil.bands';
const String kPupilCalendarTourChildren = 'calendar.pupil.children';
const String kPupilCalendarTourDay = 'calendar.pupil.day';
const String kPupilCalendarTourLayout = 'calendar.pupil.layout';
const String kPupilCalendarTourLayouts = 'calendar.pupil.layouts';

String pupilCalendarTourCards(TimeBucket band) => 'calendar.pupil.cards.${band.name}';

String get _layout => tr('Tocca per cambiare la visualizzazione del calendario.', 'Tap to change how the calendar is shown.');
String get _layouts => tr(
  "La visualizzazione per orario organizza le lezioni su una linea del tempo, mentre quella per lezioni le presenta "
      "in un elenco, una sotto l'altra. Tocca un'opzione per sceglierla.",
  'The view by time lays the lessons out on a timeline, while the view by lesson shows them in a list, one under '
      'the other. Tap an option to choose it.',
);

// The lesson sheet a parent opens, each part explained once, the first time it shows.
enum PupilLessonSheetMark { details, teacherTab, teacher }

const Map<PupilLessonSheetMark, int> _pupilSheetVersions = {
  PupilLessonSheetMark.details: 1,
  PupilLessonSheetMark.teacherTab: 2,
  PupilLessonSheetMark.teacher: 1,
};

// The sheet's second page, the teacher's facts for a parent.
const String kLessonSheetTourOther = 'calendar.sheet.other';

(String, int) _pupilSheetSeen(PupilLessonSheetMark mark) =>
    ('$_parentSlug.lesson.${mark.name}', _pupilSheetVersions[mark]!);

bool _daughter(String? gender) => gender == 'F';

// [self]: the student's own lesson.
String _pupilSheetText(
  PupilLessonSheetMark mark, {
  required String? gender,
  required bool self,
  required String? teacherGender,
})
{
  final String teacher = teacherGender == 'F' ? 'sulla docente' : 'sul docente';

  return switch (mark)
  {
    PupilLessonSheetMark.details => tr(
      'Qui trovi tutte le informazioni sulla lezione.',
      'Here you will find all the information about the lesson.',
    ),
    PupilLessonSheetMark.teacherTab => tr('Tocca «Docente».', 'Tap “Teacher”.'),
    PupilLessonSheetMark.teacher => self
        ? tr(
            'Queste sono alcune informazioni $teacher che ti seguirà per la lezione.',
            'This is some information about the teacher who will teach you in the lesson.',
          )
        : tr(
            'Queste sono alcune informazioni $teacher che seguirà ${_daughter(gender) ? 'tua figlia' : 'tuo figlio'} '
                'per la lezione.',
            'This is some information about the teacher who will teach '
                '${_daughter(gender) ? 'your daughter' : 'your son'} in the lesson.',
          ),
  };
}

Future<bool> isPupilCalendarMainTourSeen(String taxCode, {bool self = false}) =>
    _seen(taxCode, _mainSeen(self: self));

Future<bool> isPupilCalendarBandTourSeen(String taxCode, {bool self = false}) =>
    _seen(taxCode, _bandSeen(self: self));

Future<Set<PupilLessonSheetMark>> unseenPupilLessonSheetMarks(String taxCode) async
{
  return {
    for (final PupilLessonSheetMark mark in PupilLessonSheetMark.values)
      if (!await _seen(taxCode, _pupilSheetSeen(mark))) mark,
  };
}

// [genders]: every child's, when one shows at a time; [band]: the published band lit, or null.
// [openLayouts], [closeLayouts] put the layouts' sheet back when stepping back.
MobileTour pupilCalendarTour({
  required bool main,
  required List<String?>? genders,
  required TimeBucket? band,
  required List<String?> shownGenders,
  required bool online,
  required String? lessonGender,
  required String? teacherGender,
  required ValueListenable<bool> layouts,
  required VoidCallback openLayouts,
  required VoidCallback closeLayouts,
  required Set<PupilLessonSheetMark> sheetMarks,
  required LessonSheetTourLink sheet,
  bool opened = false,
  bool self = false,
})
{
  // Set once the sheet rose for the tour: closing it then leaves the tour.
  bool sheetUp = opened;

  final bool lessonAhead = band != null;

  final List<String?> all = genders ?? const [];
  final String child = all.isNotEmpty && all.every(_daughter) ? tr('la figlia', 'daughter') : tr('il figlio', 'child');

  final String whose = shownGenders.length > 1
      ? (shownGenders.every(_daughter) ? tr('delle tue figlie', "your daughters'") : tr('dei tuoi figli', "your children's"))
      : (shownGenders.isNotEmpty && _daughter(shownGenders.first)
          ? tr('di tua figlia', "your daughter's")
          : tr('di tuo figlio', "your son's"));
  final String presence = online ? tr('presenza online', 'online presence') : tr('presenza', 'presence');
  final String summary = self ? tr('della tua $presence', 'your $presence') : tr('della $presence $whose', '$whose $presence');

  MobileTourStep sheetStep(PupilLessonSheetMark mark)
  {
    final String text = _pupilSheetText(mark, gender: lessonGender, self: self, teacherGender: teacherGender);
    final (String, int) seen = _pupilSheetSeen(mark);

    // Each step on top, over the sheet's header: cards show whole, the banner stays put.
    return switch (mark)
    {
      PupilLessonSheetMark.details => MobileTourStep(
          text: text,
          shown: [lessonSheetTourTarget(LessonSheetMark.details)],
          high: true,
          present: () => sheet.open,
          coming: () => lessonAhead,
          seen: seen,
        ),
      // The sheet's link calls the teacher's facts the student's: the second page's.
      PupilLessonSheetMark.teacherTab => MobileTourStep(
          text: text,
          touched: [kLessonSheetTourTabs[1]],
          high: true,
          watch: sheet,
          reached: () => sheet.page == 1,
          undo: sheet.toFirstPage,
          present: () => sheet.open && sheet.student,
          coming: () => lessonAhead,
          seen: seen,
        ),
      PupilLessonSheetMark.teacher => MobileTourStep(
          text: text,
          shown: const [kLessonSheetTourOther],
          high: true,
          present: () => sheet.open && sheet.student && sheet.page == 1,
          coming: () => lessonAhead || sheet.student,
          seen: seen,
        ),
    };
  }

  final (String, int) mainSeen = _mainSeen(self: self);
  final (String, int) bandSeen = _bandSeen(self: self);

  final List<MobileTourStep> steps = [
    if (main) ...[
      // The page may open scrolled to the lesson under way, the header gone.
      MobileTourStep(
        text: _bands,
        shown: const [kPupilCalendarTourBands],
        reveal: kPupilCalendarTourBands,
        scrolls: false,
        seen: mainSeen,
      ),
      if (genders != null)
        MobileTourStep(
          text: tr(
            'Da qui puoi selezionare $child di cui vuoi visualizzare il calendario delle lezioni.',
            'From here you can choose the $child whose lesson calendar you want to see.',
          ),
          shown: const [kPupilCalendarTourChildren],
          reveal: kPupilCalendarTourChildren,
          joined: true,
          seen: mainSeen,
        ),
      MobileTourStep(text: _day, shown: const [kPupilCalendarTourDay], reveal: kPupilCalendarTourDay, seen: mainSeen),
    ],
    if (band != null) ...[
      MobileTourStep(
        text: tr(
          'Qui puoi consultare un riepilogo $summary, con orario di inizio e fine, il numero di lezioni e il '
              'totale delle ore previste.',
          'Here you can see a summary of $summary, with start and end time, the number of lessons and the total '
              'hours planned.',
        ),
        shown: [pupilCalendarTourCards(band)],
        reveal: pupilCalendarTourCards(band),
        seen: bandSeen,
      ),
      MobileTourStep(
        text: _layout,
        touched: const [kPupilCalendarTourLayout],
        reveal: kPupilCalendarTourLayout,
        watch: layouts,
        reached: () => layouts.value,
        undo: closeLayouts,
        seen: bandSeen,
      ),
      // Either choice closes the sheet and moves on; the forward button keeps the one chosen.
      MobileTourStep(
        text: _layouts,
        touched: const [kPupilCalendarTourLayouts],
        tapping: mobileChoiceTourChosen(kPupilCalendarTourLayouts),
        watch: layouts,
        reached: () => !layouts.value,
        undo: openLayouts,
        present: () => layouts.value,
        coming: () => true,
        seen: bandSeen,
      ),
      MobileTourStep(
        text: _lesson,
        touched: [calendarTourLesson(band)],
        reveal: calendarTourLesson(band),
        watch: sheet,
        reached: ()
        {
          sheetUp = sheetUp || sheet.open;

          return sheet.open;
        },
        undo: ()
        {
          sheetUp = false;
          sheet.close();
        },
        seen: bandSeen,
      ),
    ],
    for (final PupilLessonSheetMark mark in PupilLessonSheetMark.values)
      if (sheetMarks.contains(mark) && (band != null || opened)) sheetStep(mark),
  ];

  final (String slug, int version) = main
      ? mainSeen
      : band != null
          ? bandSeen
          : _pupilSheetSeen(PupilLessonSheetMark.values.firstWhere(sheetMarks.contains));

  return MobileTour(
    slug: slug,
    title: _title,
    version: version,
    steps: steps,
    coversIfClosed: [
      mainSeen,
      bandSeen,
      for (final PupilLessonSheetMark mark in PupilLessonSheetMark.values) _pupilSheetSeen(mark),
    ],
    leave: sheet,
    left: () => sheetUp && !sheet.open,
  );
}
