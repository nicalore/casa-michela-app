import 'package:flutter/material.dart';

import '../../../features/lessons/utils/opening_window.dart';
import '../../shared/widgets/mobile_action_circle.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_booking_day.dart';
import 'widgets/mobile_booking_parts.dart';

const String _title = 'Prenotazioni';

// Bump a version on every change to that tour.
const String _slug = 'bookings.parent';
const int _version = 9;

// A student's main tours; their parts keep the parents' slugs, seen once by whoever wears both roles.
const String _studentSlug = 'bookings.student';
const int _studentVersion = 1;
const String _readerSlug = 'bookings.student.reading';
const int _readerVersion = 1;

// Whom the sentences name: a parent's son or daughter, or the student booking for themselves.
enum BookingTourPupil
{
  son,
  daughter,
  self;

  static BookingTourPupil of({required bool self, required String? gender})
  {
    return self ? BookingTourPupil.self : (gender == 'F' ? daughter : son);
  }

  String get yours => this == daughter ? 'tua figlia' : 'tuo figlio';
}

// What a day card may show; each has a one-step tour for when the main one does not show it.
enum BookingMark { add, lock, hours, lesson, addLesson, edit }

const Map<BookingMark, int> _markVersions = {
  BookingMark.add: 2,
  BookingMark.lock: 2,
  BookingMark.hours: 1,
  BookingMark.lesson: 2,
  BookingMark.addLesson: 1,
  BookingMark.edit: 2,
};

String bookingsTourWeek(int page) => 'bookings.week.$page';
String bookingsTourTab(int page) => 'bookings.tab.$page';
String bookingsTourMark(BookingMark mark, int page) => 'bookings.${mark.name}.$page';

const String kBookingsTourChildren = 'bookings.children';
const String kBookingsTourInfo = 'bookings.info';

const EdgeInsets kBookingsTourWeekInflate = EdgeInsets.all(12);
const double kBookingsTourWeekRadius = 22;

const String _toNextWeek = 'Tocca «Settimana prossima».';
const String _nextWeek = 'Qui puoi prenotare le lezioni per la settimana prossima, che si sblocca il venerdì alle 20:00.';
const String _info =
    'In $kMobileTourGlyph trovi le scadenze entro cui effettuare o modificare le prenotazioni: toccalo per leggerle.';

const Map<BookingMark, String> _markTexts = {
  BookingMark.add: 'Con $kMobileTourGlyph e $kMobileTourGlyph puoi prenotare una lezione in presenza oppure online.',
  BookingMark.lock: 'Il lucchetto indica che non è più possibile modificare la prenotazione.',
  BookingMark.hours:
      "Le lezioni in presenza sono contrassegnate dal colore verde e dall'icona di una casa, mentre quelle online sono "
      "indicate in arancione e con l'icona di una videocamera.",
  BookingMark.lesson: 'Tocca su una materia prenotata per visualizzarne i dettagli.',
  BookingMark.addLesson:
      "Puoi richiedere direttamente un'altra lezione nella stessa fascia oraria di una lezione già prenotata.",
  BookingMark.edit:
      "Con $kMobileTourGlyph puoi modificare gli orari, spostare o eliminare le prenotazioni dell'intera fascia oraria "
      '(mattina, pomeriggio o sera).',
};

const Duration _pageBack = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

// The lesson sheet as a tour sees it: up and still, whether its lesson can be changed, how to close it.
class BookingSheetTourLink extends ChangeNotifier
{
  bool open = false;
  bool editable = false;

  VoidCallback? _close;

  void rise({required bool editable, required VoidCallback close})
  {
    this.editable = editable;
    _close = close;
    open = true;
    notifyListeners();
  }

  void fall()
  {
    open = false;
    _close = null;
    notifyListeners();
  }

  void close() => _close?.call();
}

// Where a week's tour lights each mark: a day's index, with a mode's on that day, and a lesson's in that mode.
class BookingTourPicks
{
  final int? add;
  final (int, int)? lock;
  final List<(int, int)> hours;
  final (int, int, int)? lesson;
  final (int, int)? addLesson;
  final (int, int)? edit;

  // Its sheet shows Modifica, Sposta and Elimina.
  final bool lessonEditable;

  const BookingTourPicks({
    required this.add,
    required this.lock,
    required this.hours,
    required this.lesson,
    required this.addLesson,
    required this.edit,
    required this.lessonEditable,
  });

  Set<BookingMark> get marks => {
        if (add != null) BookingMark.add,
        if (lock != null) BookingMark.lock,
        if (hours.isNotEmpty) BookingMark.hours,
        if (lesson != null) BookingMark.lesson,
        if (addLesson != null) BookingMark.addLesson,
        if (edit != null) BookingMark.edit,
      };
}

