import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import 'chart_common.dart';
import 'chart_value_popup.dart';

const double _padLeft = 44;
const double _padRight = 20;
const double _padTop = 8;
const double _padBottom = 38;

const double _labelGap = 8;

// Below this spacing the points lose their markers and only the line is drawn.
const double _markerSpacing = 14;

TextStyle get _axisStyle => GoogleFonts.plusJakartaSans(color: AppTheme.trialMutedText, fontSize: 13);

class TrendSeries
{
  final String label;
  final Color color;

  // In the axis' own unit.
  final List<double> values;

  // The line takes the chart gradient; [color] still fills the area under it.
  final bool gradient;

  const TrendSeries({required this.label, required this.color, required this.values, this.gradient = false});
}

// Where each index and value lands; shared by the painters and the hit testing.
class _Frame
{
  final Size size;
  final int count;
  final int maxValue;

  const _Frame(this.size, this.count, this.maxValue);

  double get plotWidth => size.width - _padLeft - _padRight;

  double get plotHeight => size.height - _padTop - _padBottom;

  double get bottom => _padTop + plotHeight;

  double get stepX => count > 1 ? plotWidth / (count - 1) : plotWidth;

  double xOf(int index) => count > 1 ? _padLeft + index * stepX : _padLeft + plotWidth / 2;

  double yOf(double value) => bottom - value / maxValue * plotHeight;

  Color colorOf(TrendSeries line, double x)
  {
    return line.gradient ? chartLineColorAt((x - _padLeft) / plotWidth) : line.color;
  }

  int indexAt(double x)
  {
    if (count < 2)
    {
      return 0;
    }

    return ((x - _padLeft) / stepX).round().clamp(0, count - 1);
  }

  @override
  bool operator ==(Object other) =>
      other is _Frame && other.size == size && other.count == count && other.maxValue == maxValue;

  @override
  int get hashCode => Object.hash(size, count, maxValue);
}

// The pointer picks the nearest day on the X axis; [hovered] keeps charts of one card in step.
class DailyTrendChart extends StatefulWidget
{
  final List<String> axisLabels;
  final List<TrendSeries> series;
  final String Function(int value) formatAxis;
  final ValueNotifier<int?> hovered;
  final Widget Function(int index) tooltip;

  // A soft area under the line, for a chart with one series.
  final bool filled;

  const DailyTrendChart({
    super.key,
    required this.axisLabels,
    required this.series,
    required this.formatAxis,
    required this.hovered,
    required this.tooltip,
    this.filled = false,
  });

  @override
  State<DailyTrendChart> createState() => _DailyTrendChartState();
}

class _DailyTrendChartState extends State<DailyTrendChart>
{
  bool _inside = false;

  // Survives the pointer leaving, so the popup fades out in place.
  int? _popupIndex;

  int get _count => widget.axisLabels.length;

  int get _maxValue
  {
    var highest = 0.0;

    for (final series in widget.series)
    {
      for (final value in series.values)
      {
        highest = math.max(highest, value);
      }
    }

    return chartMaxValue(highest.ceil());
  }

  @override
  void initState()
  {
    super.initState();
    widget.hovered.addListener(_onHoveredChanged);
  }

  @override
  void didUpdateWidget(DailyTrendChart oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.hovered != widget.hovered)
    {
      oldWidget.hovered.removeListener(_onHoveredChanged);
      widget.hovered.addListener(_onHoveredChanged);
    }

