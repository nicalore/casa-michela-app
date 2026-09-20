import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
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

typedef TimelineEntry = ({int startMinutes, int endMinutes, Widget block});

typedef TimelineLane = ({Widget? name, List<TimelineStretch> stretches, List<TimelineEntry> entries});

class OwnDayTimeline extends StatelessWidget
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

  bool get _isNamed => lanes.any((lane) => lane.name != null);

  double _nameWidthIn(double maxWidth) => _isNamed ? math.min(kTimelineNameWidth, maxWidth * 0.22) : 0;

  static List<(int, int)> _spansOf(TimelineLane lane)
  {
    return [for (final entry in lane.entries) (entry.startMinutes, entry.endMinutes)];
  }

  static double _rowHeightOf(TimelineLane lane)
  {
    final subLanes = assignSubLanes(_spansOf(lane)).laneCount;

    return 2 * _rowPadding + subLanes * kOwnBlockHeight + (subLanes - 1) * _subLaneGap;
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
      if (metrics.pixelsPerMinute * 30 >= 44)
        for (final minute in metrics.halfTicks()) label(minute, isHour: false),
      for (final minute in metrics.hourTicks()) label(minute, isHour: true),
    ];
  }

  List<Widget> _buildRow(TimelineMetrics metrics, int row, TimelineLane lane)
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
          top: top + _rowPadding + subLanes.laneOf[index] * (kOwnBlockHeight + _subLaneGap),
          height: kOwnBlockHeight,
          child: lane.entries[index].block,
        ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final rowHeights = [for (final lane in lanes) _rowHeightOf(lane)];

    final clock = nowMinutes;
    final showsNow = clock != null && clock >= window.$1 && clock <= window.$2;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final nameWidth = _nameWidthIn(constraints.maxWidth);

        final metrics = TimelineMetrics(
          windowStartMinutes: window.$1,
          windowEndMinutes: window.$2,
          trackWidth: math.max(0, constraints.maxWidth - nameWidth - 2 * _trackInset),
          rowHeights: rowHeights,
        );

        return SizedBox(
          height: _axisHeight + metrics.trackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var row = 0; row < lanes.length; row++)
                if (lanes[row].name case final name?)
                  Positioned(
                    left: 0,
                    width: nameWidth,
                    top: _axisHeight + metrics.topOfRow(row),
                    height: metrics.heightOfRow(row),
                    child: name,
                  ),
              Positioned(
                left: nameWidth + _trackInset,
                right: _trackInset,
                top: 0,
                height: _axisHeight,
                child: Stack(clipBehavior: Clip.none, children: _buildAxis(metrics)),
              ),
              Positioned(
                left: nameWidth + _trackInset,
                right: _trackInset,
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
                    for (var row = 0; row < lanes.length; row++) ..._buildRow(metrics, row, lanes[row]),
                    if (showsNow) CalendarNowLine(metrics: metrics, minutes: clock),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
    return oldDelegate.metrics.windowStartMinutes != metrics.windowStartMinutes ||
        oldDelegate.metrics.windowEndMinutes != metrics.windowEndMinutes ||
        oldDelegate.metrics.trackWidth != metrics.trackWidth ||
        oldDelegate.metrics.rowCount != metrics.rowCount;
  }
}
