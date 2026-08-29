import 'dart:math' as math;

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/study_program_item.dart';
import '../../people/models/person_item.dart';
import '../models/activity_item.dart';
import '../models/availability_item.dart';
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../models/schedulable_booking.dart';
import 'opening_window.dart';
import 'study_program_lookup.dart';
import 'timeline_geometry.dart';

const String kTooShortRefusal = "Una lezione dura almeno mezz'ora.";
const String kOutsideAvailabilityRefusal = 'Fuori dalla disponibilità del docente.';
const String kTeacherAtHomeRefusal = 'Un docente collegato da casa non può tenere una lezione in presenza.';
const String kMixedModesRefusal = 'Una lezione si deve svolgere interamente nella stessa modalità.';
const String kAcrossBandsRefusal =
    'Una lezione non può essere separata in fasce orarie diverse.';
const String kNoBookingRefusal = 'Una lezione deve avere almeno una prenotazione.';
const String kSettledRefusal = 'Questo calendario è pubblicato: riportalo in bozza '
    'per modificare le lezioni.';
const String kLessonWithoutDisciplineRefusal =
    'Solo i servizi non hanno discipline.';
const String kDisciplineNotRequestedRefusal =
    'Ogni disciplina della lezione deve essere collegata ad almeno una delle prenotazioni.';
const String kBookingNotOnLessonSubjectRefusal =
    'Ogni prenotazione deve avere almeno una disciplina in comune con la lezione.';
const String kTooManyPartsRefusal = 'Una prenotazione può essere divisa in al massimo due lezioni.';

const String kFreedMinutesGoBackNotice =
    'Una prenotazione può essere divisa in al massimo due lezioni: la porzione rimossa torna da pianificare.';

// Overlapping a certified student is allowed but warned about, not refused.
const String kCertifiedOverlapWarning =
    'Gli studenti con una certificazione non dovrebbero essere sovrapposti.';

const int kMaxConcurrentStudents = 2;

const String kTooManyStudentsRefusal =
    'Non è possibile sovrapporre più di $kMaxConcurrentStudents lezioni.';

const String kOnlineCannotOverlapRefusal =
    "Le lezioni online non possono avere sovrapposizioni.";

const String kOtherPartBandRefusal =
    'Le lezioni di una prenotazione devono stare nella stessa parte della giornata.';

// Activities can be as short as a quarter hour, unlike lessons (half hour).
const int kDefaultActivityMinutes = 60;

const int kMinimumActivityMinutes = kQuarterHour;

const String kActivityTooShortRefusal = "Un'attività dura almeno un quarto d'ora.";

const String kActivityAcrossBandsRefusal =
    "Un'attività non può essere separata in fasce orarie diverse.";

const String kActivitySettledRefusal = 'Questo calendario è pubblicato: riportalo in bozza '
    'per modificare le attività.';

const String kActivityOverLessonRefusal = "Il docente ha una lezione a quest'ora.";

const String kActivityOverActivityRefusal = "Il docente ha un'altra attività a quest'ora.";

const String kLessonOverActivityRefusal = "Il docente ha un'attività in calendario a quest'ora.";

const String kExcludedTeacherRefusal = 'Il docente è escluso dal calendario.';

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

class CalendarDayIndex
{
  final DateTime day;
  final TimeBucket band;

  final List<TeacherLane> lanes;
  final Map<String, TeacherLane> lanesByTeacher;

  final Map<int, SchedulableBooking> bookingsById;

  final Map<String, List<LessonItem>> lessonsByStudent;

  final Map<String, Set<(int, int)>> competencePairsByTeacher;

  final Map<String, Set<int>> competenceIdsByTeacher;

  final Map<String, Set<String>> serviceNamesByTeacher;

  final Map<String, int> studyProgrammeByStudent;

  // Read once from the people list rather than looked up per drop.
  final Set<String> certifiedStudents;

