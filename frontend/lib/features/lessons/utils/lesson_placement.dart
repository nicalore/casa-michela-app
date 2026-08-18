import 'dart:math' as math;

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/study_program_item.dart';
import '../../people/models/person_item.dart';
import '../models/availability_item.dart';
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../models/schedulable_booking.dart';
import 'opening_window.dart';
import 'study_program_lookup.dart';
import 'timeline_geometry.dart';

// Whether an hour may be put where somebody is trying to put it, and why not.
//
// The server has the last word — every mutation goes through it. This exists so
// the refusal arrives before the drop, while the block can still be moved: a
// rule enforced only by the server is a rule the user meets by failing.
//
// The wording is taken from the server's own error constants: two dictionaries
// for one rule is how a screen starts feeling like two programs.

const String kTooShortRefusal = "Una lezione dura almeno mezz'ora.";
const String kOutsideAvailabilityRefusal = 'Fuori dalla disponibilità del docente.';
const String kTeacherAtHomeRefusal = 'Un docente collegato da casa non può tenere una lezione in presenza.';
const String kMixedModesRefusal = 'Una lezione si deve svolgere interamente nella stessa modalità.';
const String kAcrossBandsRefusal = 'Una lezione non può attraversare due fasce orarie diverse.';
const String kNoBookingRefusal = 'Una lezione deve avere almeno una prenotazione.';
const String kPublishedRefusal = 'Gli orari sono già stati pubblicati: le lezioni non si possono più '
    'modificare.';
const String kLessonWithoutDisciplineRefusal =
    'Solo i servizi non hanno discipline.';
const String kDisciplineNotRequestedRefusal =
    'Ogni disciplina della lezione deve essere collegata ad almeno una delle prenotazioni.';
const String kBookingNotOnLessonSubjectRefusal =
    'Ogni prenotazione deve avere almeno una disciplina in comune con la lezione.';
const String kTooManyPartsRefusal = 'Una prenotazione può essere divisa in al massimo due lezioni.';

// The same rule from the other side: an hour of a request that already has both
// parts is shortened, and the freed minutes go back to the panel. Said out
// loud, because silence beside the hour reads as the gesture not having worked.
const String kFreedMinutesGoBackNotice =
    'Una prenotazione può essere divisa in al massimo due lezioni: la porzione rimossa torna da pianificare.';

// What is capped is the heads and not the rows: overlapping hours are allowed,
// but a group hour of two already fills the teacher up. The same number as
// teacher_occupancy.MAX_CONCURRENT_STUDENTS, and they change together.
const int kMaxConcurrentStudents = 2;

const String kTooManyStudentsRefusal =
    'Non è possibile sovrapporre più di $kMaxConcurrentStudents lezioni.';

// Only hours in the building may run together: a teacher in a call cannot be in
// a second one nor turn from it to somebody sitting beside them.
const String kOnlineCannotOverlapRefusal =
    "Le lezioni online non possono avere sovrapposizioni.";

// Which of the two bands the other part is in is not named: the rule is the same
// whichever way round it is, and the part being refused is the one under the
// hand. The same sentence the server refuses it with.
const String kOtherPartBandRefusal =
    'Le lezioni di una prenotazione devono trovarsi nella stessa fascia oraria.';

String outsidePresenceRefusal(String student, String range) => 'La lezione non rientra nelle ore di presenza di $student ($range).';

String studentOverlapRefusal(String student) => "$student ha già un'altra lezione a quest'ora.";

String missingCompetenceRefusal(Iterable<String> disciplines) =>
    'Il docente non ha la competenza per: ${disciplines.join(', ')}.';

String missingServiceRefusal(Iterable<String> services) => 'Il docente non ha la competenza per: '
    '${services.join(', ')}.';

String noSharedDisciplineRefusal(String teacher) => '$teacher non insegna nessuna delle discipline richieste.';

String remainingMinutesRefusal(int minutes) => 'Restano solo ${formatMinutes(minutes)} di questa prenotazione.';

String leaveRoomForTheRestRefusal(int minutes, Iterable<String> disciplines) =>
    'Al massimo ${formatMinutes(minutes)}: ${disciplines.join(', ')} resta da pianificare.';


String notPreferredWarning(String teacher, String student) =>
    'Il docente $teacher è indicato come non preferito da $student.';

// One day in one band, indexed the way the rules read it. Built once per
// (day, band) and not per pointer move: resolving a drop walks the teacher's
// lessons, the pupils' lessons and the competences.
class CalendarDayIndex
{
  final DateTime day;
  final TimeBucket band;

  final List<TeacherLane> lanes;
  final Map<String, TeacherLane> lanesByTeacher;

  // Every request of the day, planned or not, by booking id.
  final Map<int, SchedulableBooking> bookingsById;

  // Every lesson of the day — all bands, because a pupil booked in the morning
  // and again in the afternoon still may not be in two places at once.
  final Map<String, List<LessonItem>> lessonsByStudent;

  // The pairs the competence is actually granted in — discipline and study
  // programme. Matematica for a liceo is not Matematica for a technical
  // institute, and the discipline alone would offer an hour the server refuses.
  final Map<String, Set<(int, int)>> competencePairsByTeacher;

  // The same, flattened to the disciplines alone. It is what a pupil with no
  // school on file is checked against — there is no programme to compare, and
  // an adult taking a language is a real case.
  final Map<String, Set<int>> competenceIdsByTeacher;

  final Map<String, Set<String>> serviceNamesByTeacher;

  // Which study programme each pupil is enrolled in, by tax code. Absent where
  // the pupil has no enrolment at all.
  final Map<String, int> studyProgrammeByStudent;

  // Which disciplines each programme teaches. The pair only decides where the
  // discipline is in the pupil's programme; one no programme covers is judged
  // on the discipline alone.
  final Map<int, Set<int>> disciplinesByProgramme;

  final Map<int, String> disciplineNames;

  const CalendarDayIndex({
    required this.day,
    required this.band,
    required this.lanes,
    required this.lanesByTeacher,
    required this.bookingsById,
    required this.lessonsByStudent,
    required this.competencePairsByTeacher,
    required this.competenceIdsByTeacher,
    required this.serviceNamesByTeacher,
    required this.studyProgrammeByStudent,
    required this.disciplinesByProgramme,
    required this.disciplineNames,
  });

  int get bandStart => bandStartMinutes(band);

  int get bandEnd => bandEndMinutes(band);

