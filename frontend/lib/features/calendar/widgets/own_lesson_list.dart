import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../lessons/utils/timeline_geometry.dart';
import '../../lessons/widgets/calendar_lane_panel.dart' show CalendarLaneEmpty;
import '../../lessons/widgets/calendar_lesson_block.dart' show ElapsedShare;
import 'own_day_timeline.dart' show TimelineEntry;
import 'own_lesson_block.dart' show OwnListRows, kDenseOwnRowHeight;

const double _rowGap = 10;
const double _denseRowGap = 8;
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

  // Overlap chains: 15-16, 15:30-16:30 and 16-17 make one row of three.
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

  static ({List<int> laneOf, int laneCount}) _lanesOf(_Cluster row)
  {
    return assignSubLanes([for (final entry in row.entries) (entry.startMinutes, entry.endMinutes)]);
  }

  // Each card's width in a row [width] wide.
  static double _cardWidthIn(_Cluster row, double width)
  {
    final count = _lanesOf(row).laneCount;

    return (width - (count - 1) * _columnGap) / count;
  }

  // Pixels per minute: the shortest card keeps its full height, any card the height its lines need.
  // Rows below the wide window are all as tall: a lesson alone in its row takes exactly that.
  static double _scaleOf(_Cluster row, double width, bool dense)
  {
    final cardWidth = _cardWidthIn(row, width);

    return row.entries
        .map((entry) => (dense ? kDenseOwnRowHeight : entry.heightAt(cardWidth)) / math.max(1, entry.endMinutes - entry.startMinutes))
        .reduce(math.max);
  }

  static double _heightOf(_Cluster row, double width, bool dense) =>
      (row.endMinutes - row.startMinutes) * _scaleOf(row, width, dense);

  // Only between rows: a lesson under way is framed, not crossed.
  double? _gapLineTop(List<_Cluster> rows, double width, bool dense)
  {
    final double gap = dense ? _denseRowGap : _rowGap;

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
        return top - gap / 2;
      }

      if (now < row.endMinutes)
      {
        return null;
      }

      top += _heightOf(row, width, dense) + gap;
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

  Widget _blockOf(TimelineEntry entry)
  {
    final now = nowMinutes;

    if (now == null || now < entry.startMinutes || now >= entry.endMinutes)
    {
      return entry.block;
    }

    return ElapsedShare(share: (now - entry.startMinutes) / (entry.endMinutes - entry.startMinutes), child: entry.block);
  }

  Widget _buildRow(_Cluster row, double rowWidth, bool dense)
  {
    final scale = _scaleOf(row, rowWidth, dense);
    final lanes = _lanesOf(row);
    final width = _cardWidthIn(row, rowWidth);

    return SizedBox(
      height: _heightOf(row, rowWidth, dense),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < row.entries.length; index++)
            Positioned(
              left: lanes.laneOf[index] * (width + _columnGap),
              width: width,
              top: (row.entries[index].startMinutes - row.startMinutes) * scale,
              height: (row.entries[index].endMinutes - row.entries[index].startMinutes) * scale,
              child: _blockOf(row.entries[index]),
            ),
        ],
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

    final bool dense = AppBreakpoints.of(context).isDense;
    final Widget list = LayoutBuilder(
      builder: (context, constraints) => _buildRows(rows, constraints.maxWidth, dense),
    );

    return dense ? OwnListRows(child: list) : list;
  }

  Widget _buildRows(List<_Cluster> rows, double width, bool dense)
  {
    final gapTop = _gapLineTop(rows, width, dense);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) SizedBox(height: dense ? _denseRowGap : _rowGap),
              _buildRow(rows[index], width, dense),
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