// The first of each in the week; both add buttons on one day when one has them; a lesson by its add button.
BookingTourPicks bookingTourPicks(List<MobileBookingDay> days)
{
  (int, int)? first(bool Function(MobileBookingDay day, MobileBookingMode mode) test)
  {
    for (final (i, day) in days.indexed)
    {
      for (final (j, mode) in day.modes.indexed)
      {
        if (test(day, mode))
        {
          return (i, j);
        }
      }
    }

    return null;
  }

  // Per day, the first line of that mode in colour: a day gone by or a band past its deadline is grey.
  List<(int, int)> coloured(String kind) => [
        for (final (i, day) in days.indexed)
          if (day.modes.indexWhere((mode) => !day.isPast && mode.mode == kind && mode.slots.any((slot) => !mode.isClosed(slot)))
              case final int j when j >= 0)
            (i, j),
      ];

  final int bothAdds = days.indexWhere((day) => day.addable.length > 1);
  final int anyAdd = days.indexWhere((day) => day.addable.isNotEmpty);
  final (int, int)? addLesson = first((_, mode) => mode.canAddLesson);

  final (int, int)? lessonMode = switch (addLesson)
  {
    (final int day, final int mode) when days[day].modes[mode].lessons.isNotEmpty => addLesson,
    _ => first((day, mode) => !day.isPast && mode.lessons.isNotEmpty) ?? first((_, mode) => mode.lessons.isNotEmpty),
  };

  return BookingTourPicks(
    add: bothAdds >= 0 ? bothAdds : (anyAdd >= 0 ? anyAdd : null),
    lock: first((_, mode) => mode.hasClosed),
    hours: _closest(coloured(kPresenceMode), coloured(kOnlineMode)),
    lesson: lessonMode == null ? null : (lessonMode.$1, lessonMode.$2, 0),
    addLesson: addLesson,
    edit: first((day, mode) => !day.isPast && (mode.changeable || mode.deletable)),
    lessonEditable: switch (lessonMode)
    {
      (final int day, final int mode) => !days[day].isPast && days[day].modes[mode].lessons.first.editable,
      null => false,
    },
  );
}

// One line of each mode, on the nearest days, so both show at once; the earliest when as near.
List<(int, int)> _closest(List<(int, int)> presence, List<(int, int)> online)
{
  if (presence.isEmpty || online.isEmpty)
  {
    return [...presence.take(1), ...online.take(1)];
  }

  List<(int, int)> best = [presence.first, online.first];

  for (final (int, int) here in presence)
  {
    for (final (int, int) there in online)
    {
      if ((here.$1 - there.$1).abs() < (best[0].$1 - best[1].$1).abs())
      {
        best = [here, there];
      }
    }
  }

  return best;
}

List<Widget Function(double size)> _glyphs(BookingMark mark)
{
  return switch (mark)
  {
    BookingMark.add => [
        (size) => MobileAddModeButton.glyph(kPresenceMode, size),
        (size) => MobileAddModeButton.glyph(kOnlineMode, size),
      ],
    BookingMark.edit => [
        (size) => MobileActionCircle(icon: Icons.edit_calendar_rounded, size: size, iconSize: size * 0.62),
      ],
    BookingMark.lock || BookingMark.hours || BookingMark.lesson || BookingMark.addLesson => const [],
  };
}

MobileTourStep _markStep(BookingMark mark, int page)
{
  return MobileTourStep(
    text: _markTexts[mark]!,
    shown: [bookingsTourMark(mark, page)],
    glyphs: _glyphs(mark),
  );
}

(String, int) _markSeen(BookingMark mark) => ('$_slug.${mark.name}', _markVersions[mark]!);

const String _closeSheet = 'Tocca la $kMobileTourGlyph per chiudere il menù.';

// The lesson touched opens its sheet, read there; with [closing], its close button ends it and the page goes on.
// Closed otherwise, as by the back button, the page's steps go on too; stepping back into it opens it again.
List<MobileTourStep> _lessonSteps({
  required int page,
  required BookingSheetTourLink sheet,
  required VoidCallback open,
  required bool editable,
  required bool closing,
})
{
  final String row = bookingsTourMark(BookingMark.lesson, page);

  void reopen()
  {
    if (!sheet.open)
    {
      open();
    }
  }

  return [
    MobileTourStep(
      text: _markTexts[BookingMark.lesson]!,
      touched: [row],
      reveal: row,
      watch: sheet,
      reached: () => sheet.open,
      undo: sheet.close,
    ),
    MobileTourStep(
      text: _lessonTexts[LessonSheetMark.details]!,
      shown: [lessonSheetTourTarget(LessonSheetMark.details)],
      watch: sheet,
      acted: () => !sheet.open,
      undo: reopen,
      present: () => sheet.open,
      coming: () => true,
      seen: _lessonSeen(LessonSheetMark.details),
    ),
    MobileTourStep(
      text: _lessonTexts[LessonSheetMark.actions]!,
      shown: [lessonSheetTourTarget(LessonSheetMark.actions)],
      watch: sheet,
      acted: () => !sheet.open,
      undo: reopen,
      present: () => sheet.open && sheet.editable,
      coming: () => editable,
      seen: _lessonSeen(LessonSheetMark.actions),
    ),
    if (closing)
      MobileTourStep(
        text: _closeSheet,
        touched: const [kMobileTourSheetClose],
        glyph: MobileSheetCloseButton.glyph,
        watch: sheet,
        reached: () => !sheet.open,
        undo: reopen,
        present: () => sheet.open,
        coming: () => true,
      ),
  ];
}

