import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/calendar/utils/teacher_band_call.dart';
import '../../../features/home/widgets/home_schedule_data.dart';
import '../../../features/lessons/models/activity_item.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';

// What the day line says about a band, in the order the web home decides it.
enum MobileBandState { none, available, convened, notConvened }

// Minutes from midnight, one mode.
class MobileModeSpan
{
  final String mode;
  final int startMinutes;
  final int endMinutes;

  const MobileModeSpan({
    required this.mode,
    required this.startMinutes,
    required this.endMinutes,
  });
}

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
