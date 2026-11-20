import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../features/lessons/utils/booking_wizard_strings.dart' show bookingFinishTourText, kBandNoteTourText, teacherNotesTourText;
import '../../../features/lessons/utils/opening_window.dart';
import '../../shared/widgets/mobile_action_circle.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_booking_day.dart';
import 'widgets/mobile_booking_parts.dart';

String get _title => tr('Prenotazioni', 'Bookings');

// Bump a version on every change to that tour.
const String _slug = 'bookings.parent';
const int _version = 12;

// Student main tours; their parts keep the parents' slugs, seen once by whoever has both roles.
const String _studentSlug = 'bookings.student';
const int _studentVersion = 3;
const String _readerSlug = 'bookings.student.reading';
const int _readerVersion = 3;

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

  String get yours => this == daughter ? tr('tua figlia', 'your daughter') : tr('tuo figlio', 'your son');
}

// What a day card may show; each has a one-step tour for when the main one does not show it.
enum BookingMark { add, lock, hours, lesson, addLesson, edit }

const Map<BookingMark, int> _markVersions = {
  BookingMark.add: 2,
  BookingMark.lock: 2,
  BookingMark.hours: 1,
  BookingMark.lesson: 3,
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

String get _toNextWeek => tr('Tocca «Settimana prossima».', 'Tap “Next week”.');
String get _nextWeek => tr(
  'Qui puoi prenotare le lezioni per la settimana prossima, che si sblocca il venerdì alle 20:00.',
  'Here you can book lessons for next week, which opens on Friday at 20:00.',
);
String get _info => tr(
  'In $kMobileTourGlyph trovi le scadenze entro cui effettuare o modificare le prenotazioni: toccalo per leggerle.',
  'In $kMobileTourGlyph you will find the deadlines for making or changing bookings: tap it to read them.',
);

Map<BookingMark, String> get _markTexts => {
  BookingMark.add: tr(
    'Con $kMobileTourGlyph e $kMobileTourGlyph puoi prenotare una lezione in presenza oppure online.',
    'With $kMobileTourGlyph and $kMobileTourGlyph you can book a lesson in person or online.',
  ),
  BookingMark.lock: tr(
    'Il lucchetto indica che non è più possibile modificare la prenotazione.',
    'The padlock means that the booking can no longer be changed.',
  ),
  BookingMark.hours: tr(
    "Le lezioni in presenza sono contrassegnate dal colore verde e dall'icona di una casa, mentre quelle online sono "
        "indicate in arancione e con l'icona di una videocamera.",
    'In-person lessons are marked in green with a house icon, while online ones are shown in orange with a video '
        'camera icon.',
  ),
  BookingMark.lesson: tr(
    'Tocca su una materia prenotata per visualizzarne i dettagli.',
    'Tap a booked subject to see its details.',
  ),
  BookingMark.addLesson: tr(
    "Puoi richiedere direttamente un'altra lezione nella stessa fascia oraria di una lezione già prenotata.",
    'You can request another lesson straight away in the same time slot as a lesson already booked.',
  ),
  BookingMark.edit: tr(
    "Con $kMobileTourGlyph puoi modificare gli orari, spostare o eliminare le prenotazioni dell'intera fascia oraria "
        '(mattina, pomeriggio o sera).',
    'With $kMobileTourGlyph you can change the times, move or delete the bookings of the whole time slot '
        '(morning, afternoon or evening).',
  ),
};

const Duration _pageBack = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

// Lesson sheet as a tour sees it: up and still, lesson changeable or not, how to close it.
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

// Where a week's tour lights each mark: day index, mode index on that day, lesson index in it.
class BookingTourPicks
{
  final int? add;
  final (int, int)? lock;
  final List<(int, int)> hours;
  final (int, int, int)? lesson;
  final (int, int)? addLesson;
  final (int, int)? edit;

  // Its sheet shows "Modifica", "Sposta" and "Elimina".
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

// First of each in the week; a day with both add buttons if any; a lesson by its add button.
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

  // Per day, the first coloured line of that mode; past days and closed bands are grey.
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

String get _closeSheet => tr('Tocca la $kMobileTourGlyph per chiudere il menù.', 'Tap the $kMobileTourGlyph to close the menu.');

// The touched lesson opens its sheet; with [closing], its close button ends it, the page goes on.
// Closed otherwise, the page's steps go on too; stepping back into it opens it again.
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

// [genders]: one per child, 'F' for a daughter; [shown]: the gender of the child shown.
// [readOnly]: one who only looks, with no next week to book nor deadlines.
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

  final String child = genders.isNotEmpty && genders.every(_daughter) ? tr('la figlia', 'daughter') : tr('il figlio', 'child');
  final String yours = _daughter(shown) ? tr('tua figlia', 'your daughter') : tr('tuo figlio', 'your son');

  return MobileTour(
    slug: self ? (readOnly ? _readerSlug : _studentSlug) : _slug,
    title: _title,
    version: self ? (readOnly ? _readerVersion : _studentVersion) : _version,
    prepare: () => turnMobileTourPages(pages, 0),
    steps: [
      if (!self && genders.length > 1)
        MobileTourStep(
          text: tr(
            'Da qui puoi selezionare $child di cui vuoi gestire le prenotazioni.',
            'From here you can choose the $child whose bookings you want to manage.',
          ),
          shown: const [kBookingsTourChildren],
          joined: true,
        ),
      MobileTourStep(
        text: self
            ? tr(
                'Qui puoi vedere tutte le prenotazioni effettuate questa settimana.',
                'Here you can see all the bookings made this week.',
              )
            : tr(
                'Qui puoi vedere tutte le prenotazioni effettuate questa settimana per $yours.',
                'Here you can see all the bookings made this week for $yours.',
              ),
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
        // Ends as the (i) sheet rises and drops the menu bar; the title may be scrolled out.
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

Map<LessonSheetMark, String> get _lessonTexts => {
  LessonSheetMark.details: tr('Qui puoi vedere i dettagli della prenotazione.', 'Here you can see the details of the booking.'),
  LessonSheetMark.actions: tr(
    'Puoi modificare la prenotazione della materia, eliminarla, oppure cambiare giorno, fascia oraria e/o modalità '
        '(online o in presenza).',
    'You can change the booking of the subject, delete it, or change the day, time slot and/or mode '
        '(online or in person).',
  ),
};

String lessonSheetTourTarget(LessonSheetMark mark) => 'bookings.lesson.${mark.name}';

(String, int) _lessonSeen(LessonSheetMark mark) => ('$_slug.lesson.${mark.name}', _lessonVersions[mark]!);

// First time: every part the sheet shows; later, those shown for the first time. Closing stops it.
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
const int _modeSheetVersion = 2;

const String kBookingsTourModeActions = 'bookings.mode.actions';

String get _modeActions => tr(
  'Puoi modificare gli orari delle prenotazioni, aggiungere o modificare la nota sulla prenotazione, spostare tutte '
      'le lezioni della fascia oraria selezionata (mattina, pomeriggio o sera), eliminare tutte le materie prenotate in '
      "quella fascia oppure cancellare le prenotazioni dell'intera giornata.",
  'You can change the times of the bookings, add or edit the booking note, move all the lessons of the selected '
      'time slot (morning, afternoon or evening), delete all the subjects booked in that slot or cancel the bookings '
      'of the whole day.',
);

// Closed under it, it comes again the next time.
Future<void> startModeSheetTour({required String taxCode})
{
  return startMobileTourOnce(
    taxCode: taxCode,
    tour: MobileTour(
      slug: _modeSheetSlug,
      title: _title,
      version: _modeSheetVersion,
      steps: [MobileTourStep(text: _modeActions, shown: const [kBookingsTourModeActions])],
      leave: MobileNavSheet.hidden,
      left: () => !MobileNavSheet.hidden.value,
    ),
  );
}

// Move sheet: day, where to, hours and its button; each explained once, the first time it shows.
enum MoveMark { days, options, hours, add, bin, confirm }

const Map<MoveMark, int> _moveVersions = {
  MoveMark.days: 4,
  MoveMark.options: 4,
  MoveMark.hours: 4,
  MoveMark.add: 3,
  MoveMark.bin: 3,
  MoveMark.confirm: 3,
};

Map<MoveMark, String> get _moveTexts => {
  MoveMark.days: tr(
    'Puoi selezionare il giorno in cui vuoi spostare la prenotazione. Toccando una data barrata scopri perché non '
        'è disponibile.',
    'You can choose the day you want to move the booking to. Tap a struck-through date to find out why it is not '
        'available.',
  ),
  MoveMark.options: tr(
    "Puoi scegliere con quale modalità e in quale fascia oraria vuoi spostare la lezione. Toccando un'opzione "
        'barrata scopri perché non è disponibile.',
    'You can choose the mode and the time slot you want to move the lesson to. Tap a struck-through option to find '
        'out why it is not available.',
  ),
  MoveMark.hours: tr(
    "Con + e − cambi gli orari in cui vuoi prenotare. Toccando l'ora puoi anche scriverla direttamente.",
    'With + and − you change the times you want to book. You can also tap the time to type it in.',
  ),
  MoveMark.add: tr(
    'Puoi indicare più orari nella stessa fascia. Ad esempio, dalle 14:00 alle 15:00 e dalle 17:00 alle 18:00.',
    'You can set more than one time range in the same slot. For example, from 14:00 to 15:00 and from 17:00 to 18:00.',
  ),
  MoveMark.bin: tr('Puoi eliminare un orario toccando sul cestino.', 'You can delete a time range by tapping the bin.'),
  MoveMark.confirm: tr('Quando hai finito, tocca «Sposta».', 'When you have finished, tap “Move”.'),
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
      // Read only, as the bins and «Sposta»: adding, removing, moving are the person's own choice.
      MoveMark.add => MobileTourStep(
          text: text,
          shown: [target],
          reveal: target,
          present: hours,
          coming: coming,
          seen: seen,
        ),
      MoveMark.bin => MobileTourStep(
          text: text,
          shown: [target],
          reveal: target,
          present: bins,
          seen: seen,
        ),
      MoveMark.confirm => MobileTourStep(text: text, shown: [target], seen: seen),
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

// Booking wizard, creating or editing: each mark explained once, on the first page showing it.
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
  open,
  note,
  create,
  save,
  saveHours,
}

enum BookingWizardPage { days, hours, subjects, notes }

const Map<BookingWizardMark, int> _wizardVersions = {
  BookingWizardMark.days: 3,
  BookingWizardMark.yesNo: 4,
  BookingWizardMark.ministry: 3,
  BookingWizardMark.disciplines: 3,
  BookingWizardMark.services: 4,
  BookingWizardMark.band: 4,
  BookingWizardMark.left: 2,
  BookingWizardMark.list: 5,
  BookingWizardMark.open: 3,
  BookingWizardMark.note: 2,
  BookingWizardMark.create: 6,
  BookingWizardMark.save: 7,
  BookingWizardMark.saveHours: 3,
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
  final String presence = online ? tr('presenza online', 'online presence') : tr('presenza', 'presence');

  return switch (mark)
  {
    BookingWizardMark.days => tr(
      'Puoi selezionare una data toccandola. Toccando una data barrata scopri perché non è disponibile.',
      'You can choose a date by tapping it. Tap a struck-through date to find out why it is not available.',
    ),
    BookingWizardMark.yesNo => self
        ? tr(
            'Con il selettore aggiungi o rimuovi la tua $presence nella fascia oraria corrispondente '
                '(mattina, pomeriggio o sera).',
            'With the switch you add or remove your $presence in the matching time slot (morning, afternoon or '
                'evening).',
          )
        : tr(
            'Con il selettore aggiungi o rimuovi la $presence di $yours nella fascia oraria corrispondente '
                '(mattina, pomeriggio o sera).',
            'With the switch you add or remove the $presence of $yours in the matching time slot (morning, afternoon '
                'or evening).',
          ),
    BookingWizardMark.hours => _moveTexts[MoveMark.hours]!,
    BookingWizardMark.add => _moveTexts[MoveMark.add]!,
    BookingWizardMark.bin => _moveTexts[MoveMark.bin]!,
    BookingWizardMark.ministry => self
        ? tr(
            'In «Materie» trovi solo le materie previste nel tuo indirizzo di studi.',
            'In “Subjects” you will only find the subjects of your course of study.',
          )
        : tr(
            "In «Materie» trovi solo le materie previste nell'indirizzo di studi di $yours.",
            "In “Subjects” you will only find the subjects of $yours's course of study.",
          ),
    BookingWizardMark.disciplines => tr(
      'In «Discipline» trovi tutte le discipline che è possibile prenotare in Associazione.',
      'In “Disciplines” you will find all the disciplines that can be booked at the Association.',
    ),
    BookingWizardMark.services => self
        ? tr(
            "In «Servizi» trovi altri servizi che è possibile prenotare, come il supporto per la stesura della tesina "
                "d'esame.",
            'In “Services” you will find other services you can book, such as help with writing the exam paper.',
          )
        : tr(
            'In «Servizi» trovi altri servizi che è possibile prenotare per $yours, come il supporto per la stesura '
                "della tesina d'esame.",
            'In “Services” you will find other services you can book for $yours, such as help with writing the exam '
                'paper.',
          ),
    BookingWizardMark.band => self
        ? tr(
            "Qui trovi gli orari in cui hai indicato di essere presente${online ? ' online' : ''}: le lezioni prenotate "
                "verranno organizzate all'interno di questo intervallo.",
            "Here you will find the times when you said you would be present${online ? ' online' : ''}: the booked "
                'lessons will be arranged within this range.',
          )
        : tr(
            "Qui trovi gli orari in cui hai indicato che $yours è presente${online ? ' online' : ''}: le lezioni "
                "prenotate verranno organizzate all'interno di questo intervallo.",
            "Here you will find the times when you said $yours would be present${online ? ' online' : ''}: the "
                'booked lessons will be arranged within this range.',
          ),
    BookingWizardMark.left => tr(
      'A destra trovi il totale delle ore di lezione che puoi ancora richiedere, calcolato sottraendo le ore già '
          'prenotate dal totale delle ore di $presence indicate.',
      'On the right you will find the total lesson hours you can still request, worked out by subtracting the hours '
          'already booked from the total hours of $presence you gave.',
    ),
    BookingWizardMark.list => tr(
      'Da qui puoi selezionare le materie da prenotare.',
      'From here you can choose the subjects to book.',
    ),
    BookingWizardMark.open => tr(
      "Questa materia è articolata in più aree disciplinari. Seleziona l'area per cui desideri prenotare una lezione. "
          'Se hai bisogno di prenotare lezioni per più aree, puoi farlo separatamente, una alla volta.',
      'This subject is divided into several disciplinary areas. Choose the area you want to book a lesson for. If '
          'you need to book lessons for more than one area, you can do so separately, one at a time.',
    ),
    BookingWizardMark.note => kBandNoteTourText,
    BookingWizardMark.create => tr(
      bookingFinishTourText('tocca', editing: false),
      'When you have finished, tap “Create” to complete and save the booking.',
    ),
    BookingWizardMark.save => tr(
      bookingFinishTourText('tocca', editing: true),
      'When you have finished, tap “Save” to complete and save the booking.',
    ),
    BookingWizardMark.saveHours => tr(
      'Quando hai finito, tocca «Salva» per salvare i nuovi orari.',
      'When you have finished, tap “Save” to save the new times.',
    ),
  };
}

// Wizard news for its tour: last part touched, resting page (null while turning), or closed.
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

// Marks of [kind] never seen, now or once touched; [anyBins]: a band has two stretches.
// [toSubjects] turns the list back to the subjects, which the tabs' steps may have left.
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
        BookingWizardMark.open,
      ],
    // The band's note comes last: the button that saves it all is there.
    BookingWizardPage.notes => const [BookingWizardMark.note, BookingWizardMark.create, BookingWizardMark.save],
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
      // Read only, as the bins and the button: adding, removing, saving are the person's own choice.
      BookingWizardMark.add => MobileTourStep(
          text: text,
          shown: [target],
          reveal: target,
          present: given,
          coming: hoursMayCome,
          seen: seen,
        ),
      BookingWizardMark.bin => MobileTourStep(
          text: text,
          shown: [target],
          reveal: target,
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
      // The band's note: a field, touched to write in it.
      BookingWizardMark.note => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          present: () => isMobileTourTargetShown(target),
          seen: seen,
        ),
      // A subject divided in disciplines, once its list is open under it.
      BookingWizardMark.open => MobileTourStep(
          text: text,
          shown: [target],
          reveal: target,
          present: () => isMobileTourTargetShown(target),
          seen: seen,
        ),
      BookingWizardMark.create || BookingWizardMark.save || BookingWizardMark.saveHours => MobileTourStep(
          text: text,
          shown: [target],
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

// Subject steps, over the wizard or from a lesson's edit button: each part explained once.
enum SubjectFlowMark { intro, kinds, topic, next, durations, count, teachers, search, notes, add, save }

const Map<SubjectFlowMark, int> _subjectVersions = {
  SubjectFlowMark.intro: 1,
  SubjectFlowMark.kinds: 3,
  SubjectFlowMark.topic: 2,
  SubjectFlowMark.next: 4,
  SubjectFlowMark.durations: 5,
  SubjectFlowMark.count: 2,
  SubjectFlowMark.teachers: 3,
  SubjectFlowMark.search: 2,
  SubjectFlowMark.notes: 4,
  SubjectFlowMark.add: 3,
  SubjectFlowMark.save: 3,
};

// The footer's button: forward on every page, adding the subject on the last.
const String kSubjectFlowTourFooter = 'bookings.subject.footer';

String subjectFlowTourTarget(SubjectFlowMark mark) => 'bookings.subject.${mark.name}';

(String, int) _subjectSeen(SubjectFlowMark mark) => ('$_slug.subject.${mark.name}', _subjectVersions[mark]!);

String _subjectText(SubjectFlowMark mark, BookingTourPupil pupil)
{
  return switch (mark)
  {
    SubjectFlowMark.intro => tr(
      'Quando selezioni una materia, ti vengono chieste alcune informazioni aggiuntive, necessarie per organizzare '
          'al meglio le lezioni.',
      'When you choose a subject, you are asked for some extra information, needed to organise the lessons as well '
          'as possible.',
    ),
    SubjectFlowMark.kinds => tr(
      'Puoi selezionare uno o più tipi di lezione tra quelli indicati.',
      'You can choose one or more of the lesson types shown.',
    ),
    SubjectFlowMark.topic => tr(
      "Puoi indicare l'argomento da affrontare durante la lezione. Il campo è facoltativo, ma ti invitiamo a "
          'compilarlo quando possibile: conoscere in anticipo gli argomenti da trattare aiuta il docente a preparare '
          'la lezione in modo più mirato ed efficace.',
      'You can say which topic to cover during the lesson. The field is optional, but we encourage you to fill it '
          'in when you can: knowing the topics in advance helps the teacher prepare a more focused and effective '
          'lesson.',
    ),
    SubjectFlowMark.next => tr('Quando hai fatto, tocca «Avanti».', 'When you are done, tap “Next”.'),
    SubjectFlowMark.durations => tr(
      'Con + e − cambi la durata della lezione. Toccando un valore puoi anche scriverlo direttamente.',
      'With + and − you change the length of the lesson. You can also tap a value to type it in.',
    ),
    SubjectFlowMark.count => tr(
      'Qui puoi vedere quante ore di lezione sono state prenotate rispetto al totale delle ore che puoi richiedere.',
      'Here you can see how many lesson hours have been booked out of the total hours you can request.',
    ),
    SubjectFlowMark.teachers => tr(
      'Puoi selezionare fino a tre docenti preferiti per la lezione.',
      'You can choose up to three preferred teachers for the lesson.',
    ),
    SubjectFlowMark.search => tr(
      'Puoi cercare direttamente un docente tramite il suo nome e cognome.',
      'You can search for a teacher directly by their first and last name.',
    ),
    SubjectFlowMark.notes => tr(
      teacherNotesTourText(pupil == BookingTourPupil.self ? null : pupil.yours),
      pupil == BookingTourPupil.self
          ? 'Here you can add any other information or directions for the teacher who will teach you.'
          : 'Here you can add any other information or directions for the teacher who will teach ${pupil.yours}.',
    ),
    SubjectFlowMark.add => tr(
      'Quando hai finito, tocca «Aggiungi» per concludere e tornare alla selezione delle materie.',
      'When you have finished, tap “Add” to finish and go back to choosing the subjects.',
    ),
    SubjectFlowMark.save => tr(
      'Quando hai finito, tocca «Salva» per salvare le modifiche.',
      'When you have finished, tap “Save” to save the changes.',
    ),
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

// Page parts never seen, the last ending the tour so the page can be filled before going on.
// [first]: the flow's first page, intro first. Parts not built on the page are skipped.
Future<void> startSubjectFlowTour({
  required String taxCode,
  required List<SubjectFlowMark> marks,
  required String page,
  required bool first,
  required bool editing,
  required BookingTourPupil pupil,
  required SubjectFlowTourPulse pulse,
})
{
  MobileTourStep build(SubjectFlowMark mark, (String, int) seen)
  {
    final String text = _subjectText(mark, pupil);
    final String target = subjectFlowTourTarget(mark);

    bool built() => isMobileTourTargetShown(target);

    return switch (mark)
    {
      SubjectFlowMark.intro => MobileTourStep(text: text, lightsAll: true, seen: seen),
      SubjectFlowMark.kinds ||
      SubjectFlowMark.durations ||
      SubjectFlowMark.teachers ||
      SubjectFlowMark.notes =>
        MobileTourStep(text: text, touched: [target], reveal: target, present: built, seen: seen),
      SubjectFlowMark.topic || SubjectFlowMark.count || SubjectFlowMark.search =>
        MobileTourStep(text: text, shown: [target], reveal: target, present: built, seen: seen),
      // Read only: going on, adding a new subject or saving one edited is the person's own choice.
      SubjectFlowMark.next || SubjectFlowMark.add || SubjectFlowMark.save => MobileTourStep(
          text: text,
          shown: const [kSubjectFlowTourFooter],
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
