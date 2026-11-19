import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/theme_colours.dart';
import '../../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../../shared/widgets/page_density.dart';
import 'chart_common.dart';
import 'chart_value_popup.dart';
import 'stat_widgets.dart';

LinearGradient get _barGradient => AppTheme.chartBarGradient;

// The hovered column lights up behind its bar, as in the accounting charts.
Color get _hoverColumnColor => ThemeColours.of(0x0F4077B3);
const double _hoverColumnRadius = 8;

// The column holding what does not fit, in the charts' grey for "other".
LinearGradient get _othersGradient => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppTheme.chartGrayLight, AppTheme.chartGray],
);

// The popup's lift, arrow and padding above a bar's top.
const double _popupChrome = 31;

const double _othersColumnGap = 18;

const double _yAxisWidth = 45.0;

// Shared by the widget and the painter: if they disagree, bars and labels drift.
const double _plotBottomPadding = 52.0;

// Below this slot width names break mid-word: the last column takes the rest, or the bars are laid across.
const double _minBarSlotWidth = 95.0;

const double _barWidthRatio = 0.6;
const double _labelFontSize = 13;

const double _labelGap = 10;

// Bars laid across: the names' column, and the room between rows.
const double _acrossNamesShare = 0.4;
const double _acrossNamesMax = 200;
const double _acrossRowGap = 10;
const double _acrossBarHeight = 14;

// Bars laid across in two halves: each half's names column.
const double _splitNamesShare = 0.55;
const double _splitNamesMax = 400;

// Round a hovered row, inside the room between rows.
const double _acrossHoverInset = 3;

int _maxValueOf(List<ChartDatum> data) => chartMaxValue(data.map((item) => item.count).reduce(math.max));

// In order, into [count] runs whose lengths differ by one at most: the last is never a lone name.
List<List<T>> _balanced<T>(List<T> items, int count)
{
  final int base = items.length ~/ count;
  final int extra = items.length % count;
  final List<List<T>> runs = [];
  var start = 0;

  for (var i = 0; i < count; i++)
  {
    final int length = base + (i < extra ? 1 : 0);

    runs.add(items.sublist(start, start + length));
    start += length;
  }

  return runs;
}

class BarChart extends StatefulWidget
{
  final List<ChartDatum> data;

  // Names the last column, which holds the bars that do not fit upright; without it they are laid across.
  final String Function(int count)? othersLabel;

  // Names too long for an upright column: always laid across, in two halves in a wide window.
  final bool longNames;

  const BarChart({super.key, required this.data, this.othersLabel, this.longNames = false});

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart>
{
  int? _hoveredIndex;

  // Survives pointer exit, so the popup fades out in place.
  int? _popupIndex;

  int get _total => widget.data.fold(0, (sum, item) => sum + item.count);

  @override
  void didUpdateWidget(covariant BarChart oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data)
    {
      _hoveredIndex = null;
      _popupIndex = null;
    }
  }

  // The first columns, then one holding the rest; the data comes most numerous first.
  List<ChartDatum> _columns(int fitting)
  {
    if (widget.data.length <= fitting)
    {
      return widget.data;
    }

    final List<ChartDatum> rest = widget.data.sublist(fitting - 1);

    return [
      ...widget.data.take(fitting - 1),
      ChartDatum(label: widget.othersLabel!(rest.length), count: rest.fold(0, (sum, item) => sum + item.count)),
    ];
  }

  List<Rect> _computeBarRects(List<ChartDatum> columns, double innerWidth, double chartHeight, int maxValue)
  {
    final stepX = innerWidth / columns.length;
    final barWidth = stepX * _barWidthRatio;

    return [
      for (var i = 0; i < columns.length; i++)
        () {
          final barHeight = (columns[i].count / maxValue) * chartHeight;
          final left = (i * stepX) + (stepX / 2) - (barWidth / 2);

          return Rect.fromLTWH(left, chartHeight - barHeight, barWidth, barHeight);
        }(),
    ];
  }

  // The whole column hit-tests, label included, so moving across bars never drops the popup.
  void _hoverAt(Offset position, double innerWidth, int columns)
  {
    final slot = (position.dx / (innerWidth / columns)).floor();

    _hoverSlot(slot >= 0 && slot < columns ? slot : null);
  }

  void _hoverSlot(int? index)
  {
    if (index == _hoveredIndex)
    {
      return;
    }

    setState(()
    {
      _hoveredIndex = index;

      if (index != null)
      {
        _popupIndex = index;
      }
    });
  }

  String _popupText(ChartDatum datum)
  {
    final share = _total == 0 ? 0.0 : datum.count / _total * 100;

    return '${datum.label}: ${datum.count} (${share.toStringAsFixed(1)}%)';
  }

