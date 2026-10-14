import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/week_range.dart';
import '../../../../features/lessons/utils/timeline_geometry.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart' show NowGlide, cardShare;
import '../../../shared/mobile_palette.dart';
import 'mobile_lesson_card.dart';

// Hour height at text scale 1; it grows with the text so cards keep their room.
const double _phoneHourHeight = 120;
const double _tabletHourHeight = 156;


// A card stands this far off its hours, so back-to-back ones do not touch.
const double _cardInset = 2;

const double _nowStroke = 2;

const double _blockHeight = 136;
const double _laneGap = 10;

const double _phonePersonGap = 12;
const double _tabletPersonGap = 18;
const double _laneHeadGap = 18;


const double _trackPad = 12;

// Scrolling sideways: room for the first and last hour labels.
const double _scrollPad = 24;

// Narrowest a quarter hour gets on the lying track: the half-hour labels still fit.
const double _minTrackQuarter = 22;
const double _axisHeight = 34;
const double _axisGap = 8;
const double _blockInset = 3;

typedef _Placed = ({MobileCalendarEntry entry, int lane, int lanes});

class MobileCalendarColumn
{
  final List<MobileCalendarEntry> entries;

  final Widget? head;

  const MobileCalendarColumn({required this.entries, this.head});
}

TextStyle _labelStyle({required bool half})
{
  return GoogleFonts.plusJakartaSans(
    fontSize: half ? 10.5 : 12,
    fontWeight: half ? FontWeight.w700 : FontWeight.w800,
    color: Colors.white.withValues(alpha: half ? 0.5 : 0.86),
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

Color _gridColor({required bool half}) => Colors.white.withValues(alpha: half ? 0.07 : 0.18);

List<int> _marks((int, int) window)
{
  final int first = (window.$1 + 29) ~/ 30 * 30;

  return [for (var minute = first; minute <= window.$2; minute += 30) minute];
}

class MobileNowPill extends StatelessWidget
{
  final int minutes;

  const MobileNowPill({super.key, required this.minutes});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const BoxDecoration(
        color: MobilePalette.nowLine,
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 2), blurRadius: 6)],
      ),
      child: Text(
        formatTimeOfDayShort(timeOfDayFromMinutes(minutes)),
        maxLines: 1,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

bool _showsNow(int? nowMinutes, (int, int) window)
{
  return nowMinutes != null && nowMinutes >= window.$1 && nowMinutes < window.$2;
}

// Over the cards' faces only, stepping across their [inset] gaps: never between two lessons.
double _nowAt(double Function(int minutes) at, int minutes, (int, int) window, double inset)
{
  final int quarter = math.min(window.$2 - kQuarterHour, minutes ~/ kQuarterHour * kQuarterHour);
  final double from = at(quarter) + inset;
  final double to = at(quarter + kQuarterHour) - inset;

  return from + (minutes - quarter).clamp(0, kQuarterHour) / kQuarterHour * math.max(0.0, to - from);
}

// Overlap chains share columns: 15-16, 15:30-16:30 and 16-17 make two.
List<_Placed> _placeInColumns(List<MobileCalendarEntry> entries)
{
  final ordered = [...entries]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  final placed = <_Placed>[];

  var cluster = <MobileCalendarEntry>[];
  var clusterEnd = -1;

  void close()
  {
    if (cluster.isEmpty)
    {
      return;
    }

    final lanes = assignSubLanes([for (final entry in cluster) (entry.startMinutes, entry.endMinutes)]);

    for (final (i, entry) in cluster.indexed)
    {
      placed.add((entry: entry, lane: lanes.laneOf[i], lanes: lanes.laneCount));
    }

    cluster = [];
  }

  for (final entry in ordered)
  {
    if (cluster.isNotEmpty && entry.startMinutes >= clusterEnd)
    {
      close();
    }

    cluster.add(entry);
    clusterEnd = cluster.length == 1 ? entry.endMinutes : math.max(clusterEnd, entry.endMinutes);
  }

  close();

  return placed;
}

// The now line runs under the cards so it never crosses their text.
class MobileCalendarTimeline extends StatelessWidget
{
  final (int, int) window;

  final List<MobileCalendarColumn> columns;

  // Minute of the day; null unless the day shown is today.
  final int? nowMinutes;
  final bool pastDay;

  final bool tablet;

  // Set on the pill so the page can scroll the present into view.
  final Key? nowKey;

  const MobileCalendarTimeline({
    super.key,
    required this.window,
    required this.columns,
    required this.nowMinutes,
    required this.pastDay,
    required this.tablet,
    this.nowKey,
  });

  double get _columnGap => tablet ? 10 : 6;

  double get _personGap => tablet ? _tabletPersonGap : _phonePersonGap;

  // Half the tallest label, so the first and last are not cut.
  static const double _edge = 10;

  double _cardWidth(_Placed item, double columnWidth) => (columnWidth - (item.lanes - 1) * _columnGap) / item.lanes;

  bool _inColumn(_Placed item) => (item.lanes > 1 || columns.length > 1) && !tablet;

  // To scale, stretched where a card needs more room to write every line.
  TimeScale _scaleFor(List<List<_Placed>> placed, double columnWidth, double perMinute, TextScaler scaler)
  {
    return TimeScale.elastic(
      start: window.$1,
      end: window.$2,
      extent: perMinute * (window.$2 - window.$1),
      minQuarter: perMinute * kQuarterHour,
      needs: [
        for (final items in placed)
          for (final item in items)
            (
              startMinutes: item.entry.startMinutes,
              endMinutes: item.entry.endMinutes,
              size: 2 * _cardInset +
                  mobileCardHeight(
                    item.entry,
                    width: _cardWidth(item, columnWidth),
                    scaler: scaler,
                    past: item.entry.timeAt(nowMinutes, pastDay: pastDay) == MobileEntryTime.past,
                    inColumn: _inColumn(item),
                    scale: tablet ? kMobileTabletCardScale : kMobilePhoneCardScale,
                  ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double textScale = math.max(1, scaler.scale(1));
    final double perMinute = (tablet ? _tabletHourHeight : _phoneHourHeight) * textScale / 60;

    final double gutter = (tablet ? 50 : 44) * textScale;
    final double lineStart = gutter + 8;
    final double trackStart = gutter + (tablet ? 16 : 12);

    final int? now = _showsNow(nowMinutes, window) ? nowMinutes : null;

    // Heights are measured: rebuilt once the fonts arrive.
    final Widget timeline = ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints)
        {
          final double width = (constraints.maxWidth - trackStart - (columns.length - 1) * _personGap) / columns.length;
          final List<List<_Placed>> placed = [for (final column in columns) _placeInColumns(column.entries)];
          final TimeScale scale = _scaleFor(placed, width, perMinute, scaler);

          double y(int minutes) => _edge + scale.at(minutes);

          double left(int column) => trackStart + column * (width + _personGap);

          final double? nowY = now == null ? null : _nowAt(y, now, window, _cardInset);

          return SizedBox(
            height: y(window.$2) + _edge,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final minute in _marks(window)) ...[
                  Positioned(
                    left: lineStart,
                    right: 0,
                    top: y(minute),
                    height: 1,
                    child: ColoredBox(color: _gridColor(half: minute % 60 != 0)),
                  ),
                  if (nowY == null || (nowY - y(minute)).abs() >= 19)
                    Positioned(
                      left: 0,
                      width: gutter,
                      top: y(minute),
                      child: FractionalTranslation(
                        translation: const Offset(0, -0.5),
                        child: Text(
                          formatTimeOfDayShort(timeOfDayFromMinutes(minute)),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: _labelStyle(half: minute % 60 != 0),
                        ),
                      ),
                    ),
                ],
                if (now != null && nowY != null)
                  NowGlide(
                    minutes: now,
                    target: nowY,
                    builder: (context, top) => Positioned(
                      left: gutter + 2,
                      right: 0,
                      top: top - _nowStroke / 2,
                      height: _nowStroke,
                      child: const ColoredBox(color: MobilePalette.nowLine),
                    ),
                  ),
                for (final (i, items) in placed.indexed)
                  for (final item in items) _buildCard(item, y, left(i), width, nowY),
                if (now != null && nowY != null)
                  NowGlide(
                    minutes: now,
                    target: nowY,
                    builder: (context, top) => Positioned(
                      right: constraints.maxWidth - gutter - 4,
                      top: top,
                      child: FractionalTranslation(
                        translation: const Offset(0, -0.5),
                        child: MobileNowPill(key: nowKey, minutes: now),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    if (columns.every((column) => column.head == null))
    {
      return timeline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: trackStart),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, column) in columns.indexed) ...[
                  if (i > 0) SizedBox(width: _personGap),
                  Expanded(child: column.head ?? const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        timeline,
      ],
    );
  }

  Widget _buildCard(_Placed item, double Function(int) y, double columnStart, double columnWidth, double? nowY)
  {
    final MobileCalendarEntry entry = item.entry;
    final double width = _cardWidth(item, columnWidth);
    final double top = y(entry.startMinutes) + _cardInset;
    final double bottom = y(entry.endMinutes) - _cardInset;

    return Positioned(
      left: columnStart + item.lane * (width + _columnGap),
      width: width,
      top: top,
      height: bottom - top,
      child: MobileLessonCard(
        entry: entry,
        time: entry.timeAt(nowMinutes, pastDay: pastDay),
        elapsed: nowY == null ? 0 : cardShare(nowY, top, bottom),
        // Tablet columns are wide enough for the full card.
        inColumn: _inColumn(item),
        scale: tablet ? kMobileTabletCardScale : kMobilePhoneCardScale,
      ),
    );
  }
}

class MobileCalendarTrack extends StatelessWidget
{
  final (int, int) window;

  final List<MobileCalendarColumn> lanes;

  final int? nowMinutes;
  final bool pastDay;

  final Key? nowKey;

  // Zero without heads.
  final double headWidth;

  const MobileCalendarTrack({
    super.key,
    required this.window,
    required this.lanes,
    required this.nowMinutes,
    required this.pastDay,
    this.nowKey,
    this.headWidth = 0,
  });

  // The narrowest card that writes every line within [height].
  double _widthFor(MobileCalendarEntry entry, double height, TextScaler scaler)
  {
    final bool past = entry.timeAt(nowMinutes, pastDay: pastDay) == MobileEntryTime.past;

    bool fits(double width) =>
        mobileCardHeight(entry, width: width, scaler: scaler, past: past, scale: kMobileTabletCardScale) <= height;

    // Never so narrow that the hours lose their end or their length.
    var low = mobileCardHoursWidth(entry, scaler: scaler, past: past, scale: kMobileTabletCardScale);
    var high = math.max(low, 520.0);

    if (fits(low))
    {
      return low;
    }

    if (!fits(high))
    {
      return high;
    }

    for (var step = 0; step < 10; step++)
    {
      final double middle = (low + high) / 2;

      if (fits(middle))
      {
        high = middle;
      }
      else
      {
        low = middle;
      }
    }

    return high;
  }

  @override
  Widget build(BuildContext context)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double textScale = math.max(1, scaler.scale(1));
    final bool headed = headWidth > 0;
    final double blockHeight = _blockHeight * textScale;

    final List<({List<int> laneOf, int laneCount})> subLanes = [
      for (final lane in lanes) assignSubLanes([for (final entry in lane.entries) (entry.startMinutes, entry.endMinutes)]),
    ];

    double heightOf(int lane)
    {
      final int count = math.max(1, subLanes[lane].laneCount);

      return count * blockHeight + (count - 1) * _laneGap;
    }

    final List<double> tops = [];
    var reached = _axisHeight + _axisGap;

    for (var i = 0; i < lanes.length; i++)
    {
      tops.add(reached);
      reached += heightOf(i) + _tabletPersonGap;
    }

    final int? now = _showsNow(nowMinutes, window) ? nowMinutes : null;
    final double height = reached - _tabletPersonGap + _axisGap;

    // Widths are measured: rebuilt once the fonts arrive.
    return ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints)
        {
          final double headRoom = headed ? headWidth + _laneHeadGap : 0;
          final double room = math.max(0, constraints.maxWidth - headRoom - 2 * _trackPad);

          final TimeScale scale = TimeScale.elastic(
            start: window.$1,
            end: window.$2,
            extent: room,
            minQuarter: _minTrackQuarter,
            needs: [
              for (final lane in lanes)
                for (final entry in lane.entries)
                  (
                    startMinutes: entry.startMinutes,
                    endMinutes: entry.endMinutes,
                    size: _widthFor(entry, blockHeight, scaler) + 2 * _blockInset,
                  ),
            ],
          );

          final bool scrolls = scale.extent > room + 0.5;
          final double pad = scrolls ? _scrollPad : _trackPad;

          double x(int minutes) => pad + scale.at(minutes);

          final double? nowX = now == null ? null : _nowAt(x, now, window, _blockInset);

          final Widget track = SizedBox(
            width: scale.extent + 2 * pad,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final minute in _marks(window)) ...[
                  Positioned(
                    left: x(minute),
                    width: 1,
                    top: _axisHeight,
                    bottom: 0,
                    child: ColoredBox(color: _gridColor(half: minute % 60 != 0)),
                  ),
                  if ((nowX == null || (nowX - x(minute)).abs() >= 46) &&
                      (minute % 60 == 0 || x(minute) - x(minute - 30) >= 44))
                    Positioned(
                      left: x(minute),
                      top: 8,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: Text(
                          formatTimeOfDayShort(timeOfDayFromMinutes(minute)),
                          maxLines: 1,
                          style: _labelStyle(half: minute % 60 != 0),
                        ),
                      ),
                    ),
                ],
                if (now != null && nowX != null)
                  NowGlide(
                    minutes: now,
                    target: nowX,
                    builder: (context, left) => Positioned(
                      left: left - _nowStroke / 2,
                      width: _nowStroke,
                      top: _axisHeight - 4,
                      bottom: 0,
                      child: const ColoredBox(color: MobilePalette.nowLine),
                    ),
                  ),
                for (final (i, lane) in lanes.indexed)
                  for (final (j, entry) in lane.entries.indexed)
                    Positioned(
                      left: x(entry.startMinutes) + _blockInset,
                      width: math.max(1, x(entry.endMinutes) - x(entry.startMinutes) - 2 * _blockInset),
                      top: tops[i] + subLanes[i].laneOf[j] * (blockHeight + _laneGap),
                      height: blockHeight,
                      child: MobileLessonCard(
                        entry: entry,
                        time: entry.timeAt(nowMinutes, pastDay: pastDay),
                        elapsed: nowX == null
                            ? 0
                            : cardShare(nowX, x(entry.startMinutes) + _blockInset, x(entry.endMinutes) - _blockInset),
                        horizontal: true,
                        scale: kMobileTabletCardScale,
                      ),
                    ),
                if (now != null && nowX != null)
                  NowGlide(
                    minutes: now,
                    target: nowX,
                    builder: (context, left) => Positioned(
                      left: left,
                      top: 6,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: MobileNowPill(key: nowKey, minutes: now),
                      ),
                    ),
                  ),
              ],
            ),
          );

          return SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (headed)
                  SizedBox(
                    width: headRoom,
                    height: height,
                    child: Stack(
                      children: [
                        for (final (i, lane) in lanes.indexed)
                          if (lane.head case final head?)
                            Positioned(left: 0, width: headWidth, top: tops[i], height: heightOf(i), child: head),
                      ],
                    ),
                  ),
                Expanded(
                  child: scrolls
                      ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: track)
                      : Align(alignment: Alignment.topLeft, child: track),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
