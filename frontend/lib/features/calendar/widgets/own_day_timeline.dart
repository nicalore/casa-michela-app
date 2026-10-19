import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/descender_room.dart';
import '../../lessons/utils/timeline_geometry.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import '../../lessons/widgets/calendar_timeline.dart';
import 'own_lesson_block.dart';

const double _axisHeight = kTimelineAxisHeight;

const double _rowPadding = kTimelineRowPadding;
const double _subLaneGap = kTimelineSubLaneGap;

const double _trackInset = 28;

const double kTimelineNameWidth = 160;

typedef TimelineStretch = ({String mode, int startMinutes, int endMinutes});

// [width] fits every line, long ones wrapped; [heightAt] is the card's height at a given width.
typedef TimelineEntry = ({
  int startMinutes,
  int endMinutes,
  double width,
  double Function(double width) heightAt,
  Widget block,
});

typedef TimelineLane = ({Widget? name, List<TimelineStretch> stretches, List<TimelineEntry> entries});

// Under the rows, for the sideways scrollbar.
const double _scrollbarRoom = 14;

class OwnDayTimeline extends StatefulWidget
{
  final (int, int) window;

  final List<TimelineLane> lanes;

  // Null on any day but today.
  final int? nowMinutes;

  const OwnDayTimeline({
    super.key,
    required this.window,
    required this.lanes,
    required this.nowMinutes,
  });

  @override
  State<OwnDayTimeline> createState() => _OwnDayTimelineState();
}

class _OwnDayTimelineState extends State<OwnDayTimeline>
{
  final ScrollController _sideways = ScrollController();

  (int, int) get window => widget.window;

  List<TimelineLane> get lanes => widget.lanes;

  @override
  void dispose()
  {
    _sideways.dispose();
    super.dispose();
  }

  bool get _isNamed => lanes.any((lane) => lane.name != null);

  double _nameWidthIn(double maxWidth) => _isNamed ? math.min(kTimelineNameWidth, maxWidth * 0.22) : 0;

  static List<(int, int)> _spansOf(TimelineLane lane)
  {
    return [for (final entry in lane.entries) (entry.startMinutes, entry.endMinutes)];
  }

  static double _rowHeightOf(TimelineLane lane, double blockHeight)
  {
    final subLanes = assignSubLanes(_spansOf(lane)).laneCount;

    return 2 * _rowPadding + subLanes * blockHeight + (subLanes - 1) * _subLaneGap;
  }

  // Each row's cards as tall as the most-wrapped one, at the width the scale gives.
  static List<double> _blockHeightsOf(List<TimelineLane> lanes, TimelineMetrics metrics)
  {
    return [
      for (final lane in lanes)
        lane.entries.fold(
          kOwnBlockHeight,
          (tallest, entry) => math.max(
            tallest,
            entry.heightAt(metrics.widthOf(entry.startMinutes, entry.endMinutes) - 2 * kBlockSideGap),
          ),
        ),
    ];
  }