  // One name per line, in more columns once a single one would rise out of the chart, but never
  // wider than the chart: what still does not fit above the bar moves its arrow down the column.
  Widget _othersPopup(List<ChartDatum> rest, Rect bar, double width, double height)
  {
    final TextStyle style = AppTheme.tooltipTextStyle;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final List<String> lines = [for (final datum in rest) '${datum.label}: ${datum.count}'];
    final List<double> widths = [];
    double lineHeight = 0;

    for (final String line in lines)
    {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: line, style: style),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout();

      widths.add(painter.width);
      lineHeight = painter.height;
      painter.dispose();
    }

    final double maxWidth = ChartValuePopup.maxContentWidth(width);
    final int fitting = math.max(3, ((bar.top - _popupChrome) / lineHeight).floor());
    var count = (lines.length / fitting).ceil();

    double widthOf(List<List<double>> columns)
    {
      final double names = columns.fold(0, (sum, column) => sum + column.reduce(math.max).ceilToDouble());

      return names + _othersColumnGap * (columns.length - 1);
    }

    while (count > 1 && widthOf(_balanced(widths, count)) > maxWidth)
    {
      count--;
    }

    final List<List<String>> columns = _balanced(lines, count);
    final double contentHeight = columns.first.length * lineHeight;

    return ChartValuePopup(
      target: Offset(
        _yAxisWidth + bar.center.dx,
        math.max(bar.top, math.min(contentHeight + _popupChrome, height)),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columns.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : _othersColumnGap),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final line in columns[i]) Text(line, style: style)],
                ),
              ),
            ),
        ],
      ),
      isVisible: _hoveredIndex != null,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double innerWidth = constraints.maxWidth - _yAxisWidth;
        final int fitting = (innerWidth / _minBarSlotWidth).floor();

        // Nothing scrolls sideways; dense windows fit too few columns for an «others» one to say much.
        if (widget.longNames ||
            (widget.data.length > fitting && (dense || widget.othersLabel == null || fitting < 2)))
        {
          return _BarsAcross(
            data: widget.data,
            maxValue: _maxValueOf(widget.data),
            split: widget.longNames && !dense && widget.data.length > 1,
          );
        }

        final List<ChartDatum> columns = _columns(fitting);
        final int? othersIndex = columns.length < widget.data.length ? columns.length - 1 : null;
        final int maxValue = _maxValueOf(columns);

        // A card that lets the chart size itself gives its height as a minimum.
        final double height = constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight;
        final chartHeight = height - _plotBottomPadding;
        final barRects = _computeBarRects(columns, innerWidth, chartHeight, maxValue);
        final popupIndex = _popupIndex;
        final bool popupOnOthers = othersIndex != null && popupIndex == othersIndex;

        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: _yAxisWidth,
                    child: CustomPaint(
                      size: Size(_yAxisWidth, height),
                      painter: _YAxisPainter(maxValue: maxValue),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: height,
                      child: MouseRegion(
                        onHover: (event) => _hoverAt(event.localPosition, innerWidth, columns.length),
                        onExit: (_) => _hoverSlot(null),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _BarChartPainter(
                            data: columns,
                            barRects: barRects,
                            hoveredIndex: _hoveredIndex,
                            othersIndex: othersIndex,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (popupIndex != null && popupIndex < barRects.length)
                popupOnOthers
                    ? _othersPopup(widget.data.sublist(othersIndex), barRects[popupIndex], constraints.maxWidth, height)
                    : ChartValuePopup(
                        target: Offset(
                          _yAxisWidth + barRects[popupIndex].center.dx,
                          barRects[popupIndex].top,
                        ),
                        text: _popupText(columns[popupIndex]),
                        isVisible: _hoveredIndex != null,
                      ),
            ],
          ),
        );
      },
    );
  }
}

// One row per bar, the name on the left and the count at the end: nothing scrolls, a cut name shows whole on hover.
class _BarsAcross extends StatefulWidget
{
  final List<ChartDatum> data;
  final int maxValue;

  // Two halves side by side on one scale, the first one longer by one at most.
  final bool split;

  const _BarsAcross({required this.data, required this.maxValue, this.split = false});

  @override
  State<_BarsAcross> createState() => _BarsAcrossState();
}

class _BarsAcrossState extends State<_BarsAcross>
{
  int? _hoveredIndex;