    if (oldWidget.axisLabels.length != _count)
    {
      _popupIndex = null;
    }
  }

  @override
  void dispose()
  {
    widget.hovered.removeListener(_onHoveredChanged);
    super.dispose();
  }

  void _onHoveredChanged()
  {
    final index = widget.hovered.value;

    setState(()
    {
      if (index != null && _inside)
      {
        _popupIndex = index;
      }
    });
  }

  void _hover(Offset position, _Frame frame)
  {
    if (_count == 0)
    {
      return;
    }

    final index = frame.indexAt(position.dx);

    if (!_inside || _popupIndex != index)
    {
      setState(()
      {
        _inside = true;
        _popupIndex = index;
      });
    }

    widget.hovered.value = index;
  }

  void _leave()
  {
    setState(() => _inside = false);
    widget.hovered.value = null;
  }

  double _topOf(int index, _Frame frame)
  {
    var top = frame.bottom;

    for (final series in widget.series)
    {
      top = math.min(top, frame.yOf(series.values[index]));
    }

    return top;
  }

  @override
  Widget build(BuildContext context)
  {
    final maxValue = _maxValue;
    final hovered = widget.hovered.value;
    final popupIndex = _popupIndex;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final frame = _Frame(constraints.biggest, _count, maxValue);

        return MouseRegion(
          onHover: (event) => _hover(event.localPosition, frame),
          onExit: (_) => _leave(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  foregroundPainter: _HoverPainter(frame: frame, series: widget.series, index: hovered),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _TrendPainter(
                        frame: frame,
                        series: widget.series,
                        axisLabels: widget.axisLabels,
                        formatAxis: widget.formatAxis,
                        filled: widget.filled,
                      ),
                    ),
                  ),
                ),
              ),
              if (popupIndex != null && popupIndex < _count)
                ChartValuePopup(
                  target: Offset(frame.xOf(popupIndex), _topOf(popupIndex, frame)),
                  content: widget.tooltip(popupIndex),
                  isVisible: _inside && hovered != null,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrendPainter extends CustomPainter
{
  final _Frame frame;
  final List<TrendSeries> series;
  final List<String> axisLabels;
  final String Function(int value) formatAxis;
  final bool filled;

  _TrendPainter({
    required this.frame,
    required this.series,
    required this.axisLabels,
    required this.formatAxis,
    required this.filled,
  });

  void _paintGrid(Canvas canvas)
  {
    final gridPaint = Paint()
      ..color = AppTheme.trialLine
      ..strokeWidth = 1;

    for (var step = 0; step <= gridDivisions; step++)
    {
      final value = frame.maxValue * step ~/ gridDivisions;
      final y = frame.bottom - step * frame.plotHeight / gridDivisions;

      canvas.drawLine(Offset(_padLeft, y), Offset(frame.size.width, y), gridPaint);

      final label = TextPainter(
        text: TextSpan(text: formatAxis(value), style: _axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      label.paint(canvas, Offset(_padLeft - label.width - _labelGap, y - label.height / 2));
      label.dispose();
    }
  }

  // Every stride-th label, plus the last one; a stride label crowding the last is dropped.
  Set<int> _labelledIndices(List<TextPainter> labels)
  {
    final count = labels.length;

    if (count <= 1)
    {
      return {0};
    }

    final widest = labels.map((label) => label.width).reduce(math.max) + _labelGap;
    final stride = widest > frame.stepX ? (widest / frame.stepX).ceil() : 1;
    final indices = [for (var index = 0; index < count; index += stride) index];
    final last = count - 1;

    if (indices.last != last)
    {
      if ((last - indices.last) * frame.stepX < widest)
      {
        indices.removeLast();
      }

      indices.add(last);
    }

    return indices.toSet();
  }

  void _paintAxisLabels(Canvas canvas)
  {
    final labels = [
      for (final text in axisLabels)
        TextPainter(
          text: TextSpan(text: text, style: _axisStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(),
    ];

    for (final index in _labelledIndices(labels))
    {
      final label = labels[index];
      label.paint(canvas, Offset(frame.xOf(index) - label.width / 2, frame.bottom + _labelGap));
    }

    for (final label in labels)
    {
      label.dispose();
    }
  }

  Path _linePath(TrendSeries line)
  {
    final path = Path()..moveTo(frame.xOf(0), frame.yOf(line.values[0]));

    for (var index = 1; index < line.values.length; index++)
    {
      path.lineTo(frame.xOf(index), frame.yOf(line.values[index]));
    }

    return path;
  }

  void _paintArea(Canvas canvas, Path line, Color color)
  {
    final area = Path.from(line)
      ..lineTo(frame.xOf(frame.count - 1), frame.bottom)
      ..lineTo(frame.xOf(0), frame.bottom)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(_padLeft, _padTop, frame.plotWidth, frame.plotHeight)),
    );
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    _paintGrid(canvas);

    if (frame.count == 0)
    {
      return;
    }

    _paintAxisLabels(canvas);

    final withMarkers = frame.count == 1 || frame.stepX >= _markerSpacing;

    for (final line in series)
    {
      final path = _linePath(line);

      if (filled && frame.count > 1)
      {
        _paintArea(canvas, path, line.color);
      }

      final stroke = Paint()
        ..color = line.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (line.gradient)
      {
        stroke.shader = AppTheme.chartLineGradient.createShader(
          Rect.fromLTWH(_padLeft, _padTop, frame.plotWidth, frame.plotHeight),
        );
      }

      canvas.drawPath(path, stroke);

      if (!withMarkers)
      {
        continue;
      }

      for (var index = 0; index < frame.count; index++)
      {
        final point = Offset(frame.xOf(index), frame.yOf(line.values[index]));
        canvas.drawCircle(point, 5, Paint()..color = Colors.white);
        canvas.drawCircle(point, 4, Paint()..color = frame.colorOf(line, point.dx));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate)
  {
    return oldDelegate.frame != frame ||
        oldDelegate.series != series ||
        oldDelegate.axisLabels != axisLabels ||
        oldDelegate.filled != filled;
  }
}

class _HoverPainter extends CustomPainter
{
  final _Frame frame;
  final List<TrendSeries> series;
  final int? index;

  _HoverPainter({required this.frame, required this.series, required this.index});

  @override
  void paint(Canvas canvas, Size size)
  {
    final index = this.index;

    if (index == null || index >= frame.count)
    {
      return;
    }

    final x = frame.xOf(index);

    canvas.drawLine(
      Offset(x, _padTop),
      Offset(x, frame.bottom),
      Paint()
        ..color = AppTheme.trialMutedText.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );

    for (final line in series)
    {
      final point = Offset(x, frame.yOf(line.values[index]));
      canvas.drawCircle(point, 7, Paint()..color = Colors.white);
      canvas.drawCircle(point, 5, Paint()..color = frame.colorOf(line, x));
    }
  }

  @override
  bool shouldRepaint(covariant _HoverPainter oldDelegate)
  {
    return oldDelegate.index != index || oldDelegate.frame != frame || oldDelegate.series != series;
  }
}

// A short stroke of the series colour: the legend names lines with lines.
class TrendLineKey extends StatelessWidget
{
  final Color color;

  const TrendLineKey({super.key, required this.color});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: 16,
      height: 3,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

class TrendLegend extends StatelessWidget
{
  final List<TrendSeries> series;

  const TrendLegend({super.key, required this.series});

  @override
  Widget build(BuildContext context)
  {
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        for (final line in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrendLineKey(color: line.color),
              const SizedBox(width: 8),
              Text(
                line.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

typedef TrendTooltipRow = ({String value, String label});

class TrendTooltip extends StatelessWidget
{
  final String title;
  final String? subtitle;
  final List<TrendTooltipRow> rows;

  const TrendTooltip({super.key, required this.title, this.subtitle, required this.rows});

  @override
  Widget build(BuildContext context)
  {
    final base = AppTheme.tooltipTextStyle;
    final muted = base.copyWith(color: Colors.white.withValues(alpha: 0.72), fontWeight: FontWeight.w500);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: base.copyWith(fontWeight: FontWeight.w700)),
        if (subtitle != null) Text(subtitle!, style: muted.copyWith(fontSize: 12)),
        const SizedBox(height: 6),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(row.value, style: base.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Text(row.label, style: muted),
              ],
            ),
          ),
      ],
    );
  }
}
