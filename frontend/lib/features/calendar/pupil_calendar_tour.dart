import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';
import 'calendar_tour.dart';

// Parents' and students' Calendario: the bands and the day reuse the teachers' parts.
const String kTourPupilCalendarCards = 'calendar.pupil.cards';
const String kTourPupilCalendarLayout = 'calendar.pupil.layout';

const String _title = 'Calendario';

const String _parentRole = 'PARENT';
const String _studentRole = 'STUDENT';

// Bump a version on every change to that tour.
const (String, int) _parentSeen = ('calendar.parent', 1);
const (String, int) _studentSeen = ('calendar.student', 1);

// Summary, layouts and the lesson click, the first time a published band shows a lesson.
const (String, int) _parentBandSeen = ('calendar.parent.published', 2);
const (String, int) _studentBandSeen = ('calendar.student.published', 2);

// Lesson window parts, each told when first shown; one mark for parents and students alike.
enum PupilLessonMark { details, teacher }

const Map<PupilLessonMark, int> _markVersions = {
  PupilLessonMark.details: 1,
  PupilLessonMark.teacher: 1,
};

(String, int) _markSeen(PupilLessonMark mark) => ('calendar.pupil.lesson.${mark.name}', _markVersions[mark]!);

// Whom the lit lesson is for (own, son or daughter); set by the page before a window opens.
({bool self, String? gender}) pupilCalendarLessonFor = (self: false, gender: null);

const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.right, DesktopTourSide.above];
const List<DesktopTourSide> _leftFirst = [DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];

bool _shown(String id) => isDesktopTourTargetShown(id);

bool _daughter(String? gender) => gender == 'F';

String? get _reader
{
  final identity = ApiService().lastKnownIdentity;

  return identity?.activeRole == _parentRole || identity?.activeRole == _studentRole ? identity?.taxCode : null;
}

bool get _self => ApiService().lastKnownIdentity?.activeRole == _studentRole;

void startPupilCalendarTour(BuildContext context, DesktopTour tour)
{
  final String? taxCode = _reader;

  if (taxCode == null)
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

Future<bool> _seen(String taxCode, (String, int) mark)
{
  final (String slug, int version) = mark;

  return isDesktopTourSeen(
    taxCode: taxCode,
    tour: DesktopTour(slug: slug, title: _title, version: version, steps: const []),
  );
}

// Asked before the page's tour: a published band never told is shown where it is.
Future<bool> isPupilCalendarBandDue() async
{
  final String? taxCode = _reader;

  return taxCode != null && !await _seen(taxCode, _self ? _studentBandSeen : _parentBandSeen);
}

// [genders]: the children whose summary the page shows; [online]: theirs is online only.
String _summary({required List<String?> genders, required bool online})
{
  final String presence = online ? 'presenza online' : 'presenza';

  if (_self)
  {
    return 'della tua $presence';
  }

  final String whose = genders.length > 1
      ? (genders.every(_daughter) ? 'delle tue figlie' : 'dei tuoi figli')
      : (genders.isNotEmpty && _daughter(genders.first) ? 'di tua figlia' : 'di tuo figlio');

  return 'della $presence $whose';
}

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
List<DesktopTourStep> _bandSteps({required List<String?> genders, required bool online})
{
  final (String, int) seen = _self ? _studentBandSeen : _parentBandSeen;

  return [
    DesktopTourStep(
      targets: const [kTourPupilCalendarCards],
      text: 'Qui puoi consultare un riepilogo ${_summary(genders: genders, online: online)}, con orario di inizio e '
          'fine, il numero di lezioni e il totale delle ore previste.',
      sides: _below,
      pad: 6,
      radius: 21,
      reveal: true,
      present: () => _shown(kTourPupilCalendarCards),
      seen: seen,
    ),
    DesktopTourStep(
      targets: const [kTourPupilCalendarLayout],
      text: 'Con «Disposizione» puoi cambiare la visualizzazione del calendario: quella per orario organizza le '
          "lezioni su una linea del tempo, mentre quella per lezioni le presenta in un elenco, una sotto l'altra.",
      sides: _leftFirst,
      pad: 6,
      radius: 25,
      present: () => _shown(kTourPupilCalendarLayout),
      seen: seen,
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
      seen: seen,
    ),
  ];
}

// [undo]: first window step inside the page's tour. [coming]: counted before the window is up.
DesktopTourStep _lessonStep(PupilLessonMark mark, {VoidCallback? undo, bool Function()? coming})
{
  final ({bool self, String? gender}) whom = pupilCalendarLessonFor;

  final (String target, String text) = switch (mark)
  {
    PupilLessonMark.details => (kTourLessonDetails, 'Qui trovi tutte le informazioni sulla lezione.'),
    PupilLessonMark.teacher => (
        kTourLessonStudent,
        whom.self
            ? 'Queste sono alcune informazioni sul docente che ti seguirà per la lezione.'
            : 'Queste sono alcune informazioni sul docente che seguirà ${_daughter(whom.gender) ? 'tua figlia' : 'tuo figlio'} '
                'per la lezione.',
      ),
  };

  // The window closed under the tour takes it away.
  return DesktopTourStep(
    targets: [target],
    text: text,
    sides: _beside,
    pad: 6,
    radius: 31,
    reveal: true,
    listen: calendarLessonOpen,
    gone: () => !calendarLessonOpen.value,
    undo: undo,
    present: () => calendarLessonOpen.value && _shown(target),
    coming: coming,
    seen: _markSeen(mark),
  );
}

Future<List<PupilLessonMark>> _unseenMarks(String taxCode) async
{
  return [
    for (final PupilLessonMark mark in PupilLessonMark.values)
      if (!await _seen(taxCode, _markSeen(mark))) mark,
  ];
}

// Page, published band and lesson window as one tour (a click opens it); null if none is due.
// [genders], [online]: the summary's children and mode.
Future<DesktopTour?> pupilCalendarPageTour({required List<String?> genders, required bool online}) async
{
  final String? taxCode = _reader;

  if (taxCode == null)
  {
    return null;
  }

  final (String, int) mainSeen = _self ? _studentSeen : _parentSeen;
  final (String, int) bandSeen = _self ? _studentBandSeen : _parentBandSeen;

  final bool main = !await _seen(taxCode, mainSeen);
  final bool band = !await _seen(taxCode, bandSeen);
  final bool lesson = _shown(kTourCalendarLesson);

  if (!main && !(band && lesson))
  {
    return null;
  }

  final List<PupilLessonMark> marks = band && lesson ? await _unseenMarks(taxCode) : const [];
  final (String slug, int version) = main ? mainSeen : bandSeen;

  return DesktopTour(
    slug: slug,
    title: _title,
    version: version,
    steps: [
      if (main) ...kCalendarMainSteps,
      if (band && lesson) ..._bandSteps(genders: genders, online: online),
      for (final (int index, PupilLessonMark mark) in marks.indexed)
        _lessonStep(
          mark,
          undo: index == 0 ? () => calendarLessonCloser?.call() : null,
          coming: () => true,
        ),
    ],
  );
}

// A lesson's window opened outside the page's tour: its parts never seen, the first time they show.
Future<DesktopTour?> pupilCalendarLessonTour() async
{
  final String? taxCode = _reader;

  if (taxCode == null)
  {
    return null;
  }

  final List<PupilLessonMark> marks = await _unseenMarks(taxCode);

  return dueDesktopTour(
    taxCode: taxCode,
    title: _title,
    steps: [for (final PupilLessonMark mark in marks) _lessonStep(mark)],
  );
}