  factory CalendarDayIndex.build({
    required DateTime day,
    required TimeBucket band,
    required List<TeacherLane> lanes,
    required List<PresenceBookingGroup> groups,
    required List<LessonItem> lessons,
    required List<PersonItem> people,
    required List<AssociationSubjectItem> associationSubjects,
    List<StudyProgramItem> studyPrograms = const [],
  })
  {
    final subjectIdByName = <String, int>{
      for (final subject in associationSubjects) subject.name: subject.id,
    };

    final pairs = <String, Set<(int, int)>>{};
    final competences = <String, Set<int>>{};
    final services = <String, Set<String>>{};
    final programmes = <String, int>{};

    for (final person in people)
    {
      // Both are needed: teacherSubjects carries the programmes and is the only
      // way to know which competence was granted, while taughtSubjects is the
      // flat list covering the competences with no programme behind them.
      pairs[person.fiscalCode] = {
        for (final subject in person.teacherSubjects ?? const [])
          for (final programme in subject.studyProgramIds) (subject.subjectId, programme),
      };

      competences[person.fiscalCode] = {
        for (final name in person.taughtSubjects)
          if (subjectIdByName[name] != null) subjectIdByName[name]!,
      };

      // Null is "no services", not "unknown": the server writes the list out
      // whole and leaves it off when it is empty.
      services[person.fiscalCode] = (person.teacherServices ?? const <String>[]).toSet();

      final programme = currentStudyProgramId(person);

      if (programme != null)
      {
        programmes[person.fiscalCode] = programme;
      }
    }

    // One entry per request, and it has to be the one filed under its own
    // presence: a request that has not been planned is offered under every
    // stretch the pupil gave, and whoever looks a booking up by id — the ceiling
    // of a resize, the two parts of a merge — wants the hours it is stored in.
    final bookings = <int, SchedulableBooking>{};

    for (final group in groups)
    {
      for (final entry in group.bookings)
      {
        if (entry.isBorrowed)
        {
          bookings.putIfAbsent(entry.id, () => entry);
        }
        else
        {
          bookings[entry.id] = entry;
        }
      }
    }

    final byStudent = <String, List<LessonItem>>{};

    for (final lesson in lessons)
    {
      if (!isSameDate(lesson.date, day))
      {
        continue;
      }

      for (final taxCode in lesson.studentTaxCodes)
      {
        byStudent.putIfAbsent(taxCode, () => []).add(lesson);
      }
    }

    return CalendarDayIndex(
      day: day,
      band: band,
      lanes: lanes,
      lanesByTeacher: {for (final lane in lanes) lane.teacherTaxCode: lane},
      bookingsById: bookings,
      lessonsByStudent: byStudent,
      competencePairsByTeacher: pairs,
      competenceIdsByTeacher: competences,
      serviceNamesByTeacher: services,
      studyProgrammeByStudent: programmes,
      disciplinesByProgramme: {
        for (final programme in studyPrograms)
          programme.id: {
            for (final subject in programme.ministrySubjects)
              for (final discipline in subject.associationSubjects) discipline.id,
          },
      },
      disciplineNames: {for (final subject in associationSubjects) subject.id: subject.name},
    );
  }

  String nameOf(int disciplineId) => disciplineNames[disciplineId] ?? 'disciplina';

  List<String> namesOf(Iterable<int> disciplineIds)
  {
    return [for (final id in disciplineIds) nameOf(id)];
  }
}

// What is being dragged. A sealed hierarchy because the two things behave
// differently at the drop — one creates an hour, the other moves one — and a
// nullable field for each would let both be set at once.
sealed class CalendarDragPayload
{
  const CalendarDragPayload();
}

// A request, or one discipline of a request, on its way out of the panel.
class BookingDragPayload extends CalendarDragPayload
{
  final SchedulableBooking entry;

  // Which disciplines are going along. Everything still uncovered when the
  // whole card is dragged; a single one when a chip is.
  final Set<int> disciplineIds;

  // What the part is proposed at, before the room actually available cuts it
  // down. See [SchedulableBooking.proposedMinutesFor].
  final int minutes;

  const BookingDragPayload({
    required this.entry,
    required this.disciplineIds,
    required this.minutes,
  });

  bool get isSingleDiscipline => disciplineIds.length == 1;
}

// Where what is being carried would land, read by whatever is drawn under the
// pointer. What is in the hand is what the eye is on, so that is what turns
// red — a rectangle on the track would be behind it.
class CarriedPlacement
{
  // The hours it would take. Null off the track, and null while the place under
  // the pointer is no place at all.
  final (int, int)? span;

  // Why it may not go there, where it may not.
  final String? refusal;

  // False once the pointer has left the track: for an hour already planned,
  // letting go out there takes it out of the day.
  final bool isOverTrack;

  // Alongside an hour already there: allowed, but not the ordinary case. Said
  // in the hand, since the row only grows a second line once the second hour
  // exists and the track has nowhere to say it that is not behind the pointer.
  final bool alongside;

  // What letting go would do — a new hour, a move, joining the hour under the
  // pointer, putting two parts back together. The last two used to be written
  // inside the outline on the track, where the card in the hand covered them.
  final LessonPlacementKind? kind;

  const CarriedPlacement({
    this.span,
    this.refusal,
    this.isOverTrack = true,
    this.alongside = false,
    this.kind,
  });

  // Nothing in hand.
  static const CarriedPlacement idle = CarriedPlacement();

  // In hand, and away from the track.
  static const CarriedPlacement away = CarriedPlacement(isOverTrack: false);

  bool get isRefused => isOverTrack && refusal != null;

  bool get isAlongside => isOverTrack && refusal == null && alongside;
}

// What is in the hand, and what the day already knows about it: whether a
// teacher may teach this is a question about the whole day, answered from the
// index the track does not hold. Answered once at the pick-up and carried.
class CarriedRequest
{
  final CalendarDragPayload payload;

  // Everybody who could teach it, hours aside.
  final Set<String> competentTeachers;

  const CarriedRequest({required this.payload, this.competentTeachers = const {}});
}