  final Map<int, Set<int>> disciplinesByProgramme;

  final Map<int, String> disciplineNames;

  // Excluded teachers keep their lanes but nothing is offered to or lands on them.
  final Set<String> excludedTeachers;

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
    required this.certifiedStudents,
    required this.disciplinesByProgramme,
    required this.disciplineNames,
    this.excludedTeachers = const {},
  });

  int get bandStart => bandStartMinutes(band);

  // Anything proposing, counting or searching teachers reads this, not [lanes].
  List<TeacherLane> get callableLanes
  {
    return excludedTeachers.isEmpty
        ? lanes
        : [for (final lane in lanes) if (!excludedTeachers.contains(lane.teacherTaxCode)) lane];
  }

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
    Set<String> excludedTeachers = const {},
  })
  {
    final subjectIdByName = <String, int>{
      for (final subject in associationSubjects) subject.name: subject.id,
    };

    final pairs = <String, Set<(int, int)>>{};
    final competences = <String, Set<int>>{};
    final services = <String, Set<String>>{};
    final programmes = <String, int>{};
    final certified = <String>{};

    for (final person in people)
    {
      pairs[person.fiscalCode] = {
        for (final subject in person.teacherSubjects ?? const [])
          for (final programme in subject.studyProgramIds) (subject.subjectId, programme),
      };

      competences[person.fiscalCode] = {
        for (final name in person.taughtSubjects)
          if (subjectIdByName[name] != null) subjectIdByName[name]!,
      };

      services[person.fiscalCode] = (person.teacherServices ?? const <String>[]).toSet();

      final programme = currentStudyProgramId(person);

      if (programme != null)
      {
        programmes[person.fiscalCode] = programme;
      }

      if (person.certificationTypes.isNotEmpty)
      {
        certified.add(person.fiscalCode);
      }
    }

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
      certifiedStudents: certified,
      disciplinesByProgramme: {
        for (final programme in studyPrograms)
          programme.id: {
            for (final subject in programme.ministrySubjects)
              for (final discipline in subject.associationSubjects) discipline.id,
          },
      },
      disciplineNames: {for (final subject in associationSubjects) subject.id: subject.name},
      excludedTeachers: excludedTeachers,
    );
  }

  String nameOf(int disciplineId) => disciplineNames[disciplineId] ?? 'disciplina';

  List<String> namesOf(Iterable<int> disciplineIds)
  {
    return [for (final id in disciplineIds) nameOf(id)];
  }
}

sealed class CalendarDragPayload
{
  const CalendarDragPayload();
}

class BookingDragPayload extends CalendarDragPayload
{
  final SchedulableBooking entry;

  final Set<int> disciplineIds;

  final int minutes;

  final bool isWholeRequest;

  const BookingDragPayload({
    required this.entry,
    required this.disciplineIds,
    required this.minutes,
    this.isWholeRequest = false,
  });

  bool get isSingleDiscipline => disciplineIds.length == 1;
}

class CarriedPlacement
{
  final (int, int)? span;

  final String? refusal;

  final bool isOverTrack;

  final bool alongside;

  final LessonPlacementKind? kind;

  const CarriedPlacement({
    this.span,
    this.refusal,
    this.isOverTrack = true,
    this.alongside = false,
    this.kind,
  });

  static const CarriedPlacement idle = CarriedPlacement();

  static const CarriedPlacement away = CarriedPlacement(isOverTrack: false);

  bool get isRefused => isOverTrack && refusal != null;

  bool get isAlongside => isOverTrack && refusal == null && alongside;
}

class CarriedRequest
{
  final CalendarDragPayload payload;

  final Set<String> competentTeachers;

  const CarriedRequest({required this.payload, this.competentTeachers = const {}});
}

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

    // No window for activities: any row is as good as any other.
    case ActivityDragPayload():
      break;
  }

  final held = window;

  return (
    window: held == null ? null : intersectSpan(held.$1, held.$2, bandStart, bandEnd),
    mode: mode,
    preferred: preferred,
    avoided: avoided,
  );
}

