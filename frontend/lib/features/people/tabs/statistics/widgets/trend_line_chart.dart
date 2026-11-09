import 'dart:math' as math;
import 'dart:ui' show ClipOp;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../models/member_trend_item.dart';
import 'chart_common.dart';
import 'chart_value_popup.dart';
import 'stats_constants.dart';
import 'trend_band.dart';

// Shared by the hit testing and the painter: if they drift, hover targets leave the points.
const double _chartPaddingLeft = 40.0;
const double _chartPaddingBottom = 30.0;

// Past the plot: short of the scale on the left, round the last month's label on the right.
const double _bandOverhangLeft = 7;
const double _bandOverhangRight = 18;
const double _bandAbove = 8;

// Down past the two lines of a month's label.
const double _bandBelow = 45;
const double _bandRadius = 12;
const double _bandAlpha = 0.1;

const double _labelFontSize = 13;
const double _labelGap = 8;

// Bars as the statistics bar chart draws them.
const double _barWidthRatio = 0.6;
const double _barRadius = 8;

// The highlight rises inside the bar: a lerp between two hues passes through a dull mix.
const Duration _hoverFill = Duration(milliseconds: 200);

TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
      color: AppTheme.trialMutedText,
      fontSize: _labelFontSize,
    );

// Room for the scale of charts stacked in one card, so their plots line up.
double trendChartPadding(List<({List<MemberTrendItem> data, TrendScale scale})> charts)
{
  final TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
  double widest = 0;

  for (final chart in charts)
  {
    if (chart.data.isEmpty)
    {
      continue;
    }

    final int top = chart.scale.top(chart.data.map((item) => item.totalMembers).reduce(math.max));

    painter.text = TextSpan(text: chart.scale.axis(top), style: _labelStyle);
    painter.layout();
    widest = math.max(widest, painter.width);
  }

  painter.dispose();

  return math.max(_chartPaddingLeft, (widest + _labelGap).ceilToDouble());
}

// Shared by the hit testing and the painter: points span the plot, bars stand mid-slot.
class _Columns
{
  final double left;
  final double width;
  final int count;
  final bool bars;

  const _Columns({required this.left, required this.width, required this.count, required this.bars});

  double get step => bars ? width / count : (count > 1 ? width / (count - 1) : width / 2);

  double xOf(double index) => left + (bars ? index + 0.5 : index) * step;
}

class TrendLineChart extends StatefulWidget
{
  final List<MemberTrendItem> data;
  final bool isMonthly;

  // The months of the chosen period; null marks none.
  final TrendSpan? span;

  final TrendScale scale;

  // Months as bars, for sums such as pay.
  final bool bars;

  // Room for the scale; charts stacked in one card pass the same.
  final double? leftPadding;

  const TrendLineChart({
    required this.data,
    required this.isMonthly,
    this.span,
    this.scale = TrendScale.count,
    this.bars = false,
    this.leftPadding,
    super.key,
  });

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> with SingleTickerProviderStateMixin
{
  static const double _hoverRadius = 16.0;

  final ChartFillLevels _fills = ChartFillLevels();

  // Runs only while some bar is still filling or draining.
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;

  int? _hoveredIndex;
  Offset? _popupTargetPosition;
  int? _cachedMembersValue;

  double get _left => widget.leftPadding ?? _chartPaddingLeft;

  int get _maxValue => widget.scale.top(widget.data.map((item) => item.totalMembers).reduce(math.max));

  @override
  void initState()
  {
    super.initState();
    _ticker = createTicker(_tick);
    _fills.reset(widget.data.length);
  }

  @override
  void didUpdateWidget(covariant TrendLineChart oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data.length != widget.data.length)
    {
      _fills.reset(widget.data.length);
    }
  }

  @override
  void dispose()
  {
    _ticker.dispose();
    _fills.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed)
  {
    final step = (elapsed - _lastTick).inMicroseconds / _hoverFill.inMicroseconds;

    _lastTick = elapsed;

    if (_fills.advance(_hoveredIndex, step))
    {
      _ticker.stop();
    }
  }

  _Columns _columnsOf(BoxConstraints constraints)
  {
    return _Columns(
      left: _left,
      width: constraints.maxWidth - _left,
      count: widget.data.length,
      bars: widget.bars,
    );
  }

  List<Offset> _computePoints(BoxConstraints constraints, int maxValue)
  {
    final _Columns columns = _columnsOf(constraints);
    final chartHeight = constraints.maxHeight - _chartPaddingBottom;

    return [
      for (var i = 0; i < widget.data.length; i++)
        Offset(
          columns.xOf(i.toDouble()),
          chartHeight - ((widget.data[i].totalMembers / maxValue) * chartHeight),
        ),
    ];
  }

  int? _pointNearest(List<Offset> points, Offset position, _Columns columns)
  {
    // The whole column answers, so moving across bars never drops the popup.
    if (widget.bars)
    {
      final int slot = ((position.dx - columns.left) / columns.step).floor();

      return position.dx >= columns.left && slot < points.length ? slot : null;
    }

    for (var i = 0; i < points.length; i++)
    {
      if ((points[i] - position).distance < _hoverRadius)
      {
        return i;
      }
    }

    return null;
  }

