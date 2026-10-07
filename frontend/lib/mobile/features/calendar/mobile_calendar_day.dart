import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/calendar/utils/teacher_band_call.dart';
import '../../../features/lessons/models/activity_item.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/models/room_supervision_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/lessons/utils/timeline_geometry.dart';

// closed: no opening in either mode; it takes precedence.
enum MobileCalendarBandState { closed, unpublished, empty, convened }

// Read as the desktop calendar reads a band.
class MobileCalendarBand
{
  final TimeBucket band;
  final MobileCalendarBandState state;
  final TeacherBandCall call;

  // Open in the building: an empty band then means not convened, not no lessons.
  final bool inBuilding;

  // The teacher gave hours in the band: an empty one then means not convened.
  final bool offered;

  // The minutes the timeline spans; null unless convened.
  final (int, int)? window;

  const MobileCalendarBand({
    required this.band,
    required this.state,
    required this.call,
    required this.inBuilding,
    required this.offered,
    this.window,
  });
}

class MobileCalendarDay
{
  final DateTime date;

  // Shut in both modes: no band to choose.
  final bool closed;
  final String? closureNote;

  // In TimeBucket order.
  final List<MobileCalendarBand> bands;

  const MobileCalendarDay({
    required this.date,
    required this.closed,
    required this.closureNote,
    required this.bands,
  });

  MobileCalendarBand bandOf(TimeBucket band) => bands[band.index];
}

String? calendarClosureNote(List<OpeningDayItem> openingDays, DateTime day)
{
  for (final row in openingDays)
  {
    if (!row.isOverride || row.startTime != null || !isSameDate(row.date, day))
    {
      continue;
    }

    final note = row.note;

    if (note != null && note.isNotEmpty)
    {
      return note;
    }
  }

  return null;
}

MobileCalendarDay calendarDayFrom({
  required DateTime day,
  required List<OpeningDayItem> openingDays,
  required List<CalendarPublicationItem> publications,
  required List<LessonItem> lessons,
  required List<ActivityItem> activities,
  required List<RoomSupervisionItem> supervisions,
  required List<AvailabilityItem> availabilities,
  required List<(DateTime, TimeBucket)> unbooked,
  required String? teacherTaxCode,
})
{
  MobileCalendarBand bandOf(TimeBucket band)
  {
    final call = teacherBandCall(
      day: day,
      band: band,
      lessons: lessons,
      activities: activities,
      supervisions: supervisions,
      teacherTaxCode: teacherTaxCode,
    );

    final inBuilding = openingWindowFor(openingDays, day, kPresenceMode, band) != null;
    final offered = availabilitiesIn(
      day: day,
      band: band,
      availabilities: availabilities,
      teacherTaxCode: teacherTaxCode,
    ).isNotEmpty;

    // Closed with nobody booked counts as published: the band is what it will be.
    final settled = publications.any((row) => isSameDate(row.date, day) && row.band == band) ||
        unbooked.any((row) => isSameDate(row.$1, day) && row.$2 == band);

    final opening = unionOpeningWindow(openingDays, day, band);

    if (opening == null || !settled)
    {
      return MobileCalendarBand(
        band: band,
        state: opening == null ? MobileCalendarBandState.closed : MobileCalendarBandState.unpublished,
        call: call,
        inBuilding: inBuilding,
        offered: offered,
      );
    }

    final window = timelineWindow(
      bandStartMinutes: bandStartMinutes(band),
      bandEndMinutes: bandEndMinutes(band),
      opening: (opening.startMinutes, opening.endMinutes),
      content: call.spans,
    );

    return MobileCalendarBand(
      band: band,
      state: call.isEmpty || window == null ? MobileCalendarBandState.empty : MobileCalendarBandState.convened,
      call: call,
      inBuilding: inBuilding,
      offered: offered,
      window: window,
    );
  }

  return MobileCalendarDay(
    date: day,
    closed: !isOpenOn(openingDays, day, kPresenceMode) && !isOpenOn(openingDays, day, kOnlineMode),
    closureNote: calendarClosureNote(openingDays, day),
    bands: [for (final band in TimeBucket.values) bandOf(band)],
  );
}
