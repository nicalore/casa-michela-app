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

  final PresenceItem presence;

  final List<LessonItem> parts;

  final PresenceItem? storedOn;

  const SchedulableBooking({
    required this.booking,
    required this.presence,
    required this.parts,
    this.storedOn,
  });

  int get id => booking.id;

  bool get isBorrowed => storedOn != null;

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
        .map((entry) => entry.id)
        .toSet()
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

  for (final presence in presences)
  {
    if (!isSameDate(presence.date, day))
    {
      continue;
    }

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