  void _onHover(Offset position, List<Offset> points, _Columns columns)
  {
    _hover(_pointNearest(points, position, columns), points);
  }

  void _hover(int? foundIndex, List<Offset> points)
  {
    if (foundIndex == _hoveredIndex)
    {
      return;
    }

    setState(()
    {
      _hoveredIndex = foundIndex;

      // Target and value survive pointer exit, so the popup fades out in place.
      if (foundIndex != null)
      {
        _popupTargetPosition = points[foundIndex];
        _cachedMembersValue = widget.data[foundIndex].totalMembers;
      }
    });

    if (widget.bars && !_ticker.isActive)
    {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final maxValue = _maxValue;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final points = _computePoints(constraints, maxValue);
        final _Columns columns = _columnsOf(constraints);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: MouseRegion(
                onHover: (event) => _onHover(event.localPosition, points, columns),
                onExit: (_) => _hover(null, points),
                child: TrendBandBuilder(
                  span: widget.span,
                  count: widget.data.length,
                  builder: (context, band) => CustomPaint(
                    size: Size.infinite,
                    painter: _TrendLineChartPainter(
                      data: widget.data,
                      maxValue: maxValue,
                      isMonthly: widget.isMonthly,
                      band: band,
                      left: _left,
                      scale: widget.scale,
                      bars: widget.bars,
                      fills: _fills,
                    ),
                  ),
                ),
              ),
            ),
            if (_popupTargetPosition != null)
              ChartValuePopup(
                target: _popupTargetPosition!,
                text: widget.scale.point(_cachedMembersValue ?? 0),
                isVisible: _hoveredIndex != null,
              ),
          ],
        );
      },
    );
  }
}

class _TrendLineChartPainter extends CustomPainter
{
  final List<MemberTrendItem> data;
  final int maxValue;
  final bool isMonthly;
  final TrendBand band;
  final double left;
  final TrendScale scale;
  final bool bars;
  final ChartFillLevels fills;

