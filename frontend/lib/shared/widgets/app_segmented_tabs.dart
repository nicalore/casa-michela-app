import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Duration kSegmentedSlide = Duration(milliseconds: 240);
const Curve kSegmentedSlideCurve = Curves.easeOutCubic;

const double _padding = 3;
const double _segmentPadding = 18;

const double _borderWidth = 1.5;

const double _rowGap = 3;

class AppSegmentedTabs extends StatefulWidget
{
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  final double height;

  final double fontSize;

  final EdgeInsets padding;

  final bool hugContent;

  const AppSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 44,
    this.fontSize = 14,
    this.padding = const EdgeInsets.only(bottom: 24),
    this.hugContent = false,
  });

  @override
  State<AppSegmentedTabs> createState() => _AppSegmentedTabsState();
}

class _AppSegmentedTabsState extends State<AppSegmentedTabs>
{
  List<double> _widths = const [];

  bool _hover = false;

  @override
  void initState()
  {
    super.initState();

    // Fonts load after the first frame; a listener re-measures when they arrive.
    PaintingBinding.instance.systemFonts.addListener(_measureAll);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _measureAll();
  }

  @override
  void didUpdateWidget(AppSegmentedTabs oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.labels, widget.labels) ||
        oldWidget.labels.length != widget.labels.length ||
        oldWidget.fontSize != widget.fontSize)
    {
      _measureAll();
    }

  }

  @override
  void dispose()
  {
    PaintingBinding.instance.systemFonts.removeListener(_measureAll);
    super.dispose();
  }

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w700,
      );

  void _measureAll()
  {
    if (!mounted)
    {
      return;
    }

    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;

    final measured = [
      for (final label in widget.labels) _measure(label, scaler),
    ];

    if (measured.length == _widths.length)
    {
      var same = true;

      for (var index = 0; index < measured.length; index++)
      {
        if ((measured[index] - _widths[index]).abs() > 0.5)
        {
          same = false;
          break;
        }
      }

      if (same)
      {
        return;
      }
    }

    setState(() => _widths = measured);
  }

  double _measure(String label, TextScaler scaler)
  {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();

    return painter.width + 2 * _segmentPadding;
  }

  List<List<int>> _pack(List<double> widths, double available)
  {
    final rows = <List<int>>[];
    var row = <int>[];
    var used = 0.0;

    for (var index = 0; index < widths.length; index++)
    {
      if (row.isNotEmpty && used + widths[index] > available)
      {
        rows.add(row);
        row = <int>[];
        used = 0;
      }

      row.add(index);
      used += widths[index];
    }

    if (row.isNotEmpty)
    {
      rows.add(row);
    }

    return rows;
  }

  Widget _buildSegment(int index, double width)
  {
    final active = index == widget.selectedIndex;

    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelected(index),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: kSegmentedSlide,
            curve: kSegmentedSlideCurve,
            style: _labelStyle.copyWith(
              color: active ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
            ),
            child: Text(
              widget.labels[index],
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill(List<List<int>> rows, List<double> widths, double rowHeight)
  {
    final index = widget.selectedIndex.clamp(0, widths.length - 1);

    var left = 0.0;
    var top = 0.0;

    for (var r = 0; r < rows.length; r++)
    {
      final int at = rows[r].indexOf(index);

      if (at < 0)
      {
        continue;
      }

      top = r * (rowHeight + _rowGap);
      left = 0;

      for (var i = 0; i < at; i++)
      {
        left += widths[rows[r][i]];
      }

      break;
    }

    return AnimatedPositioned(
      duration: kSegmentedSlide,
      curve: kSegmentedSlideCurve,
      left: left,
      top: top,
      width: widths[index],
      height: rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(rowHeight / 2),
          boxShadow: AppTheme.cardShadow,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (_widths.length != widget.labels.length)
    {
      return Padding(
        padding: widget.padding,
        child: SizedBox(height: widget.height),
      );
    }

    final double oneRow = _widths.fold<double>(0, (sum, width) => sum + width) +
        2 * (_padding + _borderWidth);

    final Widget control = LayoutBuilder(
        builder: (context, constraints)
        {
          final double available =
              constraints.maxWidth - 2 * (_padding + _borderWidth);

          final List<double> widths = [
            for (final width in _widths) math.min(width, available),
          ];

          final List<List<int>> rows = _pack(widths, available);

          final double rowHeight = widget.height - 2 * (_padding + _borderWidth);
          final double ground = rows
              .map((row) => row.fold<double>(0, (sum, i) => sum + widths[i]))
              .reduce(math.max);

          return Align(
            alignment: Alignment.centerLeft,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: AnimatedContainer(
                duration: kSegmentedSlide,
                curve: kSegmentedSlideCurve,
                padding: const EdgeInsets.all(_padding),
                decoration: BoxDecoration(
                  color: AppTheme.closedSurface,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  border: Border.all(
                    color: _hover
                        ? AppTheme.trialGold
                        : AppTheme.trialGold.withValues(alpha: 0),
                    width: _borderWidth,
                  ),
                ),
                child: SizedBox(
                  width: ground,
                  height: rows.length * rowHeight + (rows.length - 1) * _rowGap,
                  child: Stack(
                    children: [
                      _buildPill(rows, widths, rowHeight),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var r = 0; r < rows.length; r++) ...[
                            if (r > 0) const SizedBox(height: _rowGap),
                            SizedBox(
                              height: rowHeight,
                              child: Row(
                                children: [
                                  for (final index in rows[r])
                                    _buildSegment(index, widths[index]),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

    return Padding(
      padding: widget.padding,
      child: widget.hugContent
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: oneRow),
              child: control,
            )
          : control,
    );
  }
}