// Where a drag in progress could go and who it concerns. The same answer for a
// request out of the panel and an hour off the track, since the track lights up
// for the same reason either way.
//
// [window] is the intersection of the presences, cut to the band: a group hour
// can only go where every pupil in it is there.
({(int, int)? window, String mode, Set<String> preferred, Set<String> avoided}) dragOutline(
  CalendarDragPayload payload, {
  required int bandStart,
  required int bandEnd,
})
{
  (int, int)? window;
  var mode = kPresenceMode;
  final preferred = <String>{};
  final avoided = <String>{};

  void take(int start, int end, BookingSummaryItem booking)
  {
    window = window == null
        ? (start, end)
        : intersectSpan(window!.$1, window!.$2, start, end);
    preferred.addAll(booking.preferredTeacherTaxCodes);
    avoided.addAll(booking.notPreferredTeacherTaxCodes);
  }

  switch (payload)
  {
    case BookingDragPayload(:final entry):
      mode = entry.presence.mode;
      take(
        minutesOfTimeOfDay(entry.presence.startTime),
        minutesOfTimeOfDay(entry.presence.endTime),
        entry.booking,
      );

    case LessonDragPayload(:final lesson):
      mode = lesson.mode;

      for (final link in lesson.bookings)
      {
        take(link.presence.startMinutes, link.presence.endMinutes, link.booking);
      }
  }

  final held = window;

  return (
    window: held == null ? null : intersectSpan(held.$1, held.$2, bandStart, bandEnd),
    mode: mode,
    preferred: preferred,
    avoided: avoided,
  );
}

// A lesson being moved. Nothing records where the pointer took hold, and that
// is not an omission: childDragAnchorStrategy means the track already receives
// the block's own left edge, so no grab offset has to be measured.
class LessonDragPayload extends CalendarDragPayload
{
  final LessonItem lesson;

  const LessonDragPayload({required this.lesson});
}

// Deliberately no payload for dragging a discipline between the two parts of a
// request: that is done by ticking it in either details window, where both
// sides are in sight and putting it on both — which two teachers taking turns
// needs — can be asked for on purpose rather than stumbled into.

// What a placement would do to the calendar. The ghost reads it to say the
// right thing under the pointer — joining an existing hour and making a new
// one look identical on the numbers and mean different things to whoever is
// dragging.
enum LessonPlacementKind
{
  create,
  move,
  resize,

  // A discipline given to an hour the request already has: no hour is written
  // and no minutes are spent. The only thing left once both hours exist.
  join,

  merge,
}

// Where an hour would end up, and whether it may. One object for both jobs —
// the ghost while the pointer is down, the request body once it is released —
// since two would be two chances to disagree.
class LessonPlacement
{
  final LessonPlacementKind kind;

  final String teacherTaxCode;
  final int startMinutes;
  final int endMinutes;

  // Null where no availability of that teacher holds the whole stretch, which
  // is itself a refusal.
  final int? availabilityId;

  // What the hour is for the pupils, read off their presences.
  final String mode;

  final List<int> bookingIds;
  final List<int> associationSubjectIds;

  // The lesson being rewritten, where there is one.
  final int? lessonId;

  // A second lesson that has to go for this one to be written, which is how
  // two parts are put back together.
  final int? deleteLessonId;

  final String? refusal;
  final List<String> warnings;

  const LessonPlacement({
    required this.teacherTaxCode,
    required this.startMinutes,
    required this.endMinutes,
    this.kind = LessonPlacementKind.create,
    this.availabilityId,
    this.mode = kPresenceMode,
    this.bookingIds = const [],
    this.associationSubjectIds = const [],
    this.lessonId,
    this.deleteLessonId,
    this.refusal,
    this.warnings = const [],
  });

  bool get isValid => refusal == null && availabilityId != null;

  int get minutes => endMinutes - startMinutes;

  // What the ghost compares itself against between one pointer move and the
  // next. A record, so the equality is by value and free.
  ({String teacher, int start, int end, String? refusal}) get signature =>
      (teacher: teacherTaxCode, start: startMinutes, end: endMinutes, refusal: refusal);

  LessonPlacement as(LessonPlacementKind newKind)
  {
    return LessonPlacement(
      teacherTaxCode: teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      kind: newKind,
      availabilityId: availabilityId,
      mode: mode,
      bookingIds: bookingIds,
      associationSubjectIds: associationSubjectIds,
      lessonId: lessonId,
      deleteLessonId: deleteLessonId,
      refusal: refusal,
      warnings: warnings,
    );
  }
}

// Which availability of that teacher can hold the whole stretch.
//
// Presence is preferred where both would do: a teacher in the building may take
// either kind of pupil, the room they are assigned hangs off their being here,
// and both modes over one hour almost always means "I am in, and I can also
// take remote pupils". The detail dialog offers the other where both are
// legal.
AvailabilityItem? resolveAvailability({
  required List<AvailabilityItem> teacherAvailabilities,
  required String lessonMode,
  required int startMinutes,
  required int endMinutes,
})
{
  AvailabilityItem? online;

  for (final slot in teacherAvailabilities)
  {
    final holds = minutesOfTimeOfDay(slot.startTime) <= startMinutes &&
        minutesOfTimeOfDay(slot.endTime) >= endMinutes;

    if (!holds)
    {
      continue;
    }

    if (slot.mode == kPresenceMode)
    {
      return slot;
    }

    // A teacher at home cannot have a pupil sitting in front of them: the
    // database says so with a CHECK, and this is the same sentence earlier.
    if (lessonMode == kOnlineMode)
    {
      online ??= slot;
    }
  }

  return online;
}

// The stretch itself, before anybody is asked about it: an hour with nobody in
// it, one too short to teach in, one reaching out of the band being planned.
String? _refuseHours({
  required CalendarDayIndex index,
  required List<SchedulableBooking> bookings,
  required int startMinutes,
  required int endMinutes,
})
{
  if (bookings.isEmpty)
  {
    return kNoBookingRefusal;
  }

  if (endMinutes - startMinutes < kMinimumBandMinutes)
  {
    return kTooShortRefusal;
  }

  if (startMinutes < index.bandStart || endMinutes > index.bandEnd)
  {
    return kAcrossBandsRefusal;
  }

  return null;
}

// The hour has to sit inside the hours every pupil in it left open.
String? _refusePresences({
  required List<SchedulableBooking> bookings,
  required int startMinutes,
  required int endMinutes,
})
{
  for (final entry in bookings)
  {
    final presence = entry.presence;

    if (startMinutes < minutesOfTimeOfDay(presence.startTime) ||
        endMinutes > minutesOfTimeOfDay(presence.endTime))
    {
      return outsidePresenceRefusal(
        presence.student.fullName,
        formatTimeRange(presence.startTime, presence.endTime),
      );
    }
  }

  return null;
}

