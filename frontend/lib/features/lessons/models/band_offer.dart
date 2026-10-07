import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import 'booking_summary_item.dart';
import 'presence_group.dart';

class BandOffer
{
  final TimeBucket band;

  // Time ranges joined by a middle dot, e.g. 14:00-15:45 and 16:45-18:45.
  final String hours;

  final int minutes;

  final int takenByOthers;

  const BandOffer({required this.band, required this.hours, required this.minutes, required this.takenByOthers});

  int get left => minutes - takenByOthers;
}

// [isOpen] leaves out bands a subject may no longer move into.
List<BandOffer> groupBandOffers(
  PresenceGroup group,
  String mode, {
  BookingSummaryItem? skip,
  bool Function(TimeBucket band)? isOpen,
})
{
  return [
    for (final band in group.bandsFor(mode))
      if (isOpen == null || isOpen(band))
        BandOffer(
          band: band,
          hours: [
            for (final slot in group.slotsFor(mode, band: band)) formatTimeRange(slot.startTime, slot.endTime),
          ].join(' · '),
          minutes: group.minutesOfferedIn(mode, band: band),
          takenByOthers: group.minutesAskedFor(mode, band: band) -
              (group.requestsFor(mode, band: band).any((request) => request.id == skip?.id) ? skip!.duration : 0),
        ),
  ];
}
