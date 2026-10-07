import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/calendar/utils/pupil_band_presence.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/lessons/utils/timeline_geometry.dart';
import 'mobile_calendar_day.dart' show calendarClosureNote;

// Mirrors the desktop calendar's reading of a band, for every pupil at once.
class MobilePupilBand
{
  final TimeBucket band;

  // Published, or closed with nobody booked: the band is what it will be.
  final bool settled;

  // Open in the building: nothing booked then means no presence, not no lessons.
  final bool inBuilding;

  // In the order of the tax codes given.
  final List<PupilBandPresence> pupils;

  final OpeningWindow? opening;

  const MobilePupilBand({
    required this.band,
    required this.settled,
    required this.inBuilding,
    required this.pupils,
    required this.opening,
  });

  PupilBandPresence of(String taxCode) => pupils.firstWhere((pupil) => pupil.pupilTaxCode == taxCode);

  // Null when nothing falls in the band.
  (int, int)? windowFor(List<PupilBandPresence> shown)
  {
    final OpeningWindow? opening = this.opening;

    return timelineWindow(
      bandStartMinutes: bandStartMinutes(band),
      bandEndMinutes: bandEndMinutes(band),
      opening: opening == null ? null : (opening.startMinutes, opening.endMinutes),
      content: [
        for (final pupil in shown) ...[
          for (final row in pupil.presences) (row.startMinutes, row.endMinutes),
          ...pupil.lessonSpans,
        ],
      ],
    );
  }
}

class MobilePupilCalendarDay
{
  final DateTime date;

  // Shut in both modes: no band to choose.
  final bool closed;
  final String? closureNote;

  // In TimeBucket order.
  final List<MobilePupilBand> bands;

  const MobilePupilCalendarDay({
    required this.date,
    required this.closed,
    required this.closureNote,
    required this.bands,
  });

  MobilePupilBand bandOf(TimeBucket band) => bands[band.index];
}

MobilePupilCalendarDay pupilCalendarDayFrom({
  required DateTime day,
  required List<OpeningDayItem> openingDays,
  required List<CalendarPublicationItem> publications,
  required List<LessonItem> lessons,
  required List<PresenceItem> presences,
  required List<(DateTime, TimeBucket)> unbooked,
  required List<String> pupilTaxCodes,
})
{
  MobilePupilBand bandOf(TimeBucket band)
  {
    return MobilePupilBand(
      band: band,
      settled: publications.any((row) => isSameDate(row.date, day) && row.band == band) ||
          unbooked.any((row) => isSameDate(row.$1, day) && row.$2 == band),
      inBuilding: openingWindowFor(openingDays, day, kPresenceMode, band) != null,
      opening: unionOpeningWindow(openingDays, day, band),
      pupils: [
        for (final taxCode in pupilTaxCodes)
          pupilBandPresence(
            day: day,
            band: band,
            pupilTaxCode: taxCode,
            presences: presences,
            lessons: lessons,
          ),
      ],
    );
  }

  return MobilePupilCalendarDay(
    date: day,
    closed: !isOpenOn(openingDays, day, kPresenceMode) && !isOpenOn(openingDays, day, kOnlineMode),
    closureNote: calendarClosureNote(openingDays, day),
    bands: [for (final band in TimeBucket.values) bandOf(band)],
  );
}
