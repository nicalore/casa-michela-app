import 'package:flutter/material.dart';

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/opening_day_item.dart';
import '../../lessons/models/activity_item.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/utils/timeline_geometry.dart';

// One booking, one declared availability or one call to teach, flattened to
// what the card shows.
class HomeSlot
{
  // Empty when the card speaks for a single person and needs no name.
  final String name;

  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  // 'presence' or 'online', as the backend stores them.
  final String mode;

  // A teacher's call to teach: arrival and departure, not an offer.
  final bool convened;

  const HomeSlot({
    required this.name,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.mode,
    this.convened = false,
  });

  String get hours => formatTimeRange(startTime, endTime);

  String get modeLabel => mode == kOnlineMode ? kOnScreen : kInBuilding;
}

// A band the association is open in, with what the reader has in it.
class HomeBandStatus
{
  final TimeBucket band;

  // Never empty: a band with no opening at all is left out of the day.
  final List<BandOpening> openings;

  final bool isPublished;

  // Whether the reader had anything in the band before publication: a
  // teacher who offered hours and got none is told so, one who offered
  // nothing is not.
  final bool offered;

  final List<HomeSlot> slots;

  // Named people with nothing in this band. Only filled when the card names
  // people at all, which is when a parent has more than one child.
  final List<String> idle;

  const HomeBandStatus({
    required this.band,
    required this.openings,
    required this.isPublished,
    required this.offered,
    required this.slots,
    required this.idle,
  });
}

List<HomeSlot> presenceSlots(List<PresenceItem> presences, {required bool named})
{
  return [
    for (final presence in presences)
      HomeSlot(
        name: named ? presence.student.firstName : '',
        date: presence.date,
        startTime: presence.startTime,
        endTime: presence.endTime,
        mode: presence.mode,
      ),
  ];
}

List<HomeSlot> availabilitySlots(List<AvailabilityItem> availabilities)
{
  return [
    for (final availability in availabilities)
      HomeSlot(
        name: '',
        date: availability.date,
        startTime: availability.startTime,
        endTime: availability.endTime,
        mode: availability.mode,
      ),
  ];
}

// Arrival and departure per band and mode: the earliest start and latest end
// of what the teacher was called for, lessons and activities alike.
List<HomeSlot> convenedSlots({
  required DateTime day,
  required List<LessonItem> lessons,
  required List<ActivityItem> activities,
})
{
  final Map<(TimeBucket, String), (int, int)> spans = {};

  void widen(TimeBucket band, String mode, int start, int end)
  {
    final current = spans[(band, mode)];

    spans[(band, mode)] = current == null
        ? (start, end)
        : (
            start < current.$1 ? start : current.$1,
            end > current.$2 ? end : current.$2,
          );
  }

  for (final lesson in lessons)
  {
    if (isSameDate(lesson.date, day))
    {
      widen(lesson.band, lesson.teacherMode, lesson.startMinutes, lesson.endMinutes);
    }
  }

  for (final activity in activities)
  {
    final placement = activity.placement;

    if (placement != null && isSameDate(activity.date, day))
    {
      widen(activity.band, placement.teacherMode, placement.startMinutes, placement.endMinutes);
    }
  }

  return [
    for (final MapEntry(key: (_, mode), value: (start, end)) in spans.entries)
      HomeSlot(
        name: '',
        date: day,
        startTime: timeOfDayFromMinutes(start),
        endTime: timeOfDayFromMinutes(end),
        mode: mode,
        convened: true,
      ),
  ];
}

// A slot belongs to every band it overlaps, the way the calendar reads it.
List<HomeSlot> _inBand(List<HomeSlot> slots, DateTime day, TimeBucket band)
{
  final bandStart = bandStartMinutes(band);
  final bandEnd = bandEndMinutes(band);

  return slots
      .where((slot) =>
          isSameDate(slot.date, day) &&
          spansOverlap(
            minutesOfTimeOfDay(slot.startTime),
            minutesOfTimeOfDay(slot.endTime),
            bandStart,
            bandEnd,
          ))
      .toList()
    ..sort(_byStartThenName);
}

// convened is a teacher's calls to teach, which replace what they offered in
// every published band; null for readers whose own slots stay, as a pupil's
// booking does once the calendar only confirms it.
List<HomeBandStatus> homeBands({
  required DateTime day,
  required List<OpeningDayItem> openingDays,
  required List<HomeSlot> slots,
  required Set<TimeBucket> published,
  List<HomeSlot>? convened,
  List<String> names = const [],
})
{
  final List<HomeBandStatus> bands = [];

  for (final band in TimeBucket.values)
  {
    final openings = bandOpeningsFor(openingDays, day, band);

    if (openings.isEmpty)
    {
      continue;
    }

    final List<HomeSlot> own = _inBand(slots, day, band);
    final bool isPublished = published.contains(band);

    final List<HomeSlot> shown =
        isPublished && convened != null ? _inBand(convened, day, band) : own;

    final busy = shown.map((slot) => slot.name).toSet();

    bands.add(HomeBandStatus(
      band: band,
      openings: openings,
      isPublished: isPublished,
      offered: own.isNotEmpty,
      slots: shown,
      idle: names.where((name) => !busy.contains(name)).toList(),
    ));
  }

  return bands;
}

int _byStartThenName(HomeSlot a, HomeSlot b)
{
  final byStart = minutesOfTimeOfDay(a.startTime).compareTo(minutesOfTimeOfDay(b.startTime));

  return byStart != 0 ? byStart : a.name.compareTo(b.name);
}