// How full the teacher would be, not whether anything clashes: overlapping is
// allowed and capped at [kMaxConcurrentStudents], so the answer takes every
// overlapping row. Across both modes, since attention does not divide by how
// each pupil reaches them.
String? _refuseOccupancy({
  required TeacherLane lane,
  required String mode,
  required int students,
  required int startMinutes,
  required int endMinutes,
  int? lessonId,
  int? deleteLessonId,
})
{
  final others = [
    for (final lesson in lane.lessons)
      if (lesson.id != lessonId && lesson.id != deleteLessonId) lesson,
  ];

  final overlapping = [
    for (final lesson in others)
      if (spansOverlap(startMinutes, endMinutes, lesson.startMinutes, lesson.endMinutes)) lesson,
  ];

  // Only hours in the building may run together: a teacher in a call is in one
  // call, and cannot turn from it to somebody sitting beside them.
  if (overlapping.isNotEmpty && (mode == kOnlineMode || overlapping.any((lesson) => lesson.mode == kOnlineMode)))
  {
    return kOnlineCannotOverlapRefusal;
  }

  final peak = peakConcurrentStudents([
    for (final lesson in others) (lesson.startMinutes, lesson.endMinutes, lesson.studentTaxCodes.length),
    (startMinutes, endMinutes, students),
  ]);

  return peak > kMaxConcurrentStudents ? kTooManyStudentsRefusal : null;
}

// The same rule from the other side of the room: no pupil in two hours at once.
String? _refuseStudentClash({
  required CalendarDayIndex index,
  required List<SchedulableBooking> bookings,
  required int startMinutes,
  required int endMinutes,
  int? lessonId,
  int? deleteLessonId,
})
{
  for (final entry in bookings)
  {
    final taken = index.lessonsByStudent[entry.presence.studentTaxCode] ?? const <LessonItem>[];

    for (final lesson in taken)
    {
      if (lesson.id == lessonId || lesson.id == deleteLessonId)
      {
        continue;
      }

      if (spansOverlap(startMinutes, endMinutes, lesson.startMinutes, lesson.endMinutes))
      {
        return studentOverlapRefusal(entry.presence.student.fullName);
      }
    }
  }

  return null;
}

// What the hour teaches has to be something its pupils asked for, and every
// pupil in it has to be there for something it teaches.
String? _refuseDisciplines({
  required List<SchedulableBooking> bookings,
  required Set<int> disciplineIds,
})
{
  final requested = <int>{for (final entry in bookings) ...entry.requestedDisciplineIds};

  if (disciplineIds.difference(requested).isNotEmpty)
  {
    return kDisciplineNotRequestedRefusal;
  }

  if (disciplineIds.isEmpty)
  {
    final anyWithDisciplines = bookings.any((entry) => entry.booking.kind != BookingRequestKind.service);

    return anyWithDisciplines ? kLessonWithoutDisciplineRefusal : null;
  }

  for (final entry in bookings)
  {
    if (entry.booking.kind == BookingRequestKind.service)
    {
      return kLessonWithoutDisciplineRefusal;
    }

    if (entry.requestedDisciplineIds.intersection(disciplineIds).isEmpty)
    {
      return kBookingNotOnLessonSubjectRefusal;
    }
  }

  return null;
}

// The competence is granted per (discipline, programme), so what the pupils are
// enrolled in decides which grant applies; a group hour on two programmes needs
// both. An hour on no discipline is a service, read against what is offered.
String? _refuseCompetence({
  required CalendarDayIndex index,
  required String teacherTaxCode,
  required List<SchedulableBooking> bookings,
  required Set<int> disciplineIds,
})
{
  final missing = missingCompetence(
    index,
    teacherTaxCode: teacherTaxCode,
    disciplineIds: disciplineIds,
    programmes: programmesOf(index, bookings.map((entry) => entry.presence.studentTaxCode)),
  );

  if (missing.isNotEmpty)
  {
    return missingCompetenceRefusal(index.namesOf(missing));
  }

  if (disciplineIds.isNotEmpty)
  {
    return null;
  }

  final offered = index.serviceNamesByTeacher[teacherTaxCode] ?? const <String>{};
  final wanted = <String>{
    for (final entry in bookings)
      if (entry.booking.serviceName != null) entry.booking.serviceName!,
  };
  final unserved = wanted.difference(offered);

  return unserved.isEmpty ? null : missingServiceRefusal(unserved);
}

// The minutes still to spend, and whether this hour leaves room for what it
// does not cover. Each booking counts whole: in a group hour the longest it may
// be is the smallest of their remainders.
String? _refuseBudget({
  required CalendarDayIndex index,
  required List<SchedulableBooking> bookings,
  required Set<int> disciplineIds,
  required int startMinutes,
  required int endMinutes,
  int? lessonId,
  int? deleteLessonId,
})
{
  for (final entry in bookings)
  {
    if (entry.isLocked)
    {
      return kPublishedRefusal;
    }

    final otherParts = entry.parts.where((part) => part.id != lessonId && part.id != deleteLessonId).toList();

    if (otherParts.length + 1 > kMaxLessonParts)
    {
      return kTooManyPartsRefusal;
    }

    final spent = otherParts.fold(0, (total, part) => total + part.minutes);
    final available = entry.booking.duration - spent;

    if (endMinutes - startMinutes > available)
    {
      return remainingMinutesRefusal(available);
    }

    // What this hour leaves out needs another one, and that cannot be shorter
    // than half an hour: growing past `available - 30` spends the minutes its
    // own leftover needs. Only where a second part is still to come.
    final coveredByOthers = <int>{for (final part in otherParts) ...part.disciplineIds};
    final leftOut = entry.requestedDisciplineIds
        .difference(disciplineIds)
        .difference(coveredByOthers);

    if (leftOut.isNotEmpty && otherParts.length + 1 < kMaxLessonParts)
    {
      final ceiling = available - kMinimumBandMinutes;

      if (endMinutes - startMinutes > ceiling)
      {
        return leaveRoomForTheRestRefusal(ceiling, index.namesOf(leftOut));
      }
    }

    for (final part in otherParts)
    {
      if (part.band != index.band)
      {
        return kOtherPartBandRefusal;
      }
    }
  }

  return null;
}