bool _daughter(String? gender) => gender == 'F';

// [genders]: one per child, 'F' for a daughter; [shown]: the gender of the child whose week shows.
// [openLesson] opens the sheet of the lesson a week's tour lights; [lessonEditable]: that sheet shows its buttons.
// [self]: a student's own bookings; [readOnly]: one who only looks, with no next week to book nor deadlines.
MobileTour bookingsTour({
  required PageController pages,
  required List<String?> genders,
  required String? shown,
  required Set<BookingMark> thisWeek,
  required Set<BookingMark> nextWeek,
  required BookingSheetTourLink sheet,
  required void Function(int page) openLesson,
  required bool Function(int page) lessonEditable,
  bool self = false,
  bool readOnly = false,
})
{
  bool onPage(int index) => pages.hasClients && ((pages.page ?? 0) - index).abs() < _settled;

  void backTo(int index)
  {
    if (pages.hasClients)
    {
      pages.animateToPage(index, duration: _pageBack, curve: Curves.easeInOutCubic);
    }
  }

  List<MobileTourStep> marks(Set<BookingMark> on, int page, {Set<BookingMark> shownBefore = const {}})
  {
    return [
      for (final BookingMark mark in BookingMark.values)
        if (on.contains(mark) && !shownBefore.contains(mark))
          ...mark == BookingMark.lesson
              ? _lessonSteps(
                  page: page,
                  sheet: sheet,
                  open: () => openLesson(page),
                  editable: lessonEditable(page),
                  closing: true,
                )
              : [_markStep(mark, page)],
    ];
  }

  final String child = genders.isNotEmpty && genders.every(_daughter) ? 'la figlia' : 'il figlio';
  final String yours = _daughter(shown) ? 'tua figlia' : 'tuo figlio';

  return MobileTour(
    slug: self ? (readOnly ? _readerSlug : _studentSlug) : _slug,
    title: _title,
    version: self ? (readOnly ? _readerVersion : _studentVersion) : _version,
    steps: [
      if (!self && genders.length > 1)
        MobileTourStep(
          text: 'Da qui puoi selezionare $child di cui vuoi gestire le prenotazioni.',
          shown: const [kBookingsTourChildren],
          joined: true,
        ),
      MobileTourStep(
        text: self
            ? 'Qui puoi vedere tutte le prenotazioni effettuate questa settimana.'
            : 'Qui puoi vedere tutte le prenotazioni effettuate questa settimana per $yours.',
        shown: [bookingsTourWeek(0)],
      ),
      ...marks(thisWeek, 0),
      if (!readOnly) ...[
        // The page scrolled down by the steps before: the strip comes back in sight.
        MobileTourStep(
          text: _toNextWeek,
          touched: [bookingsTourTab(1)],
          reveal: bookingsTourTab(1),
          watch: pages,
          reached: () => onPage(1),
          undo: () => backTo(0),
        ),
        MobileTourStep(text: _nextWeek, shown: [bookingsTourWeek(1)]),
        ...marks(nextWeek, 1, shownBefore: thisWeek),
        // Ends as the (i) sheet rises, which drops the menu bar; the page may have scrolled the title out.
        MobileTourStep(
          text: _info,
          touched: const [kBookingsTourInfo],
          reveal: kBookingsTourInfo,
          glyph: MobileInfoButton.glyph,
          watch: MobileNavSheet.hidden,
          reached: () => MobileNavSheet.hidden.value,
        ),
      ],
    ],
    covers: [for (final BookingMark mark in {...thisWeek, ...nextWeek}) _markSeen(mark)],
    coversIfClosed: [for (final BookingMark mark in BookingMark.values) _markSeen(mark)],
  );
}

// Only to ask whether the main tour was seen: its steps do not matter there.
MobileTour bookingsMainTour(PageController pages, {bool self = false, bool readOnly = false})
{
  return bookingsTour(
    pages: pages,
    genders: const [],
    shown: null,
    thisWeek: const {},
    nextWeek: const {},
    sheet: BookingSheetTourLink(),
    openLesson: (_) {},
    lessonEditable: (_) => false,
    self: self,
    readOnly: readOnly,
  );
}

