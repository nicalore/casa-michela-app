import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'booking_summary_item.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';
import 'presence_item.dart';

const int kMaxLessonParts = 2;

class SchedulableBooking
{
  final BookingSummaryItem booking;

  // The stretch the booking was typed under: pupil and mode come from here.
  final PresenceItem presence;

  // Every stretch the pupil gave that day in that mode, clock order; a lesson may sit in any.
  final List<PresenceItem> presences;

  final List<LessonItem> parts;

  const SchedulableBooking({
    required this.booking,
    required this.presence,
    required this.presences,
    required this.parts,
  });

  int get id => booking.id;

  List<(int, int)> get windows
  {
    return [
      for (final stretch in presences)
        (minutesOfTimeOfDay(stretch.startTime), minutesOfTimeOfDay(stretch.endTime)),
    ];
  }

  List<(int, int)> windowsIn(int bandStart, int bandEnd)
  {
    return [
      for (final window in windows) ?intersectSpan(window.$1, window.$2, bandStart, bandEnd),
    ];
  }

  (int, int)? windowAt(int minute)
  {
    for (final window in windows)
    {
      if (window.$1 <= minute && minute < window.$2)
      {
        return window;
      }
    }

    return null;
  }

  (int, int)? windowEndingAfter(int minute)
  {
    for (final window in windows)
    {
      if (window.$1 < minute && minute <= window.$2)
      {
        return window;
      }
    }

    return null;
  }

  bool fitsAWindow(int startMinutes, int endMinutes)
  {
    return windows.any((window) => window.$1 <= startMinutes && endMinutes <= window.$2);
  }

  String get hoursLabel => formatWindows(windows);

  int get presenceMinutes => windows.fold(0, (total, window) => total + window.$2 - window.$1);

  int get scheduledMinutes => parts.fold(0, (total, lesson) => total + lesson.minutes);

  int get remainingMinutes => booking.duration - scheduledMinutes;

  int remainingExcluding(int lessonId)
  {
    final others = parts.where((lesson) => lesson.id != lessonId);

    return booking.duration - others.fold(0, (total, lesson) => total + lesson.minutes);
  }

  Set<int> get requestedDisciplineIds => booking.disciplineIds;

  Set<int> get coveredDisciplineIds
  {
    return parts
        .expand((lesson) => lesson.disciplineIds)
        .where(requestedDisciplineIds.contains)
        .toSet();
  }

  Set<int> get uncoveredDisciplineIds => requestedDisciplineIds.difference(coveredDisciplineIds);

  bool get isFull => parts.length >= kMaxLessonParts;

  bool get isLocked => parts.any((lesson) => lesson.isLocked);

  TimeBucket? get pinnedBand => parts.isEmpty ? null : parts.first.band;

  bool get isFullyCovered => uncoveredDisciplineIds.isEmpty && remainingMinutes <= 0;

  bool get isPlaceable => !isLocked && !isFull && remainingMinutes >= kMinimumBandMinutes;

  bool get canJoinAPart => !isLocked && parts.isNotEmpty;

  bool get canSplitFurther
  {
    return !isLocked && parts.length + 2 <= kMaxLessonParts && remainingMinutes >= 2 * kMinimumBandMinutes;
  }

  int proposedMinutesFor(Set<int> disciplineIds)
  {
    final closesTheCover = uncoveredDisciplineIds.difference(disciplineIds).isEmpty;

    if (closesTheCover)
    {
      return remainingMinutes;
    }

    final ceiling = remainingMinutes - kMinimumBandMinutes;

    if (ceiling < kMinimumBandMinutes)
    {
      return remainingMinutes;
    }

    return snapQuarterDown(remainingMinutes ~/ 2).clamp(kMinimumBandMinutes, ceiling);
  }
}

// "14:00–15:45, 17:00–19:00"
String formatWindows(Iterable<(int, int)> windows)
{
  return [for (final window in windows) formatMinutesRange(window.$1, window.$2)].join(', ');
}

// One pupil, one mode: their stretches that day and every booking typed under them.
class PresenceBookingGroup
{
  final List<PresenceItem> presences;
  final List<SchedulableBooking> bookings;

  const PresenceBookingGroup({required this.presences, required this.bookings});

  PresenceItem get presence => presences.first;

  int get startMinutes => minutesOfTimeOfDay(presence.startTime);

  String get mode => presence.mode;

  bool get isOnline => presence.mode == kOnlineMode;

  bool touches(int bandStart, int bandEnd)
  {
    return presences.any((stretch) => spansOverlap(
          minutesOfTimeOfDay(stretch.startTime),
          minutesOfTimeOfDay(stretch.endTime),
          bandStart,
          bandEnd,
        ));
  }

  // The stretches the bookings can be planned in within a band.
  PresenceBookingGroup within(int bandStart, int bandEnd)
  {
    final inBand = [
      for (final stretch in presences)
        if (spansOverlap(
          minutesOfTimeOfDay(stretch.startTime),
          minutesOfTimeOfDay(stretch.endTime),
          bandStart,
          bandEnd,
        ))
          stretch,
    ];

    return PresenceBookingGroup(
      presences: inBand,
      bookings: [
        for (final entry in bookings)
          SchedulableBooking(
            booking: entry.booking,
            presence: entry.presence,
            presences: inBand,
            parts: entry.parts,
          ),
      ],
    );
  }
}

class StudentBookingGroup
{
  final PersonOptionItem student;

  final List<PresenceBookingGroup> presences;

  const StudentBookingGroup({required this.student, required this.presences});

  String get taxCode => presences.first.presence.studentTaxCode;

  int get openCount
  {
    return presences
        .expand((group) => group.bookings)
        .where((entry) => !entry.isFullyCovered)
        .length;
  }
}

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

List<PresenceBookingGroup> groupSchedulable({
  required List<PresenceItem> presences,
  required List<LessonItem> lessons,
  required DateTime day,
})
{
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

  for (final stretches in sameModeByStudent.values)
  {
    stretches.sort((a, b) => minutesOfTimeOfDay(a.startTime).compareTo(minutesOfTimeOfDay(b.startTime)));

    final bookings = [
      for (final stretch in stretches)
        for (final booking in stretch.bookings)
          SchedulableBooking(
            booking: booking,
            presence: stretch,
            presences: stretches,
            parts: partsByBooking[booking.id] ?? const <LessonItem>[],
          ),
    ];

    if (bookings.isEmpty)
    {
      continue;
    }

    groups.add(PresenceBookingGroup(presences: stretches, bookings: bookings));
  }

  groups.sort((a, b)
  {
    final byName = a.presence.student.fullName.toLowerCase().compareTo(b.presence.student.fullName.toLowerCase());

    return byName != 0 ? byName : a.startMinutes.compareTo(b.startMinutes);
  });

  return groups;
}