// The whole rule set, cheapest first. [lessonId] is the lesson being rewritten,
// left out of the overlap checks and the minutes spent: it is about to stop
// being what it was.
LessonPlacement validatePlacement({
  required CalendarDayIndex index,
  required String teacherTaxCode,
  required int startMinutes,
  required int endMinutes,
  required List<SchedulableBooking> bookings,
  required Set<int> disciplineIds,
  int? lessonId,
  int? deleteLessonId,
})
{
  LessonPlacement placement(String? refusal, {int? availabilityId, String mode = kPresenceMode, List<String> warnings = const []})
  {
    return LessonPlacement(
      teacherTaxCode: teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      availabilityId: availabilityId,
      mode: mode,
      bookingIds: [for (final entry in bookings) entry.id],
      associationSubjectIds: disciplineIds.toList()..sort(),
      lessonId: lessonId,
      deleteLessonId: deleteLessonId,
      refusal: refusal,
      warnings: warnings,
    );
  }

  final hoursRefusal = _refuseHours(
    index: index,
    bookings: bookings,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );

  if (hoursRefusal != null)
  {
    return placement(hoursRefusal);
  }

  final lane = index.lanesByTeacher[teacherTaxCode];

  if (lane == null)
  {
    return placement(kOutsideAvailabilityRefusal);
  }

  // Every booking of one lesson is one kind of hour: the server reads the
  // lesson's own mode off them, and two answers would leave it nothing to read.
  final modes = bookings.map((entry) => entry.presence.mode).toSet();

  if (modes.length > 1)
  {
    return placement(kMixedModesRefusal);
  }

  final mode = modes.single;

  final availability = resolveAvailability(
    teacherAvailabilities: lane.availabilities,
    lessonMode: mode,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );

  if (availability == null)
  {
    // Told apart on purpose: a teacher who is only online that hour is a
    // different problem from one who is not there at all, and the first has an
    // answer — the pupil could take the hour online.
    final onlyOnline = mode == kPresenceMode &&
        lane.availabilitiesIn(kOnlineMode).any((slot) =>
            minutesOfTimeOfDay(slot.startTime) <= startMinutes &&
            minutesOfTimeOfDay(slot.endTime) >= endMinutes);

    return placement(onlyOnline ? kTeacherAtHomeRefusal : kOutsideAvailabilityRefusal);
  }

  final students = <String>{for (final entry in bookings) entry.presence.studentTaxCode};

  final refusal = _refusePresences(
        bookings: bookings,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      ) ??
      _refuseOccupancy(
        lane: lane,
        mode: mode,
        students: students.length,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        lessonId: lessonId,
        deleteLessonId: deleteLessonId,
      ) ??
      _refuseStudentClash(
        index: index,
        bookings: bookings,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        lessonId: lessonId,
        deleteLessonId: deleteLessonId,
      ) ??
      _refuseDisciplines(bookings: bookings, disciplineIds: disciplineIds) ??
      _refuseCompetence(
        index: index,
        teacherTaxCode: teacherTaxCode,
        bookings: bookings,
        disciplineIds: disciplineIds,
      ) ??
      _refuseBudget(
        index: index,
        bookings: bookings,
        disciplineIds: disciplineIds,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        lessonId: lessonId,
        deleteLessonId: deleteLessonId,
      );

  if (refusal != null)
  {
    return placement(refusal);
  }

  // Not a refusal: NOT_PREFERRED says who the hour should go to last, not who
  // it may not go to. Making it an error would make the day unplannable exactly
  // when the only competent teacher is the one somebody would rather avoid.
  final warnings = <String>[
    for (final entry in bookings)
      if (entry.booking.notPreferredTeacherTaxCodes.contains(teacherTaxCode))
        notPreferredWarning(lane.teacher.fullName, entry.presence.student.fullName),
  ];

  return placement(null, availabilityId: availability.id, mode: mode, warnings: warnings);
}

// Said as the two different problems it can be: nobody has been granted them,
// which is a competence to give, or the competent ones are not there while the
// pupil is, which is an hour to move.
String noTeacherReason(CalendarDayIndex index, SchedulableBooking entry, Set<int> disciplineIds)
{
  final noneFree = 'Nessun docente è libero nelle ore di ${entry.presence.student.fullName} '
      '(${formatTimeRange(entry.presence.startTime, entry.presence.endTime)}).';

  // A service is not taught, it is provided, and who provides it is a list of
  // its own. Read through the competences it has none, which is how an hour
  // nobody in the building offers came to be reported as an hour of a full day.
  final service = entry.booking.serviceName;

  if (service != null)
  {
    final offering = index.lanes.where(
      (lane) => (index.serviceNamesByTeacher[lane.teacherTaxCode] ?? const <String>{}).contains(service),
    );

    return offering.isEmpty
        ? 'Nessun docente disponibile ha la competenza per: $service.'
        : noneFree;
  }

  final programmes = programmesOf(index, [entry.presence.studentTaxCode]);

  final competent = index.lanes.where((lane) => missingCompetence(
        index,
        teacherTaxCode: lane.teacherTaxCode,
        disciplineIds: disciplineIds,
        programmes: programmes,
      ).isEmpty);

  if (disciplineIds.isNotEmpty && competent.isEmpty)
  {
    return 'Nessun docente della giornata ha la competenza per: '
        '${index.namesOf(disciplineIds).join(', ')}.';
  }

  return noneFree;
}

// Whether any part of this request could be written today, asked before a
// window is opened on it: a form whose every field comes back empty is a room
// somebody was sent into for nothing.
//
// The shortest lesson there is, one discipline at a time: the question is
// whether something could be done, not whether everything could.
bool canPlanSomething(CalendarDayIndex index, SchedulableBooking entry)
{
  final presence = entry.presence;
  final presenceStart = minutesOfTimeOfDay(presence.startTime);
  final presenceEnd = minutesOfTimeOfDay(presence.endTime);

  final wanted = entry.requestedDisciplineIds.isEmpty
      ? <Set<int>>[const {}]
      : [for (final id in entry.requestedDisciplineIds) {id}];

  for (final lane in index.lanes)
  {
    for (final availability in lane.availabilitiesTaking(presence.mode))
    {
      final inBand = intersectSpan(
        minutesOfTimeOfDay(availability.startTime),
        minutesOfTimeOfDay(availability.endTime),
        index.bandStart,
        index.bandEnd,
      );

      final window = inBand == null
          ? null
          : intersectSpan(inBand.$1, inBand.$2, presenceStart, presenceEnd);

      if (window == null || window.$2 - window.$1 < kMinimumBandMinutes)
      {
        continue;
      }

      for (final disciplineIds in wanted)
      {
        for (var start = snapToQuarter(window.$1); start + kMinimumBandMinutes <= window.$2; start += kQuarterHour)
        {
          final placement = validatePlacement(
            index: index,
            teacherTaxCode: lane.teacherTaxCode,
            startMinutes: start,
            endMinutes: start + kMinimumBandMinutes,
            bookings: [entry],
            disciplineIds: disciplineIds,
          );

          if (placement.isValid)
          {
            return true;
          }
        }
      }
    }
  }

  return false;
}

// The programmes those pupils are enrolled in, where they are enrolled in one.
Set<int> programmesOf(CalendarDayIndex index, Iterable<String> studentTaxCodes)
{
  return {
    for (final taxCode in studentTaxCodes)
      if (index.studyProgrammeByStudent[taxCode] != null) index.studyProgrammeByStudent[taxCode]!,
  };
}

