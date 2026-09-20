import 'dart:math';

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

class HomeSlot
{
  // Empty when the card names nobody.
  final String name;

  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  // 'presence' or 'online', as the backend stores them.
  final String mode;

  final String lead;

  final int subjects;

  const HomeSlot({
    required this.name,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.mode,
    required this.lead,
    this.subjects = 0,
  });

  String get hours => formatTimeRange(startTime, endTime);
}

// Minutes from midnight.
typedef HomeSpan = (int start, int end);

class HomeLane
{
  final String mode;

  final String name;

  final OpeningWindow opening;

  // Sorted, clipped to the opening.
  final List<HomeSpan> spans;

  final int subjects;

  const HomeLane({
    required this.mode,
    required this.name,
    required this.opening,
    required this.spans,
    required this.subjects,
  });
}

class HomeBandStatus
{
  final TimeBucket band;

  final bool isPublished;

  final bool offered;

  // Never empty.
  final List<HomeLane> lanes;

  final List<String> idle;

  const HomeBandStatus({
    required this.band,
    required this.isPublished,
    required this.offered,
    required this.lanes,
    required this.idle,
  });

  bool get isEmpty => lanes.every((lane) => lane.spans.isEmpty);
}

const String kAvailableLead = 'Disponibile';
const String kBookedLead = 'Prenotato';
const String kConvenedLead = 'Convocato';

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
        lead: kBookedLead,
        subjects: presence.bookings.length,
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
        lead: kAvailableLead,
      ),
  ];
}

// Earliest start and latest end per band and mode, lessons and activities alike.
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
        lead: kConvenedLead,
      ),
  ];
}

// A slot belongs to every band it overlaps.
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
      .toList();
}

// A booking straddling two bands is clipped to each band's opening.
HomeLane _laneOf(List<HomeSlot> slots, String mode, String name, OpeningWindow opening)
{
  final List<HomeSpan> spans = [];
  int subjects = 0;

  for (final slot in slots)
  {
    if (slot.mode != mode || slot.name != name)
    {
      continue;
    }

    final start = max(minutesOfTimeOfDay(slot.startTime), opening.startMinutes);
    final end = min(minutesOfTimeOfDay(slot.endTime), opening.endMinutes);

    if (end > start)
    {
      spans.add((start, end));
      subjects += slot.subjects;
    }
  }

  spans.sort((a, b) => a.$1.compareTo(b.$1));

  return HomeLane(mode: mode, name: name, opening: opening, spans: spans, subjects: subjects);
}

List<HomeLane> _lanes(Map<String, OpeningWindow> openings, List<HomeSlot> slots, List<String> names)
{
  if (names.isEmpty)
  {
    return [
      for (final MapEntry(key: mode, value: opening) in openings.entries)
        _laneOf(slots, mode, '', opening),
    ];
  }

  return [
    for (final name in names)
      for (final MapEntry(key: mode, value: opening) in openings.entries)
        if (_laneOf(slots, mode, name, opening) case final lane when lane.spans.isNotEmpty) lane,
  ];
}

// convened replaces the reader's own slots in published bands; null keeps them.
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
    final Map<String, OpeningWindow> openings = {
      for (final mode in const [kPresenceMode, kOnlineMode])
        mode: ?openingWindowFor(openingDays, day, mode, band),
    };

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
      isPublished: isPublished,
      offered: own.isNotEmpty,
      lanes: _lanes(openings, shown, names),
      idle: names.where((name) => !busy.contains(name)).toList(),
    ));
  }

  return bands;
}