// The lesson's goes on in its sheet, once [sheet] and [openLesson] are given.
MobileTour bookingsMarkTour(
  BookingMark mark,
  int page, {
  BookingSheetTourLink? sheet,
  VoidCallback? openLesson,
  bool lessonEditable = false,
})
{
  final (String slug, int version) = _markSeen(mark);

  return MobileTour(
    slug: slug,
    title: _title,
    version: version,
    steps: mark == BookingMark.lesson && sheet != null && openLesson != null
        ? _lessonSteps(page: page, sheet: sheet, open: openLesson, editable: lessonEditable, closing: false)
        : [_markStep(mark, page)],
  );
}

MobileTour _seenMarker((String, int) seen) => MobileTour(slug: seen.$1, title: _title, version: seen.$2, steps: const []);

// The parts never seen, as one tour slugged after the first; each part marked seen once shown.
Future<void> _startFresh(
  String taxCode,
  List<(MobileTourStep Function((String, int) seen), (String, int))> parts, {
  required List<(String, int)> all,
  required Listenable leave,
  required bool Function() left,
}) async
{
  final List<MobileTourStep> steps = [];
  (String, int)? first;

  for (final (build, seen) in parts)
  {
    if (!await isMobileTourSeen(taxCode: taxCode, tour: _seenMarker(seen)))
    {
      final MobileTourStep step = build(seen);

      steps.add(step);

      if (first == null && step.isPresent)
      {
        first = seen;
      }
    }
  }

  // Closed while the marks were read, or nothing shows yet.
  if (first == null || left())
  {
    return;
  }

  await startMobileTourOnce(
    taxCode: taxCode,
    tour: MobileTour(
      slug: first.$1,
      title: _title,
      version: first.$2,
      steps: steps,
      coversIfClosed: all,
      leave: leave,
      left: left,
    ),
  );
}

// The lesson sheet, opened from a lesson's row.
enum LessonSheetMark { details, actions }

const Map<LessonSheetMark, int> _lessonVersions = {
  LessonSheetMark.details: 2,
  LessonSheetMark.actions: 1,
};

const Map<LessonSheetMark, String> _lessonTexts = {
  LessonSheetMark.details: 'Qui puoi vedere i dettagli della prenotazione.',
  LessonSheetMark.actions:
      'Puoi modificare la prenotazione della materia, eliminarla, oppure cambiare giorno, fascia oraria e/o modalità '
      '(online o in presenza).',
};

String lessonSheetTourTarget(LessonSheetMark mark) => 'bookings.lesson.${mark.name}';

(String, int) _lessonSeen(LessonSheetMark mark) => ('$_slug.lesson.${mark.name}', _lessonVersions[mark]!);

// The first time: every part the sheet shows; later, those shown for the first time. Closing the sheet stops it.
Future<void> startLessonSheetTour({required String taxCode, required Set<LessonSheetMark> present})
{
  return _startFresh(
    taxCode,
    [
      for (final LessonSheetMark mark in LessonSheetMark.values)
        if (present.contains(mark))
          (
            (seen) => MobileTourStep(text: _lessonTexts[mark]!, shown: [lessonSheetTourTarget(mark)], seen: seen),
            _lessonSeen(mark),
          ),
    ],
    all: [for (final LessonSheetMark mark in LessonSheetMark.values) _lessonSeen(mark)],
    leave: MobileNavSheet.hidden,
    left: () => !MobileNavSheet.hidden.value,
  );
}

// The sheet of a mode's round button: its actions at once, the first time it opens.
const String _modeSheetSlug = '$_slug.mode';
const int _modeSheetVersion = 1;

const String kBookingsTourModeActions = 'bookings.mode.actions';

const String _modeActions =
    'Puoi modificare gli orari delle prenotazioni, spostare tutte le lezioni della fascia oraria selezionata '
    '(mattina, pomeriggio o sera), eliminare tutte le materie prenotate in quella fascia oppure cancellare le '
    "prenotazioni dell'intera giornata.";

// Closed under it, it comes again the next time.
Future<void> startModeSheetTour({required String taxCode})
{
  return startMobileTourOnce(
    taxCode: taxCode,
    tour: MobileTour(
      slug: _modeSheetSlug,
      title: _title,
      version: _modeSheetVersion,
      steps: const [MobileTourStep(text: _modeActions, shown: [kBookingsTourModeActions])],
      leave: MobileNavSheet.hidden,
      left: () => !MobileNavSheet.hidden.value,
    ),
  );
}

// The move sheet: day, where to, hours and its button; each explained once, the first time it shows.
enum MoveMark { days, options, hours, add, bin, confirm }

const Map<MoveMark, int> _moveVersions = {
  MoveMark.days: 3,
  MoveMark.options: 3,
  MoveMark.hours: 3,
  MoveMark.add: 1,
  MoveMark.bin: 1,
  MoveMark.confirm: 1,
};