// Which of [disciplineIds] this teacher may not teach those pupils. One place,
// and it has to stay one: the same question is asked when a drop is judged and
// when the track lights up, and two answers is a row that welcomes an hour it
// then refuses.
Set<int> missingCompetence(
  CalendarDayIndex index, {
  required String teacherTaxCode,
  required Set<int> disciplineIds,
  required Set<int> programmes,
})
{
  final pairs = index.competencePairsByTeacher[teacherTaxCode] ?? const <(int, int)>{};
  final flat = index.competenceIdsByTeacher[teacherTaxCode] ?? const <int>{};

  final missing = <int>{};

  for (final disciplineId in disciplineIds)
  {
    // Two ways of having no programme to compare against, same answer to both:
    // nobody in the hour has a school on file, or the discipline belongs to no
    // programme. Refusing either makes the hour unplannable from here.
    final withinAny = programmes.any(
      (programme) => index.disciplinesByProgramme[programme]?.contains(disciplineId) ?? false,
    );

    if (programmes.isEmpty || !withinAny)
    {
      if (!flat.contains(disciplineId))
      {
        missing.add(disciplineId);
      }

      continue;
    }

    if (programmes.any((programme) => !pairs.contains((disciplineId, programme))))
    {
      missing.add(disciplineId);
    }
  }

  return missing;
}

// Everybody who could teach what is carried, hours aside. Read once at the
// pick-up, since it is about the teacher and the request and not about where
// the pointer is.
Set<String> teachersWhoCouldTeach(CalendarDayIndex index, CalendarDragPayload payload)
{
  final (disciplineIds, services, students) = switch (payload)
  {
    BookingDragPayload(:final entry, :final disciplineIds) => (
        disciplineIds,
        {?entry.booking.serviceName},
        {entry.presence.studentTaxCode},
      ),
    LessonDragPayload(:final lesson) => (
        lesson.disciplineIds,
        {
          for (final link in lesson.bookings)
            if (link.booking.serviceName != null) link.booking.serviceName!,
        },
        lesson.studentTaxCodes,
      ),
  };

  final programmes = programmesOf(index, students);

  return {
    for (final lane in index.lanes)
      if (missingCompetence(
                index,
                teacherTaxCode: lane.teacherTaxCode,
                disciplineIds: disciplineIds,
                programmes: programmes,
              ).isEmpty &&
          // A request for a service asks nothing of the disciplines and
          // everything of the list of services the teacher offers.
          services.difference(index.serviceNamesByTeacher[lane.teacherTaxCode] ?? const <String>{}).isEmpty)
        lane.teacherTaxCode,
  };
}

// A request dropped on empty track. The proposed length is cut to the room
// actually there before it is judged, so dropping near a boundary gives the
// shorter lesson that fits instead of a refusal.
LessonPlacement planDrop(CalendarDayIndex index, BookingDragPayload drag, String teacherTaxCode, int startMinutes)
{
  final entry = drag.entry;
  final lane = index.lanesByTeacher[teacherTaxCode];

  if (lane == null)
  {
    return LessonPlacement(
      teacherTaxCode: teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: startMinutes + drag.minutes,
      refusal: kOutsideAvailabilityRefusal,
    );
  }

  // Let go on an hour this request already has: it keeps its place and length
  // and comes out covering one subject more. The only thing a discipline can do
  // once both hours exist.
  final host = _hostAt(lane, entry, startMinutes);

  if (host != null)
  {
    return validatePlacement(
      index: index,
      teacherTaxCode: teacherTaxCode,
      startMinutes: host.startMinutes,
      endMinutes: host.endMinutes,
      bookings: [entry],
      disciplineIds: {...host.disciplineIds, ...drag.disciplineIds},
      lessonId: host.id,
    ).as(LessonPlacementKind.join);
  }

  final ceiling = _roomAt(index, lane, entry, startMinutes);
  final minutes = snapQuarterDown(drag.minutes.clamp(0, ceiling));

  return validatePlacement(
    index: index,
    teacherTaxCode: teacherTaxCode,
    startMinutes: startMinutes,
    endMinutes: startMinutes + (minutes < kMinimumBandMinutes ? drag.minutes : minutes),
    bookings: [entry],
    disciplineIds: drag.disciplineIds,
  );
}

// The hour of this request the pointer is over. Of this request and not any:
// somebody else's lesson is a different booking with nothing to join, so there
// the drop asks for an hour of its own.
LessonItem? _hostAt(TeacherLane lane, SchedulableBooking entry, int startMinutes)
{
  for (final lesson in lane.lessons)
  {
    final carries = lesson.bookings.any((booking) => booking.id == entry.id);

    if (carries && startMinutes >= lesson.startMinutes && startMinutes < lesson.endMinutes)
    {
      return lesson;
    }
  }

  return null;
}

// The most minutes available from [startMinutes] onwards, before anything is
// judged: whichever of the four boundaries comes first.
int _roomAt(CalendarDayIndex index, TeacherLane lane, SchedulableBooking entry, int startMinutes)
{
  var ceiling = index.bandEnd - startMinutes;

  final presenceEnd = minutesOfTimeOfDay(entry.presence.endTime);
  ceiling = ceiling < presenceEnd - startMinutes ? ceiling : presenceEnd - startMinutes;

  final availability = lane.availabilities
      .where((slot) => minutesOfTimeOfDay(slot.startTime) <= startMinutes && minutesOfTimeOfDay(slot.endTime) > startMinutes)
      .fold<int?>(null, (widest, slot)
  {
    final end = minutesOfTimeOfDay(slot.endTime);

    return widest == null || end > widest ? end : widest;
  });

  if (availability != null)
  {
    ceiling = ceiling < availability - startMinutes ? ceiling : availability - startMinutes;
  }

  for (final lesson in lane.lessons)
  {
    if (lesson.startMinutes >= startMinutes && lesson.startMinutes - startMinutes < ceiling)
    {
      ceiling = lesson.startMinutes - startMinutes;
    }
  }

  return ceiling < 0 ? 0 : ceiling;
}