  _TrendLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.isMonthly,
    required this.band,
    required this.left,
    required this.scale,
    required this.bars,
    required this.fills,
  }) : super(repaint: fills);

  String _labelFor(MemberTrendItem item)
  {
    if (!isMonthly)
    {
      return '${item.year}';
    }

    return '${monthAbbreviations[(item.month ?? 1) - 1]}\n${item.year}';
  }

  // The last point is always labelled; a stride label too close to it is dropped.
  ({Set<int> indices, int stride}) _visibleLabels(_Columns columns)
  {
    if (data.length <= 1)
    {
      return (indices: {0}, stride: 1);
    }

    final sampleText = isMonthly ? '${monthAbbreviations[0]}\n9999' : '9999';
    final samplePainter = TextPainter(
      text: TextSpan(text: sampleText, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final neededWidth = samplePainter.width + _labelGap;
    samplePainter.dispose();

    final double stepX = columns.step;
    var stride = 1;

    if (stepX > 0 && neededWidth > stepX)
    {
      stride = (neededWidth / stepX).ceil();
    }

    final indices = <int>[for (var i = 0; i < data.length; i += stride) i];
    final lastIndex = data.length - 1;

    if (indices.isNotEmpty && indices.last == lastIndex)
    {
      return (indices: indices.toSet(), stride: stride);
    }

    if (indices.isNotEmpty)
    {
      final lastRegularX = columns.xOf(indices.last.toDouble());
      final trueLastX = columns.xOf(lastIndex.toDouble());

      if ((trueLastX - lastRegularX) < neededWidth)
      {
        indices.removeLast();
      }
    }

    indices.add(lastIndex);

    return (indices: indices.toSet(), stride: stride);
  }

  Rect _bandRect(Size size, _Columns columns, double chartHeight)
  {
    // Where a line chart's band ends past the first and the last month, so stacked bands line up.
    final _Columns line = _Columns(left: left, width: columns.width, count: columns.count, bars: false);
    final double first = math.max(line.xOf(-0.5), left - _bandOverhangLeft);
    final double last = math.min(line.xOf(columns.count - 0.5), size.width + _bandOverhangRight);

    if (!bars)
    {
      return Rect.fromLTRB(
        math.max(columns.xOf(band.start), first),
        -_bandAbove,
        math.min(columns.xOf(band.end), last),
        chartHeight + _bandBelow,
      );
    }

    // Bars end within the plot: the outer edges reach the line's as the band arrives there.
    final double toFirst = (0.5 - band.start).clamp(0.0, 1.0);
    final double toLast = (band.end - (columns.count - 1.5)).clamp(0.0, 1.0);

    return Rect.fromLTRB(
      columns.xOf(band.start) + (first - left) * toFirst,
      -_bandAbove,
      columns.xOf(band.end) + (last - size.width) * toLast,
      chartHeight + _bandBelow,
    );
  }

  TextStyle _monthStyle(int index, double alpha)
  {
    final bool marked = band.marks(index);

    return _labelStyle.copyWith(
      color: (marked ? AppTheme.trialOcean : AppTheme.trialMutedText).withValues(alpha: alpha),
      fontWeight: marked ? FontWeight.w800 : null,
    );
  }

  void _paintGrid(Canvas canvas, Size size, double chartHeight, TextPainter textPainter)
  {
    final gridPaint = Paint()
      ..color = AppTheme.trialLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= gridDivisions; i++)
    {
      final y = chartHeight - (i * (chartHeight / gridDivisions));
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);

      textPainter.text = TextSpan(
        text: scale.axis(((maxValue / gridDivisions) * i).round()),
        style: _labelStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(left - textPainter.width - _labelGap, y - 6));
    }
  }

  void _paintArea(Canvas canvas, Path linePath, List<Offset> points, double chartWidth, double chartHeight)
  {
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.chartOcean.withValues(alpha: 0.18),
            AppTheme.chartOcean.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(left, 0, chartWidth, chartHeight)),
    );
  }

  // Grey outside the band and the gradient inside, cut where the band's edge passes as it slides.
  void _paintBars(Canvas canvas, List<Offset> tops, _Columns columns, double chartHeight, Rect bandRect)
  {
    final double width = columns.step * _barWidthRatio;
    final List<(int, RRect)> shown = [
      for (var i = 0; i < data.length; i++)
        if (data[i].totalMembers > 0)
          (
            i,
            RRect.fromRectAndRadius(
              Rect.fromLTRB(tops[i].dx - width / 2, tops[i].dy, tops[i].dx + width / 2, chartHeight),
              const Radius.circular(_barRadius),
            ),
          ),
    ];

    canvas.save();
    canvas.clipRect(bandRect, clipOp: ClipOp.difference);

    for (final (_, bar) in shown)
    {
      canvas.drawRRect(bar, Paint()..color = AppTheme.chartGrayLight);
    }

    canvas.restore();
    canvas.save();
    canvas.clipRect(bandRect);

    for (final (_, bar) in shown)
    {
      canvas.drawRRect(bar, Paint()..shader = AppTheme.chartBarGradient.createShader(bar.outerRect));
    }

    canvas.restore();

    for (final (index, bar) in shown)
    {
      final double highlight = fills.eased(index);

      if (highlight <= 0)
      {
        continue;
      }

      final Rect rect = bar.outerRect;

      canvas.save();
      canvas.clipRRect(bar);
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.bottom - rect.height * highlight, rect.right, rect.bottom),
        Paint()..color = band.covers(index) ? AppTheme.chartLilac : AppTheme.chartGray,
      );
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    if (data.isEmpty)
    {
      return;
    }

    final chartWidth = size.width - left;
    final chartHeight = size.height - _chartPaddingBottom;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final _Columns columns = _Columns(left: left, width: chartWidth, count: data.length, bars: bars);
    final bandRect = _bandRect(size, columns, chartHeight);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bandRect, const Radius.circular(_bandRadius)),
      Paint()..color = AppTheme.chartOcean.withValues(alpha: _bandAlpha * band.strength),
    );

    _paintGrid(canvas, size, chartHeight, textPainter);

    final labels = _visibleLabels(columns);
    final points = <Offset>[];

    for (var i = 0; i < data.length; i++)
    {
      final x = columns.xOf(i.toDouble());
      final y = chartHeight - ((data[i].totalMembers / maxValue) * chartHeight);
      points.add(Offset(x, y));

      final labelAlpha = band.labelAlpha(i, labels.indices, labels.stride);

      if (labelAlpha > 0)
      {
        textPainter.text = TextSpan(text: _labelFor(data[i]), style: _monthStyle(i, labelAlpha));
        textPainter.textAlign = TextAlign.center;
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - (textPainter.width / 2), chartHeight + _labelGap),
        );
      }
    }

    if (bars)
    {
      _paintBars(canvas, points, columns, chartHeight, bandRect);
      textPainter.dispose();

      return;
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++)
    {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.clipRect(bandRect, clipOp: ClipOp.difference);
    canvas.drawPath(linePath, linePaint..color = AppTheme.chartGrayLight);
    canvas.restore();

    canvas.save();
    canvas.clipRect(bandRect);
    canvas.drawPath(
      linePath,
      linePaint
        ..shader = AppTheme.chartLineGradient.createShader(
          Rect.fromLTWH(left, 0, chartWidth, chartHeight),
        ),
    );
    _paintArea(canvas, linePath, points, chartWidth, chartHeight);
    canvas.restore();

    for (var i = 0; i < points.length; i++)
    {
      final point = points[i];
      final color = band.covers(i)
          ? chartLineColorAt((point.dx - left) / chartWidth)
          : AppTheme.chartGrayLight;
      canvas.drawCircle(point, 5, Paint()..color = color);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }

    textPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _TrendLineChartPainter oldDelegate)
  {
    return oldDelegate.data != data ||
        oldDelegate.band != band ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.left != left ||
        oldDelegate.bars != bars ||
        oldDelegate.scale != scale;
  }
}