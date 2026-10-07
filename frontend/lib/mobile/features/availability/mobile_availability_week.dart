import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/utils/opening_window.dart';

// Mirrors how the desktop row decides a band.
class MobileAvailabilityBand
{
  final TimeBucket band;

  // One per mode the Association opens, presence first.
  final List<(String, OpeningWindow)> openings;

  // Day-ordered.
  final List<AvailabilityItem> slots;

  final bool hasClosed;

  const MobileAvailabilityBand({
    required this.band,
    required this.openings,
    required this.slots,
    required this.hasClosed,
  });

  bool get isOpen => openings.isNotEmpty;

  bool get isLocked => hasClosed || !isOpen;

  // The lock marks a passed deadline, or slots left in a band since closed.
  bool get showsLock => isOpen ? hasClosed : slots.isNotEmpty;

  // Slots left in a band that has since closed are still shown, locked.
  bool get isShown => isOpen || slots.isNotEmpty;

  bool get canDelete => !isLocked && slots.isNotEmpty;
}

class MobileAvailabilityDay
{
  final DateTime date;

  final bool isToday;
  final bool isPast;

  // All three, in the day's order.
  final List<MobileAvailabilityBand> bands;

  const MobileAvailabilityDay({
    required this.date,
    required this.isToday,
    required this.isPast,
    required this.bands,
  });

  List<MobileAvailabilityBand> get shownBands => bands.where((band) => band.isShown).toList();

  bool get isClosed => !bands.any((band) => band.isShown);

  bool get hasSlots => bands.any((band) => band.slots.isNotEmpty);

  bool get isEditable => bands.any((band) => band.isOpen && !band.hasClosed);

  bool get canDelete => hasSlots && bands.every((band) => band.slots.isEmpty || band.canDelete);
}

List<MobileAvailabilityDay> availabilityWeek({
  required DateTime monday,
  required DateTime now,
  required List<AvailabilityItem> availabilities,
  required List<OpeningDayItem> openingDays,
  required String? teacherTaxCode,
})
{
  final DateTime today = DateTime(now.year, now.month, now.day);

  final List<AvailabilityItem> own = [
    for (final slot in availabilities)
      if (teacherTaxCode == null || slot.teacherTaxCode == teacherTaxCode) slot,
  ]..sort((a, b) => minutesOfTimeOfDay(a.startTime).compareTo(minutesOfTimeOfDay(b.startTime)));

  return [
    for (final day in daysOfWeek(monday))
      MobileAvailabilityDay(
        date: day,
        isToday: isSameDate(day, today),
        isPast: day.isBefore(today),
        bands: [
          for (final band in TimeBucket.values)
            MobileAvailabilityBand(
              band: band,
              openings: [
                for (final mode in const [kPresenceMode, kOnlineMode])
                  if (openingWindowFor(openingDays, day, mode, band) case final OpeningWindow window)
                    (mode, window),
              ],
              slots: [
                for (final slot in own)
                  if (isSameDate(slot.date, day) && bucketFor(slot.startTime) == band) slot,
              ],
              hasClosed: haveBookingsClosed(day, band, now),
            ),
        ],
      ),
  ];
}