  List<Widget> _buildAxis(TimelineMetrics metrics)
  {
    Widget label(int minute, {required bool isHour})
    {
      return Positioned(
        left: metrics.xOf(minute) - 24,
        width: 48,
        bottom: 6,
        child: Center(
          child: Text(
            formatTimeOfDayShort(timeOfDayFromMinutes(minute)),
            style: GoogleFonts.plusJakartaSans(
              fontSize: isHour ? 11 : 9.5,
              fontWeight: isHour ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.4,
              color: isHour ? AppTheme.trialMutedText : AppTheme.trialMutedText.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return [
      for (final minute in metrics.halfTicks())
        if (metrics.roomAround(minute, 30) >= 44) label(minute, isHour: false),
      for (final minute in metrics.hourTicks()) label(minute, isHour: true),
    ];
  }

  // The card under way learns where the now line crosses it, which the scale may not reach evenly.
  Widget _blockOf(TimelineMetrics metrics, TimelineEntry entry, int? now)
  {
    if (now == null || now < entry.startMinutes || now >= entry.endMinutes)
    {
      return entry.block;
    }

    return ElapsedShare(
      share: cardShare(
        nowLineX(metrics, now),
        metrics.xOf(entry.startMinutes) + kBlockSideGap,
        metrics.xOf(entry.endMinutes) - kBlockSideGap,
      ),
      child: entry.block,
    );
  }

  List<Widget> _buildRow(TimelineMetrics metrics, int row, TimelineLane lane, int? now, double blockHeight)
  {
    final top = metrics.topOfRow(row);
    final height = metrics.heightOfRow(row);
    final subLanes = assignSubLanes(_spansOf(lane));

    return [
      for (final stretch in lane.stretches)
        if (intersectSpan(stretch.startMinutes, stretch.endMinutes, window.$1, window.$2) case final span?)
          Positioned(
            left: metrics.xOf(span.$1),
            width: metrics.widthOf(span.$1, span.$2),
            top: top + _rowPadding - kStretchBleed,
            height: height - 2 * (_rowPadding - kStretchBleed),
            child: CalendarAvailabilityStretch(mode: stretch.mode),
          ),
      for (var index = 0; index < lane.entries.length; index++)
        Positioned(
          left: metrics.xOf(lane.entries[index].startMinutes) + kBlockSideGap,
          width: math.max(
            1,
            metrics.widthOf(lane.entries[index].startMinutes, lane.entries[index].endMinutes) - 2 * kBlockSideGap,
          ),
          top: top + _rowPadding + subLanes.laneOf[index] * (blockHeight + _subLaneGap),
          height: blockHeight,
          child: _blockOf(metrics, lane.entries[index], now),
        ),
    ];
  }

  Widget _buildTrack(TimelineMetrics metrics, int? now, List<double> blockHeights)
  {
    return SizedBox(
      width: metrics.trackWidth + 2 * _trackInset,
      height: _axisHeight + metrics.trackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _trackInset,
            width: metrics.trackWidth,
            top: 0,
            height: _axisHeight,
            child: Stack(clipBehavior: Clip.none, children: _buildAxis(metrics)),
          ),
          Positioned(
            left: _trackInset,
            width: metrics.trackWidth,
            top: _axisHeight,
            height: metrics.trackHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _GridPainter(metrics: metrics)),
                  ),
                ),
                for (var row = 0; row < lanes.length; row++) ..._buildRow(metrics, row, lanes[row], now, blockHeights[row]),
                if (now != null) CalendarNowLine(metrics: metrics, minutes: now),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final rowHeights = [for (final lane in lanes) _rowHeightOf(lane, kOwnBlockHeight)];

    final clock = widget.nowMinutes;
    final now = clock != null && clock >= window.$1 && clock <= window.$2 ? clock : null;

    // Widths are measured: rebuilt once the fonts arrive.
    return ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints)
        {
          final nameWidth = _nameWidthIn(constraints.maxWidth);
          final room = math.max(0.0, constraints.maxWidth - nameWidth - 2 * _trackInset);

          final scaled = TimelineMetrics.scaled(
            scale: TimeScale.elastic(
              start: window.$1,
              end: window.$2,
              extent: room,
              minQuarter: kMinQuarterWidth,
              needs: [
                for (final lane in lanes)
                  for (final entry in lane.entries)
                    (startMinutes: entry.startMinutes, endMinutes: entry.endMinutes, size: entry.width),
              ],
            ),
            rowHeights: rowHeights,
          );

          final blockHeights = _blockHeightsOf(lanes, scaled);
          final metrics = scaled.withRowHeights([
            for (var row = 0; row < lanes.length; row++) _rowHeightOf(lanes[row], blockHeights[row]),
          ]);

          final scrolls = metrics.trackWidth > room + 0.5;
          final track = _buildTrack(metrics, now, blockHeights);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nameWidth > 0)
                SizedBox(
                  width: nameWidth,
                  height: _axisHeight + metrics.trackHeight,
                  child: Stack(
                    children: [
                      for (var row = 0; row < lanes.length; row++)
                        if (lanes[row].name case final name?)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: _axisHeight + metrics.topOfRow(row),
                            height: metrics.heightOfRow(row),
                            child: name,
                          ),
                    ],
                  ),
                ),
              Expanded(
                child: scrolls
                    ? Scrollbar(
                        controller: _sideways,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _sideways,
                          scrollDirection: Axis.horizontal,
                          child: Padding(padding: const EdgeInsets.only(bottom: _scrollbarRoom), child: track),
                        ),
                      )
                    : track,
              ),
            ],
          );
        },
      ),
    );
  }
}

class TimelineLaneName extends StatelessWidget
{
  final String name;

  const TimelineLaneName({super.key, required this.name});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DescenderRoom(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter
{
  final TimelineMetrics metrics;

  const _GridPainter({required this.metrics});

  @override
  void paint(Canvas canvas, Size size)
  {
    final hour = Paint()
      ..color = AppTheme.trialTealDeep.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    final half = Paint()
      ..color = AppTheme.trialTealDeep.withValues(alpha: 0.14)
      ..strokeWidth = 1;

    final quarter = Paint()
      ..color = AppTheme.trialLine.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    for (final minute in metrics.quarterTicks())
    {
      final x = metrics.xOf(minute);

      if (minute % 30 == 0)
      {
        for (var y = 0.0; y < size.height; y += 8)
        {
          canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 4, size.height)), half);
        }
      }
      else
      {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), quarter);
      }
    }

    for (final minute in metrics.hourTicks())
    {
      final x = metrics.xOf(minute);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hour);
    }

    for (var row = 1; row < metrics.rowCount; row++)
    {
      final y = metrics.topOfRow(row);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hour);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate)
  {
    return !oldDelegate.metrics.sameAxis(metrics) || oldDelegate.metrics.rowCount != metrics.rowCount;
  }
}
