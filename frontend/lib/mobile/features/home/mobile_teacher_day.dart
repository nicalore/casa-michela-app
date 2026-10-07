import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/calendar/utils/calendar_strings.dart';
import '../../../features/calendar/utils/teacher_band_call.dart';
import '../../../features/home/widgets/home_schedule_data.dart';
import '../../../features/home/widgets/role_home_layout.dart';
import '../../../features/lessons/models/activity_item.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import 'mobile_home_day.dart';

// What the day line says about a band, in the order the web home decides it.
enum MobileBandState { none, available, convened, notConvened }

class MobileDayBand
{
  final TimeBucket band;
  final bool isPublished;
  final MobileBandState state;

  // The teacher's own slots, shown while the band is unpublished.
  final List<MobileModeSpan> availabilities;

  // Set when convened.
  final TeacherBandCall? call;

  // The Association's hours, one per open mode.
  final List<MobileModeSpan> openings;

  const MobileDayBand({
    required this.band,
    required this.isPublished,
    required this.state,
    required this.availabilities,
    required this.call,
    required this.openings,
  });

  int get startMinutes => bandStartMinutes(band);

  int get endMinutes => bandEndMinutes(band);
}

// Only the bands the Association opens; none at all means a closed day.
class MobileTeacherDay
{
  final DateTime day;
  final List<MobileDayBand> bands;

  const MobileTeacherDay({required this.day, required this.bands});

  bool get isClosed => bands.isEmpty;
}

MobileTeacherDay teacherDayFrom({
  required DateTime day,
  required List<OpeningDayItem> openingDays,
  required List<CalendarPublicationItem> publications,
  required List<AvailabilityItem> availabilities,
  required List<LessonItem> lessons,
  required List<ActivityItem> activities,
  required String? teacherTaxCode,
})
{
  final List<HomeBandStatus> statuses = homeBands(
    day: day,
    openingDays: openingDays,
    slots: availabilitySlots(availabilities),
    published: {
      for (final publication in publications)
        if (isSameDate(publication.date, day)) publication.band,
    },
    convened: convenedSlots(day: day, lessons: lessons, activities: activities),
  );

  return MobileTeacherDay(
    day: day,
    bands: [
      for (final status in statuses)
        _bandFrom(
          status,
          day: day,
          availabilities: availabilities,
          lessons: lessons,
          activities: activities,
          teacherTaxCode: teacherTaxCode,
        ),
    ],
  );
}

MobileDayBand _bandFrom(
  HomeBandStatus status, {
  required DateTime day,
  required List<AvailabilityItem> availabilities,
  required List<LessonItem> lessons,
  required List<ActivityItem> activities,
  required String? teacherTaxCode,
})
{
  final TeacherBandCall call = teacherBandCall(
    day: day,
    band: status.band,
    lessons: lessons,
    activities: activities,
    supervisions: const [],
    teacherTaxCode: teacherTaxCode,
  );

  final List<AvailabilityItem> own = availabilitiesIn(
    day: day,
    band: status.band,
    availabilities: availabilities,
    teacherTaxCode: teacherTaxCode,
  )..sort((a, b) => minutesOfTimeOfDay(a.startTime).compareTo(minutesOfTimeOfDay(b.startTime)));

  final MobileBandState state;

  if (status.isPublished)
  {
    state = !call.isEmpty
        ? MobileBandState.convened
        : status.offered
            ? MobileBandState.notConvened
            : MobileBandState.none;
  }
  else
  {
    state = own.isNotEmpty ? MobileBandState.available : MobileBandState.none;
  }

  return MobileDayBand(
    band: status.band,
    isPublished: status.isPublished,
    state: state,
    availabilities: [
      for (final slot in own)
        MobileModeSpan(
          mode: slot.mode,
          startMinutes: minutesOfTimeOfDay(slot.startTime),
          endMinutes: minutesOfTimeOfDay(slot.endTime),
        ),
    ],
    call: state == MobileBandState.convened ? call : null,
    // Nobody is named for a teacher, so the lanes are one per open mode.
    openings: [
      for (final lane in status.lanes)
        MobileModeSpan(
          mode: lane.mode,
          startMinutes: lane.opening.startMinutes,
          endMinutes: lane.opening.endMinutes,
        ),
    ],
  );
}

// Worded as the calendar's convocation card.
MobileLineEntry _convenedEntry(TeacherBandCall call, {required bool feminine})
{
  final String detail = [
    for (final span in call.byMode) modeLabel(span.mode),
    convocationSummary(call),
  ].join(' · ');

  return MobileLineEntry(
    convocationTitle(call, feminine: feminine),
    mode: inBuildingSpan(call) == null ? kOnlineMode : kPresenceMode,
    detail: detail,
  );
}

List<MobileLineEntry> _teacherEntries(MobileDayBand band, {required bool feminine})
{
  switch (band.state)
  {
    case MobileBandState.convened:
      return [_convenedEntry(band.call!, feminine: feminine)];

    case MobileBandState.notConvened:
      return [
        MobileLineEntry(unconvenedLabelFor(kTeacherRole, feminine: feminine)!),
      ];

    case MobileBandState.available:
      return [
        for (final span in band.availabilities)
          MobileLineEntry(
            '$kAvailableLead ${homeLineRange(span.startMinutes, span.endMinutes)}',
            mode: span.mode,
            detail: modeLabel(span.mode),
          ),
      ];

    case MobileBandState.none:
      return [MobileLineEntry(emptyBandLabelFor(kTeacherRole))];
  }
}

MobileHomeDay teacherHomeDay(MobileTeacherDay day, {required bool feminine})
{
  return MobileHomeDay(
    day: day.day,
    bands: [
      for (final band in day.bands)
        MobileLineBand(
          band: band.band,
          isPublished: band.isPublished,
          entries: _teacherEntries(band, feminine: feminine),
          openings: band.openings,
        ),
    ],
  );
}
