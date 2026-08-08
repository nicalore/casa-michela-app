import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../models/member_trend_item.dart';
import 'chart_common.dart';
import 'chart_value_popup.dart';
import 'stats_constants.dart';

// Chart geometry shared by the hit testing widget and the painter: if these
// drift apart the hover targets no longer sit on the drawn points.
const double _chartPaddingLeft = 40.0;
const double _chartPaddingBottom = 30.0;

class TrendLineChart extends StatefulWidget
{
  final List<MemberTrendItem> data;
  final bool isMonthly;

  const TrendLineChart({required this.data, required this.isMonthly, super.key});

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart>
{
  static const double _hoverRadius = 16.0;

  Offset? _hoverPosition;
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

    setState(()
    {
      _hoverPosition = position;
      _hoveredIndex = foundIndex;

      // The target and the value survive the pointer leaving the point, so the
      // popup can fade out in place instead of jumping.
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
                onExit: (_) => setState(()
                {
                  _hoverPosition = null;
                  _hoveredIndex = null;
                }),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TrendLineChartPainter(
                    data: widget.data,
                    maxValue: maxValue,
                    isMonthly: widget.isMonthly,
                    hoverPosition: _hoverPosition,
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
  final Offset? hoverPosition;

  _TrendLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.isMonthly,
    this.hoverPosition,
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

  // Picks which points get a label, based on how much room each one has versus
  // the width of a representative label.
  //
  // The last point is always labelled, to give context on the most recent
  // period. When the fixed stride would place the previous label too close to
  // it, that previous one is dropped rather than letting the two overlap.
  Set<int> _visibleLabelIndices(double stepX)
  {
    if (data.length <= 1)
    {
      return {0};
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
      return indices.toSet();
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

    return indices.toSet();
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
            AppTheme.trialTurquoise.withValues(alpha: 0.22),
            AppTheme.trialTurquoise.withValues(alpha: 0.0),
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

    _paintGrid(canvas, size, chartHeight, textPainter);

    final stepX = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth / 2;
    final labelIndices = _visibleLabelIndices(stepX);
    final points = <Offset>[];

    for (var i = 0; i < data.length; i++)
    {
      final x = _chartPaddingLeft + (i * stepX);
      final y = chartHeight - ((data[i].totalMembers / maxValue) * chartHeight);
      points.add(Offset(x, y));

      if (labelIndices.contains(i))
      {
        textPainter.text = TextSpan(text: _labelFor(data[i]), style: _labelStyle);
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

    // The line runs the brand ramp along its own length, deep teal where the
    // series starts into turquoise where it arrives — the same pair the buttons
    // and the bars are made of, laid the way this chart is read.
    canvas.drawPath(
      linePath,
      Paint()
        ..shader = AppTheme.brandGradient.createShader(
          Rect.fromLTWH(_chartPaddingLeft, 0, chartWidth, chartHeight),
        )
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _paintArea(canvas, linePath, points, chartWidth, chartHeight);

    for (final point in points)
    {
      canvas.drawCircle(point, 5, Paint()..color = AppTheme.trialTealDeep);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }

    textPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _TrendLineChartPainter oldDelegate)
  {
    return oldDelegate.hoverPosition != hoverPosition || oldDelegate.data != data;
  }
}