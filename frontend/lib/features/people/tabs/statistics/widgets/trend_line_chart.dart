import 'dart:math' as math;
import 'dart:ui' show ClipOp;

import 'package:flutter/material.dart';
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

class TrendLineChart extends StatefulWidget
{
  final List<MemberTrendItem> data;
  final bool isMonthly;

  // The months of the chosen period; null marks none.
  final TrendSpan? span;

  const TrendLineChart({required this.data, required this.isMonthly, this.span, super.key});

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart>
{
  static const double _hoverRadius = 16.0;

  int? _hoveredIndex;
  Offset? _popupTargetPosition;
  int? _cachedMembersValue;

  int get _maxValue =>
      chartMaxValue(widget.data.map((item) => item.totalMembers).reduce(math.max));

  List<Offset> _computePoints(BoxConstraints constraints, int maxValue)
  {
    final chartWidth = constraints.maxWidth - _chartPaddingLeft;
    final chartHeight = constraints.maxHeight - _chartPaddingBottom;
    final stepX = widget.data.length > 1
        ? chartWidth / (widget.data.length - 1)
        : chartWidth / 2;

    return [
      for (var i = 0; i < widget.data.length; i++)
        Offset(
          _chartPaddingLeft + (i * stepX),
          chartHeight - ((widget.data[i].totalMembers / maxValue) * chartHeight),
        ),
    ];
  }

  int? _pointNearest(List<Offset> points, Offset position)
  {
    for (var i = 0; i < points.length; i++)
    {
      if ((points[i] - position).distance < _hoverRadius)
      {
        return i;
      }
    }

    return null;
  }

  void _onHover(Offset position, List<Offset> points)
  {
    final foundIndex = _pointNearest(points, position);

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
  }

  @override
  Widget build(BuildContext context)
  {
    final maxValue = _maxValue;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final points = _computePoints(constraints, maxValue);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: MouseRegion(
                onHover: (event) => _onHover(event.localPosition, points),
                onExit: (_) => setState(() => _hoveredIndex = null),
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
                    ),
                  ),
                ),
              ),
            ),
            if (_popupTargetPosition != null)
              ChartValuePopup(
                target: _popupTargetPosition!,
                text: '${_cachedMembersValue ?? 0}',
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
  static const double _labelFontSize = 13;
  static const double _labelGap = 8;

  final List<MemberTrendItem> data;
  final int maxValue;
  final bool isMonthly;
  final TrendBand band;

  _TrendLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.isMonthly,
    required this.band,
  });

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
        color: AppTheme.trialMutedText,
        fontSize: _labelFontSize,
      );

  String _labelFor(MemberTrendItem item)
  {
    if (!isMonthly)
    {
      return '${item.year}';
    }

    return '${monthAbbreviations[(item.month ?? 1) - 1]}\n${item.year}';
  }

  // The last point is always labelled; a stride label too close to it is dropped.
  ({Set<int> indices, int stride}) _visibleLabels(double stepX)
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
      final lastRegularX = _chartPaddingLeft + (indices.last * stepX);
      final trueLastX = _chartPaddingLeft + (lastIndex * stepX);

      if ((trueLastX - lastRegularX) < neededWidth)
      {
        indices.removeLast();
      }
    }

    indices.add(lastIndex);

    return (indices: indices.toSet(), stride: stride);
  }

  Rect _bandRect(Size size, double stepX, double chartHeight)
  {
    return Rect.fromLTRB(
      math.max(_chartPaddingLeft + band.start * stepX, _chartPaddingLeft - _bandOverhangLeft),
      -_bandAbove,
      math.min(_chartPaddingLeft + band.end * stepX, size.width + _bandOverhangRight),
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
      canvas.drawLine(Offset(_chartPaddingLeft, y), Offset(size.width, y), gridPaint);

      textPainter.text = TextSpan(
        text: '${((maxValue / gridDivisions) * i).round()}',
        style: _labelStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(_chartPaddingLeft - textPainter.width - _labelGap, y - 6));
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
        ).createShader(Rect.fromLTWH(_chartPaddingLeft, 0, chartWidth, chartHeight)),
    );
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    if (data.isEmpty)
    {
      return;
    }

    final chartWidth = size.width - _chartPaddingLeft;
    final chartHeight = size.height - _chartPaddingBottom;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final stepX = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth / 2;
    final bandRect = _bandRect(size, stepX, chartHeight);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bandRect, const Radius.circular(_bandRadius)),
      Paint()..color = AppTheme.chartOcean.withValues(alpha: _bandAlpha * band.strength),
    );

    _paintGrid(canvas, size, chartHeight, textPainter);

    final labels = _visibleLabels(stepX);
    final points = <Offset>[];

    for (var i = 0; i < data.length; i++)
    {
      final x = _chartPaddingLeft + (i * stepX);
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
          Rect.fromLTWH(_chartPaddingLeft, 0, chartWidth, chartHeight),
        ),
    );
    _paintArea(canvas, linePath, points, chartWidth, chartHeight);
    canvas.restore();

    for (var i = 0; i < points.length; i++)
    {
      final point = points[i];
      final color = band.covers(i)
          ? chartLineColorAt((point.dx - _chartPaddingLeft) / chartWidth)
          : AppTheme.chartGrayLight;
      canvas.drawCircle(point, 5, Paint()..color = color);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }

    textPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _TrendLineChartPainter oldDelegate)
  {
    return oldDelegate.data != data || oldDelegate.band != band;
  }
}