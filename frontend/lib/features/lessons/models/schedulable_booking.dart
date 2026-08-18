import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'booking_summary_item.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';
import 'presence_item.dart';

// A booking is planned in at most two lessons: `_MAX_LESSON_PARTS` on the
// server, checked in the before_flush hook of lesson_bookings.
const int kMaxLessonParts = 2;

// One booking of one pupil, with whatever of it has already been planned.
//
// The thing to hold on to is that a booking has **two** quantities to cover,
// and they are independent:
//
//   * the minutes — [BookingSummaryItem.duration], spread over at most two
//     lessons of at least half an hour each, never summing past what was asked;
//   * the disciplines — [BookingSummaryItem.disciplineIds], which the union of
//     the parts has to *cover*.
//
// Cover and not partition: the server allows the two parts to share a
// discipline, because two teachers taking turns on the same subject is a real
// thing. What it does not allow is a requested discipline left out of both.
//
// Ninety minutes of "Matematica: Algebra e Geometria" planned as forty-five on
// Algebra is *half the minutes* and *Geometria uncovered*. A single bar at 50%
// would be telling one of the two, and it would be the one that does not stop
// the band from being published.
class SchedulableBooking
{
  final BookingSummaryItem booking;

  // The hours it is being offered in — which is what any placement of it is
  // judged against.
  final PresenceItem presence;

  // The lessons it hangs off, earliest first.
  final List<LessonItem> parts;

  // The presence it is actually stored on, where that is not [presence].
  //
  // A pupil can be there twice in a day in the same way — the morning and the
  // afternoon in the building — and a request that has not been planned yet
  // belongs to all of those hours, not only to the stretch the server happened
  // to file it under. So it is offered under each of them, and planning it in
  // one is what settles which.
  //
  // Null on the copy shown under its own presence: nothing to put right there.
  final PresenceItem? storedOn;

  const SchedulableBooking({
    required this.booking,
    required this.presence,
    required this.parts,
    this.storedOn,
  });

  int get id => booking.id;

  // Whether writing an hour for it has to move the request first: the server
  // checks a lesson against the presence the booking is filed under, and this
  // one is filed elsewhere.
  bool get isBorrowed => storedOn != null;

  // --- minutes ------------------------------------------------------------

  int get scheduledMinutes => parts.fold(0, (total, lesson) => total + lesson.minutes);

  int get remainingMinutes => booking.duration - scheduledMinutes;

  // The same, with one lesson taken out of the count: what an edit of that
  // lesson has to play with, which is not the same as what a new one has.
  int remainingExcluding(int lessonId)
  {
    final others = parts.where((lesson) => lesson.id != lessonId);

    return booking.duration - others.fold(0, (total, lesson) => total + lesson.minutes);
  }

  // --- disciplines --------------------------------------------------------

  Set<int> get requestedDisciplineIds => booking.disciplineIds;

  Set<int> get coveredDisciplineIds
  {
    return parts
        .expand((lesson) => lesson.disciplineIds)
        .where(requestedDisciplineIds.contains)
        .toSet();
  }

  Set<int> get uncoveredDisciplineIds => requestedDisciplineIds.difference(coveredDisciplineIds);

  // --- state --------------------------------------------------------------

  bool get isFull => parts.length >= kMaxLessonParts;

  // A part of it is published, so nothing about it may be touched until the
  // band is taken back down.
  bool get isLocked => parts.any((lesson) => lesson.isPublished);

  // Which band the other part is in. Both parts have to be in the same one —
  // half a booking publishable and half not says nothing to anybody — so once
  // there is a part, the band is decided.
  TimeBucket? get pinnedBand => parts.isEmpty ? null : parts.first.band;

  bool get isFullyCovered => uncoveredDisciplineIds.isEmpty && remainingMinutes <= 0;

  // Whether another lesson can still be made out of what is left. A remainder
  // of a quarter of an hour is *not* placeable — the shortest lesson is half
  // an hour — but it is still spendable by lengthening a part that exists,
  // which is a different sentence and the card says it.
  bool get isPlaceable => !isLocked && !isFull && remainingMinutes >= kMinimumBandMinutes;