const Map<MoveMark, String> _moveTexts = {
  MoveMark.days:
      'Puoi selezionare il giorno in cui vuoi spostare la prenotazione. Toccando una data barrata scopri perché non '
      'è disponibile.',
  MoveMark.options:
      "Puoi scegliere con quale modalità e in quale fascia oraria vuoi spostare la lezione. Toccando un'opzione "
      'barrata scopri perché non è disponibile.',
  MoveMark.hours: "Con + e − cambi gli orari in cui vuoi prenotare. Toccando l'ora puoi anche scriverla direttamente.",
  MoveMark.add: 'Puoi indicare più orari nella stessa fascia. Ad esempio, dalle 14:00 alle 15:00 e dalle 17:00 alle 18:00.',
  MoveMark.bin: 'Puoi eliminare un orario toccando sul cestino.',
  MoveMark.confirm: 'Quando hai finito, tocca «Sposta».',
};

String moveTourTarget(MoveMark mark) => 'bookings.move.${mark.name}';

(String, int) _moveSeen(MoveMark mark) => ('$_slug.move.${mark.name}', _moveVersions[mark]!);

// The move sheet's news for its tour: the part just used, or that the sheet is gone.
class MoveTourPulse extends ChangeNotifier
{
  MoveMark? used;
  bool gone = false;

  void use(MoveMark mark)
  {
    used = mark;
    notifyListeners();
  }

  void leave()
  {
    gone = true;
    notifyListeners();
  }
}

// [hours]: the hours show now; [hoursMayCome]: an option of the day chosen would show them.
// [bins]: the hours hold more than one stretch, as once the add button was touched.
Future<void> startMoveTour({
  required String taxCode,
  required MoveTourPulse pulse,
  required bool Function() hasOptions,
  required bool Function() hours,
  required bool Function() hoursMayCome,
  required bool Function() bins,
}) async
{
  final bool asksOption = !await isMobileTourSeen(taxCode: taxCode, tour: _seenMarker(_moveSeen(MoveMark.options)));

  bool used(MoveMark mark) => pulse.used == mark;
  bool coming() => asksOption && hoursMayCome();

  MobileTourStep build(MoveMark mark, (String, int) seen)
  {
    final String target = moveTourTarget(mark);
    final String text = _moveTexts[mark]!;

    return switch (mark)
    {
      MoveMark.days => MobileTourStep(
          text: text,
          touched: [target],
          watch: pulse,
          acted: () => used(mark),
          seen: seen,
        ),
      MoveMark.options => MobileTourStep(
          text: text,
          touched: [target],
          watch: pulse,
          acted: () => used(mark),
          present: hasOptions,
          seen: seen,
        ),
      MoveMark.hours => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          watch: pulse,
          acted: () => used(mark),
          present: hours,
          coming: coming,
          seen: seen,
        ),
      MoveMark.add => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          tapMovesOn: true,
          present: hours,
          coming: coming,
          seen: seen,
        ),
      MoveMark.bin => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          tapMovesOn: true,
          present: bins,
          seen: seen,
        ),
      MoveMark.confirm => MobileTourStep(text: text, touched: [target], tapMovesOn: true, seen: seen),
    };
  }

  await _startFresh(
    taxCode,
    [
      for (final MoveMark mark in MoveMark.values) ((seen) => build(mark, seen), _moveSeen(mark)),
    ],
    all: [for (final MoveMark mark in MoveMark.values) _moveSeen(mark)],
    leave: pulse,
    left: () => pulse.gone,
  );
}

// The booking wizard, creating or editing: each mark explained once, on the first page showing it, in either mode.
// Hours, adding and bins are the move sheet's own marks: seen in one, seen in both.
enum BookingWizardMark
{
  days,
  yesNo,
  hours,
  add,
  bin,
  ministry,
  disciplines,
  services,
  band,
  left,
  list,
  create,
  save,
  saveHours,
}

enum BookingWizardPage { days, hours, subjects }

const Map<BookingWizardMark, int> _wizardVersions = {
  BookingWizardMark.days: 2,
  BookingWizardMark.yesNo: 3,
  BookingWizardMark.ministry: 2,
  BookingWizardMark.disciplines: 2,
  BookingWizardMark.services: 3,
  BookingWizardMark.band: 4,
  BookingWizardMark.left: 2,
  BookingWizardMark.list: 4,
  BookingWizardMark.create: 2,
  BookingWizardMark.save: 3,
  BookingWizardMark.saveHours: 1,
};

const Map<BookingWizardMark, MoveMark> _sharedWithMove = {
  BookingWizardMark.hours: MoveMark.hours,
  BookingWizardMark.add: MoveMark.add,
  BookingWizardMark.bin: MoveMark.bin,
};