// The most minutes available before [endMinutes], the mirror of [_roomAt]. The
// hour being shortened need not be excluded: it is the only lesson spanning the
// freed minutes, and one that spans them ends after them.
int _roomBefore(CalendarDayIndex index, TeacherLane lane, SchedulableBooking entry, int endMinutes)
{
  var ceiling = endMinutes - index.bandStart;

  final presenceStart = minutesOfTimeOfDay(entry.presence.startTime);
  ceiling = math.min(ceiling, endMinutes - presenceStart);

  final availability = lane.availabilities
      .where((slot) => minutesOfTimeOfDay(slot.startTime) < endMinutes && minutesOfTimeOfDay(slot.endTime) >= endMinutes)
      .fold<int?>(null, (earliest, slot)
  {
    final start = minutesOfTimeOfDay(slot.startTime);

    return earliest == null || start < earliest ? start : earliest;
  });

  if (availability != null)
  {
    ceiling = math.min(ceiling, endMinutes - availability);
  }

  for (final lesson in lane.lessons)
  {
    if (lesson.endMinutes <= endMinutes)
    {
      ceiling = math.min(ceiling, endMinutes - lesson.endMinutes);
    }
  }

  return ceiling < 0 ? 0 : ceiling;
}

// A lesson dragged onto another hour, or onto another teacher — which on the
// server is nothing more than a change of availability.
LessonPlacement planMove(CalendarDayIndex index, LessonItem lesson, String teacherTaxCode, int startMinutes)
{
  final bookings = _bookingsOf(index, lesson);

  if (lesson.isPublished)
  {
    return LessonPlacement(
      teacherTaxCode: teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: startMinutes + lesson.minutes,
      kind: LessonPlacementKind.move,
      lessonId: lesson.id,
      refusal: kPublishedRefusal,
    );
  }

  return validatePlacement(
    index: index,
    teacherTaxCode: teacherTaxCode,
    startMinutes: startMinutes,
    endMinutes: startMinutes + lesson.minutes,
    bookings: bookings,
    disciplineIds: lesson.disciplineIds,
    lessonId: lesson.id,
  ).as(LessonPlacementKind.move);
}

// A lesson stretched or shortened from one of its edges. It is also how a
// request is split in two: shorten the first part, and the remainder becomes
// draggable again in the panel.
LessonPlacement planResize(CalendarDayIndex index, LessonItem lesson, int startMinutes, int endMinutes)
{
  if (lesson.isPublished)
  {
    return LessonPlacement(
      teacherTaxCode: lesson.teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      kind: LessonPlacementKind.resize,
      lessonId: lesson.id,
      refusal: kPublishedRefusal,
    );
  }

  return validatePlacement(
    index: index,
    teacherTaxCode: lesson.teacherTaxCode,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    bookings: _bookingsOf(index, lesson),
    disciplineIds: lesson.disciplineIds,
    lessonId: lesson.id,
  ).as(LessonPlacementKind.resize);
}

// The minutes still unspent on every booking in it, counting its own length as
// available again. The smallest and not the sum: the lesson counts whole
// against each pupil, so the tightest decides.
int resizeCeiling(CalendarDayIndex index, LessonItem lesson)
{
  var ceiling = -1;

  for (final entry in lesson.bookings)
  {
    final booking = index.bookingsById[entry.id];

    if (booking == null)
    {
      continue;
    }

    var available = booking.remainingExcluding(lesson.id);

    // A discipline this hour leaves out needs an hour of its own, and that one
    // cannot be under half an hour either — so the room for it comes off the
    // top here, and the edge stops where the leftover begins.
    final others = booking.parts.where((part) => part.id != lesson.id).toList();
    final coveredByOthers = <int>{for (final part in others) ...part.disciplineIds};
    final leftOut = booking.requestedDisciplineIds
        .difference(lesson.disciplineIds)
        .difference(coveredByOthers);

    if (leftOut.isNotEmpty && others.length + 1 < kMaxLessonParts)
    {
      available -= kMinimumBandMinutes;
    }

    if (ceiling < 0 || available < ceiling)
    {
      ceiling = available;
    }
  }

  return ceiling < kMinimumBandMinutes ? kMinimumBandMinutes : ceiling;
}

// An edge dragged sideways, with the shortest and longest a lesson may be held
// as limits rather than refusals: those are where the gesture stops, not
// mistakes somebody makes, and a block turning red for three pixels is telling
// you off for something you cannot see.
//
// Everything else stays a refusal: those have no obvious stopping point.
LessonPlacement planResizeWithin(CalendarDayIndex index, LessonItem lesson, int startMinutes, int endMinutes)
{
  final ceiling = resizeCeiling(index, lesson);

  // Which edge moved is told by the one that did not: the caller holds the
  // other at the lesson's own.
  if (endMinutes == lesson.endMinutes)
  {
    final earliest = endMinutes - ceiling;
    final latest = endMinutes - kMinimumBandMinutes;

    return planResize(index, lesson, startMinutes.clamp(earliest, latest), endMinutes);
  }

  return planResize(
    index,
    lesson,
    startMinutes,
    endMinutes.clamp(startMinutes + kMinimumBandMinutes, startMinutes + ceiling),
  );
}

