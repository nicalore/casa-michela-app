import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import 'chart_common.dart';
import 'chart_value_popup.dart';

const Color _barColor = Color(0xFF0284C7);

// Width reserved for the Y axis, which is painted outside the scrollable area so
// the labels stay visible while the bars scroll.
const double _yAxisWidth = 45.0;

// Room below the plot for the category labels. Shared by the widget and the
// painter: if they disagree, the bars and their labels drift apart.
const double _plotBottomPadding = 40.0;

// Below this the bars become unreadable, so the plot starts scrolling
// horizontally instead of shrinking further.
const double _minBarSlotWidth = 75.0;

const double _barWidthRatio = 0.6;
const double _labelFontSize = 13;

class BarChart extends StatefulWidget
{
  final List<ChartDatum> data;

  const BarChart({super.key, required this.data});

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart>
{
  Offset? _popupTarget;
  int? _hoveredIndex;
  String? _popupText;

  int get _total => widget.data.fold(0, (sum, item) => sum + item.count);

  List<Rect> _computeBarRects(double innerWidth, double chartHeight, int maxValue)
  {
    final stepX = innerWidth / widget.data.length;
    final barWidth = stepX * _barWidthRatio;

    return [
      for (var i = 0; i < widget.data.length; i++)
        () {
          final barHeight = (widget.data[i].count / maxValue) * chartHeight;
          final left = (i * stepX) + (stepX / 2) - (barWidth / 2);

          return Rect.fromLTWH(left, chartHeight - barHeight, barWidth, barHeight);
        }(),
    ];
  }

  void _onHover(Offset position, List<Rect> barRects)
  {
    int? foundIndex;

    for (var i = 0; i < barRects.length; i++)
    {
      if (barRects[i].contains(position))
      {
        foundIndex = i;
        break;
      }
    }

    setState(()
    {
      _hoveredIndex = foundIndex;

      // Target and text survive the pointer leaving the bar, so the popup can
      // fade out in place instead of jumping.
      if (foundIndex != null)
      {
        final datum = widget.data[foundIndex];
        final share = _total == 0 ? 0.0 : datum.count / _total * 100;

        _popupTarget = Offset(barRects[foundIndex].center.dx, barRects[foundIndex].top);
        _popupText = '${datum.label}: ${datum.count} (${share.toStringAsFixed(1)}%)';
      }
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final maxValue = chartMaxValue(widget.data.map((item) => item.count).reduce(math.max));

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final innerWidth = math.max(
          constraints.maxWidth - _yAxisWidth,
          widget.data.length * _minBarSlotWidth,
        );

        final chartHeight = constraints.maxHeight - _plotBottomPadding;
        final barRects = _computeBarRects(innerWidth, chartHeight, maxValue);

        return Row(
          children: [
            SizedBox(
              width: _yAxisWidth,
              child: CustomPaint(
                size: Size(_yAxisWidth, constraints.maxHeight),
                painter: _YAxisPainter(maxValue: maxValue),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: innerWidth,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: MouseRegion(
                          onHover: (event) => _onHover(event.localPosition, barRects),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _BarChartPainter(
                              data: widget.data,
                              barRects: barRects,
                              hoveredIndex: _hoveredIndex,
                            ),
                          ),
                        ),
                      ),
                      if (_popupTarget != null)
                        ChartValuePopup(
                          target: _popupTarget!,
                          text: _popupText ?? '',
                          isVisible: _hoveredIndex != null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Painted in its own non scrolling column, so the scale stays readable while the
// bars scroll sideways.
class _YAxisPainter extends CustomPainter
{
  final int maxValue;

  _YAxisPainter({required this.maxValue});

  @override
  void paint(Canvas canvas, Size size)
  {
    final gridPaint = Paint()
      ..color = AppTheme.slate200
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
        style: GoogleFonts.plusJakartaSans(color: AppTheme.slate400, fontSize: _labelFontSize),
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

  _BarChartPainter({
    required this.data,
    required this.barRects,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size)
  {
    final gridPaint = Paint()
      ..color = AppTheme.slate200
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final chartHeight = size.height - _plotBottomPadding;

    for (var i = 0; i <= gridDivisions; i++)
    {
      final y = chartHeight - (i * (chartHeight / gridDivisions));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final barPaint = Paint()
      ..color = _barColor
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < barRects.length; i++)
    {
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRects[i], const Radius.circular(6)),
        barPaint,
      );

      textPainter.text = TextSpan(
        text: data[i].label,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.slate400,
          fontSize: _labelFontSize,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.textAlign = TextAlign.center;
      textPainter.maxLines = 1;
      textPainter.ellipsis = '...';
      textPainter.layout(maxWidth: size.width / data.length);
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
    return oldDelegate.hoveredIndex != hoveredIndex || oldDelegate.data != data;
  }
}