class LessonDragPayload extends CalendarDragPayload
{
  final LessonItem lesson;

  const LessonDragPayload({required this.lesson});
}

class ActivityDragPayload extends CalendarDragPayload
{
  final ActivityItem activity;

  final int minutes;

  const ActivityDragPayload({required this.activity, required this.minutes});

  factory ActivityDragPayload.of(ActivityItem activity)
  {
    return ActivityDragPayload(
      activity: activity,
      minutes: activity.placement?.minutes ?? kDefaultActivityMinutes,
    );
  }

  bool get isAssigned => activity.isAssigned;
}

enum LessonPlacementKind
{
  create,
  move,
  resize,

  join,

  merge,
}

class LessonPlacement
{
  final LessonPlacementKind kind;

  final String teacherTaxCode;
  final int startMinutes;
  final int endMinutes;

  final int? availabilityId;

  final String mode;

  final List<int> bookingIds;
  final List<int> associationSubjectIds;

  final int? lessonId;

  final int? deleteLessonId;

  // Set instead of [lessonId] when placing an activity; never both.
  final int? activityId;

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
    this.activityId,
    this.refusal,
    this.warnings = const [],
  });

  bool get isValid => refusal == null && availabilityId != null;

  int get minutes => endMinutes - startMinutes;

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
      activityId: activityId,
      refusal: refusal,
      warnings: warnings,
    );
  }
}

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

    if (lessonMode == kOnlineMode)
    {
      online ??= slot;
    }
  }

  return online;
}

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
  // Mirrored by the activity-side check: lessons and activities never overlap.
  final busy = lane.activities.any(
    (activity) => spansOverlap(startMinutes, endMinutes, activity.startMinutes, activity.endMinutes),
  );

  if (busy)
  {
    return kLessonOverActivityRefusal;
  }

  final others = [
    for (final lesson in lane.lessons)
      if (lesson.id != lessonId && lesson.id != deleteLessonId) lesson,
  ];

  final overlapping = [
    for (final lesson in others)
      if (spansOverlap(startMinutes, endMinutes, lesson.startMinutes, lesson.endMinutes)) lesson,
  ];

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
      return kSettledRefusal;
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

    final coveredByOthers = <int>{for (final part in otherParts) ...part.disciplineIds};
    final leftOut = entry.requestedDisciplineIds
        .difference(disciplineIds)
        .difference(coveredByOthers);

    if (leftOut.isNotEmpty && otherParts.length + 1 < kMaxLessonParts)
    {
      // Keep room for the disciplines this part leaves out to fit a second part.
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

  if (index.excludedTeachers.contains(teacherTaxCode))
  {
    return placement(kExcludedTeacherRefusal);
  }

  final lane = index.lanesByTeacher[teacherTaxCode];

  if (lane == null)
  {
    return placement(kOutsideAvailabilityRefusal);
  }

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

  final warnings = <String>[
    for (final entry in bookings)
      if (entry.booking.notPreferredTeacherTaxCodes.contains(teacherTaxCode))
        notPreferredWarning(lane.teacher.fullName, entry.presence.student.fullName),
  ];

  return placement(null, availabilityId: availability.id, mode: mode, warnings: warnings);
}

// Must be asked of the index as it stands before the write.
bool overlapsACertifiedStudent(CalendarDayIndex index, LessonPlacement placement)
{
  if (index.certifiedStudents.isEmpty)
  {
    return false;
  }

  final alongside = [
    for (final lesson in index.lanesByTeacher[placement.teacherTaxCode]?.lessons ?? const <LessonItem>[])
      if (lesson.id != placement.lessonId &&
          lesson.id != placement.deleteLessonId &&
          spansOverlap(placement.startMinutes, placement.endMinutes, lesson.startMinutes, lesson.endMinutes))
        lesson,
  ];

  if (alongside.isEmpty)
  {
    return false;
  }

  final students = <String>{
    for (final id in placement.bookingIds)
      if (index.bookingsById[id] case final entry?) entry.presence.studentTaxCode,
    for (final lesson in alongside) ...lesson.studentTaxCodes,
  };

  return students.any(index.certifiedStudents.contains);
}

