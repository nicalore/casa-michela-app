import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/week_range.dart';
import '../../../../features/lessons/utils/opening_window.dart' show kOnlineMode;
import '../../../../features/lessons/utils/timeline_geometry.dart';
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


const double _stretchBleed = 5;
const double _trackPad = 12;
const double _axisHeight = 34;
const double _axisGap = 8;
const double _blockInset = 3;

typedef _Placed = ({MobileCalendarEntry entry, int lane, int lanes});

typedef MobileCalendarStretch = ({String mode, int startMinutes, int endMinutes});

class MobileCalendarColumn
{
  final List<MobileCalendarEntry> entries;

  final List<MobileCalendarStretch> stretches;

  final Widget? head;

  const MobileCalendarColumn({required this.entries, this.stretches = const [], this.head});
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

class _Stretch extends StatelessWidget
{
  final String mode;

  const _Stretch(this.mode);

  @override
  Widget build(BuildContext context)
  {
    final bool online = mode == kOnlineMode;
    final Color tint = online ? MobilePalette.onlineOnSea : Colors.white;

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint.withValues(alpha: online ? 0.16 : 0.11),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(color: tint.withValues(alpha: 0.22)),
        ),
      ),
    );
  }
}

bool _showsNow(int? nowMinutes, (int, int) window)
{
  return nowMinutes != null && nowMinutes >= window.$1 && nowMinutes < window.$2;
}

double _elapsed(MobileCalendarEntry entry, int? nowMinutes)
{
  if (nowMinutes == null)
  {
    return 0;
  }

  return ((nowMinutes - entry.startMinutes) / entry.minutes).clamp(0.0, 1.0);
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

  @override
  Widget build(BuildContext context)
  {
    final double textScale = math.max(1, MediaQuery.textScalerOf(context).scale(1));
    final double perMinute = (tablet ? _tabletHourHeight : _phoneHourHeight) * textScale / 60;

    double y(int minutes) => _edge + (minutes - window.$1) * perMinute;

    final double gutter = (tablet ? 50 : 44) * textScale;
    final double lineStart = gutter + 8;
    final double trackStart = gutter + (tablet ? 16 : 12);

    final int? now = _showsNow(nowMinutes, window) ? nowMinutes : null;

    final Widget timeline = SizedBox(
      height: y(window.$2) + _edge,
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final double width = (constraints.maxWidth - trackStart - (columns.length - 1) * _personGap) / columns.length;

          double left(int column) => trackStart + column * (width + _personGap);

          return Stack(
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
                if (now == null || (y(now) - y(minute)).abs() >= 19)
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
              for (final (i, column) in columns.indexed)
                for (final stretch in column.stretches)
                  if (intersectSpan(stretch.startMinutes, stretch.endMinutes, window.$1, window.$2) case final span?)
                    Positioned(
                      left: left(i) - _stretchBleed,
                      width: width + 2 * _stretchBleed,
                      top: y(span.$1) - _stretchBleed + _cardInset,
                      height: y(span.$2) - y(span.$1) + 2 * (_stretchBleed - _cardInset),
                      child: _Stretch(stretch.mode),
                    ),
              if (now != null)
                Positioned(
                  left: gutter + 2,
                  right: 0,
                  top: y(now) - _nowStroke / 2,
                  height: _nowStroke,
                  child: const ColoredBox(color: MobilePalette.nowLine),
                ),
              for (final (i, column) in columns.indexed)
                for (final item in _placeInColumns(column.entries)) _buildCard(item, y, left(i), width),
              if (now != null)
                Positioned(
                  right: constraints.maxWidth - gutter - 4,
                  top: y(now),
                  child: FractionalTranslation(
                    translation: const Offset(0, -0.5),
                    child: MobileNowPill(key: nowKey, minutes: now),
                  ),
                ),
            ],
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

  Widget _buildCard(_Placed item, double Function(int) y, double columnStart, double columnWidth)
  {
    final MobileCalendarEntry entry = item.entry;
    final double width = (columnWidth - (item.lanes - 1) * _columnGap) / item.lanes;

    return Positioned(
      left: columnStart + item.lane * (width + _columnGap),
      width: width,
      top: y(entry.startMinutes) + _cardInset,
      height: y(entry.endMinutes) - y(entry.startMinutes) - 2 * _cardInset,
      child: MobileLessonCard(
        entry: entry,
        time: entry.timeAt(nowMinutes, pastDay: pastDay),
        elapsed: _elapsed(entry, nowMinutes),
        // Tablet columns are wide enough for the full card.
        inColumn: (item.lanes > 1 || columns.length > 1) && !tablet,
        timeInset: _cardInset,
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

  @override
  Widget build(BuildContext context)
  {
    final double textScale = math.max(1, MediaQuery.textScalerOf(context).scale(1));
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

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final double start = headed ? headWidth + _laneHeadGap + _trackPad : _trackPad;
          final double perMinute = (constraints.maxWidth - start - _trackPad) / (window.$2 - window.$1);

          double x(int minutes) => start + (minutes - window.$1) * perMinute;

          return Stack(
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
                if (now == null || (x(now) - x(minute)).abs() >= 46)
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
              for (final (i, lane) in lanes.indexed) ...[
                if (lane.head case final head?)
                  Positioned(left: 0, width: headWidth, top: tops[i], height: heightOf(i), child: head),
                for (final stretch in lane.stretches)
                  if (intersectSpan(stretch.startMinutes, stretch.endMinutes, window.$1, window.$2) case final span?)
                    Positioned(
                      left: x(span.$1) - _stretchBleed + _blockInset,
                      width: x(span.$2) - x(span.$1) + 2 * (_stretchBleed - _blockInset),
                      top: tops[i] - _stretchBleed,
                      height: heightOf(i) + 2 * _stretchBleed,
                      child: _Stretch(stretch.mode),
                    ),
              ],
              if (now != null)
                Positioned(
                  left: x(now) - _nowStroke / 2,
                  width: _nowStroke,
                  top: _axisHeight - 4,
                  bottom: 0,
                  child: const ColoredBox(color: MobilePalette.nowLine),
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
                      elapsed: _elapsed(entry, nowMinutes),
                      horizontal: true,
                      timeInset: _blockInset,
                      scale: kMobileTabletCardScale,
                    ),
                  ),
              if (now != null)
                Positioned(
                  left: x(now),
                  top: 6,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: MobileNowPill(key: nowKey, minutes: now),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