  // Whether a discipline can still be given to an hour this request already
  // has.
  //
  // Joining writes no hour and spends no minutes, so it outlives the two things
  // that close everything else: the second hour being there already, and the
  // minutes running out. As long as there is an hour and the band is not
  // published, a subject can be added to it.
  bool get canJoinAPart => !isLocked && parts.isNotEmpty;

  // Whether what is left could still be cut in two: two hours of half an hour
  // each, out of a request nothing has been planned from yet.
  //
  // It used to be what decided whether a single discipline could be dragged out
  // on its own. The panel asks a narrower question now — whether *this*
  // discipline leaves anything behind that would need an hour of its own — so
  // that a discipline already carried by an hour can be dragged out again, to
  // be given to a second teacher as well.
  bool get canSplitFurther
  {
    return !isLocked && parts.length + 2 <= kMaxLessonParts && remainingMinutes >= 2 * kMinimumBandMinutes;
  }

  // The minutes a part carrying [disciplineIds] should be proposed at.
  //
  // The whole remainder where those disciplines close the cover, because there
  // is nothing left to leave room for. Half of it, rounded down to the
  // quarter, where a second part is still to come — deterministic, explainable,
  // and a drag of the edge away from whatever was actually wanted.
  int proposedMinutesFor(Set<int> disciplineIds)
  {
    final closesTheCover = uncoveredDisciplineIds.difference(disciplineIds).isEmpty;

    if (closesTheCover)
    {
      return remainingMinutes;
    }

    // What is left for the part that has to come after this one. Where there is
    // not enough for one at all, this part is proposed the whole remainder: the
    // placement is going to be refused either way — it leaves a discipline with
    // nowhere to go — and a refusal read in the hand says more than a length
    // computed from two ends that have crossed over.
    final ceiling = remainingMinutes - kMinimumBandMinutes;

    if (ceiling < kMinimumBandMinutes)
    {
      return remainingMinutes;
    }

    return snapQuarterDown(remainingMinutes ~/ 2).clamp(kMinimumBandMinutes, ceiling);
  }
}

// The bookings of one presence, in the order they were asked for.
//
// Grouped by presence and not by pupil: one pupil can have two presences on
// the same day — the morning in the building and the evening at a screen, or
// two stretches of the same band — and they are two different sets of hours a
// lesson can be put in. Two headings with the same name and different
// subtitles are honest; one heading with two worlds inside it is not.
class PresenceBookingGroup
{
  final PresenceItem presence;
  final List<SchedulableBooking> bookings;

  const PresenceBookingGroup({required this.presence, required this.bookings});

  int get startMinutes => minutesOfTimeOfDay(presence.startTime);

  int get endMinutes => minutesOfTimeOfDay(presence.endTime);

  String get mode => presence.mode;

  bool get isOnline => presence.mode == kOnlineMode;

  String get hoursLabel => formatTimeRange(presence.startTime, presence.endTime);

  String get subtitle => '$hoursLabel · ${modeLabel(presence.mode)}';

  bool touches(int bandStart, int bandEnd)
  {
    return spansOverlap(startMinutes, endMinutes, bandStart, bandEnd);
  }
}

// Everything one pupil still has open on this day, whichever stretch of hours
// it was asked in.
//
// The pupil is what a person reads the panel by — "what is left of Rossi" —
// while the presence is what a lesson is *planned* under, because the hours and
// the mode are what any placement is judged against. So the two are nested
// rather than chosen between: one heading with the name, and inside it one
// band per stretch of hours, saying which world it is.
class StudentBookingGroup
{
  final PersonOptionItem student;

  // The pupil's stretches of hours that have something to plan, in the order
  // the clock gives them.
  final List<PresenceBookingGroup> presences;

  const StudentBookingGroup({required this.student, required this.presences});

  String get taxCode => presences.first.presence.studentTaxCode;