// The subjects page's tabs, in their order.
const List<BookingWizardMark> kBookingWizardTabs = [
  BookingWizardMark.ministry,
  BookingWizardMark.disciplines,
  BookingWizardMark.services,
];

String bookingWizardTourTarget(BookingWizardMark mark, String page) => 'bookings.wizard.${mark.name}.$page';

(String, int) _wizardSeen(BookingWizardMark mark)
{
  final MoveMark? shared = _sharedWithMove[mark];

  return shared != null ? _moveSeen(shared) : ('$_slug.wizard.${mark.name}', _wizardVersions[mark]!);
}

// [online] words the presence as online.
String _wizardText(BookingWizardMark mark, {required bool online, required BookingTourPupil pupil})
{
  final bool self = pupil == BookingTourPupil.self;
  final String yours = pupil.yours;
  final String presence = online ? 'presenza online' : 'presenza';

  return switch (mark)
  {
    BookingWizardMark.days =>
      'Puoi selezionare una data toccandola. Toccando una data barrata scopri perché non è disponibile.',
    BookingWizardMark.yesNo => self
        ? 'Con il selettore aggiungi o rimuovi la tua $presence nella fascia oraria corrispondente '
            '(mattina, pomeriggio o sera).'
        : 'Con il selettore aggiungi o rimuovi la $presence di $yours nella fascia oraria corrispondente '
            '(mattina, pomeriggio o sera).',
    BookingWizardMark.hours => _moveTexts[MoveMark.hours]!,
    BookingWizardMark.add => _moveTexts[MoveMark.add]!,
    BookingWizardMark.bin => _moveTexts[MoveMark.bin]!,
    BookingWizardMark.ministry => self
        ? 'In «Materie» trovi solo le materie previste nel tuo indirizzo di studi.'
        : "In «Materie» trovi solo le materie previste nell'indirizzo di studi di $yours.",
    BookingWizardMark.disciplines => 'In «Discipline» trovi tutte le discipline che è possibile prenotare in Associazione.',
    BookingWizardMark.services => self
        ? "In «Servizi» trovi altri servizi che è possibile prenotare, come il supporto per la stesura della tesina "
            "d'esame."
        : 'In «Servizi» trovi altri servizi che è possibile prenotare per $yours, come il supporto per la stesura '
            "della tesina d'esame.",
    BookingWizardMark.band => self
        ? "Qui trovi gli orari in cui hai indicato di essere presente${online ? ' online' : ''}: le lezioni prenotate "
            "verranno organizzate all'interno di questo intervallo."
        : "Qui trovi gli orari in cui hai indicato che $yours è presente${online ? ' online' : ''}: le lezioni "
            "prenotate verranno organizzate all'interno di questo intervallo.",
    BookingWizardMark.left =>
      'A destra trovi il totale delle ore di lezione che puoi ancora richiedere, calcolato sottraendo le ore già '
          'prenotate dal totale delle ore di $presence indicate.',
    BookingWizardMark.list => 'Da qui puoi selezionare le materie da prenotare.',
    BookingWizardMark.create =>
      'Quando hai selezionato tutte le materie che ti interessano, tocca «Crea» per concludere e salvare la prenotazione.',
    BookingWizardMark.save =>
      'Quando hai selezionato tutte le materie che ti interessano, tocca «Salva» per concludere e salvare la prenotazione.',
    BookingWizardMark.saveHours => 'Quando hai finito, tocca «Salva» per salvare i nuovi orari.',
  };
}

// The wizard's news for its tour: the part just touched, the page it rests on (null while turning), or that it closed.
class BookingWizardTourPulse extends ChangeNotifier
{
  BookingWizardMark? used;
  String? page;
  bool gone = false;

  void use(BookingWizardMark mark)
  {
    used = mark;
    notifyListeners();
  }

  void rest(String? key)
  {
    if (key != page)
    {
      page = key;
      notifyListeners();
    }
  }

  void leave()
  {
    gone = true;
    notifyListeners();
  }
}

