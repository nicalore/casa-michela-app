import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';

String homeLineRange(int startMinutes, int endMinutes)
{
  return 'dalle ${formatTimeOfDayShort(timeOfDayFromMinutes(startMinutes))} '
      'alle ${formatTimeOfDayShort(timeOfDayFromMinutes(endMinutes))}';
}

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

class MobileLineEntry
{
  final String text;

  // Colours the line; none for a muted one.
  final String? mode;

  final String? detail;

  const MobileLineEntry(this.text, {this.mode, this.detail});
}

class MobileLineBand
{
  final TimeBucket band;
  final bool isPublished;
  final List<MobileLineEntry> entries;

  final List<MobileModeSpan> openings;

  const MobileLineBand({
    required this.band,
    required this.isPublished,
    required this.entries,
    required this.openings,
  });

  int get startMinutes => bandStartMinutes(band);

  int get endMinutes => bandEndMinutes(band);
}

// Only the bands the Association opens; none at all means a closed day.
class MobileHomeDay
{
  final DateTime day;
  final List<MobileLineBand> bands;

  const MobileHomeDay({required this.day, required this.bands});

  bool get isClosed => bands.isEmpty;
}