// The minutes just freed, as an hour of their own beside the shortened one:
// shortening is the quick way of splitting a request, and the half let go
// should not have to be found again in the panel.
//
// [startMinutes] and [endMinutes] are the hours the lesson is about to have.
// [reached] is how far it used to reach, so that two reductions of a quarter
// add up — measured one gesture at a time, neither ever amounts to anything.
//
// It grows from the edge that moved and stops at the first of three: the
// minutes given back, the minutes still unspent, and the room actually there.
//
// Null wherever the second part would not be legal — both parts already exist,
// too little is left over, no room beside it, no competence for what is
// uncovered — and then the resize is simply a resize.
//
// The disciplines are the uncovered ones where there are any, otherwise the
// first part's: what is short then is the minutes and not the cover, and a
// lesson has to carry a discipline.
LessonPlacement? planSplitRemainder(
  CalendarDayIndex index,
  LessonItem lesson,
  int startMinutes,
  int endMinutes, {
  (int, int)? reached,
})
{
  if (lesson.isPublished)
  {
    return null;
  }

  final bookings = _bookingsOf(index, lesson);
  final lane = index.lanesByTeacher[lesson.teacherTaxCode];

  if (bookings.isEmpty || lane == null)
  {
    return null;
  }

  // The lesson being shortened is one of the parts, so it is counted here: what
  // is being asked for is one more beside it.
  if (bookings.any((entry) => entry.parts.length >= kMaxLessonParts))
  {
    return null;
  }

  // Only a shortening asks for a second part. Stretching an hour spends the
  // minutes left over rather than freeing any, and the request may still have
  // some unspent afterwards — which is the panel's business, not a gesture's.
  if (endMinutes - startMinutes >= lesson.minutes)
  {
    return null;
  }

  // Which edge moved. The other one is where the caller left it.
  final fromTheLeft = startMinutes > lesson.startMinutes;

  // How far the hour used to reach on that side, this reduction and the ones
  // before it. Without a memory it is this reduction alone, which is right the
  // first time and short every time after.
  final was = reached == null
      ? (lesson.startMinutes, lesson.endMinutes)
      : (
          math.min(reached.$1, lesson.startMinutes),
          math.max(reached.$2, lesson.endMinutes),
        );

  var minutes = fromTheLeft ? startMinutes - was.$1 : was.$2 - endMinutes;

  for (final entry in bookings)
  {
    // What this request has left once the shortened hour is paid for. The piece
    // never takes more than this: minutes that were never planned anywhere are
    // the panel's to hand out, not this gesture's.
    final unspent = entry.remainingExcluding(lesson.id) - (endMinutes - startMinutes);

    final room = fromTheLeft
        ? _roomBefore(index, lane, entry, startMinutes)
        : _roomAt(index, lane, entry, endMinutes);

    minutes = math.min(minutes, math.min(unspent, room));
  }

  if (minutes < kMinimumBandMinutes)
  {
    return null;
  }

  final (freedStart, freedEnd) = fromTheLeft
      ? (startMinutes - minutes, startMinutes)
      : (endMinutes, endMinutes + minutes);

  final coveredElsewhere = <int>{
    for (final entry in bookings)
      for (final part in entry.parts)
        if (part.id != lesson.id) ...part.disciplineIds,
  };

  final leftOut = <int>{for (final entry in bookings) ...entry.requestedDisciplineIds}
      .difference(lesson.disciplineIds)
      .difference(coveredElsewhere);

  // Judged against the lesson it came out of — `lessonId` takes that one out of
  // the overlaps and out of the minutes already spent, which is right on both
  // counts: it is about to be shorter, and the two halves together spend no more
  // than it spent whole.
  final judged = validatePlacement(
    index: index,
    teacherTaxCode: lesson.teacherTaxCode,
    startMinutes: freedStart,
    endMinutes: freedEnd,
    bookings: bookings,
    disciplineIds: leftOut.isNotEmpty ? leftOut : lesson.disciplineIds,
    lessonId: lesson.id,
  );

  if (!judged.isValid)
  {
    return null;
  }

  // Written out rather than copied with `as`: what was judged as a rewrite of
  // the old hour has to leave as an hour of its own, and carrying `lessonId`
  // over would turn the second part into a second write of the first.
  return LessonPlacement(
    teacherTaxCode: judged.teacherTaxCode,
    startMinutes: freedStart,
    endMinutes: freedEnd,
    availabilityId: judged.availabilityId,
    mode: judged.mode,
    bookingIds: judged.bookingIds,
    associationSubjectIds: judged.associationSubjectIds,
    warnings: judged.warnings,
  );
}

// The request both lessons are parts of. Null where they belong to different
// requests, or to more than one between them as a group hour can: then dropping
// one on the other is not a merge.
SchedulableBooking? sharedSplitBooking(CalendarDayIndex index, LessonItem first, LessonItem second)
{
  final shared = first.bookingIds.intersection(second.bookingIds);

  if (shared.length != 1)
  {
    return null;
  }

  final entry = index.bookingsById[shared.single];

  return entry != null && entry.parts.length == 2 ? entry : null;
}

// The two parts of a request put back into one. The survivor grows to the sum
// and takes the union of the disciplines: nothing is invented, so two parts of
// thirty on a request of ninety come back as one of sixty.
//
// Which way it grows is chosen and not assumed: growing rightwards fails
// whenever the minutes after the survivor are taken, and leftwards is the same
// merge. Where both fit, the one landing on fewer of the teacher's other hours
// wins.
//
// [keepTeacher] chooses which hour survives where the parts are on different
// teachers; left out, the one that starts first.
//
// The answer carries `deleteLessonId`: the merge is two calls in that order.
LessonPlacement? planMerge(
  CalendarDayIndex index,
  SchedulableBooking entry, {
  String? keepTeacher,
  int? keepLessonId,
})
{
  if (entry.parts.length < 2)
  {
    return null;
  }

  final ordered = [...entry.parts]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  // [keepLessonId] is what a drag names: dropping one part onto the other means
  // "put them together *here*", and here is the one that was dropped on. The
  // button has no such answer and takes the earlier of the two.
  final survivor = keepLessonId != null
      ? ordered.firstWhere((lesson) => lesson.id == keepLessonId, orElse: () => ordered.first)
      : keepTeacher == null
          ? ordered.first
          : ordered.firstWhere((lesson) => lesson.teacherTaxCode == keepTeacher, orElse: () => ordered.first);

  final dropped = ordered.firstWhere((lesson) => lesson.id != survivor.id);

  final minutes = ordered.fold(0, (total, lesson) => total + lesson.minutes);

  final bookings = <int, SchedulableBooking>{
    for (final lesson in ordered)
      for (final booking in _bookingsOf(index, lesson)) booking.id: booking,
  };

  LessonPlacement grownFrom(int startMinutes)
  {
    return validatePlacement(
      index: index,
      teacherTaxCode: survivor.teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: startMinutes + minutes,
      bookings: bookings.values.toList(),
      disciplineIds: {for (final lesson in ordered) ...lesson.disciplineIds},
      lessonId: survivor.id,
      deleteLessonId: dropped.id,
    ).as(LessonPlacementKind.merge);
  }

  final rightwards = grownFrom(survivor.startMinutes);
  final leftwards = grownFrom(survivor.endMinutes - minutes);

  if (!rightwards.isValid)
  {
    // The reason for keeping the start is the one worth reading where neither
    // way works: it is the hour somebody was looking at.
    return leftwards.isValid ? leftwards : rightwards;
  }

  if (!leftwards.isValid)
  {
    return rightwards;
  }

  final lane = index.lanesByTeacher[survivor.teacherTaxCode];

  int disturbance(LessonPlacement placement)
  {
    return lane == null
        ? 0
        : lane.lessons
            .where((lesson) =>
                lesson.id != survivor.id &&
                lesson.id != dropped.id &&
                spansOverlap(placement.startMinutes, placement.endMinutes, lesson.startMinutes, lesson.endMinutes))
            .length;
  }

  // A tie keeps the start: it is the hour that was there, and moving it for
  // nothing would be a change of its own.
  return disturbance(leftwards) < disturbance(rightwards) ? leftwards : rightwards;
}

List<SchedulableBooking> _bookingsOf(CalendarDayIndex index, LessonItem lesson)
{
  return [
    for (final entry in lesson.bookings)
      if (index.bookingsById[entry.id] != null) index.bookingsById[entry.id]!,
  ];
}