// The marks of [kind] never seen, as they stand or as touches on the page will make them.
// [anyOpen]: a band can be given; [anyGiven]: one has hours; [anyBins]: one has two stretches; [band]: the tag shows.
// [toSubjects] turns the list back to the subjects, which the tabs' steps may have left on another.
// [creates], [saves]: the page's button creates the booking, or saves an edited one; a subject is chosen, and no
// subject's own pages cover the wizard. [savesHours]: the hours page is the last, when only the hours are edited.
Future<void> startBookingWizardTour({
  required String taxCode,
  required BookingWizardPage kind,
  required String page,
  required bool online,
  required BookingTourPupil pupil,
  required BookingWizardTourPulse pulse,
  bool Function()? anyOpen,
  bool Function()? anyGiven,
  bool Function()? anyBins,
  bool Function()? band,
  bool Function()? creates,
  bool Function()? saves,
  bool Function()? savesHours,
  VoidCallback? toSubjects,
}) async
{
  final List<BookingWizardMark> marks = switch (kind)
  {
    BookingWizardPage.days => const [BookingWizardMark.days],
    BookingWizardPage.hours => const [
        BookingWizardMark.yesNo,
        BookingWizardMark.hours,
        BookingWizardMark.add,
        BookingWizardMark.bin,
        BookingWizardMark.saveHours,
      ],
    BookingWizardPage.subjects => const [
        BookingWizardMark.ministry,
        BookingWizardMark.disciplines,
        BookingWizardMark.services,
        BookingWizardMark.band,
        BookingWizardMark.left,
        BookingWizardMark.list,
        BookingWizardMark.create,
        BookingWizardMark.save,
      ],
  };

  final bool asksYesNo = !await isMobileTourSeen(taxCode: taxCode, tour: _seenMarker(_wizardSeen(BookingWizardMark.yesNo)));

  bool used(BookingWizardMark mark) => pulse.used == mark;
  bool open() => anyOpen?.call() ?? false;
  bool given() => anyGiven?.call() ?? false;
  bool hoursMayCome() => asksYesNo && open();

  MobileTourStep build(BookingWizardMark mark, (String, int) seen)
  {
    final String target = bookingWizardTourTarget(mark, page);
    final String text = _wizardText(mark, online: online, pupil: pupil);

    return switch (mark)
    {
      BookingWizardMark.days || BookingWizardMark.yesNo => MobileTourStep(
          text: text,
          touched: [target],
          watch: pulse,
          acted: () => used(mark),
          present: mark == BookingWizardMark.yesNo ? open : null,
          seen: seen,
        ),
      BookingWizardMark.hours => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          watch: pulse,
          acted: () => used(mark),
          present: given,
          coming: hoursMayCome,
          seen: seen,
        ),
      BookingWizardMark.add => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          tapMovesOn: true,
          present: given,
          coming: hoursMayCome,
          seen: seen,
        ),
      BookingWizardMark.bin => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          tapMovesOn: true,
          present: () => anyBins?.call() ?? false,
          seen: seen,
        ),
      BookingWizardMark.ministry || BookingWizardMark.disciplines || BookingWizardMark.services => MobileTourStep(
          text: text,
          touched: [target],
          tapMovesOn: true,
          seen: seen,
        ),
      BookingWizardMark.band || BookingWizardMark.left => MobileTourStep(
          text: text,
          shown: [target],
          present: () => band?.call() ?? false,
          seen: seen,
        ),
      // It opens the subject's own steps over the wizard: nothing left to light.
      BookingWizardMark.list => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          enter: toSubjects,
          tapEnds: true,
          seen: seen,
        ),
      // Touched, it saves and closes the wizard.
      BookingWizardMark.create || BookingWizardMark.save || BookingWizardMark.saveHours => MobileTourStep(
          text: text,
          touched: [target],
          tapEnds: true,
          present: () => switch (mark)
          {
            BookingWizardMark.create => creates,
            BookingWizardMark.save => saves,
            _ => savesHours,
          }?.call() ?? false,
          seen: seen,
        ),
    };
  }

  await _startFresh(
    taxCode,
    [
      for (final BookingWizardMark mark in marks) ((seen) => build(mark, seen), _wizardSeen(mark)),
    ],
    all: [for (final BookingWizardMark mark in BookingWizardMark.values) _wizardSeen(mark)],
    leave: pulse,
    left: () => pulse.gone || pulse.page != page,
  );
}

// The subject's own steps, over the wizard or from a lesson's edit button: each part explained once, on its page.
enum SubjectFlowMark { intro, disciplines, kinds, topic, next, durations, count, teachers, search, notes, add, save }

const Map<SubjectFlowMark, int> _subjectVersions = {
  SubjectFlowMark.intro: 1,
  SubjectFlowMark.disciplines: 1,
  SubjectFlowMark.kinds: 2,
  SubjectFlowMark.topic: 2,
  SubjectFlowMark.next: 2,
  SubjectFlowMark.durations: 2,
  SubjectFlowMark.count: 1,
  SubjectFlowMark.teachers: 2,
  SubjectFlowMark.search: 2,
  SubjectFlowMark.notes: 2,
  SubjectFlowMark.add: 1,
  SubjectFlowMark.save: 1,
};

// The footer's button: forward on every page, adding the subject on the last.
const String kSubjectFlowTourFooter = 'bookings.subject.footer';

String subjectFlowTourTarget(SubjectFlowMark mark) => 'bookings.subject.${mark.name}';

(String, int) _subjectSeen(SubjectFlowMark mark) => ('$_slug.subject.${mark.name}', _subjectVersions[mark]!);