String noTeacherReason(CalendarDayIndex index, SchedulableBooking entry, Set<int> disciplineIds)
{
  final noneFree = 'Nessun docente è libero nelle ore di ${entry.presence.student.fullName} '
      '(${formatTimeRange(entry.presence.startTime, entry.presence.endTime)}).';

  final service = entry.booking.serviceName;

  if (service != null)
  {
    final offering = index.callableLanes.where(
      (lane) => (index.serviceNamesByTeacher[lane.teacherTaxCode] ?? const <String>{}).contains(service),
    );

    return offering.isEmpty
        ? 'Nessun docente disponibile ha la competenza per: $service.'
        : noneFree;
  }

  final programmes = programmesOf(index, [entry.presence.studentTaxCode]);

  final competent = index.callableLanes.where((lane) => missingCompetence(
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

bool canPlanSomething(CalendarDayIndex index, SchedulableBooking entry)
{
  final presence = entry.presence;
  final presenceStart = minutesOfTimeOfDay(presence.startTime);
  final presenceEnd = minutesOfTimeOfDay(presence.endTime);

  final wanted = entry.requestedDisciplineIds.isEmpty
      ? <Set<int>>[const {}]
      : [for (final id in entry.requestedDisciplineIds) {id}];

  for (final lane in index.callableLanes)
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

Set<int> programmesOf(CalendarDayIndex index, Iterable<String> studentTaxCodes)
{
  return {
    for (final taxCode in studentTaxCodes)
      if (index.studyProgrammeByStudent[taxCode] != null) index.studyProgrammeByStudent[taxCode]!,
  };
}

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
    // Activities require no competence: any teacher qualifies.
    ActivityDragPayload() => (const <int>{}, const <String>{}, const <String>{}),
  };

  final programmes = programmesOf(index, students);

  return {
    for (final lane in index.callableLanes)
      if (missingCompetence(
                index,
                teacherTaxCode: lane.teacherTaxCode,
                disciplineIds: disciplineIds,
                programmes: programmes,
              ).isEmpty &&
          services.difference(index.serviceNamesByTeacher[lane.teacherTaxCode] ?? const <String>{}).isEmpty)
        lane.teacherTaxCode,
  };
}

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

  final host = _hostAt(lane, entry, startMinutes);

  if (host != null)
  {
    final joined = {...host.disciplineIds, ...drag.disciplineIds};
    final grown = _grownEnd(index, lane, entry, host, drag.minutes);

    LessonPlacement join(int endMinutes)
    {
      return validatePlacement(
        index: index,
        teacherTaxCode: teacherTaxCode,
        startMinutes: host.startMinutes,
        endMinutes: endMinutes,
        bookings: [entry],
        disciplineIds: joined,
        lessonId: host.id,
      ).as(LessonPlacementKind.join);
    }

    final placement = join(grown);

    if (placement.isValid || grown == host.endMinutes)
    {
      return placement;
    }

    return join(host.endMinutes);
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

int _grownEnd(CalendarDayIndex index, TeacherLane lane, SchedulableBooking entry, LessonItem host, int minutes)
{
  final ceiling = _roomAt(index, lane, entry, host.startMinutes, ignoring: host.id);
  final grown = snapQuarterDown(math.min(host.minutes + minutes, ceiling));

  return grown > host.minutes ? host.startMinutes + grown : host.endMinutes;
}

int _roomAt(CalendarDayIndex index, TeacherLane lane, SchedulableBooking entry, int startMinutes, {int? ignoring})
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
    if (lesson.id == ignoring)
    {
      continue;
    }

    if (lesson.startMinutes >= startMinutes && lesson.startMinutes - startMinutes < ceiling)
    {
      ceiling = lesson.startMinutes - startMinutes;
    }
  }

  return ceiling < 0 ? 0 : ceiling;
}

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

LessonPlacement planMove(CalendarDayIndex index, LessonItem lesson, String teacherTaxCode, int startMinutes)
{
  final bookings = _bookingsOf(index, lesson);

  if (lesson.isLocked)
  {
    return LessonPlacement(
      teacherTaxCode: teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: startMinutes + lesson.minutes,
      kind: LessonPlacementKind.move,
      lessonId: lesson.id,
      refusal: kSettledRefusal,
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

LessonPlacement planResize(CalendarDayIndex index, LessonItem lesson, int startMinutes, int endMinutes)
{
  if (lesson.isLocked)
  {
    return LessonPlacement(
      teacherTaxCode: lesson.teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      kind: LessonPlacementKind.resize,
      lessonId: lesson.id,
      refusal: kSettledRefusal,
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

LessonPlacement planResizeWithin(CalendarDayIndex index, LessonItem lesson, int startMinutes, int endMinutes)
{
  final ceiling = resizeCeiling(index, lesson);

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

LessonPlacement? planSplitRemainder(
  CalendarDayIndex index,
  LessonItem lesson,
  int startMinutes,
  int endMinutes, {
  (int, int)? reached,
})
{
  if (lesson.isLocked)
  {
    return null;
  }

  final bookings = _bookingsOf(index, lesson);
  final lane = index.lanesByTeacher[lesson.teacherTaxCode];

  if (bookings.isEmpty || lane == null)
  {
    return null;
  }

  if (bookings.any((entry) => entry.parts.length >= kMaxLessonParts))
  {
    return null;
  }

  if (endMinutes - startMinutes >= lesson.minutes)
  {
    return null;
  }

  final fromTheLeft = startMinutes > lesson.startMinutes;

  final was = reached == null
      ? (lesson.startMinutes, lesson.endMinutes)
      : (
          math.min(reached.$1, lesson.startMinutes),
          math.max(reached.$2, lesson.endMinutes),
        );

  var minutes = fromTheLeft ? startMinutes - was.$1 : was.$2 - endMinutes;

  for (final entry in bookings)
  {
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

  return disturbance(leftwards) < disturbance(rightwards) ? leftwards : rightwards;
}

List<SchedulableBooking> _bookingsOf(CalendarDayIndex index, LessonItem lesson)
{
  return [
    for (final entry in lesson.bookings)
      if (index.bookingsById[entry.id] != null) index.bookingsById[entry.id]!,
  ];
}

// Unlike lessons: no competence or pupil checks, only teacher availability.
LessonPlacement validateActivityPlacement({
  required CalendarDayIndex index,
  required ActivityItem activity,
  required String teacherTaxCode,
  required int startMinutes,
  required int endMinutes,
  LessonPlacementKind kind = LessonPlacementKind.create,
})
{
  LessonPlacement placement(String? refusal, {int? availabilityId})
  {
    return LessonPlacement(
      teacherTaxCode: teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      kind: kind,
      availabilityId: availabilityId,
      activityId: activity.id,
      refusal: refusal,
    );
  }

  if (activity.isLocked)
  {
    return placement(kActivitySettledRefusal);
  }

  if (endMinutes - startMinutes < kMinimumActivityMinutes)
  {
    return placement(kActivityTooShortRefusal);
  }

  if (activity.band != index.band || startMinutes < index.bandStart || endMinutes > index.bandEnd)
  {
    return placement(kActivityAcrossBandsRefusal);
  }

  if (index.excludedTeachers.contains(teacherTaxCode))
  {
    return placement(kExcludedTeacherRefusal);
  }

  final lane = index.lanesByTeacher[teacherTaxCode];

  if (lane == null)
  {
    return placement(kOutsideAvailabilityRefusal);
  }

  final availability = resolveAvailability(
    teacherAvailabilities: lane.availabilities,
    // kOnlineMode accepts either availability kind: an activity needs time, not a room.
    lessonMode: kOnlineMode,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );

  if (availability == null)
  {
    return placement(kOutsideAvailabilityRefusal);
  }

  for (final lesson in lane.lessons)
  {
    if (spansOverlap(startMinutes, endMinutes, lesson.startMinutes, lesson.endMinutes))
    {
      return placement(kActivityOverLessonRefusal);
    }
  }

  for (final other in lane.activities)
  {
    if (other.id != activity.id &&
        spansOverlap(startMinutes, endMinutes, other.startMinutes, other.endMinutes))
    {
      return placement(kActivityOverActivityRefusal);
    }
  }

  return placement(null, availabilityId: availability.id);
}

// Only used to shorten a new activity: a moved one keeps its length, and a
// misfit is refused instead of silently resized.
int _activityRoomAt(CalendarDayIndex index, TeacherLane lane, int startMinutes, {int? ignoring})
{
  var ceiling = index.bandEnd;

  for (final slot in lane.availabilities)
  {
    final start = minutesOfTimeOfDay(slot.startTime);
    final end = minutesOfTimeOfDay(slot.endTime);

    if (start <= startMinutes && end > startMinutes && end < ceiling)
    {
      ceiling = end;
    }
  }

  for (final lesson in lane.lessons)
  {
    if (lesson.startMinutes >= startMinutes && lesson.startMinutes < ceiling)
    {
      ceiling = lesson.startMinutes;
    }
  }

  for (final activity in lane.activities)
  {
    if (activity.id != ignoring &&
        activity.startMinutes >= startMinutes &&
        activity.startMinutes < ceiling)
    {
      ceiling = activity.startMinutes;
    }
  }

  return ceiling - startMinutes;
}

LessonPlacement planActivityDrop(
  CalendarDayIndex index,
  ActivityDragPayload drag,
  String teacherTaxCode,
  int startMinutes,
)
{
  final activity = drag.activity;
  final kind = drag.isAssigned ? LessonPlacementKind.move : LessonPlacementKind.create;
  final lane = index.lanesByTeacher[teacherTaxCode];

  if (lane == null)
  {
    return LessonPlacement(
      teacherTaxCode: teacherTaxCode,
      startMinutes: startMinutes,
      endMinutes: startMinutes + drag.minutes,
      kind: kind,
      activityId: activity.id,
      refusal: kOutsideAvailabilityRefusal,
    );
  }

  final room = snapQuarterDown(
    _activityRoomAt(index, lane, startMinutes, ignoring: activity.id),
  );

  final minutes = drag.isAssigned
      ? drag.minutes
      : math.max(kMinimumActivityMinutes, math.min(drag.minutes, room));

  return validateActivityPlacement(
    index: index,
    activity: activity,
    teacherTaxCode: teacherTaxCode,
    startMinutes: startMinutes,
    endMinutes: startMinutes + minutes,
    kind: kind,
  );
}

// A handle dragged past the fixed end stops instead of inverting the block.
LessonPlacement planActivityResize(
  CalendarDayIndex index,
  ScheduledActivity scheduled,
  int startMinutes,
  int endMinutes,
)
{
  final moving = endMinutes == scheduled.endMinutes
      ? (math.min(startMinutes, endMinutes - kMinimumActivityMinutes), endMinutes)
      : (startMinutes, math.max(endMinutes, startMinutes + kMinimumActivityMinutes));

  return validateActivityPlacement(
    index: index,
    activity: scheduled.activity,
    teacherTaxCode: scheduled.teacherTaxCode,
    startMinutes: moving.$1,
    endMinutes: moving.$2,
    kind: LessonPlacementKind.resize,
  );
}
