import 'dart:math';

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/home/widgets/home_schedule_data.dart';
import '../../../features/home/widgets/role_home_layout.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/lessons/utils/timeline_geometry.dart';
import '../../../features/people/models/person_face.dart';
import 'mobile_home_day.dart';

const String _pupilRole = 'STUDENT';

class MobilePupilStay
{
  final TimeBucket band;
  final bool isPublished;
  final String mode;
  final int startMinutes;
  final int endMinutes;
  final int subjects;

  const MobilePupilStay({
    required this.band,
    required this.isPublished,
    required this.mode,
    required this.startMinutes,
    required this.endMinutes,
    required this.subjects,
  });

  String get detail => _stayDetail(mode, subjects);
}

String _stayDetail(String mode, int subjects)
{
  return [
    modeLabel(mode),
    if (subjects > 0) homeSubjectsLabel(subjects),
  ].join(' · ');
}

class MobileStayGroup
{
  final String mode;

  // By start.
  final List<MobilePupilStay> stays;

  const MobileStayGroup({required this.mode, required this.stays});

  String get detail => _stayDetail(mode, stays.fold(0, (sum, stay) => sum + stay.subjects));
}

class MobileBandStays
{
  final TimeBucket band;
  final bool isPublished;

  // Modes in the order of their first stay.
  final List<MobileStayGroup> groups;

  const MobileBandStays({required this.band, required this.isPublished, required this.groups});
}

class MobileChildDay
{
  final PersonFace face;
  final String taxCode;

  // In band order; empty when the child booked nothing today.
  final List<MobilePupilStay> stays;

  const MobileChildDay({required this.face, required this.taxCode, required this.stays});

  List<MobileBandStays> get bands
  {
    final Map<TimeBucket, Map<String, List<MobilePupilStay>>> byBand = {};

    for (final stay in stays)
    {
      ((byBand[stay.band] ??= {})[stay.mode] ??= []).add(stay);
    }

    return [
      for (final MapEntry(key: band, value: modes) in byBand.entries)
        MobileBandStays(
          band: band,
          isPublished: modes.values.first.first.isPublished,
          groups: [
            for (final MapEntry(key: mode, value: stays) in modes.entries)
              MobileStayGroup(mode: mode, stays: stays),
          ],
        ),
    ];
  }
}

class MobileParentDay
{
  final DateTime day;
  final bool isClosed;
  final List<MobileChildDay> children;

  const MobileParentDay({required this.day, required this.isClosed, required this.children});
}

List<HomeBandStatus> _statuses(
  DateTime day,
  List<OpeningDayItem> openingDays,
  List<CalendarPublicationItem> publications,
  List<HomeSlot> slots,
)
{
  return homeBands(
    day: day,
    openingDays: openingDays,
    slots: slots,
    published: {
      for (final publication in publications)
        if (isSameDate(publication.date, day)) publication.band,
    },
  );
}

Map<String, OpeningWindow> _openingsIn(List<OpeningDayItem> openingDays, DateTime day, TimeBucket band)
{
  return {
    for (final mode in const [kPresenceMode, kOnlineMode])
      mode: ?openingWindowFor(openingDays, day, mode, band),
  };
}

// As on the web home: a stay counts in every band it overlaps, clipped to its mode's opening there.
List<MobilePupilStay> _staysIn(
  HomeBandStatus status, {
  required DateTime day,
  required List<HomeSlot> slots,
  required Map<String, OpeningWindow> openings,
})
{
  final List<MobilePupilStay> stays = [];

  for (final slot in slots)
  {
    final OpeningWindow? opening = openings[slot.mode];

    final int slotStart = minutesOfTimeOfDay(slot.startTime);
    final int slotEnd = minutesOfTimeOfDay(slot.endTime);

    if (opening == null ||
        !isSameDate(slot.date, day) ||
        !spansOverlap(slotStart, slotEnd, bandStartMinutes(status.band), bandEndMinutes(status.band)))
    {
      continue;
    }

    final int start = max(slotStart, opening.startMinutes);
    final int end = min(slotEnd, opening.endMinutes);

    if (end > start)
    {
      stays.add(MobilePupilStay(
        band: status.band,
        isPublished: status.isPublished,
        mode: slot.mode,
        startMinutes: start,
        endMinutes: end,
        subjects: slot.subjects,
      ));
    }
  }

  return stays..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
}

// [presences] must be the student's own.
MobileHomeDay pupilHomeDay({
  required DateTime day,
  required List<OpeningDayItem> openingDays,
  required List<CalendarPublicationItem> publications,
  required List<PresenceItem> presences,
})
{
  final List<HomeSlot> slots = presenceSlots(presences, named: false);

  return MobileHomeDay(
    day: day,
    bands: [
      for (final status in _statuses(day, openingDays, publications, slots))
        _lineBand(status, day: day, openingDays: openingDays, slots: slots),
    ],
  );
}

MobileLineBand _lineBand(
  HomeBandStatus status, {
  required DateTime day,
  required List<OpeningDayItem> openingDays,
  required List<HomeSlot> slots,
})
{
  final Map<String, OpeningWindow> openings = _openingsIn(openingDays, day, status.band);
  final List<MobilePupilStay> stays = _staysIn(status, day: day, slots: slots, openings: openings);

  return MobileLineBand(
    band: status.band,
    isPublished: status.isPublished,
    entries: stays.isEmpty
        ? [MobileLineEntry(emptyBandLabelFor(_pupilRole))]
        : [
            for (final stay in stays)
              MobileLineEntry(
                '$kBookedLead ${homeLineRange(stay.startMinutes, stay.endMinutes)}',
                mode: stay.mode,
                detail: stay.detail,
              ),
          ],
    openings: [
      for (final MapEntry(key: mode, value: opening) in openings.entries)
        MobileModeSpan(
          mode: mode,
          startMinutes: opening.startMinutes,
          endMinutes: opening.endMinutes,
        ),
    ],
  );
}

// [children] in the parent's order, each with their tax code.
MobileParentDay parentHomeDay({
  required DateTime day,
  required List<OpeningDayItem> openingDays,
  required List<CalendarPublicationItem> publications,
  required List<PresenceItem> presences,
  required List<(PersonFace, String)> children,
})
{
  final List<HomeBandStatus> statuses = _statuses(day, openingDays, publications, const []);

  MobileChildDay childDay(PersonFace face, String taxCode)
  {
    final List<HomeSlot> slots = presenceSlots(
      presences.where((presence) => presence.studentTaxCode == taxCode).toList(),
      named: false,
    );

    return MobileChildDay(
      face: face,
      taxCode: taxCode,
      stays: [
        for (final status in statuses)
          ..._staysIn(status, day: day, slots: slots, openings: _openingsIn(openingDays, day, status.band)),
      ],
    );
  }

  return MobileParentDay(
    day: day,
    isClosed: statuses.isEmpty,
    children: [for (final (face, taxCode) in children) childDay(face, taxCode)],
  );
}