  Widget _row(int index, double namesWidth, {required bool last})
  {
    final ChartDatum datum = widget.data[index];
    final bool hovered = index == _hoveredIndex;
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: 12.5,
      fontWeight: hovered ? FontWeight.w700 : FontWeight.w600,
      color: hovered ? AppTheme.trialOceanText : AppTheme.trialInk,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = _hoveredIndex == index ? null : _hoveredIndex),
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : _acrossRowGap - 2 * _acrossHoverInset),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: _acrossHoverInset),
          decoration: BoxDecoration(
            color: hovered ? _hoverColumnColor : null,
            borderRadius: BorderRadius.circular(_hoverColumnRadius),
          ),
          child: Row(
            children: [
              SizedBox(
                width: namesWidth,
                child: OverflowTooltipText(text: datum.label, maxLines: 2, style: style),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AcrossBar(fraction: widget.maxValue == 0 ? 0 : datum.count / widget.maxValue),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24),
                child: Text(
                  '${datum.count}',
                  textAlign: TextAlign.right,
                  style: style.copyWith(fontWeight: FontWeight.w700, color: AppTheme.trialOceanText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    Widget rows(int start, int end, double namesWidth)
    {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = start; i < end; i++) _row(i, namesWidth, last: i == end - 1),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final int count = widget.data.length;

        if (!widget.split)
        {
          return rows(0, count, math.min(constraints.maxWidth * _acrossNamesShare, _acrossNamesMax));
        }

        final double namesWidth = math.min(constraints.maxWidth / 2 * _splitNamesShare, _splitNamesMax);
        final int half = (count + 1) ~/ 2;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Align(alignment: Alignment.topCenter, child: rows(0, half, namesWidth))),
              const StatColumnDivider(),
              Expanded(child: Align(alignment: Alignment.topCenter, child: rows(half, count, namesWidth))),
            ],
          ),
        );
      },
    );
  }
}

class _AcrossBar extends StatelessWidget
{
  final double fraction;

  const _AcrossBar({required this.fraction});

  @override
  Widget build(BuildContext context)
  {
    final BorderRadius radius = BorderRadius.circular(_acrossBarHeight / 2);

    return Container(
      height: _acrossBarHeight,
      decoration: BoxDecoration(color: AppTheme.slate200.withValues(alpha: 0.6), borderRadius: radius),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0, 1),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(colors: [AppTheme.chartNavy, AppTheme.chartViolet]),
          ),
        ),
      ),
    );
  }
}

class _YAxisPainter extends CustomPainter
{
  final int maxValue;

  _YAxisPainter({required this.maxValue});

  @override
  void paint(Canvas canvas, Size size)
  {
    final gridPaint = Paint()
      ..color = AppTheme.trialLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final chartHeight = size.height - _plotBottomPadding;

    for (var i = 0; i <= gridDivisions; i++)
    {
      final y = chartHeight - (i * (chartHeight / gridDivisions));
      canvas.drawLine(Offset(size.width - 5, y), Offset(size.width, y), gridPaint);

      textPainter.text = TextSpan(
        text: '${((maxValue / gridDivisions) * i).round()}',
        style: GoogleFonts.plusJakartaSans(color: AppTheme.trialMutedText, fontSize: _labelFontSize),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 12, y - 6));
    }

    textPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _YAxisPainter oldDelegate) => oldDelegate.maxValue != maxValue;
}

class _BarChartPainter extends CustomPainter
{
  final List<ChartDatum> data;
  final List<Rect> barRects;
  final int? hoveredIndex;
  final int? othersIndex;

  _BarChartPainter({
    required this.data,
    required this.barRects,
    required this.hoveredIndex,
    required this.othersIndex,
  });

  @override
  void paint(Canvas canvas, Size size)
  {
    final slotWidth = size.width / data.length;
    final chartHeight = size.height - _plotBottomPadding;

    final gridPaint = Paint()
      ..color = AppTheme.trialLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= gridDivisions; i++)
    {
      final y = chartHeight - (i * (chartHeight / gridDivisions));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final int? lit = hoveredIndex;

    if (lit != null && lit < barRects.length)
    {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(lit * slotWidth, 0, (lit + 1) * slotWidth, chartHeight),
          const Radius.circular(_hoverColumnRadius),
        ),
        Paint()..color = _hoverColumnColor,
      );
    }

    for (var i = 0; i < barRects.length; i++)
    {
      final bool hovered = i == hoveredIndex;
      final bool others = i == othersIndex;

      final Rect rect = barRects[i];
      final RRect bar = RRect.fromRectAndRadius(rect, const Radius.circular(8));

      // Per bar: a shader spans the rect it fills; a plot-wide one gives each bar a ramp slice.
      canvas.drawRRect(bar, Paint()..shader = (others ? _othersGradient : _barGradient).createShader(rect));

      textPainter.text = TextSpan(
        text: data[i].label,
        style: GoogleFonts.plusJakartaSans(
          color: hovered ? AppTheme.trialOceanText : AppTheme.trialMutedText,
          fontSize: _labelFontSize,
          fontWeight: hovered ? FontWeight.w700 : FontWeight.w600,
        ),
      );
      textPainter.textAlign = TextAlign.center;
      // Two lines: long city and school names do not fit one slot.
      textPainter.maxLines = 2;
      textPainter.ellipsis = '...';
      textPainter.layout(maxWidth: slotWidth - _labelGap);
      textPainter.paint(
        canvas,
        Offset(barRects[i].center.dx - (textPainter.width / 2), chartHeight + 12),
      );
    }

    textPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate)
  {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.othersIndex != othersIndex ||
        oldDelegate.data != data ||
        oldDelegate.barRects != barRects;
  }
}
