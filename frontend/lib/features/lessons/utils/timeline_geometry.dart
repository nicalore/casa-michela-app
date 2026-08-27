import 'dart:math' as math;

import '../../../core/utils/week_range.dart' show kQuarterHour;

// A span is a pair of minutes since midnight, half-open like TimeBucket.

// Rounds to nearest: rounding down would land drops a quarter early.
int snapToQuarter(int minutes)
{
  return (minutes / kQuarterHour).round() * kQuarterHour;
}

int snapQuarterDown(int minutes)
{
  return (minutes / kQuarterHour).floor() * kQuarterHour;
}

// Slides a span inside [lower, upper] keeping its length (never clips). A span
// longer than the range comes back flush left and too long, for the caller to refuse.
(int, int) clampSpanInto(int start, int end, int lower, int upper)
{
  final length = end - start;

  if (length >= upper - lower)
  {
    return (lower, lower + length);
  }

  if (start < lower)
  {
    return (lower, lower + length);
  }

  if (end > upper)
  {
    return (upper - length, upper);
  }

  return (start, end);
}

// Half-open: touching at an endpoint is not overlapping.
bool spansOverlap(int aStart, int aEnd, int bStart, int bEnd)
{
  return aStart < bEnd && bStart < aEnd;
}

(int, int)? intersectSpan(int aStart, int aEnd, int bStart, int bEnd)
{
  final start = math.max(aStart, bStart);
  final end = math.min(aEnd, bEnd);

  return start < end ? (start, end) : null;
}

// Merges adjacent spans as well as overlapping ones.
List<(int, int)> mergeSpans(List<(int, int)> spans)
{
  if (spans.isEmpty)
  {
    return const [];
  }

  final sorted = [...spans]..sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[sorted.first];

  for (final span in sorted.skip(1))
  {
    final last = merged.last;

    if (span.$1 <= last.$2)
    {
      merged[merged.length - 1] = (last.$1, math.max(last.$2, span.$2));

      continue;
    }

    merged.add(span);
  }

  return merged;
}

// [from] minus [holes]; both merged first so input order does not matter.
List<(int, int)> subtractSpans(List<(int, int)> from, List<(int, int)> holes)
{
  final remaining = <(int, int)>[];

  for (final span in mergeSpans(from))
  {
    var start = span.$1;

    for (final hole in mergeSpans(holes))
    {
      if (hole.$2 <= start || hole.$1 >= span.$2)
      {
        continue;
      }

      if (hole.$1 > start)
      {
        remaining.add((start, hole.$1));
      }

      start = math.max(start, hole.$2);
    }

    if (start < span.$2)
    {
      remaining.add((start, span.$2));
    }
  }

  return remaining;
}

// Must stay identical to teacher_occupancy.peak_concurrent_students on the
// backend; this copy exists so the refusal arrives under the pointer.
int peakConcurrentStudents(List<(int, int, int)> spans)
{
  final events = <(int, int)>[];

  for (final span in spans)
  {
    events.add((span.$1, span.$3));
    events.add((span.$2, -span.$3));
  }

  // Negative deltas sort first, so closures precede openings at the same minute.
  events.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));

  var peak = 0;
  var current = 0;

  for (final event in events)
  {
    current += event.$2;
    peak = math.max(peak, current);
  }

  return peak;
}

// Assigns each span the first free sub-lane. [preferred] only changes the
// order spans are served in: honoring last frame's lanes keeps untouched
// blocks in place while one is dragged.
({List<int> laneOf, int laneCount}) assignSubLanes(
  List<(int, int)> spans, {
  List<int?> preferred = const [],
})
{
  int claimOf(int index) => (index < preferred.length ? preferred[index] : null) ?? _noClaim;

  final order = [for (var i = 0; i < spans.length; i++) i]
    ..sort((a, b)
    {
      final byClaim = claimOf(a).compareTo(claimOf(b));

      return byClaim != 0 ? byClaim : spans[a].$1.compareTo(spans[b].$1);
    });

  final laneOf = List<int>.filled(spans.length, 0);

  // Check the whole lane, not just its last span: spans are served out of
  // time order.
  final laneSpans = <List<(int, int)>>[];

  for (final index in order)
  {
    final span = spans[index];
    var lane = 0;

    while (lane < laneSpans.length &&
        laneSpans[lane].any((other) => spansOverlap(span.$1, span.$2, other.$1, other.$2)))
    {
      lane++;
    }

    if (lane == laneSpans.length)
    {
      laneSpans.add([]);
    }

    laneSpans[lane].add(span);
    laneOf[index] = lane;
  }

  return (laneOf: laneOf, laneCount: laneSpans.isEmpty ? 1 : laneSpans.length);
}

// Unclaimed spans sort after every claimed one.
const int _noClaim = 1 << 20;