String _subjectText(SubjectFlowMark mark, {required bool online, required BookingTourPupil pupil})
{
  final String presence = online ? 'presenza online' : 'presenza';
  final String total = pupil == BookingTourPupil.self
      ? 'il totale delle tue ore di $presence'
      : 'il totale di ore di $presence di ${pupil.yours}';

  return switch (mark)
  {
    SubjectFlowMark.intro =>
      'Quando selezioni una materia, ti vengono chieste alcune informazioni aggiuntive, necessarie per organizzare '
          'al meglio le lezioni.',
    SubjectFlowMark.disciplines =>
      'Le materie possono essere divise in più aree: in tal caso, è necessario selezionarne almeno una su cui deve '
          'svolgersi la lezione.',
    SubjectFlowMark.kinds => 'Puoi selezionare uno o più tipi di lezione tra quelli indicati.',
    SubjectFlowMark.topic =>
      "Puoi indicare l'argomento da affrontare durante la lezione. Il campo è facoltativo, ma ti invitiamo a "
          'compilarlo quando possibile: conoscere in anticipo gli argomenti da trattare aiuta il docente a preparare '
          'la lezione in modo più mirato ed efficace.',
    SubjectFlowMark.next => 'Quando hai fatto, tocca «Avanti».',
    SubjectFlowMark.durations => 'Qui puoi selezionare la durata della lezione.',
    SubjectFlowMark.count =>
      'Qui puoi vedere quante ore di lezione sono state prenotate rispetto al totale delle ore che puoi richiedere. '
          'Se diventa rosso, significa che hai superato $total.',
    SubjectFlowMark.teachers => 'Puoi selezionare fino a tre docenti preferiti per la lezione.',
    SubjectFlowMark.search => 'Puoi cercare direttamente un docente tramite il suo nome e cognome.',
    SubjectFlowMark.notes => 'Qui puoi aggiungere eventuali altre osservazioni o informazioni che ritieni utili.',
    SubjectFlowMark.add =>
      'Quando hai finito, tocca «Aggiungi» per concludere e tornare alla selezione delle materie.',
    SubjectFlowMark.save => 'Quando hai finito, tocca «Salva» per salvare le modifiche.',
  };
}

// The flow's news for its tour: the page it rests on (null while turning), or that it closed.
class SubjectFlowTourPulse extends ChangeNotifier
{
  String? page;
  bool gone = false;

  void rest(String? key)
  {
    if (key != page)
    {
      page = key;
      notifyListeners();
    }
  }

  void leave()
  {
    gone = true;
    notifyListeners();
  }
}

// The page's parts never seen, the last ending the tour so the page can be filled before going on; [first]: the
// flow's first page, where the intro comes first. A part not built on the page is passed over.
Future<void> startSubjectFlowTour({
  required String taxCode,
  required List<SubjectFlowMark> marks,
  required String page,
  required bool first,
  required bool editing,
  required bool online,
  required BookingTourPupil pupil,
  required SubjectFlowTourPulse pulse,
})
{
  MobileTourStep build(SubjectFlowMark mark, (String, int) seen)
  {
    final String text = _subjectText(mark, online: online, pupil: pupil);
    final String target = subjectFlowTourTarget(mark);

    bool built() => isMobileTourTargetShown(target);

    return switch (mark)
    {
      SubjectFlowMark.intro => MobileTourStep(text: text, lightsAll: true, seen: seen),
      SubjectFlowMark.disciplines ||
      SubjectFlowMark.kinds ||
      SubjectFlowMark.durations ||
      SubjectFlowMark.teachers ||
      SubjectFlowMark.notes =>
        MobileTourStep(text: text, touched: [target], reveal: target, present: built, seen: seen),
      SubjectFlowMark.topic || SubjectFlowMark.count || SubjectFlowMark.search =>
        MobileTourStep(text: text, shown: [target], reveal: target, present: built, seen: seen),
      // Touched, it turns the page or ends the flow: the tour leaves with it, its parts after it come next time.
      // The last page's button adds a new subject, or saves one edited.
      SubjectFlowMark.next || SubjectFlowMark.add || SubjectFlowMark.save => MobileTourStep(
          text: text,
          touched: const [kSubjectFlowTourFooter],
          present: switch (mark)
          {
            SubjectFlowMark.add => () => !editing,
            SubjectFlowMark.save => () => editing,
            _ => null,
          },
          seen: seen,
        ),
    };
  }

  return _startFresh(
    taxCode,
    [
      for (final SubjectFlowMark mark in [if (first) SubjectFlowMark.intro, ...marks])
        ((seen) => build(mark, seen), _subjectSeen(mark)),
    ],
    all: [for (final SubjectFlowMark mark in SubjectFlowMark.values) _subjectSeen(mark)],
    leave: pulse,
    left: () => pulse.gone || pulse.page != page,
  );
}
