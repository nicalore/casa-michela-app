import 'dart:math' as math;

import '../../../core/utils/week_range.dart' show kQuarterHour;

// Minutes into pixels and back, plus the span algebra between. Nothing here
// knows about widgets, deliberately: a rule that can only be exercised by
// pumping a widget is a rule nobody tests.
//
// A span is a pair of minutes since midnight, half-open like TimeBucket.

// Nearest and not down: a drag aims at a place, and rounding down always puts
// the block a quarter before where the pointer was let go.
int snapToQuarter(int minutes)
{
  return (minutes / kQuarterHour).round() * kQuarterHour;
}

int snapQuarterDown(int minutes)
{
  return (minutes / kQuarterHour).floor() * kQuarterHour;
}

// Slides a span inside [lower, upper] keeping its length rather than clipping:
// a block that shortened against an edge would change the lesson's duration by
// a gesture about its position. Too long for the room, it comes back flush with
// the lower bound and too long, and the caller refuses it.
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

// Adjacent as well as overlapping: 09:00–11:00 and 11:00–13:00 are one stretch
// of the morning, and a seam between them would draw a gap that is not there.
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

// What is left of [from] once [holes] is taken out of it. Both are merged
// first, so the answer does not depend on the order they arrive in.
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

// The busiest moment of a teacher's day, in pupils. Summing is sound because
// the same pupil cannot be in two overlapping lessons, a rule of its own.
//
// The same arithmetic as teacher_occupancy.peak_concurrent_students, and it has
// to stay the same: this copy exists so the refusal arrives under the pointer.
int peakConcurrentStudents(List<(int, int, int)> spans)
{
  final events = <(int, int)>[];

  for (final span in spans)
  {
    events.add((span.$1, span.$3));
    events.add((span.$2, -span.$3));
  }

  // Closures before openings at the same minute, which falls out of a negative
  // delta sorting first: 15:00 to 15:00 is not an overlap.
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

// Which sub-lane each span belongs to, by index into [spans].
//
// Every span takes the first sub-lane free over its stretch, always: nothing
// holds a place it does not need, which is what makes an hour rise back to the
// top once it stops overlapping.
//
// [preferred] changes only the order they are asked in, and that is the trick.
// In time order, dragging the lower of two stacked hours earlier makes it first
// by time, so it takes lane zero and pushes the untouched one down — two blocks
// moving for one gesture. Asked in the order they were drawn last time, the one
// that had zero keeps it and only the dragged block moves.
({List<int> laneOf, int laneCount}) assignSubLanes(
  List<(int, int)> spans, {
  List<int?> preferred = const [],
})
{
  int claimOf(int index) => (index < preferred.length ? preferred[index] : null) ?? _noClaim;

  // Whoever had a lane is served first, lowest first, and time settles ties.
  final order = [for (var i = 0; i < spans.length; i++) i]
    ..sort((a, b)
    {
      final byClaim = claimOf(a).compareTo(claimOf(b));

      return byClaim != 0 ? byClaim : spans[a].$1.compareTo(spans[b].$1);
    });

  final laneOf = List<int>.filled(spans.length, 0);

  // Checked against all of a lane and not only its last span: served out of
  // time order, "the last one has ended" is no longer the whole story.
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

// A span nobody has drawn yet waits behind the ones with a place to keep.
const int _noClaim = 1 << 20;

// The smallest span containing both, or whichever of the two exists.
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

// The stretch of the day the axis covers: the opening and nothing more. A band
// is six hours wide and the place is open for three, so an axis drawn on the
// band would spend half its width where nothing can ever be put.
//
// [content] does not size the axis. It only stretches it where something
// already written falls outside the opening, which happens when the hours are
// changed after a lesson exists: clipped away it would be out of reach.
//
// Null for a band that is closed and has never been written into.
(int, int)? timelineWindow({
  required int bandStartMinutes,
  required int bandEndMinutes,
  (int, int)? opening,
  List<(int, int)> content = const [],
})
{
  // Only what the opening does not already cover: a rescue for the unreachable,
  // not a second opinion on where the axis should start.
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

  // Narrower than an hour has no scale: widened towards whichever side has
  // room.
  if (end - start < 60)
  {
    end = math.min(bandEndMinutes, start + 60);
    start = math.max(bandStartMinutes, end - 60);
  }

  return (start, end);
}

// Where every minute and row falls, once the width is known. Built inside a
// LayoutBuilder and cheap enough to rebuild on every frame.
class TimelineMetrics
{
  final int windowStartMinutes;
  final int windowEndMinutes;

  // The track alone: the column of names on the left is not part of it, so
  // that nothing here has to know the column exists.
  final double trackWidth;

  // One height per row, because the rows are not all the same height any more:
  // a teacher taking two pupils at once needs two sub-lanes and gets a taller
  // row for them.
  //
  // This is what [rowAt] used to get for free from a division. It is a walk
  // down the list now — which is nothing for the ten or twenty rows a band
  // holds, and is the price of rows that fit what is in them.
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

  // Never zero, even for a span entirely outside the window: a block one pixel
  // wide is something the eye can find and click, while a block of no width is
  // a lesson that has vanished.
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

  // Which row a vertical position falls on, or null above and below them.
  //
  // The air between two rows is padding *inside* a row, so there are no dead
  // bands where a drop would land nowhere — that part matters as much as the
  // arithmetic, and it is why the rows are drawn edge to edge.
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

  // Whole hours inside the window, both ends included where they fall on one.
  List<int> hourTicks()
  {
    final ticks = <int>[];

    for (var minute = ((windowStartMinutes + 59) ~/ 60) * 60; minute <= windowEndMinutes; minute += 60)
    {
      ticks.add(minute);
    }

    return ticks;
  }

  // The half hours between them, which are where most lessons start and end.
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

  // The quarters between the hours: the grid a lesson snaps to, drawn thin.
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