// Smallest span containing both, or whichever of the two exists.
(int, int)? hullOf((int, int)? a, (int, int)? b)
{
  if (a == null)
  {
    return b;
  }

  if (b == null)
  {
    return a;
  }

  return (math.min(a.$1, b.$1), math.max(a.$2, b.$2));
}

// The axis covers the opening hours, not the whole band. [content] only
// stretches it where existing items fall outside the opening (hours changed
// after a lesson existed). Null for a closed, never-written band.
(int, int)? timelineWindow({
  required int bandStartMinutes,
  required int bandEndMinutes,
  (int, int)? opening,
  List<(int, int)> content = const [],
})
{
  final outside = opening == null
      ? content
      : content.where((span) => span.$1 < opening.$1 || span.$2 > opening.$2).toList();

  final outsideHull = outside.isEmpty
      ? null
      : (
          outside.map((span) => span.$1).reduce(math.min),
          outside.map((span) => span.$2).reduce(math.max),
        );

  final hull = hullOf(opening, outsideHull);

  if (hull == null)
  {
    return null;
  }

  var start = math.max(bandStartMinutes, hull.$1);
  var end = math.min(bandEndMinutes, hull.$2);

  if (start >= end)
  {
    return null;
  }

  // Windows narrower than an hour are widened towards whichever side has room.
  if (end - start < 60)
  {
    end = math.min(bandEndMinutes, start + 60);
    start = math.max(bandStartMinutes, end - 60);
  }

  return (start, end);
}

// Built inside a LayoutBuilder; cheap enough to rebuild every frame.
class TimelineMetrics
{
  final int windowStartMinutes;
  final int windowEndMinutes;

  // The track alone, excluding the name column on the left.
  final double trackWidth;

  // Rows vary in height: a row with concurrent lessons needs extra sub-lanes.
  final List<double> rowHeights;

  const TimelineMetrics({
    required this.windowStartMinutes,
    required this.windowEndMinutes,
    required this.trackWidth,
    required this.rowHeights,
  });

  int get windowMinutes => windowEndMinutes - windowStartMinutes;

  double get pixelsPerMinute => windowMinutes <= 0 ? 0 : trackWidth / windowMinutes;

  int get rowCount => rowHeights.length;

  double get trackHeight => rowHeights.fold(0, (total, height) => total + height);

  double heightOfRow(int index) => rowHeights[index];

  double xOf(int minutes)
  {
    final clamped = minutes.clamp(windowStartMinutes, windowEndMinutes);

    return (clamped - windowStartMinutes) * pixelsPerMinute;
  }

  // Never zero: a zero-width block is a lesson that has vanished.
  double widthOf(int startMinutes, int endMinutes)
  {
    return math.max(1, xOf(endMinutes) - xOf(startMinutes));
  }

  int minutesAt(double x)
  {
    if (pixelsPerMinute <= 0)
    {
      return windowStartMinutes;
    }

    final minutes = windowStartMinutes + (x / pixelsPerMinute).round();

    return minutes.clamp(windowStartMinutes, windowEndMinutes);
  }

  int snappedMinutesAt(double x)
  {
    return snapToQuarter(minutesAt(x)).clamp(windowStartMinutes, windowEndMinutes);
  }

  // Row at a vertical position, or null outside the rows. Inter-row air is
  // padding inside a row, so no drop lands in a dead band.
  int? rowAt(double y)
  {
    if (y < 0)
    {
      return null;
    }

    var top = 0.0;

    for (var index = 0; index < rowHeights.length; index++)
    {
      top += rowHeights[index];

      if (y < top)
      {
        return index;
      }
    }

    return null;
  }

  double topOfRow(int index)
  {
    var top = 0.0;

    for (var i = 0; i < index && i < rowHeights.length; i++)
    {
      top += rowHeights[i];
    }

    return top;
  }

  List<int> hourTicks()
  {
    final ticks = <int>[];

    for (var minute = ((windowStartMinutes + 59) ~/ 60) * 60; minute <= windowEndMinutes; minute += 60)
    {
      ticks.add(minute);
    }

    return ticks;
  }

  List<int> halfTicks()
  {
    final ticks = <int>[];
    final first = ((windowStartMinutes + 29) ~/ 30) * 30;

    for (var minute = first; minute <= windowEndMinutes; minute += 30)
    {
      if (minute % 60 != 0)
      {
        ticks.add(minute);
      }
    }

    return ticks;
  }

  List<int> quarterTicks()
  {
    final ticks = <int>[];
    final first = ((windowStartMinutes + kQuarterHour - 1) ~/ kQuarterHour) * kQuarterHour;

    for (var minute = first; minute <= windowEndMinutes; minute += kQuarterHour)
    {
      if (minute % 60 != 0)
      {
        ticks.add(minute);
      }
    }

    return ticks;
  }
}