  // Counted by request and not by card: one that has not been planned yet is
  // offered under every stretch of hours the pupil gave in that mode, and there
  // is still only one of it to plan.
  int get openCount
  {
    return presences
        .expand((group) => group.bookings)
        .where((entry) => !entry.isFullyCovered)
        .map((entry) => entry.id)
        .toSet()
        .length;
  }
}

// The presence groups gathered under the pupil they belong to, keeping the
// order they came in — which [groupSchedulable] has already put by name and
// then by hour.
List<StudentBookingGroup> groupByStudent(List<PresenceBookingGroup> groups)
{
  final byStudent = <String, List<PresenceBookingGroup>>{};

  for (final group in groups)
  {
    byStudent.putIfAbsent(group.presence.studentTaxCode, () => []).add(group);
  }

  return [
    for (final entry in byStudent.values)
      StudentBookingGroup(student: entry.first.presence.student, presences: entry),
  ];
}

// Everything that could still be planned on that day, with what of it already
// has been.
//
// The presences are read as they are: no request is invented and none is
// dropped, so a booking whose parts are all in another band still shows up,
// with its parts counted. Hiding it would be hiding the reason it cannot be
// planned here.
List<PresenceBookingGroup> groupSchedulable({
  required List<PresenceItem> presences,
  required List<LessonItem> lessons,
  required DateTime day,
})
{
  // The presences one pupil gave in one way of being there. A request filed
  // under any of them can be planned in any of them, so each of them offers it.
  final sameModeByStudent = <(String, String), List<PresenceItem>>{};

  for (final presence in presences)
  {
    if (!isSameDate(presence.date, day))
    {
      continue;
    }

    sameModeByStudent
        .putIfAbsent((presence.studentTaxCode, presence.mode), () => [])
        .add(presence);
  }

  final partsByBooking = <int, List<LessonItem>>{};

  for (final lesson in lessons)
  {
    if (!isSameDate(lesson.date, day))
    {
      continue;
    }

    for (final entry in lesson.bookings)
    {
      partsByBooking.putIfAbsent(entry.id, () => []).add(lesson);
    }
  }

  for (final parts in partsByBooking.values)
  {
    parts.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  final groups = <PresenceBookingGroup>[];

  for (final presence in presences)
  {
    if (!isSameDate(presence.date, day))
    {
      continue;
    }

    // Borrowed from the pupil's other stretches of the same mode, and only what
    // has not been planned yet: once a part exists it was checked against the
    // presence it hangs off, and moving that now would leave the calendar saying
    // something that was never true. The server refuses it in those words.
    final borrowed = <SchedulableBooking>[];

    for (final other in sameModeByStudent[(presence.studentTaxCode, presence.mode)] ?? const <PresenceItem>[])
    {
      if (other.id == presence.id)
      {
        continue;
      }

      for (final booking in other.bookings)
      {
        if ((partsByBooking[booking.id] ?? const <LessonItem>[]).isNotEmpty)
        {
          continue;
        }

        borrowed.add(SchedulableBooking(
          booking: booking,
          presence: presence,
          parts: const [],
          storedOn: other,
        ));
      }
    }

    final bookings = [
      for (final booking in presence.bookings)
        SchedulableBooking(
          booking: booking,
          presence: presence,
          parts: partsByBooking[booking.id] ?? const <LessonItem>[],
        ),
      ...borrowed,
    ];

    // A stretch of hours with nothing to plan in it is not a heading. Counted
    // after the borrowing and not before: a pupil who asked for everything in the
    // morning and is also there in the afternoon has an afternoon worth showing,
    // and skipping it early was exactly what kept the request in one band.
    if (bookings.isEmpty)
    {
      continue;
    }

    groups.add(PresenceBookingGroup(presence: presence, bookings: bookings));
  }

  groups.sort((a, b)
  {
    final byName = a.presence.student.fullName.toLowerCase().compareTo(b.presence.student.fullName.toLowerCase());

    return byName != 0 ? byName : a.startMinutes.compareTo(b.startMinutes);
  });

  return groups;
}
