import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../lessons/utils/timeline_geometry.dart';
import '../../lessons/widgets/calendar_lane_panel.dart' show CalendarLaneEmpty;
import 'own_day_timeline.dart' show TimelineEntry;
import 'own_lesson_block.dart';

const double _rowGap = 10;
const double _columnGap = 10;

const double _nowLineHeight = 2;
const double _nowLineBleed = 4;

typedef _Cluster = ({int startMinutes, int endMinutes, List<TimelineEntry> entries});

class OwnLessonList extends StatelessWidget
{
  final List<TimelineEntry> entries;

  // Null on any day but today.
  final int? nowMinutes;

  const OwnLessonList({super.key, required this.entries, required this.nowMinutes});

  // Overlap chains: 15–16, 15:30–16:30 and 16–17 make one row of three.
  List<_Cluster> get _clusters
  {
    final ordered = [...entries]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final clusters = <_Cluster>[];

    for (final entry in ordered)
    {
      final last = clusters.lastOrNull;

      if (last != null && spansOverlap(last.startMinutes, last.endMinutes, entry.startMinutes, entry.endMinutes))
      {
        clusters[clusters.length - 1] = (
          startMinutes: last.startMinutes,
          endMinutes: math.max(last.endMinutes, entry.endMinutes),
          entries: [...last.entries, entry],
        );

        continue;
      }

      clusters.add((startMinutes: entry.startMinutes, endMinutes: entry.endMinutes, entries: [entry]));
    }

    return clusters;
  }

  // Pixels per minute; the shortest block keeps its full height.
  static double _scaleOf(_Cluster row)
  {
    return row.entries
        .map((entry) => kOwnBlockHeight / math.max(1, entry.endMinutes - entry.startMinutes))
        .reduce(math.max);
  }

  static double _heightOf(_Cluster row) => (row.endMinutes - row.startMinutes) * _scaleOf(row);

  // Inside a row the row draws the line itself.
  double? _gapLineTop(List<_Cluster> rows)
  {
    final now = nowMinutes;

    if (now == null || rows.isEmpty || now < rows.first.startMinutes)
    {
      return null;
    }

    var top = 0.0;

    for (final row in rows)
    {
      if (now < row.startMinutes)
      {
        return top - _rowGap / 2;
      }

      if (now < row.endMinutes)
      {
        return null;
      }

      top += _heightOf(row) + _rowGap;
    }

    return null;
  }

  Widget _buildNowLine()
  {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.trialDanger,
          borderRadius: BorderRadius.all(Radius.circular(_nowLineHeight / 2)),
        ),
      ),
    );
  }

  Widget _buildRow(_Cluster row)
  {
    final scale = _scaleOf(row);
    final lanes = assignSubLanes([for (final entry in row.entries) (entry.startMinutes, entry.endMinutes)]);

    final now = nowMinutes;
    final clockInRow = now != null && now >= row.startMinutes && now < row.endMinutes;

    return SizedBox(
      height: _heightOf(row),
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final width = (constraints.maxWidth - (lanes.laneCount - 1) * _columnGap) / lanes.laneCount;

          double leftOf(int index) => lanes.laneOf[index] * (width + _columnGap);

          var lineLeft = double.infinity;
          var lineRight = double.negativeInfinity;

          if (clockInRow)
          {
            for (var index = 0; index < row.entries.length; index++)
            {
              final entry = row.entries[index];

              if (now >= entry.startMinutes && now < entry.endMinutes)
              {
                lineLeft = math.min(lineLeft, leftOf(index));
                lineRight = math.max(lineRight, leftOf(index) + width);
              }
            }
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < row.entries.length; index++)
                Positioned(
                  left: leftOf(index),
                  width: width,
                  top: (row.entries[index].startMinutes - row.startMinutes) * scale,
                  height: (row.entries[index].endMinutes - row.entries[index].startMinutes) * scale,
                  child: row.entries[index].block,
                ),
              if (clockInRow && lineLeft < lineRight)
                Positioned(
                  left: lineLeft - _nowLineBleed,
                  width: lineRight - lineLeft + 2 * _nowLineBleed,
                  top: (now - row.startMinutes) * scale - _nowLineHeight / 2,
                  height: _nowLineHeight,
                  child: _buildNowLine(),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final rows = _clusters;

    if (rows.isEmpty)
    {
      return const CalendarLaneEmpty();
    }

    final gapTop = _gapLineTop(rows);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const SizedBox(height: _rowGap),
              _buildRow(rows[index]),
            ],
          ],
        ),
        if (gapTop != null)
          Positioned(
            left: -_nowLineBleed,
            right: -_nowLineBleed,
            top: gapTop - _nowLineHeight / 2,
            height: _nowLineHeight,
            child: _buildNowLine(),
          ),
      ],
    );
  }
}
